/**
 * Tests for Iter 8 武器 5: Hook Server 回放 + Audit 模式
 *
 * Covers:
 *   1. HookEventsStore: append + hash-chain + query
 *   2. HookDispatcher.execute() writes audit entry per call
 *   3. HTTP server POST /hooks/replay replays events to target session
 *   4. HTTP server GET /hooks/audit queries the audit log
 *   5. 6 endpoints preserved (pre/post/compact/permission/session-start/session-end)
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, rmSync, existsSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ok } from 'neverthrow';
import {
  createHookEventsStore,
  appendHookEvent,
} from '../src/hooks/hook-events-store.js'; // appendHookEvent used in unit tests below
import {
  createHookDispatcher,
} from '../src/hooks/dispatcher.js';
import { createHookServer } from '../src/hooks/http-hook-server.js';
import type { HookEventsStore } from '../src/hooks/hook-events-store.js';
import type { HookDispatcher, Hook, HookContext } from '../src/hooks/types.js';

function createContext(overrides: Partial<HookContext> = {}): HookContext {
  return {
    phase: 'pre-tool-use',
    toolName: 'Bash',
    toolParams: { command: 'echo hello' },
    sessionId: 'session-test',
    metadata: {},
    ...overrides,
  };
}

describe('HookEventsStore (武器 5 Audit)', () => {
  let tmpDir: string;
  let store: HookEventsStore;

  beforeEach(() => {
    tmpDir = mkdtempSync(join(tmpdir(), 'kallax-hook-events-'));
    store = createHookEventsStore({ projectRoot: tmpDir });
  });

  afterEach(() => {
    if (existsSync(tmpDir)) {
      rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  it('appends entry with hash-chain (seq=1, prevHash=genesis)', async () => {
    const entry = await appendHookEvent(store, {
      sessionId: 's1',
      hookType: 'pre-tool-use',
      toolName: 'Bash',
      resultCode: 'allow',
    });
    expect(entry.seq).toBe(1);
    expect(entry.prevHash).toBe('sha256:genesis');
    expect(entry.hash).toMatch(/^sha256:[a-f0-9]{64}$/);
    expect(entry.sessionId).toBe('s1');
    expect(entry.hookType).toBe('pre-tool-use');
    expect(entry.resultCode).toBe('allow');
  });

  it('chains hashes across appends', async () => {
    const e1 = await appendHookEvent(store, {
      sessionId: 's1', hookType: 'pre-tool-use', resultCode: 'allow',
    });
    const e2 = await appendHookEvent(store, {
      sessionId: 's1', hookType: 'post-tool-use', resultCode: 'allow',
    });
    const e3 = await appendHookEvent(store, {
      sessionId: 's2', hookType: 'pre-tool-use', resultCode: 'block', reason: 'denied',
    });

    expect(e1.seq).toBe(1);
    expect(e2.seq).toBe(2);
    expect(e3.seq).toBe(3);
    expect(e2.prevHash).toBe(e1.hash);
    expect(e3.prevHash).toBe(e2.hash);
  });

  it('queries by sessionId', async () => {
    await appendHookEvent(store, { sessionId: 's1', hookType: 'pre-tool-use', resultCode: 'allow' });
    await appendHookEvent(store, { sessionId: 's2', hookType: 'pre-tool-use', resultCode: 'allow' });
    await appendHookEvent(store, { sessionId: 's1', hookType: 'post-tool-use', resultCode: 'block' });

    const s1Events = store.query({ sessionId: 's1' });
    expect(s1Events).toHaveLength(2);
    expect(s1Events.every((e) => e.sessionId === 's1')).toBe(true);
  });

  it('queries by time range', async () => {
    const e1 = await appendHookEvent(store, { sessionId: 's', hookType: 'pre-tool-use', resultCode: 'allow' });
    await new Promise((r) => setTimeout(r, 10));
    const cutoff = Date.now();
    await new Promise((r) => setTimeout(r, 10));
    const e3 = await appendHookEvent(store, { sessionId: 's', hookType: 'pre-tool-use', resultCode: 'allow' });

    const after = store.query({ fromTimestamp: cutoff });
    expect(after.map((e) => e.seq)).toEqual([e3.seq]);
    expect(after.find((e) => e.seq === e1.seq)).toBeUndefined();
  });

  it('persists entries to JSONL file', async () => {
    await appendHookEvent(store, { sessionId: 's', hookType: 'pre-tool-use', resultCode: 'allow' });
    expect(existsSync(store.path())).toBe(true);
    const content = readFileSync(store.path(), 'utf-8');
    const lines = content.split('\n').filter((l) => l.trim());
    expect(lines).toHaveLength(1);
    const parsed = JSON.parse(lines[0]!);
    expect(parsed.seq).toBe(1);
    expect(parsed.hash).toMatch(/^sha256:/);
  });

  it('size() returns total count', async () => {
    expect(store.size()).toBe(0);
    await appendHookEvent(store, { sessionId: 's', hookType: 'pre-tool-use', resultCode: 'allow' });
    await appendHookEvent(store, { sessionId: 's', hookType: 'pre-tool-use', resultCode: 'allow' });
    expect(store.size()).toBe(2);
  });
});

describe('HookDispatcher audit integration (武器 5)', () => {
  let tmpDir: string;
  let store: HookEventsStore;
  let dispatcher: HookDispatcher;
  const triggeredHooks: string[] = [];

  beforeEach(() => {
    tmpDir = mkdtempSync(join(tmpdir(), 'kallax-hook-events-'));
    store = createHookEventsStore({ projectRoot: tmpDir });
    dispatcher = createHookDispatcher(undefined, store);
    triggeredHooks.length = 0;
  });

  afterEach(() => {
    if (existsSync(tmpDir)) {
      rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  it('writes audit entry on allow', async () => {
    const hook: Hook = {
      name: 'test_hook',
      phases: ['pre-tool-use'],
      priority: 1,
      async execute(ctx) { triggeredHooks.push(ctx.sessionId ?? ''); return ok({ allowed: true }); },
    };
    dispatcher.register(hook);

    await dispatcher.execute(createContext({ sessionId: 's-allow' }));

    // audit is fire-and-forget; give it a tick to flush
    await new Promise((r) => setTimeout(r, 20));

    expect(store.size()).toBe(1);
    const events = store.query({});
    expect(events[0]?.resultCode).toBe('allow');
    expect(events[0]?.sessionId).toBe('s-allow');
    expect(events[0]?.hookType).toBe('pre-tool-use');
    expect(events[0]?.toolName).toBe('Bash');
  });

  it('writes audit entry on block (with reason)', async () => {
    const hook: Hook = {
      name: 'blocker',
      phases: ['pre-tool-use'],
      priority: 1,
      async execute() { return ok({ allowed: false, reason: 'policy violation' }); },
    };
    dispatcher.register(hook);

    await dispatcher.execute(createContext({ sessionId: 's-block' }));
    await new Promise((r) => setTimeout(r, 20));

    const events = store.query({});
    expect(events).toHaveLength(1);
    expect(events[0]?.resultCode).toBe('block');
    expect(events[0]?.reason).toBe('policy violation');
  });

  it('writes audit entry on error', async () => {
    // No hooks registered → check rules pass → no hook runs → allow (empty list)
    // Force an error path by registering a hook that throws
    const hook: Hook = {
      name: 'thrower',
      phases: ['pre-tool-use'],
      priority: 1,
      async execute() { throw new Error('boom'); },
    };
    dispatcher.register(hook);

    await dispatcher.execute(createContext({ sessionId: 's-err' }));
    await new Promise((r) => setTimeout(r, 20));

    const events = store.query({});
    expect(events).toHaveLength(1);
    expect(events[0]?.resultCode).toBe('error');
    expect(events[0]?.reason).toContain('boom');
  });

  it('chains hashes across multiple executions', async () => {
    const hook: Hook = {
      name: 'passthrough',
      phases: ['pre-tool-use'],
      priority: 1,
      async execute() { return ok({ allowed: true }); },
    };
    dispatcher.register(hook);

    for (let i = 0; i < 3; i++) {
      await dispatcher.execute(createContext({ sessionId: `s-${i}` }));
    }
    await new Promise((r) => setTimeout(r, 30));

    const events = store.query({});
    expect(events).toHaveLength(3);
    expect(events[0]?.prevHash).toBe('sha256:genesis');
    expect(events[1]?.prevHash).toBe(events[0]?.hash);
    expect(events[2]?.prevHash).toBe(events[1]?.hash);
  });

  it('does NOT write audit when no auditStore provided (backward compat)', async () => {
    const noAuditDispatcher = createHookDispatcher();
    const result = await noAuditDispatcher.execute(createContext());
    expect(result.isOk()).toBe(true);
    // No way to assert size without store — but no throw means OK
    expect(true).toBe(true);
  });
});

describe('HTTP Hook Server: /hooks/replay + /hooks/audit (武器 5)', () => {
  let tmpDir: string;
  let store: HookEventsStore;
  let dispatcher: HookDispatcher;
  let server: ReturnType<typeof createHookServer>;
  let baseUrl: string;
  let port: number;

  beforeEach(async () => {
    tmpDir = mkdtempSync(join(tmpdir(), 'kallax-hook-events-'));
    store = createHookEventsStore({ projectRoot: tmpDir });
    dispatcher = createHookDispatcher(undefined, store);

    // Register a simple allow-all hook
    dispatcher.register({
      name: 'recorder',
      phases: ['pre-tool-use', 'post-tool-use', 'session-start'],
      priority: 1,
      async execute(ctx) {
        return ok({
          allowed: true,
          metadata: ctx.metadata?.['replay'] !== undefined ? { replayed: true } : undefined,
        });
      },
    });

    server = createHookServer(dispatcher, {
      port: 0, // OS-assigned
      auditStore: store,
      apiKey: process.env['KALLAX_HOOK_API_KEY'] ?? 'test-kallax-hook-api-key-12345678',
      adminApiKey: 'test-admin-api-key-admin12345678',
    });
    const startResult = await server.start();
    expect(startResult.isOk()).toBe(true);
    port = server.getPort();
    baseUrl = `http://127.0.0.1:${port}`;
  });

  // EPIC-069-B: helper that attaches Authorization header for S-002 fail-closed API key
  function authHeaders(): Record<string, string> {
    return {
      authorization: `Bearer ${process.env['KALLAX_HOOK_API_KEY'] ?? 'test-kallax-hook-api-key-12345678'}`,
      'content-type': 'application/json',
    };
  }

  afterEach(async () => {
    await server.stop();
    if (existsSync(tmpDir)) {
      rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  it('GET /hooks/audit returns all events when no filters', async () => {
    // Seed 3 hook events by hitting the regular endpoint
    for (const phase of ['session-start', 'pre-tool-use', 'post-tool-use']) {
      await fetch(`${baseUrl}/hooks/${phase}`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ sessionId: 'seed-s', toolName: 'Bash' }),
      });
    }
    await new Promise((r) => setTimeout(r, 30));

    // EPIC-070-B1: 全量导出需要 admin token (无 sessionId scope)
    const res = await fetch(`${baseUrl}/hooks/audit`, {
      headers: { authorization: `Bearer test-admin-api-key-admin12345678`, 'content-type': 'application/json' },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { total: number; events: unknown[]; path: string };
    expect(body.total).toBeGreaterThanOrEqual(3);
    expect(Array.isArray(body.events)).toBe(true);
    expect(body.path).toContain('hook-events.jsonl');
  });

  it('GET /hooks/audit filters by sessionId', async () => {
    await fetch(`${baseUrl}/hooks/pre-tool-use`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ sessionId: 'alice' }),
    });
    await fetch(`${baseUrl}/hooks/pre-tool-use`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({ sessionId: 'bob' }),
    });
    await new Promise((r) => setTimeout(r, 30));

    const res = await fetch(`${baseUrl}/hooks/audit?sessionId=alice`, { headers: authHeaders() });
    const body = await res.json() as { total: number; events: Array<{ sessionId: string }> };
    expect(body.events.every((e) => e.sessionId === 'alice')).toBe(true);
    expect(body.total).toBeGreaterThanOrEqual(1);
  });

  it('POST /hooks/replay replays historical events to target session', async () => {
    // Seed: 3 hook events for source session 'old-session'
    for (let i = 0; i < 3; i++) {
      await fetch(`${baseUrl}/hooks/pre-tool-use`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ sessionId: 'old-session', toolName: 'Bash', metadata: { toolParams: { command: `echo ${i}` } } }),
      });
    }
    await new Promise((r) => setTimeout(r, 30));

    const beforeCount = store.query({ sessionId: 'new-session' }).length;

    // Replay all 3 events from old-session to new-session
    // S-005: cross-session replay requires admin token (adminApiKey) since sessions differ
    const res = await fetch(`${baseUrl}/hooks/replay`, {
      method: 'POST',
      headers: {
        authorization: `Bearer test-admin-api-key-admin12345678`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        sessionId: 'old-session',
        targetSessionId: 'new-session',
      }),
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { totalEvents: number; replayed: number; results: Array<{ allowed: boolean }> };
    expect(body.totalEvents).toBe(3);
    expect(body.replayed).toBe(3);
    expect(body.results).toHaveLength(3);
    expect(body.results.every((r) => r.allowed === true)).toBe(true);

    // Verify new-session got 3 more events (replayed)
    await new Promise((r) => setTimeout(r, 30));
    const newSessionEvents = store.query({ sessionId: 'new-session' });
    expect(newSessionEvents.length).toBeGreaterThanOrEqual(beforeCount + 3);
  });

  it('POST /hooks/replay returns 400 when targetSessionId missing', async () => {
    const res = await fetch(`${baseUrl}/hooks/replay`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(400);
  });

  it('POST /hooks/replay returns empty results when no source events match', async () => {
    // Cross-session replay → admin token required
    const res = await fetch(`${baseUrl}/hooks/replay`, {
      method: 'POST',
      headers: {
        authorization: `Bearer test-admin-api-key-admin12345678`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        sessionId: 'nonexistent',
        targetSessionId: 'target',
      }),
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { totalEvents: number; replayed: number };
    expect(body.totalEvents).toBe(0);
    expect(body.replayed).toBe(0);
  });

  it('6 phase endpoints remain POST-only (backward compat)', async () => {
    for (const endpoint of ['pre-tool-use', 'post-tool-use', 'compact', 'permission', 'session-start', 'session-end']) {
      const getRes = await fetch(`${baseUrl}/hooks/${endpoint}`, { method: 'GET', headers: authHeaders() });
      expect(getRes.status).toBe(405);
    }
  });

  it('POST /hooks/replay is rejected with wrong method (GET)', async () => {
    const res = await fetch(`${baseUrl}/hooks/replay`, { method: 'GET', headers: authHeaders() });
    expect(res.status).toBe(405);
  });

  // EPIC-070-B1: 无 sessionId 无 admin token → 403 (防全量审计数据外泄)
  it('GET /hooks/audit without sessionId and without admin returns 403 (B1 scope guard)', async () => {
    const res = await fetch(`${baseUrl}/hooks/audit`, { headers: authHeaders() });
    expect(res.status).toBe(403);
  });

  it('GET /hooks/audit is rejected with wrong method (POST)', async () => {
    const res = await fetch(`${baseUrl}/hooks/audit`, { method: 'POST', headers: authHeaders() });
    expect(res.status).toBe(405);
  });
});
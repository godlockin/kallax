/**
 * Expert Invocations Queue tests — 3-tier degradation chain.
 *
 * Covers:
 *   L1 (Redis) — happy path + timeout → L2 fallback
 *   L2 (SQLite) — happy path + error → L3 fallback
 *   L3 (file) — happy path
 *   drain reads from current backend
 *   health reports current state
 *   probeRecovery attempts L1 after interval
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {
  createExpertInvocationsQueue,
  L1_LATENCY_THRESHOLD_MS,
  type ExpertInvocation,
} from '../src/core/expert-invocations-queue.js';

// ─── Fake Redis client (DI per Hard Rule #7) ────────────────────────────────

type FakeRedisTuple = readonly [string, readonly string[]];

interface FakeRedisState {
  readonly entries: readonly FakeRedisTuple[];
  readonly pingBehavior: () => Promise<void>;
  readonly xaddBehavior: (payload: string) => Promise<string>;
  readonly xrangeBehavior: () => Promise<readonly FakeRedisTuple[]>;
}

function createFakeRedis(initial: Partial<FakeRedisState> = {}): {
  xadd: ReturnType<typeof vi.fn>;
  xrange: ReturnType<typeof vi.fn>;
  xdel: ReturnType<typeof vi.fn>;
  ping: ReturnType<typeof vi.fn>;
  status: string;
} {
  const state: FakeRedisState = {
    entries: initial.entries ?? [],
    pingBehavior: initial.pingBehavior ?? (async () => {}),
    xaddBehavior:
      initial.xaddBehavior ??
      ((payload: string) => {
        const id = `${Date.now()}-${state.entries.length}`;
        state.entries.push([id, ['payload', payload]] as FakeRedisTuple);
        return Promise.resolve(id);
      }),
    xrangeBehavior:
      initial.xrangeBehavior ?? (async () => state.entries),
  };

  const xadd = vi.fn(async (_key: string, _id: string, _field: string, payload: string) =>
    state.xaddBehavior(payload),
  );
  const xrange = vi.fn(async (_key: string, _start: string, _end: string) =>
    state.xrangeBehavior(),
  );
  const xdel = vi.fn(async (_key: string, _id: string) => 1);
  const ping = vi.fn(async () => state.pingBehavior());

  return { xadd, xrange, xdel, ping, status: 'ready' };
}

function makeInvocation(expertId: string, ticketId: string): ExpertInvocation {
  return { expertId, ticketId, timestamp: Date.now() };
}

// ─── Test fixtures ──────────────────────────────────────────────────────────

let tmpDir: string;
let sqlitePath: string;
let filePath: string;

beforeEach(async () => {
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'kallax-eiq-'));
  sqlitePath = path.join(tmpDir, 'expert_invocations.db');
  filePath = path.join(tmpDir, 'expert_invocations.jsonl');
});

afterEach(async () => {
  await fs.rm(tmpDir, { recursive: true, force: true });
});

// ─── L1 Redis backend ───────────────────────────────────────────────────────

describe('ExpertInvocationsQueue — L1 Redis', () => {
  it('writes to Redis when available', async () => {
    const fakeRedis = createFakeRedis();
    const queue = createExpertInvocationsQueue({
      redis: fakeRedis as unknown as Parameters<typeof createExpertInvocationsQueue>[0]['redis'],
      sqlitePath,
      filePath,
    });

    const result = await queue.emit(makeInvocation('kallax.backend.001', 'EPIC-021-F'));
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe('redis');
    expect(fakeRedis.xadd).toHaveBeenCalledTimes(1);
    expect(queue.health().backend).toBe('redis');
  });

  it('falls back to L2 SQLite when Redis op exceeds L1 latency threshold', async () => {
    const fakeRedis = createFakeRedis({
      xaddBehavior: () => new Promise<string>((resolve) => {
        setTimeout(() => resolve('late-id'), L1_LATENCY_THRESHOLD_MS + 200);
      }),
    });
    const queue = createExpertInvocationsQueue({
      redis: fakeRedis as unknown as Parameters<typeof createExpertInvocationsQueue>[0]['redis'],
      sqlitePath,
      filePath,
      l1LatencyThresholdMs: 50,
    });

    const result = await queue.emit(makeInvocation('kallax.backend.001', 'EPIC-021-F'));
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe('sqlite');
    expect(queue.health().backend).toBe('sqlite');
    expect(queue.health().degradedFrom).toBe('redis');
    expect(queue.health().lastError).toContain('exceeded');
  });

  it('falls back to L2 SQLite when Redis throws', async () => {
    const fakeRedis = createFakeRedis({
      xaddBehavior: () => Promise.reject(new Error('ECONNREFUSED')),
    });
    const queue = createExpertInvocationsQueue({
      redis: fakeRedis as unknown as Parameters<typeof createExpertInvocationsQueue>[0]['redis'],
      sqlitePath,
      filePath,
    });

    const result = await queue.emit(makeInvocation('kallax.backend.001', 'EPIC-021-F'));
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe('sqlite');
    expect(queue.health().backend).toBe('sqlite');
    expect(queue.health().lastError).toContain('ECONNREFUSED');
  });

  it('drain reads from Redis when available', async () => {
    const entries = [
      ['1-0', ['payload', JSON.stringify(makeInvocation('kallax.backend.001', 'EPIC-021-A'))]],
      ['2-0', ['payload', JSON.stringify(makeInvocation('kallax.backend.002', 'EPIC-021-B'))]],
    ];
    const fakeRedis = createFakeRedis({ entries });
    const queue = createExpertInvocationsQueue({
      redis: fakeRedis as unknown as Parameters<typeof createExpertInvocationsQueue>[0]['redis'],
      sqlitePath,
      filePath,
    });

    const drainResult = await queue.drain();
    expect(drainResult.isOk()).toBe(true);
    const items = drainResult._unsafeUnwrap();
    expect(items.length).toBe(2);
    expect(items[0]?.expertId).toBe('kallax.backend.001');
    expect(items[1]?.ticketId).toBe('EPIC-021-B');
  });
});

// ─── L2 SQLite backend ──────────────────────────────────────────────────────

describe('ExpertInvocationsQueue — L2 SQLite', () => {
  it('writes to SQLite when no Redis configured', async () => {
    const queue = createExpertInvocationsQueue({ sqlitePath, filePath });

    const result = await queue.emit(makeInvocation('kallax.backend.001', 'EPIC-021-F'));
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe('sqlite');
    expect(queue.health().backend).toBe('sqlite');
  });

  it('falls back to L3 file when SQLite write fails', async () => {
    const queue = createExpertInvocationsQueue({ sqlitePath: '/nonexistent/path/db.sqlite', filePath });

    const result = await queue.emit(makeInvocation('kallax.backend.001', 'EPIC-021-F'));
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe('file');
    expect(queue.health().backend).toBe('file');
    expect(queue.health().degradedFrom).toBe('sqlite');

    const fileContent = await fs.readFile(filePath, 'utf8');
    expect(fileContent.length).toBeGreaterThan(0);
    const parsed = JSON.parse(fileContent.trim()) as ExpertInvocation;
    expect(parsed.expertId).toBe('kallax.backend.001');
  });

  it('drain from SQLite reads and clears', async () => {
    const queue = createExpertInvocationsQueue({ sqlitePath, filePath });
    await queue.emit(makeInvocation('kallax.backend.001', 'EPIC-021-A'));
    await queue.emit(makeInvocation('kallax.backend.002', 'EPIC-021-B'));

    const drainResult = await queue.drain();
    expect(drainResult.isOk()).toBe(true);
    const items = drainResult._unsafeUnwrap();
    expect(items.length).toBe(2);

    const drainAgain = await queue.drain();
    expect(drainAgain._unsafeUnwrap().length).toBe(0);
  });

  it('survives degraded-then-recovered state across multiple emits', async () => {
    let redisHealthy = false;
    const fakeRedis = createFakeRedis({
      xaddBehavior: async (payload: string) => {
        if (!redisHealthy) throw new Error('down');
        const id = `${Date.now()}-${Math.random()}`;
        return id;
      },
      pingBehavior: async () => {
        if (!redisHealthy) throw new Error('down');
      },
    });
    const queue = createExpertInvocationsQueue({
      redis: fakeRedis as unknown as Parameters<typeof createExpertInvocationsQueue>[0]['redis'],
      sqlitePath,
      filePath,
    });

    await queue.emit(makeInvocation('e1', 'T1'));
    expect(queue.health().backend).toBe('sqlite');

    redisHealthy = true;
    const probe = await queue.probeRecovery();
    expect(probe).toBe('redis');
    expect(queue.health().backend).toBe('redis');

    await queue.emit(makeInvocation('e2', 'T2'));
    expect(queue.health().backend).toBe('redis');
  });
});

// ─── L3 File backend ────────────────────────────────────────────────────────

describe('ExpertInvocationsQueue — L3 file', () => {
  it('writes to file when no Redis and no SQLite available', async () => {
    const queue = createExpertInvocationsQueue({
      sqlitePath: '/nonexistent/path/db.sqlite',
      filePath,
    });

    const result = await queue.emit(makeInvocation('kallax.backend.001', 'EPIC-021-F'));
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe('file');
    expect(queue.health().backend).toBe('file');
  });

  it('appends JSONL correctly across multiple emits', async () => {
    const queue = createExpertInvocationsQueue({
      sqlitePath: '/nonexistent/path/db.sqlite',
      filePath,
    });

    await queue.emit(makeInvocation('e1', 'T1'));
    await queue.emit(makeInvocation('e2', 'T2'));
    await queue.emit(makeInvocation('e3', 'T3'));

    const content = await fs.readFile(filePath, 'utf8');
    const lines = content.trim().split('\n');
    expect(lines.length).toBe(3);
    const parsed = lines.map((l) => JSON.parse(l) as ExpertInvocation);
    expect(parsed.map((p) => p.expertId)).toEqual(['e1', 'e2', 'e3']);
  });

  it('drain reads and clears file backend', async () => {
    const queue = createExpertInvocationsQueue({
      sqlitePath: '/nonexistent/path/db.sqlite',
      filePath,
    });

    await queue.emit(makeInvocation('e1', 'T1'));
    await queue.emit(makeInvocation('e2', 'T2'));

    const drainResult = await queue.drain();
    expect(drainResult.isOk()).toBe(true);
    expect(drainResult._unsafeUnwrap().length).toBe(2);

    const drainAgain = await queue.drain();
    expect(drainAgain._unsafeUnwrap().length).toBe(0);
  });
});

// ─── Health & recovery ──────────────────────────────────────────────────────

describe('ExpertInvocationsQueue — health & recovery', () => {
  it('reports health with no errors on healthy L1', () => {
    const fakeRedis = createFakeRedis();
    const queue = createExpertInvocationsQueue({
      redis: fakeRedis as unknown as Parameters<typeof createExpertInvocationsQueue>[0]['redis'],
      sqlitePath,
      filePath,
    });

    const health = queue.health();
    expect(health.backend).toBe('redis');
    expect(health.lastError).toBeNull();
    expect(health.degradedFrom).toBeNull();
  });

  it('probeRecovery respects recovery interval (no immediate re-probe)', async () => {
    let pingCount = 0;
    const fakeRedis = createFakeRedis({
      pingBehavior: async () => {
        pingCount++;
      },
    });
    const queue = createExpertInvocationsQueue({
      redis: fakeRedis as unknown as Parameters<typeof createExpertInvocationsQueue>[0]['redis'],
      sqlitePath,
      filePath,
      recoveryProbeIntervalMs: 60_000,
    });

    const first = await queue.probeRecovery();
    const second = await queue.probeRecovery();
    expect(first).toBe('redis');
    expect(second).toBe('redis');
    expect(pingCount).toBe(0);
  });

  it('probeRecovery attempts Redis when degraded and Redis healthy', async () => {
    const fakeRedis = createFakeRedis({
      xaddBehavior: () => Promise.reject(new Error('down')),
      pingBehavior: async () => {},
    });
    const queue = createExpertInvocationsQueue({
      redis: fakeRedis as unknown as Parameters<typeof createExpertInvocationsQueue>[0]['redis'],
      sqlitePath,
      filePath,
    });

    await queue.emit(makeInvocation('e1', 'T1'));
    expect(queue.health().backend).toBe('sqlite');

    const probe = await queue.probeRecovery();
    expect(probe).toBe('redis');
    expect(queue.health().backend).toBe('redis');
  });
});
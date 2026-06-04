/**
 * KALLAX E2E: Heartbeat + Dead Detection + Auto-Reassign
 *
 * Covers the full KALLAX P0 lifecycle:
 *   Performer sends heartbeats → server records → stale detection → task release
 *
 * Scenarios:
 *   1. Performer registers, sends heartbeats, DB updated
 *   2. Performer goes silent → detected as stale via API
 *   3. Stale performer's task released → other performer re-claims
 *   4. Multiple performers send heartbeats concurrently
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as http from 'node:http';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { ok } from 'neverthrow';
import { createSQLiteManager, type SQLiteManager } from '../../src/core/sqlite/index.js';
import { createApiServer, type ApiServer } from '../../src/api/server.js';
import { createTaskAssigner } from '../../src/core/task-assigner.js';
import { createInstanceRegistry } from '../../src/core/instance-registry.js';
import { createIsolationChecker } from '../../src/core/isolation-checker.js';
import { createSSEBus } from '../../src/core/sse-bus.js';
import { createOutputVerifier } from '../../src/core/output-verifier.js';
import { createHeartbeatClient } from '../../src/core/heartbeat-monitor.js';
import type { WorktreeManager } from '../../src/core/worktree-manager.js';
import type { Ticket, Instance, Task } from '../../src/types/index.js';
import { TaskStatus, InstanceRole, InstanceStatus } from '../../src/types/index.js';

let db: SQLiteManager;
let dbPath: string;
let server: ApiServer;
let baseUrl: string;

const PORT = 19878;
const API_KEY = 'kallax-dev-key';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function httpRequest(
  urlStr: string,
  options: http.RequestOptions = {},
  body?: unknown,
): Promise<{ status: number; data: unknown }> {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const opts: http.RequestOptions = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: options.method ?? 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-KALLAX-API-Key': API_KEY,
        ...options.headers,
      },
      ...options,
    };

    const req = http.request(opts, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode ?? 500, data: JSON.parse(body) });
        } catch {
          resolve({ status: res.statusCode ?? 500, data: body });
        }
      });
    });

    req.on('error', reject);
    if (body !== undefined) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

function makeTicket(overrides?: Partial<Ticket>): Ticket {
  const now = Date.now();
  return {
    id: `TICKET-HB-${Math.random().toString(36).slice(2, 8)}`,
    title: 'Heartbeat E2E Ticket',
    description: 'Integration test ticket for heartbeat dead detection',
    status: 'todo',
    priority: 'P2',
    assigneeId: null,
    createdAt: now,
    updatedAt: now,
    acceptanceCriteria: ['AC1: heartbeat recovery works'],
    labels: ['e2e', 'heartbeat'],
    ...overrides,
  } as Ticket;
}

function makeInstance(overrides?: Partial<Instance>): Instance {
  const now = Date.now();
  return {
    id: `inst-hb-${Math.random().toString(36).slice(2, 8)}`,
    role: InstanceRole.PERFORMER,
    status: InstanceStatus.ACTIVE,
    hostname: 'hb-e2e-host',
    pid: process.pid,
    startedAt: now,
    lastHeartbeat: now,
    currentTaskId: null,
    capabilities: ['typescript'],
    ...overrides,
  } as Instance;
}

async function startServer(dbManager: SQLiteManager): Promise<ApiServer> {
  const isolation = createIsolationChecker();
  const registry = createInstanceRegistry(dbManager);
  const sseBus = createSSEBus();
  const assigner = createTaskAssigner(dbManager, isolation, registry);

  const outputVerifier = createOutputVerifier({
    projectRoot: process.cwd(),
    testCommand: 'echo ok',
    lintCommand: 'echo ok',
  });

  const mockWorktreeManager: WorktreeManager = {
    create: async () => ok({ path: '/tmp/wt', branch: 'kallax/hb', commit: 'abc', taskId: 't' }),
    remove: async () => ok(undefined),
    list: async () => ok([]),
    getByTaskId: async () => ok(null),
    validateIsolation: async () => ok(true),
    getPath: () => '/tmp/wt',
  } as unknown as WorktreeManager;

  const srv = createApiServer(
    { port: PORT, host: '127.0.0.1', apiKey: API_KEY },
    {
      db: dbManager,
      taskAssigner: assigner,
      instanceRegistry: registry,
      worktreeManager: mockWorktreeManager,
      outputVerifier,
      isolationChecker: isolation,
      sseBus,
    },
  );

  await srv.start();
  return srv;
}

// Wait for a given number of milliseconds
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ---------------------------------------------------------------------------
// Setup / Teardown
// ---------------------------------------------------------------------------

beforeEach(async () => {
  dbPath = path.join(os.tmpdir(), `kallax-e2e-hb-${Date.now()}.db`);
  const result = createSQLiteManager({ path: dbPath });
  if (result.isErr()) throw new Error(`DB init failed: ${result.error.message}`);
  db = result.value;
  baseUrl = `http://127.0.0.1:${PORT}`;
});

afterEach(async () => {
  try { await server.stop(); } catch { /* ignore */ }
  try { db.close(); } catch { /* ignore */ }
  try { fs.unlinkSync(dbPath); } catch { /* ignore */ }
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('Heartbeat + Dead Detection (E2E)', () => {

  it('performer sends heartbeats and server records them in DB', async () => {
    server = await startServer(db);

    // Register performer via API
    const regRes = await httpRequest(
      `${baseUrl}/api/agents/register`,
      { method: 'POST' },
      { name: 'hb-performer', capabilities: ['typescript'] },
    );
    expect(regRes.status).toBe(201);
    const regBody = regRes.data as Record<string, unknown>;
    const agentId = (regBody.data as Record<string, unknown>).id as string;

    // Create heartbeat client with API key and send a few beats
    const client = createHeartbeatClient(baseUrl, API_KEY);
    const recordedTimestamp: number[] = [];
    client.startHeartbeat(agentId, null, 50); // very fast interval for testing

    // Wait for a few heartbeats to go through
    await sleep(350); // ~7 heartbeats at 50ms interval

    client.stopHeartbeat();

    // Verify DB reflects updated heartbeat (captured after heartbeats)
    const dbInstance = db.getInstance(agentId);
    expect(dbInstance.isOk()).toBe(true);
    if (dbInstance.isOk() && dbInstance.value) {
      const hb = dbInstance.value.lastHeartbeat;
      expect(hb).toBeGreaterThan(0);
      const afterBeat = Date.now();
      // Heartbeat should have occurred within last 2s
      expect(hb).toBeGreaterThan(afterBeat - 2000);
      expect(hb).toBeLessThanOrEqual(afterBeat);
    }

    // Client stats should show sent heartbeats with 0 errors
    const stats = client.getStats();
    expect(stats.heartbeatsSent).toBeGreaterThanOrEqual(1);
    expect(stats.errors).toBe(0);
    expect(stats.lastHeartbeatSent).not.toBeNull();
  });

  it('detects stale performer after heartbeats stop', async () => {
    server = await startServer(db);

    // Register performer
    const regRes = await httpRequest(
      `${baseUrl}/api/agents/register`,
      { method: 'POST' },
      { name: 'stale-performer', capabilities: ['go'] },
    );
    const regBody = regRes.data as Record<string, unknown>;
    const agentId = (regBody.data as Record<string, unknown>).id as string;

    // Send some heartbeats
    const client = createHeartbeatClient(baseUrl);
    client.startHeartbeat(agentId, null, 30);
    await sleep(150);
    client.stopHeartbeat();

    // Manually make instance stale by setting lastHeartbeat far in past
    const staleTime = Date.now() - 120000; // 2 minutes ago
    const updateResult = db.updateInstance(agentId, { lastHeartbeat: staleTime });
    expect(updateResult.isOk()).toBe(true);

    // Query heartbeat status with low threshold
    const statusRes = await httpRequest(
      `${baseUrl}/api/heartbeat/status?thresholdMs=100`,
    );
    expect(statusRes.status).toBe(200);
    const statusBody = statusRes.data as Record<string, unknown>;
    expect(statusBody.success).toBe(true);

    const entries = statusBody.data as Array<Record<string, unknown>>;
    const thisEntry = entries.find((e) => e.instanceId === agentId);
    expect(thisEntry).toBeDefined();
    expect(thisEntry!.isStale).toBe(true);

    // staleOnly filter returns only stale instances
    const staleOnlyRes = await httpRequest(
      `${baseUrl}/api/heartbeat/status?staleOnly=true&thresholdMs=100`,
    );
    const staleOnlyBody = staleOnlyRes.data as Record<string, unknown>;
    const staleEntries = staleOnlyBody.data as Array<Record<string, unknown>>;
    expect(staleEntries.length).toBeGreaterThanOrEqual(1);
    expect(staleEntries.every((e) => e.isStale === true)).toBe(true);
  });

  it('releases task from stale performer so another can claim', async () => {
    server = await startServer(db);
    const isolation = createIsolationChecker();
    const registry = createInstanceRegistry(db);
    const assigner = createTaskAssigner(db, isolation, registry);

    // Setup: ticket + task + performer A
    const ticket = makeTicket({ id: 'E2E-HB-RELEASE' });
    db.createTicket(ticket);
    const taskResult = assigner.createTask(ticket);
    expect(taskResult.isOk()).toBe(true);
    const taskId = taskResult.value.id;

    const perfA = makeInstance({ id: 'perf-hb-a' });
    db.registerInstance(perfA);

    // Performer A claims the task
    const claimA = db.claimTask(taskId, 'perf-hb-a');
    expect(claimA.isOk()).toBe(true);
    if (claimA.isOk()) expect(claimA.value).toBe(true);

    // Verify task is claimed by A
    const claimedTask = db.getTask(taskId);
    if (claimedTask.isOk() && claimedTask.value) {
      expect(claimedTask.value.performerId).toBe('perf-hb-a');
      expect(claimedTask.value.status).toBe(TaskStatus.CLAIMED);
    }

    // Simulate: performer A goes stale (heartbeat in past)
    const staleTime = Date.now() - 120000;
    db.updateInstance('perf-hb-a', { lastHeartbeat: staleTime });

    // Release task from stale performer
    const releaseResult = await assigner.releaseTask(taskId);
    expect(releaseResult.isOk()).toBe(true);

    // Verify task is released
    const releasedTask = db.getTask(taskId);
    if (releasedTask.isOk() && releasedTask.value) {
      expect(releasedTask.value.performerId).toBeNull();
      expect(releasedTask.value.status).toBe(TaskStatus.PENDING);
    }

    // Performer B can claim the released task
    const perfB = makeInstance({ id: 'perf-hb-b' });
    db.registerInstance(perfB);

    const claimB = db.claimTask(taskId, 'perf-hb-b');
    expect(claimB.isOk()).toBe(true);
    if (claimB.isOk()) expect(claimB.value).toBe(true);

    // Verify task is now claimed by B
    const reClaimedTask = db.getTask(taskId);
    if (reClaimedTask.isOk() && reClaimedTask.value) {
      expect(reClaimedTask.value.performerId).toBe('perf-hb-b');
      expect(reClaimedTask.value.status).toBe(TaskStatus.CLAIMED);
    }
  });

  it('multiple performers send heartbeats concurrently', async () => {
    server = await startServer(db);

    // Register 3 performers
    const agentIds: string[] = [];
    for (let i = 0; i < 3; i++) {
      const regRes = await httpRequest(
        `${baseUrl}/api/agents/register`,
        { method: 'POST' },
        { name: `concurrent-perf-${i}`, capabilities: ['rust'] },
      );
      expect(regRes.status).toBe(201);
      const regBody = regRes.data as Record<string, unknown>;
      const agentId = (regBody.data as Record<string, unknown>).id as string;
      agentIds.push(agentId);
    }

    // Create a client for each performer, all sending heartbeats concurrently
    const clients = agentIds.map((id) => {
      const c = createHeartbeatClient(baseUrl);
      c.startHeartbeat(id, null, 30);
      return c;
    });

    // Let them all send for a bit
    await sleep(200);

    // Stop all
    for (const c of clients) {
      c.stopHeartbeat();
    }

    // Verify all 3 performers have recent heartbeats in DB
    const before = Date.now() - 500;
    for (const id of agentIds) {
      const dbInstance = db.getInstance(id);
      expect(dbInstance.isOk()).toBe(true);
      if (dbInstance.isOk() && dbInstance.value) {
        expect(dbInstance.value.lastHeartbeat).toBeGreaterThanOrEqual(before);
      }
    }

    // No client should have errors
    for (const c of clients) {
      const stats = c.getStats();
      expect(stats.errors).toBe(0);
      expect(stats.heartbeatsSent).toBeGreaterThanOrEqual(1);
    }
  });
});

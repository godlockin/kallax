/**
 * KALLAX E2E: Claim Queue
 * Priority-based task dispatch with capability filtering.
 * Tests: priority ordering, capability matching, FIFO, reQueue, remove, stats.
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as http from 'node:http';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { ok } from 'neverthrow';
import { createClaimQueue, type ClaimQueue, type ClaimQueueItem } from '../../src/core/claim-queue.js';
import { createSQLiteManager, type SQLiteManager } from '../../src/core/sqlite/index.js';
import { createApiServer, type ApiServer } from '../../src/api/server.js';
import { createTaskAssigner } from '../../src/core/task-assigner.js';
import { createInstanceRegistry } from '../../src/core/instance-registry.js';
import { createIsolationChecker } from '../../src/core/isolation-checker.js';
import { createSSEBus } from '../../src/core/sse-bus.js';
import { createOutputVerifier } from '../../src/core/output-verifier.js';
import type { WorktreeManager } from '../../src/core/worktree-manager.js';
import type { Ticket } from '../../src/types/index.js';

// ============================================================================
// Helpers
// ============================================================================

function httpRequest(
  urlStr: string,
  options: http.RequestOptions = {},
  body?: unknown
): Promise<{ status: number; data: unknown }> {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const opts: http.RequestOptions = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: options.method ?? 'GET',
      agent: false,
      headers: {
        'Content-Type': 'application/json',
        'X-KALLAX-API-Key': 'kallax-dev-key',
        ...options.headers,
      },
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

// ============================================================================
// Unit Tests — ClaimQueue
// ============================================================================

describe('ClaimQueue (Unit)', () => {
  let queue: ClaimQueue;

  beforeEach(() => {
    queue = createClaimQueue();
  });

  it('returns null on dequeue from empty queue', () => {
    const item = queue.dequeue('perf-1', ['typescript']);
    expect(item).toBeNull();
  });

  it('returns highest priority task first', () => {
    queue.enqueue('task-p3', 'ticket-3', 10, []);
    queue.enqueue('task-p1', 'ticket-1', 1000, []);
    queue.enqueue('task-p2', 'ticket-2', 100, []);

    const first = queue.dequeue('perf-1', []);
    expect(first).not.toBeNull();
    expect(first!.taskId).toBe('task-p1');

    const second = queue.dequeue('perf-1', []);
    expect(second).not.toBeNull();
    expect(second!.taskId).toBe('task-p2');

    const third = queue.dequeue('perf-1', []);
    expect(third).not.toBeNull();
    expect(third!.taskId).toBe('task-p3');
  });

  it('respects FIFO order within same priority', () => {
    queue.enqueue('task-a', 'ticket-a', 100, []);
    queue.enqueue('task-b', 'ticket-b', 100, []);
    queue.enqueue('task-c', 'ticket-c', 100, []);

    const first = queue.dequeue('perf-1', []);
    expect(first!.taskId).toBe('task-a');

    const second = queue.dequeue('perf-1', []);
    expect(second!.taskId).toBe('task-b');

    const third = queue.dequeue('perf-1', []);
    expect(third!.taskId).toBe('task-c');
  });

  it('filters by performer capabilities', () => {
    queue.enqueue('task-ts', 'ticket-ts', 100, ['typescript']);
    queue.enqueue('task-py', 'ticket-py', 100, ['python']);
    queue.enqueue('task-gen', 'ticket-gen', 10, []);

    // Performer with only typescript can only get typescript or uncapped tasks
    const first = queue.dequeue('perf-ts', ['typescript']);
    expect(first).not.toBeNull();
    expect(first!.taskId).toBe('task-ts');

    const gen = queue.dequeue('perf-ts', ['typescript']);
    expect(gen).not.toBeNull();
    expect(gen!.taskId).toBe('task-gen');

    // python task should remain
    const py = queue.dequeue('perf-ts', ['typescript']);
    expect(py).toBeNull();
  });

  it('prefers highest priority within capability constraint', () => {
    queue.enqueue('task-high-nocap', 'ticket-hn', 1000, []);
    queue.enqueue('task-mid-ts', 'ticket-mt', 500, ['typescript']);
    queue.enqueue('task-low-py', 'ticket-lp', 10, ['python']);

    // Performer with python should get mid-ts first (higher priority > capability match)
    // Wait - priority is 500 for mid-ts which is higher than 10 for low-py but lower than 1000 for high-nocap.
    // Since the queue is sorted by priority, the order we scan is: high-nocap(1000), mid-ts(500), low-py(10).
    // But high-nocap has no required capabilities, so any performer can take it.
    // So python performer gets high-nocap first (priority 1000, no capability required).
    const first = queue.dequeue('perf-py', ['python']);
    expect(first).not.toBeNull();
    expect(first!.taskId).toBe('task-high-nocap');

    // Next: mid-ts requires typescript which perf-py doesn't have, so skip
    // low-py requires python which perf-py has
    const second = queue.dequeue('perf-py', ['python']);
    expect(second).not.toBeNull();
    expect(second!.taskId).toBe('task-low-py');
  });

  it('reQueue puts task back into queue', () => {
    queue.enqueue('task-1', 'ticket-1', 100, []);
    queue.enqueue('task-2', 'ticket-2', 10, []);

    const claimed = queue.dequeue('perf-1', []);
    expect(claimed!.taskId).toBe('task-1');

    // Re-queue the claimed task
    queue.reQueue('task-1');
    const stats = queue.stats();
    expect(stats.total).toBe(2);

    // Should be high priority again
    const reClaimed = queue.dequeue('perf-1', []);
    expect(reClaimed!.taskId).toBe('task-1');
  });

  it('reQueue is no-op for task still in queue', () => {
    queue.enqueue('task-1', 'ticket-1', 100, []);
    const before = queue.stats().total;
    queue.reQueue('task-1');
    expect(queue.stats().total).toBe(before);
  });

  it('reQueue is no-op for unknown task', () => {
    queue.reQueue('nonexistent');
    expect(queue.stats().total).toBe(0);
  });

  it('remove takes task out of queue', () => {
    queue.enqueue('task-1', 'ticket-1', 100, []);
    queue.enqueue('task-2', 'ticket-2', 10, []);
    expect(queue.stats().total).toBe(2);

    queue.remove('task-1');
    expect(queue.stats().total).toBe(1);

    const remaining = queue.dequeue('perf-1', []);
    expect(remaining!.taskId).toBe('task-2');
  });

  it('remove also cleans active claims (dequeued items)', () => {
    queue.enqueue('task-1', 'ticket-1', 100, []);
    queue.dequeue('perf-1', []);

    queue.remove('task-1');
    expect(queue.stats().pendingClaimCount).toBe(0);
  });

  it('stats returns correct counts and priority distribution', () => {
    queue.enqueue('task-p0', 'ticket-0', 1000, []);
    queue.enqueue('task-p1a', 'ticket-1a', 500, []);
    queue.enqueue('task-p1b', 'ticket-1b', 500, []);
    queue.enqueue('task-p2', 'ticket-2', 100, []);

    const stats = queue.stats();
    expect(stats.total).toBe(4);
    expect(stats.byPriority[1000]).toBe(1);
    expect(stats.byPriority[500]).toBe(2);
    expect(stats.byPriority[100]).toBe(1);
    expect(stats.pendingClaimCount).toBe(0);
  });

  it('stats includes pending claim count after dequeue', () => {
    queue.enqueue('task-1', 'ticket-1', 100, []);
    queue.dequeue('perf-1', []);
    expect(queue.stats().pendingClaimCount).toBe(1);
  });

  it('fires onTaskReleased callback when task is reQueued', () => {
    const released: Array<{ taskId: string; performerId: string }> = [];
    queue.onTaskReleased((item, performerId) => {
      released.push({ taskId: item.taskId, performerId });
    });

    queue.enqueue('task-1', 'ticket-1', 100, []);
    queue.dequeue('perf-1', []);
    queue.reQueue('task-1');

    expect(released.length).toBe(1);
    expect(released[0]!.taskId).toBe('task-1');
    expect(released[0]!.performerId).toBe('perf-1');
  });

  it('handles multiple capabilities — performer must have ALL required', () => {
    queue.enqueue('task-multi', 'ticket-multi', 100, ['typescript', 'react']);

    // Performer missing react
    const wrong = queue.dequeue('perf-ts', ['typescript']);
    expect(wrong).toBeNull();

    // Performer with both
    const right = queue.dequeue('perf-fullstack', ['typescript', 'react', 'node']);
    expect(right).not.toBeNull();
    expect(right!.taskId).toBe('task-multi');
  });
});

// ============================================================================
// E2E Tests — API Integration
// ============================================================================

describe('ClaimQueue API Integration (E2E)', () => {
  let db: SQLiteManager;
  let dbPath: string;
  let server: ApiServer;
  let baseUrl: string;
  let claimQueue: ClaimQueue;
  const PORT = 19879;
  const API_KEY = 'kallax-dev-key';

  async function startServer(): Promise<ApiServer> {
    const isolation = createIsolationChecker();
    const registry = createInstanceRegistry(db);
    const sseBus = createSSEBus();
    const assigner = createTaskAssigner(db, isolation, registry);

    const outputVerifier = createOutputVerifier({
      projectRoot: process.cwd(),
      testCommand: 'echo ok',
      lintCommand: 'echo ok',
    });

    const mockWorktreeManager: WorktreeManager = {
      create: async () => ok({ path: '/tmp/wt', branch: 'kallax/t', commit: 'abc', taskId: 't' }),
      remove: async () => ok(undefined),
      list: async () => ok([]),
      getByTaskId: async () => ok(null),
      validateIsolation: async () => ok(true),
      getPath: () => '/tmp/wt',
    } as unknown as WorktreeManager;

    const srv = createApiServer(
      { port: PORT, host: '127.0.0.1', apiKey: API_KEY },
      {
        db,
        taskAssigner: assigner,
        instanceRegistry: registry,
        worktreeManager: mockWorktreeManager,
        outputVerifier,
        isolationChecker: isolation,
        sseBus,
        claimQueue,
      },
    );

    await srv.start();
    return srv;
  }

  beforeEach(async () => {
    dbPath = path.join(os.tmpdir(), `kallax-claim-queue-${Date.now()}.db`);
    const result = createSQLiteManager({ path: dbPath });
    if (result.isErr()) throw new Error(`DB init failed: ${result.error.message}`);
    db = result.value;
    claimQueue = createClaimQueue();
    baseUrl = `http://127.0.0.1:${PORT}`;
  });

  afterEach(async () => {
    try { await server.stop(); } catch { /* ignore */ }
    try { db.close(); } catch { /* ignore */ }
    try { fs.unlinkSync(dbPath); } catch { /* ignore */ }
  });

  it('GET /api/tasks/next returns 400 without performerId', async () => {
    server = await startServer();
    const res = await httpRequest(`${baseUrl}/api/tasks/next`);
    expect(res.status).toBe(400);
    const body = res.data as Record<string, unknown>;
    expect(body.success).toBe(false);
    const err = body.error as Record<string, unknown>;
    expect(err.code).toBe('VALIDATION_ERROR');
  });

  it('GET /api/tasks/next returns null when queue is empty', async () => {
    server = await startServer();
    const res = await httpRequest(
      `${baseUrl}/api/tasks/next?performerId=perf-1&capabilities=typescript`
    );
    expect(res.status).toBe(200);
    const body = res.data as Record<string, unknown>;
    expect(body.success).toBe(true);
    expect(body.data).toBeNull();
  });

  it('GET /api/tasks/next claims task by priority from claim queue', async () => {
    server = await startServer();

    // Seed ticket directly via DB
    const now = Date.now();
    const ticket: Ticket = {
      id: 'CQ-E2E-TKT-001',
      title: 'Claim Queue Test',
      description: 'test',
      status: 'backlog',
      priority: 'P2',
      assigneeId: null,
      createdAt: now,
      updatedAt: now,
      acceptanceCriteria: ['AC1'],
      labels: ['typescript'],
    };
    db.createTicket(ticket);

    // Create task via API (auto-enqueues in claimQueue)
    const createRes = await httpRequest(
      `${baseUrl}/api/tasks`,
      { method: 'POST' },
      { ticketId: 'CQ-E2E-TKT-001', type: 'development' },
    );
    expect(createRes.status).toBe(201);

    // Also register performer
    const regRes = await httpRequest(
      `${baseUrl}/api/agents/register`,
      { method: 'POST' },
      { name: 'perf-cq', capabilities: ['typescript'] },
    );
    expect(regRes.status).toBe(201);
    const regBody = regRes.data as Record<string, unknown>;
    const perfData = regBody.data as Record<string, unknown>;
    const performerId = perfData.id as string;

    // Claim next task
    const claimRes = await httpRequest(
      `${baseUrl}/api/tasks/next?performerId=${performerId}&capabilities=typescript`
    );
    expect(claimRes.status).toBe(200);
    const claimBody = claimRes.data as Record<string, unknown>;
    expect(claimBody.success).toBe(true);
    const claimedTask = claimBody.data as Record<string, unknown>;
    expect(claimedTask).not.toBeNull();
    expect(claimedTask.performerId).toBe(performerId);
  });

  it('enqueues multiple priorities and returns via /tasks/next in order', async () => {
    server = await startServer();

    // Register performer
    const regRes = await httpRequest(
      `${baseUrl}/api/agents/register`,
      { method: 'POST' },
      { name: 'perf-prio', capabilities: ['test'] },
    );
    const regBody = regRes.data as Record<string, unknown>;
    const perfData = regBody.data as Record<string, unknown>;
    const performerId = perfData.id as string;

    // Manually enqueue tasks with different priorities
    claimQueue.enqueue('e2e-task-3', 'e2e-ticket-3', 10, []);
    claimQueue.enqueue('e2e-task-1', 'e2e-ticket-1', 1000, []);
    claimQueue.enqueue('e2e-task-2', 'e2e-ticket-2', 100, []);

    // Seed ticket in DB so assignTask can verify performer
    const now = Date.now();
    db.createTicket({
      id: 'e2e-ticket-1',
      title: 'High',
      description: '',
      status: 'backlog',
      priority: 'P0',
      assigneeId: null,
      createdAt: now,
      updatedAt: now,
      acceptanceCriteria: [],
      labels: [],
    });
    db.createTicket({
      id: 'e2e-ticket-2',
      title: 'Mid',
      description: '',
      status: 'backlog',
      priority: 'P1',
      assigneeId: null,
      createdAt: now,
      updatedAt: now,
      acceptanceCriteria: [],
      labels: [],
    });
    db.createTicket({
      id: 'e2e-ticket-3',
      title: 'Low',
      description: '',
      status: 'backlog',
      priority: 'P2',
      assigneeId: null,
      createdAt: now,
      updatedAt: now,
      acceptanceCriteria: [],
      labels: [],
    });

    // Create actual DB tasks so assignTask can find them
    const task1 = db.createTask({ id: 'e2e-task-1', ticketId: 'e2e-ticket-1', type: 'development', status: 'pending', performerId: null, createdAt: now, updatedAt: now, progress: 0 });
    const task2 = db.createTask({ id: 'e2e-task-2', ticketId: 'e2e-ticket-2', type: 'development', status: 'pending', performerId: null, createdAt: now, updatedAt: now, progress: 0 });
    const task3 = db.createTask({ id: 'e2e-task-3', ticketId: 'e2e-ticket-3', type: 'development', status: 'pending', performerId: null, createdAt: now, updatedAt: now, progress: 0 });

    // Claim next — should get highest priority (task-1)
    const first = await httpRequest(
      `${baseUrl}/api/tasks/next?performerId=${performerId}`
    );
    expect(first.status).toBe(200);
    const firstBody = first.data as Record<string, unknown>;
    expect(firstBody.success).toBe(true);
    const firstTask = firstBody.data as Record<string, unknown>;
    expect(firstTask.id).toBe('e2e-task-1');

    const second = await httpRequest(
      `${baseUrl}/api/tasks/next?performerId=${performerId}`
    );
    expect(second.status).toBe(200);
    const secondBody = second.data as Record<string, unknown>;
    const secondTask = secondBody.data as Record<string, unknown>;
    expect(secondTask.id).toBe('e2e-task-2');

    const third = await httpRequest(
      `${baseUrl}/api/tasks/next?performerId=${performerId}`
    );
    expect(third.status).toBe(200);
    const thirdBody = third.data as Record<string, unknown>;
    const thirdTask = thirdBody.data as Record<string, unknown>;
    expect(thirdTask.id).toBe('e2e-task-3');
  });

  it('capability filtering works via API', async () => {
    server = await startServer();

    // Register performer with limited capabilities
    const regRes = await httpRequest(
      `${baseUrl}/api/agents/register`,
      { method: 'POST' },
      { name: 'perf-cap', capabilities: ['python'] },
    );
    const regBody = regRes.data as Record<string, unknown>;
    const perfData = regBody.data as Record<string, unknown>;
    const performerId = perfData.id as string;

    const now = Date.now();
    claimQueue.enqueue('task-py', 't-py', 100, ['python']);
    claimQueue.enqueue('task-ts', 't-ts', 500, ['typescript']);

    db.createTicket({ id: 't-py', title: 'Py Task', description: '', status: 'backlog', priority: 'P1', assigneeId: null, createdAt: now, updatedAt: now, acceptanceCriteria: [], labels: ['python'] });
    db.createTicket({ id: 't-ts', title: 'TS Task', description: '', status: 'backlog', priority: 'P0', assigneeId: null, createdAt: now, updatedAt: now, acceptanceCriteria: [], labels: ['typescript'] });

    db.createTask({ id: 'task-py', ticketId: 't-py', type: 'development', status: 'pending', performerId: null, createdAt: now, updatedAt: now, progress: 0 });
    db.createTask({ id: 'task-ts', ticketId: 't-ts', type: 'development', status: 'pending', performerId: null, createdAt: now, updatedAt: now, progress: 0 });

    // Even though task-ts has higher priority (500 > 100), performer only has python
    // So they should get task-py
    const first = await httpRequest(
      `${baseUrl}/api/tasks/next?performerId=${performerId}&capabilities=python`
    );
    const firstBody = first.data as Record<string, unknown>;
    const firstTask = firstBody.data as Record<string, unknown>;
    expect(firstTask.id).toBe('task-py');
  });

  it('reQueue returns completed/released task to pool', async () => {
    server = await startServer();

    const regRes = await httpRequest(
      `${baseUrl}/api/agents/register`,
      { method: 'POST' },
      { name: 'perf-rq', capabilities: ['test'] },
    );
    const perfData = (regRes.data as Record<string, unknown>).data as Record<string, unknown>;
    const performerId = perfData.id as string;

    const now = Date.now();
    claimQueue.enqueue('rq-task', 'rq-ticket', 100, []);

    db.createTicket({ id: 'rq-ticket', title: 'RQ', description: '', status: 'backlog', priority: 'P2', assigneeId: null, createdAt: now, updatedAt: now, acceptanceCriteria: [], labels: [] });
    db.createTask({ id: 'rq-task', ticketId: 'rq-ticket', type: 'development', status: 'pending', performerId: null, createdAt: now, updatedAt: now, progress: 0 });

    // First claim
    const first = await httpRequest(
      `${baseUrl}/api/tasks/next?performerId=${performerId}`
    );
    expect(first.status).toBe(200);
    const firstBody = first.data as Record<string, unknown>;
    expect(firstBody.success).toBe(true);

    // Release the task
    const releaseRes = await httpRequest(
      `${baseUrl}/api/tasks/rq-task/release`,
      { method: 'POST' }
    );
    expect(releaseRes.status).toBe(200);

    // Re-queue
    claimQueue.reQueue('rq-task');

    // Another performer should be able to claim it
    const regRes2 = await httpRequest(
      `${baseUrl}/api/agents/register`,
      { method: 'POST' },
      { name: 'perf-rq2', capabilities: ['test'] },
    );
    const perfData2 = (regRes2.data as Record<string, unknown>).data as Record<string, unknown>;
    const performerId2 = perfData2.id as string;

    const second = await httpRequest(
      `${baseUrl}/api/tasks/next?performerId=${performerId2}`
    );
    expect(second.status).toBe(200);
    const secondBody = second.data as Record<string, unknown>;
    expect(secondBody.success).toBe(true);
    const secondTask = secondBody.data as Record<string, unknown>;
    expect(secondTask.id).toBe('rq-task');
  });
});

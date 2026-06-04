/**
 * KALLAX E2E: Concurrent Task Claim
 * Verifies that concurrent claim requests are serialized: only one succeeds,
 * the rest get 409 Conflict. Uses real SQLite with temp DB.
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
import type { WorktreeManager } from '../../src/core/worktree-manager.js';
import type { Ticket, Instance } from '../../src/types/index.js';

let db: SQLiteManager;
let dbPath: string;
let server: ApiServer;
let baseUrl: string;
const PORT = 19878;
const API_KEY = 'kallax-dev-key';

// ── Helpers ─────────────────────────────────────────────────────────────────

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
      agent: false, // Disable connection pooling to avoid stale connections across server restarts
      headers: {
        'Content-Type': 'application/json',
        'X-KALLAX-API-Key': API_KEY,
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
    },
  );

  await srv.start();
  return srv;
}

// ── Setup / Teardown ────────────────────────────────────────────────────────

beforeEach(async () => {
  dbPath = path.join(os.tmpdir(), `kallax-concurrent-claim-${Date.now()}.db`);
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

// ── Tests ───────────────────────────────────────────────────────────────────

describe('Concurrent Task Claim', () => {

  it('only one performer succeeds when two claim the same task concurrently', async () => {
    server = await startServer();

    // ── Step 1: Register 2 performers ────────────────────────────────────
    const p1Res = await httpRequest(
      `${baseUrl}/api/agents/register`,
      { method: 'POST' },
      { name: 'performer-alpha', capabilities: ['typescript'] },
    );
    expect(p1Res.status).toBe(201);
    const p1Data = p1Res.data as Record<string, unknown>;
    expect(p1Data.success).toBe(true);
    const performer1 = p1Data.data as Record<string, unknown>;
    const p1Id = performer1.id as string;

    const p2Res = await httpRequest(
      `${baseUrl}/api/agents/register`,
      { method: 'POST' },
      { name: 'performer-beta', capabilities: ['python'] },
    );
    expect(p2Res.status).toBe(201);
    const p2Data = p2Res.data as Record<string, unknown>;
    expect(p2Data.success).toBe(true);
    const performer2 = p2Data.data as Record<string, unknown>;
    const p2Id = performer2.id as string;

    // ── Step 2: Create a ticket and task ──────────────────────────────────
    const now = Date.now();
    const ticket: Ticket = {
      id: 'CONCUR-TKT-001',
      title: 'Concurrent Claim Test',
      description: 'Test concurrent claim behavior',
      status: 'backlog',
      priority: 'P1',
      assigneeId: null,
      createdAt: now,
      updatedAt: now,
      acceptanceCriteria: ['AC1'],
      labels: ['e2e'],
    };
    db.createTicket(ticket);

    const createRes = await httpRequest(
      `${baseUrl}/api/tasks`,
      { method: 'POST' },
      { ticketId: 'CONCUR-TKT-001', type: 'development' },
    );
    expect(createRes.status).toBe(201);
    const createBody = createRes.data as Record<string, unknown>;
    expect(createBody.success).toBe(true);
    const task = createBody.data as Record<string, unknown>;
    const taskId = task.id as string;
    expect(task.status).toBe('pending');

    // ── Step 3: Send 2 concurrent claim requests ─────────────────────────
    const [claim1, claim2] = await Promise.all([
      httpRequest(
        `${baseUrl}/api/tasks/${taskId}/claim`,
        { method: 'POST' },
        { performerId: p1Id },
      ),
      httpRequest(
        `${baseUrl}/api/tasks/${taskId}/claim`,
        { method: 'POST' },
        { performerId: p2Id },
      ),
    ]);

    // ── Step 4: Verify one succeeded, one got 409 ────────────────────────
    const successCount = [claim1, claim2].filter((r) => r.status === 200).length;
    const conflictCount = [claim1, claim2].filter((r) => r.status === 409).length;

    expect(successCount).toBe(1);
    expect(conflictCount).toBe(1);

    // The successful one should have the performerId set
    const successResp = [claim1, claim2].find((r) => r.status === 200)!;
    const successBody = successResp.data as Record<string, unknown>;
    expect(successBody.success).toBe(true);

    // The 409 should have a proper error message
    const conflictResp = [claim1, claim2].find((r) => r.status === 409)!;
    const conflictBody = conflictResp.data as Record<string, unknown>;
    expect(conflictBody.success).toBe(false);
    const errorBody = conflictBody.error as Record<string, unknown>;
    expect(errorBody.code).toBe('TASK_ALREADY_CLAIMED');

    // ── Step 5: Verify DB state is consistent ────────────────────────────
    const taskResult = db.getTask(taskId);
    expect(taskResult.isOk()).toBe(true);
    if (taskResult.isOk()) {
      const dbTask = taskResult.value;
      expect(dbTask).not.toBeNull();
      if (dbTask !== null) {
        // The task should be claimed by exactly one performer
        expect(dbTask.status).toBe('claimed');
        expect(dbTask.performerId).not.toBeNull();
        // performerId should be one of the two performers
        expect([p1Id, p2Id]).toContain(dbTask.performerId);
        // Should have a startedAt timestamp
        expect(dbTask.startedAt).toBeDefined();
      }
    }

    // Verify only one task exists and it's claimed
    const allTasks = db.listTasks({ limit: 10 });
    expect(allTasks.isOk()).toBe(true);
    if (allTasks.isOk()) {
      const tasks = allTasks.value;
      expect(tasks.length).toBe(1);
      expect(tasks[0]?.status).toBe('claimed');
    }
  });

  it('returns 404 for claim on nonexistent task', async () => {
    server = await startServer();

    const res = await httpRequest(
      `${baseUrl}/api/tasks/nonexistent-task/claim`,
      { method: 'POST' },
      { performerId: 'some-performer' },
    );
    // The router matches /:id/claim, so nonexistent ID triggers assignTask which returns INSTANCE_NOT_FOUND
    expect(res.status).toBe(404);
  });

  it('returns 400 for claim without performerId', async () => {
    server = await startServer();

    const res = await httpRequest(
      `${baseUrl}/api/tasks/some-task/claim`,
      { method: 'POST' },
      {},
    );
    expect(res.status).toBe(400);
    const body = res.data as Record<string, unknown>;
    expect(body.success).toBe(false);
    const errorBody = body.error as Record<string, unknown>;
    expect(errorBody.code).toBe('VALIDATION_ERROR');
  });
});

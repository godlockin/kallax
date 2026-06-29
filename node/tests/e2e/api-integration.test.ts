/**
 * KALLAX E2E: API Server Integration
 * Starts a temporary server -> health check -> CRUD -> stops server.
 * Uses real SQLite with temp DB file and direct HTTP requests.
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
import type { Ticket } from '../../src/types/index.js';

let db: SQLiteManager;
let dbPath: string;
let server: ApiServer;
let baseUrl: string;
const PORT = 19877; // Use a high, likely-unused port
const API_KEY = 'kallax-test-key-0123456789abcdef0123';

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

// ── Setup / Teardown ────────────────────────────────────────────────────────

beforeEach(async () => {
  dbPath = path.join(os.tmpdir(), `kallax-e2e-api-${Date.now()}.db`);
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

describe('API Server Integration (E2E)', () => {

  it('health check returns healthy status', async () => {
    server = await startServer(db);
    const res = await httpRequest(`${baseUrl}/health`);
    expect(res.status).toBe(200);
    const body = res.data as Record<string, unknown>;
    expect(body.success).toBe(true);
    const health = body.data as Record<string, unknown>;
    expect(health.status).toBe('healthy');
    expect(health.dbConnected).toBe(true);
    expect(health.version).toBe('1.0.0');
  });

  it('version endpoint returns server info', async () => {
    server = await startServer(db);
    const res = await httpRequest(`${baseUrl}/version`);
    expect(res.status).toBe(200);
    const body = res.data as Record<string, unknown>;
    expect(body.success).toBe(true);
    const info = body.data as Record<string, unknown>;
    expect(info.version).toBe('1.0.0');
    expect(info.name).toBe('@kallax/node');
  });

  it('creates ticket and task via DB then retrieves via API', async () => {
    server = await startServer(db);

    // Seed ticket directly via DB
    const now = Date.now();
    const ticket: Ticket = {
      id: 'E2E-API-TKT-001',
      title: 'API Test Ticket',
      description: 'Created via DB for API test',
      status: 'backlog',
      priority: 'P2',
      assigneeId: null,
      createdAt: now,
      updatedAt: now,
      acceptanceCriteria: ['AC1'],
      labels: ['api-test'],
    };
    db.createTicket(ticket);

    // Create a task via API
    const createRes = await httpRequest(
      `${baseUrl}/api/tasks`,
      { method: 'POST' },
      { ticketId: 'E2E-API-TKT-001', type: 'development' },
    );
    expect(createRes.status).toBe(201);
    const createBody = createRes.data as Record<string, unknown>;
    expect(createBody.success).toBe(true);
    const task = createBody.data as Record<string, unknown>;
    expect(task.ticketId).toBe('E2E-API-TKT-001');
    const taskId = task.id as string;

    // List tasks via API
    const listRes = await httpRequest(`${baseUrl}/api/tasks`);
    expect(listRes.status).toBe(200);
    const listBody = listRes.data as Record<string, unknown>;
    expect(listBody.success).toBe(true);
    const paginated = listBody.data as Record<string, unknown>;
    expect(paginated.items).toBeInstanceOf(Array);
    expect((paginated.items as unknown[]).length).toBeGreaterThanOrEqual(1);

    // Get single task via API
    const getRes = await httpRequest(`${baseUrl}/api/tasks/${taskId}`);
    expect(getRes.status).toBe(200);
    const getBody = getRes.data as Record<string, unknown>;
    expect(getBody.success).toBe(true);
    const enriched = getBody.data as Record<string, unknown>;
    expect((enriched.task as Record<string, unknown>).id).toBe(taskId);
  });

  it('registers agent and sends heartbeat via API', async () => {
    server = await startServer(db);

    // Register agent
    const regRes = await httpRequest(
      `${baseUrl}/api/agents/register`,
      { method: 'POST' },
      { name: 'e2e-performer', capabilities: ['typescript'] },
    );
    expect(regRes.status).toBe(201);
    const regBody = regRes.data as Record<string, unknown>;
    expect(regBody.success).toBe(true);
    const agent = regBody.data as Record<string, unknown>;
    expect(agent.role).toBe('performer');
    const agentId = agent.id as string;

    // Send heartbeat
    const hbRes = await httpRequest(
      `${baseUrl}/api/agents/${agentId}/heartbeat`,
      { method: 'PUT' },
      { status: 'busy' },
    );
    expect(hbRes.status).toBe(200);
    const hbBody = hbRes.data as Record<string, unknown>;
    expect(hbBody.success).toBe(true);

    // Verify agent status updated via DB
    const dbAgent = db.getInstance(agentId);
    expect(dbAgent.isOk()).toBe(true);
    if (dbAgent.isOk() && dbAgent.value) {
      expect(dbAgent.value.status).toBe('busy');
    }
  });

  it('404 returns error for unknown endpoints', async () => {
    server = await startServer(db);
    const res = await httpRequest(`${baseUrl}/api/nonexistent`);
    expect(res.status).toBe(404);
    const body = res.data as Record<string, unknown>;
    expect(body.success).toBe(false);
    expect((body.error as Record<string, unknown>).code).toBe('NOT_FOUND');
  });

  it('server stop and restart works cleanly', async () => {
    server = await startServer(db);

    // Verify it's running
    const res1 = await httpRequest(`${baseUrl}/health`);
    expect(res1.status).toBe(200);

    // Stop
    await server.stop();

    // Starting again should work
    await server.start();
    const res2 = await httpRequest(`${baseUrl}/health`);
    expect(res2.status).toBe(200);
  });
});

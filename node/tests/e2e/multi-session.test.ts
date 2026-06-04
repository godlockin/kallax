/**
 * KALLAX Multi-Session Simulation Test
 * Spawns a real API server process (separate process via tsx), then simulates
 * Conductor and Performer collaborating through the API. Validates concurrent
 * claim protection, state consistency, and server crash recovery.
 *
 * Architecture:
 * 1. Seeds a temp SQLite DB with a ticket (from test process)
 * 2. Writes a bootstrap .mts file inside project dir (for ESM resolution)
 * 3. Spawns API server via tsx (separate OS process)
 * 4. Simulates Conductor and Performer sessions via HTTP fetch
 * 5. Validates state across both "windows"
 * 6. Tests crash recovery by killing and restarting the server
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { spawn } from 'node:child_process';
import type { ChildProcess } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';

import { createSQLiteManager } from '../../src/core/sqlite/index.js';
import type { Ticket } from '../../src/types/index.js';

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const MONOREPO_ROOT = path.resolve(__dirname, '../../..');
const PROJECT_ROOT = path.resolve(__dirname, '../..');
const API_KEY = 'kallax-dev-key';
const TSX_BIN = path.join(MONOREPO_ROOT, 'node_modules', '.bin', 'tsx');
const BOOT_DIR = path.join(PROJECT_ROOT, 'tests', '.boot');
const TICKET_ID = 'MULTI-SESSION-TKT-001';

let dbPath: string;
let port: number;
let baseUrl: string;
let serverProc: ChildProcess | null;
let bootstrapPath: string;

// ── Bootstrap Generator ────────────────────────────────────────────────────

/**
 * Generate a standalone server bootstrap script.
 * Bootstrap is written inside the project dir so ESM package resolution works.
 */
function makeBootstrap(db: string, p: number): string {
  return `
import { createSQLiteManager } from '../../src/core/sqlite/index.js';
import { createApiServer } from '../../src/api/server.js';
import { createTaskAssigner } from '../../src/core/task-assigner.js';
import { createInstanceRegistry } from '../../src/core/instance-registry.js';
import { createIsolationChecker } from '../../src/core/isolation-checker.js';
import { createSSEBus } from '../../src/core/sse-bus.js';
import { createOutputVerifier } from '../../src/core/output-verifier.js';
import { ok } from 'neverthrow';

(async () => {
const _dbR = createSQLiteManager({ path: '${db}' });
if (_dbR.isErr()) { console.error('DB init error:', _dbR.error.message); process.exit(1); }
const _db = _dbR.value;
const _isolation = createIsolationChecker();
const _registry = createInstanceRegistry(_db);
const _sseBus = createSSEBus();
const _assigner = createTaskAssigner(_db, _isolation, _registry);
const _ov = createOutputVerifier({ projectRoot: process.cwd(), testCommand: 'echo ok' });
const _wt = {
  create: async () => ok({ path: '/tmp/wt', branch: 'br', commit: 'c', taskId: 't' }),
  remove: async () => ok(undefined),
  list: async () => ok([]),
  getByTaskId: async () => ok(null),
  validateIsolation: async () => ok(true),
  getPath: () => '/tmp/wt',
};
const _server = createApiServer(
  { port: ${p}, host: '127.0.0.1', apiKey: '${API_KEY}' },
  { db: _db, taskAssigner: _assigner, instanceRegistry: _registry, worktreeManager: _wt, outputVerifier: _ov, isolationChecker: _isolation, sseBus: _sseBus },
);
await _server.start();
console.log('KALLAX_READY');
process.on('SIGTERM', async () => { await _server.stop(); _db.close(); process.exit(0); });
process.on('SIGINT', async () => { await _server.stop(); _db.close(); process.exit(0); });
})();
`.trim();
}

// ── HTTP Helper ─────────────────────────────────────────────────────────────

async function api(method: string, urlPath: string, body?: unknown): Promise<{ status: number; data: Record<string, unknown> }> {
  const url = new URL(urlPath, baseUrl).toString();
  const res = await fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      'X-KALLAX-API-Key': API_KEY,
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, data: (await res.json()) as Record<string, unknown> };
}

// ── Health Check ────────────────────────────────────────────────────────────

async function waitForHealth(url: string, retries = 30, interval = 1000): Promise<void> {
  for (let i = 0; i < retries; i++) {
    try {
      const res = await fetch(url);
      if (res.ok) {
        const body = (await res.json()) as Record<string, unknown>;
        const health = body['data'] as Record<string, unknown> | undefined;
        if (health?.['status'] === 'healthy') return;
      }
    } catch {
      // server not ready yet
    }
    await new Promise((r) => setTimeout(r, interval));
  }
  throw new Error(`Server health check timed out after ${retries * interval}ms`);
}

// ── Server Lifecycle ────────────────────────────────────────────────────────

async function spawnServer(db: string, p: number): Promise<ChildProcess> {
  fs.mkdirSync(BOOT_DIR, { recursive: true });
  if (bootstrapPath !== undefined) {
    try { fs.unlinkSync(bootstrapPath); } catch { /* ignore */ }
  }
  bootstrapPath = path.join(BOOT_DIR, `ms-${Date.now()}.mts`);
  fs.writeFileSync(bootstrapPath, makeBootstrap(db, p), 'utf-8');

  const proc = spawn(TSX_BIN, [bootstrapPath], {
    cwd: PROJECT_ROOT,
    stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env as Record<string, string> },
  });

  // Drain stdout
  proc.stdout!.on('data', () => {});
  // Log stderr for debugging
  const stderrBuf: string[] = [];
  proc.stderr!.on('data', (chunk: Buffer) => { stderrBuf.push(chunk.toString()); });

  try {
    await waitForHealth(`http://127.0.0.1:${p}/health`);
  } catch (err) {
    const stderrText = stderrBuf.join('');
    const extra = stderrText.length > 0 ? `\nChild stderr:\n${stderrText}` : '';
    throw new Error(`${(err as Error).message}${extra}`);
  }

  return proc;
}

async function killServer(proc: ChildProcess): Promise<void> {
  if (!proc || proc.killed) return;
  proc.kill('SIGTERM');
  await new Promise<void>((resolve) => {
    const timer = setTimeout(() => {
      if (!proc.killed) proc.kill('SIGKILL');
      resolve();
    }, 4000);
    proc.on('exit', () => {
      clearTimeout(timer);
      resolve();
    });
  });
}

// ── Ticket Seed ─────────────────────────────────────────────────────────────

function seedTicket(dbFilePath: string, ticketId: string): void {
  const result = createSQLiteManager({ path: dbFilePath });
  if (result.isErr()) throw new Error(`DB init failed: ${result.error.message}`);
  const db = result.value;
  const now = Date.now();
  const ticket: Ticket = {
    id: ticketId,
    title: 'Multi-Session Test Ticket',
    description: 'Seeded for multi-session e2e test',
    status: 'backlog',
    priority: 'P2',
    assigneeId: null,
    createdAt: now,
    updatedAt: now,
    acceptanceCriteria: ['AC1: multi-session works'],
    labels: ['e2e', 'multi-session'],
  };
  const createResult = db.createTicket(ticket);
  if (createResult.isErr()) throw new Error(`Ticket creation failed: ${createResult.error.message}`);
  db.close();
}

// ── Setup / Teardown ────────────────────────────────────────────────────────

beforeAll(async () => {
  dbPath = path.join(os.tmpdir(), `kallax-ms-${Date.now()}.db`);
  port = 28760 + Math.floor(Math.random() * 2000);
  baseUrl = `http://127.0.0.1:${port}`;

  seedTicket(dbPath, TICKET_ID);
  serverProc = await spawnServer(dbPath, port);
}, 30000); // 30s hook timeout for process spawn

afterAll(async () => {
  if (serverProc) await killServer(serverProc);
  try { fs.unlinkSync(dbPath); } catch { /* ignore */ }
  if (bootstrapPath !== undefined) { try { fs.unlinkSync(bootstrapPath); } catch { /* ignore */ } }
  try { fs.rmSync(BOOT_DIR, { recursive: true, force: true }); } catch { /* ignore */ }
}, 15000);

// ── Tests ───────────────────────────────────────────────────────────────────

describe('Multi-Session Simulated Flow', () => {

  it('Scenario 1: Conductor creates pipeline, Performer executes (happy path)', async () => {
    // ── Conductor session ───────────────────────────────────────────────────
    // Conductor registers (POST /api/agents/register)
    const condReg = await api('POST', '/api/agents/register', {
      name: 'conductor-ms',
      capabilities: ['orchestration'],
    });
    expect(condReg.status).toBe(201);
    const conductorId = (condReg.data['data'] as Record<string, unknown>)?.['id'] as string;
    expect(conductorId).toBeTruthy();

    // Conductor creates a task from the seeded ticket
    const taskCreate = await api('POST', '/api/tasks', {
      ticketId: TICKET_ID,
      type: 'development',
    });
    expect(taskCreate.status).toBe(201);
    const taskData = taskCreate.data['data'] as Record<string, unknown>;
    expect(taskData['ticketId']).toBe(TICKET_ID);
    const taskId = taskData['id'] as string;

    // Conductor polls for pending tasks
    const pendingList = await api('GET', '/api/tasks?status=pending');
    expect(pendingList.status).toBe(200);
    const pendingItems = (pendingList.data['data'] as Record<string, unknown>)?.['items'] as unknown[];
    const foundPending = pendingItems.some((t: unknown) => (t as Record<string, unknown>)['id'] === taskId);
    expect(foundPending).toBe(true);

    // ── Performer session ──────────────────────────────────────────────────
    // Performer registers
    const perfReg = await api('POST', '/api/agents/register', {
      name: 'performer-ms',
      capabilities: ['typescript', 'node'],
    });
    expect(perfReg.status).toBe(201);
    const performerId = (perfReg.data['data'] as Record<string, unknown>)?.['id'] as string;

    // Performer claims the task
    const claim = await api('POST', `/api/tasks/${taskId}/claim`, { performerId });
    expect(claim.status).toBe(200);
    const claimedTask = claim.data['data'] as Record<string, unknown>;
    expect(claimedTask['status']).toBe('claimed');
    expect(claimedTask['performerId']).toBe(performerId);

    // Verify state via GET (Conductor polls and sees Performer's update)
    const getClaimed = await api('GET', `/api/tasks/${taskId}`);
    expect(getClaimed.status).toBe(200);
    const enriched = getClaimed.data['data'] as Record<string, unknown>;
    const taskState = enriched['task'] as Record<string, unknown>;
    expect(taskState['status']).toBe('claimed');
    expect(taskState['performerId']).toBe(performerId);

    // Performer completes the task
    const complete = await api('PUT', `/api/tasks/${taskId}/complete`, {
      output: 'Multi-session test completed successfully',
    });
    expect(complete.status).toBe(200);

    // Verify completed state (Conductor polls and sees completion)
    const getDone = await api('GET', `/api/tasks/${taskId}`);
    expect(getDone.status).toBe(200);
    const doneEnriched = getDone.data['data'] as Record<string, unknown>;
    const doneTask = doneEnriched['task'] as Record<string, unknown>;
    expect(doneTask['status']).toBe('completed');
    expect(doneTask['progress']).toBe(100);
    expect(doneTask['output']).toBe('Multi-session test completed successfully');
  });

  it('Scenario 2: Concurrent claim protection (two performers, one task)', async () => {
    // Create a fresh task for this test
    const taskCreate = await api('POST', '/api/tasks', {
      ticketId: TICKET_ID,
      type: 'development',
    });
    expect(taskCreate.status).toBe(201);
    const taskId = (taskCreate.data['data'] as Record<string, unknown>)['id'] as string;

    // Register two performers
    const p1Reg = await api('POST', '/api/agents/register', { name: 'perf-a', capabilities: ['ts'] });
    expect(p1Reg.status).toBe(201);
    const p1Id = (p1Reg.data['data'] as Record<string, unknown>)['id'] as string;

    const p2Reg = await api('POST', '/api/agents/register', { name: 'perf-b', capabilities: ['ts'] });
    expect(p2Reg.status).toBe(201);
    const p2Id = (p2Reg.data['data'] as Record<string, unknown>)['id'] as string;

    // Fire two claims concurrently -- only one should succeed
    const [r1, r2] = await Promise.all([
      api('POST', `/api/tasks/${taskId}/claim`, { performerId: p1Id }),
      api('POST', `/api/tasks/${taskId}/claim`, { performerId: p2Id }),
    ]);
    const okCount = [r1, r2].filter((c) => c.status === 200).length;
    const conflictCount = [r1, r2].filter((c) => c.status === 409).length;

    // Exactly one succeeds, the other gets 409 conflict
    expect(okCount).toBe(1);
    expect(conflictCount).toBe(1);

    // The winning performer is recorded in DB
    const getFinal = await api('GET', `/api/tasks/${taskId}`);
    expect(getFinal.status).toBe(200);
    const enriched = getFinal.data['data'] as Record<string, unknown>;
    const finalTask = enriched['task'] as Record<string, unknown>;
    expect(finalTask['status']).toBe('claimed');
    expect([p1Id, p2Id]).toContain(finalTask['performerId']);
  });

  it('Scenario 3: Server crash recovery (data persists after restart)', async () => {
    // Create data through running server
    const tc = await api('POST', '/api/tasks', { ticketId: TICKET_ID, type: 'bugfix' });
    expect(tc.status).toBe(201);
    const taskId = (tc.data['data'] as Record<string, unknown>)['id'] as string;

    // Register performer and claim
    const reg = await api('POST', '/api/agents/register', { name: 'crash-perf', capabilities: ['go'] });
    expect(reg.status).toBe(201);
    const perfId = (reg.data['data'] as Record<string, unknown>)['id'] as string;

    const claim = await api('POST', `/api/tasks/${taskId}/claim`, { performerId: perfId });
    expect(claim.status).toBe(200);

    // ── Kill server (simulate crash) ────────────────────────────────────────
    expect(serverProc).not.toBeNull();
    await killServer(serverProc!);
    serverProc = null;

    // ── Start new server (same DB) ─────────────────────────────────────────
    const newProc = await spawnServer(dbPath, port);
    serverProc = newProc;

    // Verify data persisted -- task still exists in claimed state
    const get = await api('GET', `/api/tasks/${taskId}`);
    expect(get.status).toBe(200);
    const enriched = get.data['data'] as Record<string, unknown>;
    const task = enriched['task'] as Record<string, unknown>;
    expect(task['status']).toBe('claimed');
    expect(task['performerId']).toBe(perfId);
    expect(task['ticketId']).toBe(TICKET_ID);
  }, 20000); // 20s timeout for crash recovery test (restart overhead)

});

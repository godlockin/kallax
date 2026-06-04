/**
 * Property-based tests for multi-session collaboration invariants.
 *
 * Invariants that must ALWAYS hold:
 * 1. Claim is atomic — two concurrent claims on the same task → exactly one succeeds
 * 2. Complete is idempotent — completing an already-completed task is safe
 * 3. State transitions are valid — no pending→completed without claimed
 * 4. Conductor poll sees consistent state after Performer actions
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import Database from 'better-sqlite3';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
const execFileAsync = promisify(execFile);

const API_BASE = 'http://127.0.0.1:19777';
let serverProcess: ReturnType<typeof execFile> | null = null;

async function startServer(): Promise<void> {
  const { mkdirSync } = require('node:fs');
  mkdirSync('.kallax/data', { recursive: true });
  const cp = require('node:child_process');
  serverProcess = cp.spawn('npx', ['tsx', 'src/api/server.ts'], {
    env: { ...process.env, KALLAX_PORT: '19777', KALLAX_API_KEY: 'test-key' },
    stdio: 'pipe',
  });
  // Wait for server ready
  for (let i = 0; i < 20; i++) {
    try {
      await fetch(`${API_BASE}/health`);
      return;
    } catch { await new Promise(r => setTimeout(r, 300)); }
  }
  throw new Error('Server failed to start');
}

async function api(path: string, options?: RequestInit) {
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer test-key', ...options?.headers },
  });
  return { status: res.status, data: await res.json().catch(() => null) };
}

describe('Multi-Session Property Tests', () => {

  beforeAll(async () => { await startServer(); }, 30000);
  afterAll(() => { if (serverProcess) serverProcess.kill(); });

  it('claim is atomic — concurrent claims produce exactly one winner', async () => {
    // Setup: create ticket + task
    const ticket = await api('/api/tasks', { method: 'POST', body: JSON.stringify({ title: 'Atomic Claim Test', priority: 'P1' }) });
    const task = await api('/api/tasks', { method: 'POST', body: JSON.stringify({ ticketId: ticket.data.id, type: 'development' }) });
    const taskId = task.data.id;

    // Register 2 performers
    const p1 = await api('/api/agents/register', { method: 'POST', body: JSON.stringify({ name: 'perf-1', capabilities: ['test'] }) });
    const p2 = await api('/api/agents/register', { method: 'POST', body: JSON.stringify({ name: 'perf-2', capabilities: ['test'] }) });

    // Concurrent claims
    const [r1, r2] = await Promise.all([
      api(`/api/tasks/${taskId}/claim`, { method: 'PUT', body: JSON.stringify({ performerId: p1.data.id }) }),
      api(`/api/tasks/${taskId}/claim`, { method: 'PUT', body: JSON.stringify({ performerId: p2.data.id }) }),
    ]);

    // Exactly one must succeed (200 or 201)
    const successes = [r1, r2].filter(r => r.status >= 200 && r.status < 300).length;
    expect(successes).toBe(1);
  });

  it('complete is idempotent', async () => {
    const ticket = await api('/api/tasks', { method: 'POST', body: JSON.stringify({ title: 'Idempotent Complete', priority: 'P2' }) });
    const task = await api('/api/tasks', { method: 'POST', body: JSON.stringify({ ticketId: ticket.data.id }) });
    const perf = await api('/api/agents/register', { method: 'POST', body: JSON.stringify({ name: 'perf-comp', capabilities: ['test'] }) });

    await api(`/api/tasks/${task.data.id}/claim`, { method: 'PUT', body: JSON.stringify({ performerId: perf.data.id }) });
    await api(`/api/tasks/${task.data.id}/complete`, { method: 'PUT' });

    // Second complete should be safe (either success or proper error)
    const r = await api(`/api/tasks/${task.data.id}/complete`, { method: 'PUT' });
    expect([200, 400, 409, 422]).toContain(r.status);
  });

  it('state transitions are valid — no pending→completed without claimed', async () => {
    const ticket = await api('/api/tasks', { method: 'POST', body: JSON.stringify({ title: 'State Transition', priority: 'P1' }) });
    const task = await api('/api/tasks', { method: 'POST', body: JSON.stringify({ ticketId: ticket.data.id }) });

    // Try to complete without claiming
    const r = await api(`/api/tasks/${task.data.id}/complete`, { method: 'PUT' });
    // Must reject — can't complete a pending task
    expect(r.status).toBeGreaterThanOrEqual(400);
  });

  it('Conductor poll reflects Performer state changes', async () => {
    // Create task, verify it appears in poll
    const ticket = await api('/api/tasks', { method: 'POST', body: JSON.stringify({ title: 'Poll Test', priority: 'P1' }) });
    await api('/api/tasks', { method: 'POST', body: JSON.stringify({ ticketId: ticket.data.id }) });
    const perf = await api('/api/agents/register', { method: 'POST', body: JSON.stringify({ name: 'perf-poll', capabilities: ['test'] }) });

    // Conductor should see assignable tasks
    const poll = await api('/api/tasks?status=pending');
    expect(poll.status).toBe(200);

    // Claim the first pending task
    const tasks = poll.data as Array<{id: string}>;
    if (tasks.length > 0) {
      await api(`/api/tasks/${tasks[0].id}/claim`, { method: 'PUT', body: JSON.stringify({ performerId: perf.data.id }) });
      // After claim, poll again — claimed task should NOT appear in pending
      const poll2 = await api('/api/tasks?status=pending');
      const stillPending = (poll2.data as Array<{id: string}>).filter(t => t.id === tasks[0].id);
      expect(stillPending.length).toBe(0);
    }
  });
});

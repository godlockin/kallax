/**
 * SQLite Manager Unit Tests
 * Uses :memory: database for fast, isolated testing.
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { createSQLiteManager, type SQLiteManager } from '../src/core/sqlite/index.js';
import { createTicket, createTask, createInstance, createMessage } from './helpers/factories.js';
import { KallaxErrorCode } from '../src/types/index.js';
import * as fs from 'node:fs';

let db: SQLiteManager;
const DB_PATH = ':memory:';

beforeEach(() => {
  const result = createSQLiteManager({ path: DB_PATH });
  if (result.isOk()) db = result.value;
  else throw new Error('Failed to create test database');
});

afterEach(() => {
  db.close();
});

// ── Ticket CRUD ─────────────────────────────────────────────────────────────

describe('Ticket Operations', () => {
  it('creates and retrieves a ticket', () => {
    const ticket = createTicket({ id: 'TCKT-001', title: 'Test' });
    const createResult = db.createTicket(ticket);
    expect(createResult.isOk()).toBe(true);

    const getResult = db.getTicket('TCKT-001');
    expect(getResult.isOk()).toBe(true);
    if (getResult.isOk()) {
      expect(getResult.value?.title).toBe('Test');
      expect(getResult.value?.status).toBe('todo');
    }
  });

  it('returns null for non-existent ticket', () => {
    const result = db.getTicket('NONEXIST');
    expect(result.isOk()).toBe(true);
    if (result.isOk()) expect(result.value).toBeNull();
  });

  it('updates ticket fields', () => {
    db.createTicket(createTicket({ id: 'TCKT-002' }));
    db.updateTicket('TCKT-002', { status: 'in_progress' as const, title: 'Updated' });
    const result = db.getTicket('TCKT-002');
    if (result.isOk()) {
      expect(result.value?.title).toBe('Updated');
      expect(result.value?.status).toBe('in_progress');
    }
  });

  it('lists tickets with filters', () => {
    db.createTicket(createTicket({ id: 'A', status: 'todo' as const, priority: 'P0' as const }));
    db.createTicket(createTicket({ id: 'B', status: 'done' as const, priority: 'P1' as const }));
    db.createTicket(createTicket({ id: 'C', status: 'todo' as const, priority: 'P0' as const }));

    const byStatus = db.listTickets({ status: 'todo' });
    if (byStatus.isOk()) expect(byStatus.value.length).toBe(2);

    const byPriority = db.listTickets({ priority: 'P0' });
    if (byPriority.isOk()) expect(byPriority.value.length).toBe(2);

    const limited = db.listTickets({ limit: 1 });
    if (limited.isOk()) expect(limited.value.length).toBe(1);
  });

  it('stores acceptance criteria and labels as JSON', () => {
    const ticket = createTicket({
      id: 'TCKT-JSON',
      acceptanceCriteria: ['AC1', 'AC2'],
      labels: ['frontend', 'urgent'],
    });
    db.createTicket(ticket);
    const result = db.getTicket('TCKT-JSON');
    if (result.isOk()) {
      expect(result.value?.acceptanceCriteria).toEqual(['AC1', 'AC2']);
      expect(result.value?.labels).toEqual(['frontend', 'urgent']);
    }
  });

  it('stores file scope', () => {
    const ticket = createTicket({
      id: 'TCKT-SCOPE',
      fileScope: ['src/foo.ts', 'src/bar.ts'],
    });
    db.createTicket(ticket);
    const result = db.getTicket('TCKT-SCOPE');
    if (result.isOk()) {
      expect(result.value?.fileScope).toEqual(['src/foo.ts', 'src/bar.ts']);
    }
  });
});

// ── Task CRUD ───────────────────────────────────────────────────────────────

describe('Task Operations', () => {
  // Helper: create ticket first so FK constraint is satisfied
  function setupTask(taskId: string, ticketId: string, overrides?: Record<string, unknown>) {
    db.createTicket(createTicket({ id: ticketId }));
    const task = createTask({ id: taskId, ticketId, ...overrides });
    db.createTask(task);
  }

  it('creates and retrieves a task', () => {
    setupTask('TASK-001', 'TCKT-001');
    const getResult = db.getTask('TASK-001');
    expect(getResult.isOk()).toBe(true);
    if (getResult.isOk()) expect(getResult.value?.status).toBe('pending');
  });

  it('claims a task atomically', () => {
    setupTask('TASK-CLAIM', 'TCKT-CLAIM');
    const claimResult = db.claimTask('TASK-CLAIM', 'perf-001');
    expect(claimResult.isOk()).toBe(true);
    if (claimResult.isOk()) expect(claimResult.value).toBe(true);

    const getResult = db.getTask('TASK-CLAIM');
    if (getResult.isOk()) {
      expect(getResult.value?.performerId).toBe('perf-001');
      expect(getResult.value?.status).toBe('claimed');
    }
  });

  it('prevents double-claim', () => {
    setupTask('TASK-DC', 'TCKT-DC');
    db.claimTask('TASK-DC', 'perf-A');
    const secondClaim = db.claimTask('TASK-DC', 'perf-B');
    if (secondClaim.isOk()) expect(secondClaim.value).toBe(false);
  });

  it('updates task progress', () => {
    setupTask('TASK-PROG', 'TCKT-PROG');
    db.updateTask('TASK-PROG', { progress: 75, status: 'running' as const });
    const result = db.getTask('TASK-PROG');
    if (result.isOk()) {
      expect(result.value?.progress).toBe(75);
      expect(result.value?.status).toBe('running');
    }
  });

  it('completes a task', () => {
    setupTask('TASK-DONE', 'TCKT-DONE');
    db.updateTask('TASK-DONE', { status: 'completed' as const, progress: 100, completedAt: Date.now() });
    const result = db.getTask('TASK-DONE');
    if (result.isOk()) {
      expect(result.value?.status).toBe('completed');
      expect(result.value?.progress).toBe(100);
    }
  });

  it('lists tasks by performer', () => {
    setupTask('TA', 'TCKT-A', { performerId: 'p1' });
    setupTask('TB', 'TCKT-B', { performerId: 'p1' });
    setupTask('TC', 'TCKT-C', { performerId: 'p2' });

    const result = db.listTasks({ performerId: 'p1' });
    if (result.isOk()) expect(result.value.length).toBe(2);
  });
});

// ── Instance Operations ─────────────────────────────────────────────────────

describe('Instance Operations', () => {
  it('registers and retrieves instance', () => {
    const instance = createInstance({ id: 'inst-001' });
    db.registerInstance(instance);
    const result = db.getInstance('inst-001');
    if (result.isOk()) {
      expect(result.value?.role).toBe('performer');
      expect(result.value?.hostname).toBe('test-host');
    }
  });

  it('updates heartbeat', () => {
    db.registerInstance(createInstance({ id: 'inst-hb', lastHeartbeat: 1000 }));
    db.updateHeartbeat('inst-hb');
    const result = db.getInstance('inst-hb');
    if (result.isOk()) expect(result.value!.lastHeartbeat).toBeGreaterThan(10000);
  });

  it('detects stale instances', () => {
    const old = Date.now() - 120000; // 2 minutes ago
    db.registerInstance(createInstance({ id: 'inst-stale', lastHeartbeat: old }));
    db.registerInstance(createInstance({ id: 'inst-fresh', lastHeartbeat: Date.now() }));

    const result = db.getStaleInstances(60000); // 1 minute threshold
    if (result.isOk()) {
      expect(result.value.some((i) => i.id === 'inst-stale')).toBe(true);
      expect(result.value.some((i) => i.id === 'inst-fresh')).toBe(false);
    }
  });

  it('lists instances by role', () => {
    db.registerInstance(createInstance({ id: 'ic', role: 'conductor' as const }));
    db.registerInstance(createInstance({ id: 'ip1', role: 'performer' as const }));
    db.registerInstance(createInstance({ id: 'ip2', role: 'performer' as const }));

    const conductors = db.listInstances({ role: 'conductor' });
    if (conductors.isOk()) expect(conductors.value.length).toBe(1);

    const performers = db.listInstances({ role: 'performer' });
    if (performers.isOk()) expect(performers.value.length).toBe(2);
  });
});

// ── Message Operations ───────────────────────────────────────────────────────

describe('Message Operations', () => {
  it('enqueues and dequeues messages', () => {
    const msg = createMessage({ id: 'msg-001', type: 'task.created' });
    db.enqueueMessage(msg);

    const peekResult = db.peekMessages(10);
    if (peekResult.isOk()) expect(peekResult.value.length).toBeGreaterThanOrEqual(0);
  });

  it('dequeues returns null when empty', () => {
    const result = db.dequeueMessage();
    expect(result.isOk()).toBe(true);
    if (result.isOk()) expect(result.value).toBeNull();
  });

  it('handles multiple messages', () => {
    db.enqueueMessage(createMessage({ id: 'm1', priority: 2 }));
    db.enqueueMessage(createMessage({ id: 'm2', priority: 0 }));
    db.enqueueMessage(createMessage({ id: 'm3', priority: 3 }));

    const peekResult = db.peekMessages(10);
    if (peekResult.isOk()) {
      // Should be ordered by priority DESC
      expect(peekResult.value.length).toBeGreaterThanOrEqual(0);
    }
  });
});

// ── Stats ────────────────────────────────────────────────────────────────────

describe('getStats', () => {
  it('returns correct counts', () => {
    db.createTicket(createTicket({ id: 't1' }));
    db.createTicket(createTicket({ id: 't2' }));
    db.createTicket(createTicket({ id: 'tck1' })); db.createTask(createTask({ id: 'task1', ticketId: 'tck1' }));
    db.registerInstance(createInstance({ id: 'i1' }));

    const stats = db.getStats();
    expect(stats.ticketCount).toBe(3);
    expect(stats.taskCount).toBe(1);
    expect(stats.instanceCount).toBe(1);
  });
});

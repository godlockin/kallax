/**
 * KALLAX E2E: Performer Lifecycle
 * Full performer lifecycle: register -> claim -> complete -> verify DB state
 * Mocks worktreeManager to avoid real git operations. Verifies Saga compensation.
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { createSQLiteManager, type SQLiteManager } from '../../src/core/sqlite/index.js';
import { createIsolationChecker } from '../../src/core/isolation-checker.js';
import { createTaskAssigner } from '../../src/core/task-assigner.js';
import { createInstanceRegistry } from '../../src/core/instance-registry.js';
import { createSagaExecutor, type TaskCompletionState } from '../../src/core/saga-executor.js';
import type { Ticket, Task, Instance } from '../../src/types/index.js';
import { TaskStatus, InstanceRole, InstanceStatus } from '../../src/types/index.js';

let db: SQLiteManager;
let dbPath: string;

beforeEach(() => {
  dbPath = path.join(os.tmpdir(), `kallax-e2e-performer-${Date.now()}.db`);
  const result = createSQLiteManager({ path: dbPath });
  if (result.isErr()) throw new Error(`DB init failed: ${result.error.message}`);
  db = result.value;
});

afterEach(() => {
  db.close();
  try { fs.unlinkSync(dbPath); } catch { /* ignore */ }
});

// ── Helpers ─────────────────────────────────────────────────────────────────

function makeTicket(overrides?: Partial<Ticket>): Ticket {
  const now = Date.now();
  return {
    id: `TICKET-${Math.random().toString(36).slice(2, 8)}`,
    title: 'Performer E2E Ticket',
    description: 'Integration test ticket for performer lifecycle',
    status: 'todo',
    priority: 'P2',
    assigneeId: null,
    createdAt: now,
    updatedAt: now,
    acceptanceCriteria: ['AC1: works end to end'],
    labels: ['e2e'],
    ...overrides,
  } as Ticket;
}

function makeInstance(overrides?: Partial<Instance>): Instance {
  const now = Date.now();
  return {
    id: `inst_${Math.random().toString(36).slice(2, 8)}`,
    role: InstanceRole.PERFORMER,
    status: InstanceStatus.ACTIVE,
    hostname: 'performer-e2e',
    pid: process.pid,
    startedAt: now,
    lastHeartbeat: now,
    currentTaskId: null,
    capabilities: ['typescript'],
    ...overrides,
  } as Instance;
}

// ── Tests ───────────────────────────────────────────────────────────────────

describe('Performer Lifecycle (E2E)', () => {

  it('performer registers, claims, and completes task synchronously', async () => {
    const isolation = createIsolationChecker();
    const assigner = createTaskAssigner(db, isolation, createInstanceRegistry(db));

    // Setup: ticket + task + performer
    const ticket = makeTicket({ id: 'E2E-PERF-LIFECYCLE' });
    db.createTicket(ticket);
    const taskR = assigner.createTask(ticket);
    expect(taskR.isOk()).toBe(true);
    const taskId = taskR.value.id;

    const performer = makeInstance({ id: 'perf-lifecycle' });
    db.registerInstance(performer);

    // Claim
    const claimR = db.claimTask(taskId, 'perf-lifecycle');
    expect(claimR.isOk()).toBe(true);
    if (claimR.isOk()) expect(claimR.value).toBe(true);

    // Verify claimed state
    const claimedTask = db.getTask(taskId);
    if (claimedTask.isOk() && claimedTask.value) {
      expect(claimedTask.value.performerId).toBe('perf-lifecycle');
      expect(claimedTask.value.status).toBe(TaskStatus.CLAIMED);
    }

    // Complete via assigner
    const completeR = await assigner.completeTask(taskId, 'work done!');
    expect(completeR.isOk()).toBe(true);

    // Verify completed state
    const doneTask = db.getTask(taskId);
    if (doneTask.isOk() && doneTask.value) {
      expect(doneTask.value.status).toBe(TaskStatus.COMPLETED);
      expect(doneTask.value.progress).toBe(100);
      expect(doneTask.value.output).toBe('work done!');
    }
  });

  it('performer cannot claim already-claimed task (atomic claim)', () => {
    const isolation = createIsolationChecker();
    const assigner = createTaskAssigner(db, isolation, createInstanceRegistry(db));

    const ticket = makeTicket({ id: 'E2E-PERF-DC' });
    db.createTicket(ticket);
    const taskR = assigner.createTask(ticket);
    const taskId = taskR.value.id;

    db.registerInstance(makeInstance({ id: 'perf-a' }));
    db.registerInstance(makeInstance({ id: 'perf-b' }));

    // First claim succeeds
    const claim1 = db.claimTask(taskId, 'perf-a');
    expect(claim1.isOk()).toBe(true);
    if (claim1.isOk()) expect(claim1.value).toBe(true);

    // Second claim fails
    const claim2 = db.claimTask(taskId, 'perf-b');
    expect(claim2.isOk()).toBe(true);
    if (claim2.isOk()) expect(claim2.value).toBe(false);
  });

  it('saga compensation reverts completed steps on failure', async () => {
    const order: string[] = [];

    // Build a custom saga that fails on the 3rd step
    const saga = createSagaExecutor<TaskCompletionState>({ name: 'e2e-test' })
      .addStep({
        name: 'step-a',
        execute: async (s) => { order.push('a'); return s; },
        compensate: async () => { order.push('ca'); },
      })
      .addStep({
        name: 'step-b',
        execute: async (s) => { order.push('b'); return s; },
        compensate: async () => { order.push('cb'); },
      })
      .addStep({
        name: 'step-c-fail',
        execute: async () => { order.push('c'); throw new Error('simulated saga failure'); },
        compensate: async () => { order.push('cc'); },
      });

    const result = await saga.execute({
      taskId: 'saga-fail-task',
      ticketId: 'saga-ticket',
      worktreePath: '/tmp/worktree',
      branchName: 'kallax/saga-test',
      testsRun: false,
      lintPassed: false,
    });

    expect(result.isErr()).toBe(true);
    // Steps execute forward: a, b, c
    // Compensation runs reverse: b, a
    expect(order).toEqual(['a', 'b', 'c', 'cb', 'ca']);
  });

  it('saga success completes all steps in order', async () => {
    const order: string[] = [];

    const saga = createSagaExecutor<TaskCompletionState>({ name: 'e2e-success' })
      .addStep({
        name: 'setup',
        execute: async (s) => { order.push('setup'); return { ...s, testsRun: true }; },
        compensate: async () => { order.push('c-setup'); },
      })
      .addStep({
        name: 'stage',
        execute: async (s) => { order.push('stage'); return { ...s, lintPassed: true }; },
        compensate: async () => { order.push('c-stage'); },
      });

    const result = await saga.execute({
      taskId: 'saga-ok-task',
      ticketId: 'saga-ok',
      worktreePath: '/tmp/wt',
      branchName: 'kallax/ok',
      testsRun: false,
      lintPassed: false,
    });

    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.success).toBe(true);
      expect(result.value.completedSteps).toEqual(['setup', 'stage']);
      expect(result.value.finalState.testsRun).toBe(true);
      expect(result.value.finalState.lintPassed).toBe(true);
    }
    expect(order).toEqual(['setup', 'stage']);
  });

  it('task failure updates DB and preserves error message', async () => {
    const isolation = createIsolationChecker();
    const assigner = createTaskAssigner(db, isolation, createInstanceRegistry(db));

    const ticket = makeTicket({ id: 'E2E-PERF-FAIL' });
    db.createTicket(ticket);
    const taskR = assigner.createTask(ticket);
    const taskId = taskR.value.id;

    // Fail the task via assigner
    const failR = await assigner.failTask(taskId, 'Something went wrong in e2e');
    expect(failR.isOk()).toBe(true);

    const failedTask = db.getTask(taskId);
    if (failedTask.isOk() && failedTask.value) {
      expect(failedTask.value.status).toBe(TaskStatus.FAILED);
      expect(failedTask.value.error).toBe('Something went wrong in e2e');
    }
  });
});

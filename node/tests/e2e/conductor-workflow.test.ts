/**
 * KALLAX E2E: Conductor Workflow
 * Full conductor flow: create ticket -> create task -> register performer -> poll finds task
 * Uses real SQLite with temp DB file. Verifies conductor heartbeat output.
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { createSQLiteManager, type SQLiteManager } from '../../src/core/sqlite/index.js';
import { createIsolationChecker } from '../../src/core/isolation-checker.js';
import { createTaskAssigner } from '../../src/core/task-assigner.js';
import { createInstanceRegistry } from '../../src/core/instance-registry.js';
import { createHeartbeatMonitor } from '../../src/core/heartbeat-monitor.js';
import type { Ticket, Task, Instance } from '../../src/types/index.js';
import { TaskStatus, InstanceRole, InstanceStatus } from '../../src/types/index.js';

let db: SQLiteManager;
let dbPath: string;

beforeEach(() => {
  dbPath = path.join(os.tmpdir(), `kallax-e2e-conductor-${Date.now()}.db`);
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
    title: overrides?.title ?? 'E2E Conductor Ticket',
    description: overrides?.description ?? 'Integration test ticket',
    status: 'backlog',
    priority: 'P2',
    assigneeId: null,
    createdAt: now,
    updatedAt: now,
    acceptanceCriteria: ['AC1: passes e2e test'],
    labels: ['e2e'],
    ...overrides,
  } as Ticket;
}

function makeTask(ticketId: string, overrides?: Partial<Task>): Task {
  const now = Date.now();
  return {
    id: `task_${Math.random().toString(36).slice(2, 8)}`,
    ticketId,
    type: 'development',
    status: 'pending',
    performerId: null,
    createdAt: now,
    updatedAt: now,
    progress: 0,
    ...overrides,
  } as Task;
}

function makeInstance(overrides?: Partial<Instance>): Instance {
  const now = Date.now();
  return {
    id: `inst_${Math.random().toString(36).slice(2, 8)}`,
    role: InstanceRole.PERFORMER,
    status: InstanceStatus.ACTIVE,
    hostname: 'e2e-test-host',
    pid: process.pid,
    startedAt: now,
    lastHeartbeat: now,
    currentTaskId: null,
    capabilities: ['typescript'],
    ...overrides,
  } as Instance;
}

// ── Tests ───────────────────────────────────────────────────────────────────

describe('Conductor Workflow (E2E)', () => {

  it('creates ticket, creates task, registers performer, and poll finds the task', async () => {
    const isolation = createIsolationChecker();
    const registry = createInstanceRegistry(db);
    const assigner = createTaskAssigner(db, isolation, registry);

    // 1. Create ticket
    const ticket = makeTicket({ id: 'E2E-COND-001' });
    const ticketResult = db.createTicket(ticket);
    expect(ticketResult.isOk()).toBe(true);

    // 2. Conductor creates a task from the ticket
    const taskResult = assigner.createTask(ticket);
    expect(taskResult.isOk()).toBe(true);
    const taskId = taskResult.value.id;

    // 3. Verify task is pending
    const pendingTasks = db.listTasks({ status: 'pending' });
    expect(pendingTasks.isOk()).toBe(true);
    if (pendingTasks.isOk()) {
      expect(pendingTasks.value.some((t) => t.id === taskId)).toBe(true);
      expect(pendingTasks.value.length).toBe(1);
    }

    // 4. Register a performer instance
    const performer = makeInstance({ id: 'perf-e2e-cond' });
    db.registerInstance(performer);

    // 5. Performer polls — claimNextTask should find our task
    const claimed = await assigner.claimNextTask('perf-e2e-cond');
    expect(claimed.isOk()).toBe(true);
    if (claimed.isOk()) {
      expect(claimed.value).not.toBeNull();
      expect(claimed.value!.id).toBe(taskId);
      expect(claimed.value!.performerId).toBe('perf-e2e-cond');
      expect(claimed.value!.status).toBe(TaskStatus.CLAIMED);
    }
  });

  it('conductor heartbeat monitor works with real DB', async () => {
    const registry = createInstanceRegistry(db);

    // Register conductor instance
    const conductor = makeInstance({
      id: 'cond-heartbeat',
      role: InstanceRole.CONDUCTOR,
    });
    db.registerInstance(conductor);

    // Create heartbeat monitor (fast intervals for test)
    const monitor = createHeartbeatMonitor(registry, {
      heartbeatIntervalMs: 50,
      staleThresholdMs: 5000,
      checkIntervalMs: 100,
    });

    // Register onStaleInstance handler to capture output
    const staleCaught: Instance[] = [];
    monitor.onStaleInstance(async (instances) => {
      staleCaught.push(...instances);
    });

    monitor.start();
    expect(monitor.isRunning()).toBe(true);

    // Wait for a few heartbeats
    await new Promise((r) => setTimeout(r, 200));
    expect(monitor.getStats().heartbeatsSent).toBeGreaterThanOrEqual(1);

    // Verify heartbeat updated in DB
    const instanceResult = db.getInstance('cond-heartbeat');
    if (instanceResult.isOk() && instanceResult.value) {
      expect(instanceResult.value.lastHeartbeat).toBeGreaterThan(conductor.lastHeartbeat);
    }

    monitor.stop();
    expect(monitor.isRunning()).toBe(false);

    // No stale instances detected within short window
    expect(staleCaught.length).toBe(0);
  });

  it('conductor can list and manage multiple tasks', () => {
    const isolation = createIsolationChecker();
    const registry = createInstanceRegistry(db);
    const assigner = createTaskAssigner(db, isolation, registry);

    // Create ticket with file scope for isolation checking
    const ticket = makeTicket({
      id: 'E2E-COND-MULTI',
      fileScope: ['src/feature-a/**'],
    });
    db.createTicket(ticket);

    // Create 3 tasks
    const t1R = assigner.createTask(ticket);
    expect(t1R.isOk()).toBe(true);
    const t2R = assigner.createTask(ticket);
    expect(t2R.isOk()).toBe(true);
    const t3R = assigner.createTask(ticket);
    expect(t3R.isOk()).toBe(true);

    // List all pending tasks
    const allPending = db.listTasks({ status: 'pending' });
    expect(allPending.isOk()).toBe(true);
    if (allPending.isOk()) {
      expect(allPending.value.length).toBe(3);
    }

    // Assignable tasks (with isolation check)
    const assignable = assigner.getAssignableTasks();
    expect(assignable.isOk()).toBe(true);
  });

  it('verifies DB stats match conductor state', () => {
    const ticket = makeTicket({ id: 'E2E-COND-STATS' });
    db.createTicket(ticket);
    const task = makeTask('E2E-COND-STATS');
    db.createTask(task);

    const performer = makeInstance({ id: 'perf-stats' });
    db.registerInstance(performer);

    const stats = db.getStats();
    expect(stats.ticketCount).toBe(1);
    expect(stats.taskCount).toBe(1);
    expect(stats.instanceCount).toBe(1);
  });
});

/**
 * KALLAX E2E: Agent Farm
 * Persistent service managing the Performer pool.
 *
 * Tests:
 *   1. Farm lifecycle (start/stop)
 *   2. Register performers and check state
 *   3. Enqueue tasks, register performers, auto-assign by capability
 *   4. Complete tasks and verify stats
 *   5. Full workflow with multiple performers
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { createSQLiteManager, type SQLiteManager } from '../../src/core/sqlite/index.js';
import { createInstanceRegistry, type InstanceRegistry } from '../../src/core/instance-registry.js';
import { createClaimQueue, type ClaimQueue } from '../../src/core/claim-queue.js';
import { createExpertMatcher, type ExpertMatcher } from '../../src/core/expert-matcher.js';
import {
  createAgentFarm,
  resetAgentFarm,
  type AgentFarm,
} from '../../src/core/agent-farm.js';
import type { Instance } from '../../src/types/index.js';

// ============================================================================
// Helpers
// ============================================================================

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function makeConductorInstance(): Instance {
  return {
    id: 'conductor-1',
    role: 'conductor',
    status: 'active',
    hostname: 'localhost',
    pid: process.pid,
    startedAt: Date.now(),
    lastHeartbeat: Date.now(),
    currentTaskId: null,
    capabilities: [],
  };
}

// ============================================================================
// Agent Farm Tests
// ============================================================================

describe('AgentFarm (E2E)', () => {
  let db: SQLiteManager;
  let registry: InstanceRegistry;
  let claimQueue: ClaimQueue;
  let expertMatcher: ExpertMatcher;
  let farm: AgentFarm;

  beforeEach(async () => {
    resetAgentFarm();

    const dbResult = createSQLiteManager({ path: ':memory:' });
    if (dbResult.isErr()) throw new Error(`DB init failed: ${dbResult.error.message}`);
    db = dbResult.value;

    db.registerInstance(makeConductorInstance());

    registry = createInstanceRegistry(db);
    claimQueue = createClaimQueue();
    expertMatcher = createExpertMatcher();
  });

  afterEach(async () => {
    try {
      await farm.stop();
    } catch {
      // ignore
    }
    try {
      db.close();
    } catch {
      // ignore
    }
  });

  // ---------------------------------------------------------------------------
  // 1. Farm Lifecycle
  // ---------------------------------------------------------------------------

  it('starts and stops without errors', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    expect(farm.getState().status).toBe('stopped');

    await farm.start();
    // Empty farm (no performers yet) is 'degraded', not 'running'
    expect(farm.getState().status).toBe('degraded');

    await farm.stop();
    expect(farm.getState().status).toBe('stopped');
  });

  it('start is idempotent — second start is a no-op', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();
    const state1 = farm.getState();
    await farm.start(); // should not throw
    const state2 = farm.getState();
    expect(state2.status).toBe(state1.status);
  });

  // ---------------------------------------------------------------------------
  // 2. Performer Registration
  // ---------------------------------------------------------------------------

  it('registers a performer and reflects in state', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();

    const perfId = await farm.registerPerformer(['typescript', 'react']);
    expect(perfId).toBeTruthy();
    expect(perfId.startsWith('perf_')).toBe(true);

    const state = farm.getState();
    expect(state.totalPerformers).toBe(1);
    expect(state.idlePerformers).toBe(1);
    expect(state.busyPerformers).toBe(0);
  });

  it('registers multiple performers', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();

    await farm.registerPerformer(['typescript']);
    await farm.registerPerformer(['python', 'ml']);
    await farm.registerPerformer(['go', 'rust']);

    const state = farm.getState();
    expect(state.totalPerformers).toBe(3);
    expect(state.idlePerformers).toBe(3);
  });

  it('rejects registration beyond maxPerformers', async () => {
    farm = createAgentFarm(
      claimQueue,
      expertMatcher,
      registry,
      'conductor-1',
      { maxPerformers: 2 }
    );
    await farm.start();

    await farm.registerPerformer(['ts']);
    await farm.registerPerformer(['py']);
    await expect(farm.registerPerformer(['go'])).rejects.toThrow('Farm at capacity');
  });

  it('unregisters a performer and re-queues its task', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();

    const perfId = await farm.registerPerformer(['ts']);

    // Enqueue a task and assign it
    claimQueue.enqueue('task-1', 'ticket-1', 100, []);
    const task = await farm.getNextTask(perfId);
    expect(task).not.toBeNull();

    // Unregister — task should be re-queued
    await farm.unregisterPerformer(perfId);

    const stateAfter = farm.getState();
    expect(stateAfter.totalPerformers).toBe(0);
    expect(stateAfter.taskQueueDepth).toBe(1); // task was re-queued
  });

  // ---------------------------------------------------------------------------
  // 3. Task Assignment
  // ---------------------------------------------------------------------------

  it('returns null when no tasks available', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();

    const perfId = await farm.registerPerformer(['ts']);
    const task = await farm.getNextTask(perfId);
    expect(task).toBeNull();
  });

  it('returns null for unknown performer', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();

    const task = await farm.getNextTask('nonexistent');
    expect(task).toBeNull();
  });

  it('assigns tasks by priority respecting capabilities', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();

    // Register two performers with different capabilities
    const tsPerf = await farm.registerPerformer(['typescript']);
    const pyPerf = await farm.registerPerformer(['python']);

    // Enqueue tasks with different priority + capability requirements
    claimQueue.enqueue('ts-task', 'ticket-ts', 500, ['typescript']);
    claimQueue.enqueue('py-task', 'ticket-py', 100, ['python']);
    claimQueue.enqueue('any-task', 'ticket-any', 1000, []);

    // TS performer gets any-task first (highest priority)
    const task1 = await farm.getNextTask(tsPerf);
    expect(task1).not.toBeNull();
    expect(task1!.taskId).toBe('any-task');

    // Complete any-task so TS performer can claim next
    await farm.completeTask(tsPerf, task1!.taskId, true);

    // Now TS performer gets ts-task (matches their capability)
    const task2 = await farm.getNextTask(tsPerf);
    expect(task2).not.toBeNull();
    expect(task2!.taskId).toBe('ts-task');
    await farm.completeTask(tsPerf, task2!.taskId, true);

    // Python performer gets py-task
    const task3 = await farm.getNextTask(pyPerf);
    expect(task3).not.toBeNull();
    expect(task3!.taskId).toBe('py-task');
    await farm.completeTask(pyPerf, task3!.taskId, true);

    // No more tasks
    const task4 = await farm.getNextTask(pyPerf);
    expect(task4).toBeNull();
  });

  it('returns null when performer already has an active task', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();

    const perfId = await farm.registerPerformer(['ts']);
    claimQueue.enqueue('task-1', 'ticket-1', 100, []);

    const first = await farm.getNextTask(perfId);
    expect(first).not.toBeNull();

    // Second call while busy should return null
    const second = await farm.getNextTask(perfId);
    expect(second).toBeNull();
  });

  // ---------------------------------------------------------------------------
  // 4. Task Completion & Stats
  // ---------------------------------------------------------------------------

  it('tracks completed and failed tasks in stats', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();

    const perfId = await farm.registerPerformer(['ts']);

    claimQueue.enqueue('task-ok', 'ticket-ok', 100, []);
    claimQueue.enqueue('task-fail', 'ticket-fail', 90, []);

    // Complete first task successfully
    const task1 = await farm.getNextTask(perfId);
    expect(task1).not.toBeNull();
    await farm.completeTask(perfId, task1!.taskId, true);

    // Complete second task as failure
    const task2 = await farm.getNextTask(perfId);
    expect(task2).not.toBeNull();
    await farm.completeTask(perfId, task2!.taskId, false);

    const stats = farm.getStats();
    expect(stats.tasksCompleted).toBe(1);
    expect(stats.tasksFailed).toBe(1);
    // avgCompletionMs can be 0 if tasks complete in same millisecond
    expect(stats.avgCompletionMs).toBeGreaterThanOrEqual(0);
  });

  it('performer becomes idle again after completing a task', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();

    const perfId = await farm.registerPerformer(['ts']);
    claimQueue.enqueue('task-1', 'ticket-1', 100, []);

    // Before: idle
    expect(farm.getState().idlePerformers).toBe(1);

    // Claim: busy
    const task = await farm.getNextTask(perfId);
    expect(farm.getState().busyPerformers).toBe(1);
    expect(farm.getState().idlePerformers).toBe(0);

    // Complete: idle again
    await farm.completeTask(perfId, task!.taskId, true);
    expect(farm.getState().busyPerformers).toBe(0);
    expect(farm.getState().idlePerformers).toBe(1);
  });

  it('ignores completion with mismatched task id', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();

    const perfId = await farm.registerPerformer(['ts']);
    claimQueue.enqueue('task-1', 'ticket-1', 100, []);

    const task = await farm.getNextTask(perfId);
    expect(task).not.toBeNull();

    // Complete with wrong task id — no-op
    await farm.completeTask(perfId, 'wrong-task-id', true);

    // Performer should still be busy with original task
    expect(farm.getState().busyPerformers).toBe(1);
  });

  // ---------------------------------------------------------------------------
  // 5. Full Workflow: 2 performers, 3 tasks, verify state
  // ---------------------------------------------------------------------------

  it('full workflow: 2 performers, 3 tasks, auto-assign, verify all states', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();

    // Register 2 performers
    const perfA = await farm.registerPerformer(['typescript', 'react']);
    const perfB = await farm.registerPerformer(['python', 'ml']);

    // Create 3 tasks with different capabilities
    claimQueue.enqueue('fe-task', 'ticket-fe', 100, ['typescript', 'react']);
    claimQueue.enqueue('ml-task', 'ticket-ml', 100, ['python', 'ml']);
    claimQueue.enqueue('any-task', 'ticket-any', 50, []);

    // State before any assignment
    let state = farm.getState();
    expect(state.totalPerformers).toBe(2);
    expect(state.taskQueueDepth).toBe(3);

    // perfA gets fe-task (exact capability match, high priority)
    const t1 = await farm.getNextTask(perfA);
    expect(t1).not.toBeNull();
    expect(t1!.taskId).toBe('fe-task');

    // perfB gets ml-task (exact capability match, high priority)
    const t2 = await farm.getNextTask(perfB);
    expect(t2).not.toBeNull();
    expect(t2!.taskId).toBe('ml-task');

    state = farm.getState();
    expect(state.busyPerformers).toBe(2);
    expect(state.idlePerformers).toBe(0);
    expect(state.taskQueueDepth).toBe(1); // any-task still pending

    // Complete both tasks
    await farm.completeTask(perfA, t1!.taskId, true);
    await farm.completeTask(perfB, t2!.taskId, true);

    // perfA gets remaining any-task
    const t3 = await farm.getNextTask(perfA);
    expect(t3).not.toBeNull();
    expect(t3!.taskId).toBe('any-task');

    await farm.completeTask(perfA, t3!.taskId, true);

    // Final state
    state = farm.getState();
    expect(state.taskQueueDepth).toBe(0);
    expect(state.idlePerformers).toBe(2);
    expect(state.busyPerformers).toBe(0);

    const stats = farm.getStats();
    expect(stats.tasksCompleted).toBe(3);
    expect(stats.tasksFailed).toBe(0);
    expect(stats.avgCompletionMs).toBeGreaterThanOrEqual(0);
    expect(stats.uptime).toBeGreaterThanOrEqual(0);
  });

  // ---------------------------------------------------------------------------
  // 6. getStats with uptime
  // ---------------------------------------------------------------------------

  it('getStats returns uptime info after start', async () => {
    farm = createAgentFarm(claimQueue, expertMatcher, registry, 'conductor-1');
    await farm.start();
    await sleep(10);

    const stats = farm.getStats();
    expect(stats.uptime).toBeGreaterThanOrEqual(10);
    expect(stats.tasksCompleted).toBe(0);
    expect(stats.tasksFailed).toBe(0);
    expect(stats.avgCompletionMs).toBe(0);
  });

  // ---------------------------------------------------------------------------
  // 7. Status transitions
  // ---------------------------------------------------------------------------

  it('status is degraded when farm is below capacity', async () => {
    farm = createAgentFarm(
      claimQueue,
      expertMatcher,
      registry,
      'conductor-1',
      { maxPerformers: 5, minIdle: 2 }
    );
    await farm.start();

    // Only 1 performer, far below maxPerformers=5
    await farm.registerPerformer(['ts']);
    expect(farm.getState().status).toBe('degraded');

    // Fill to full capacity
    for (let i = 0; i < 4; i++) {
      await farm.registerPerformer([`lang-${i}`]);
    }
    expect(farm.getState().status).toBe('running');
  });
});

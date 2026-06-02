/**
 * KALLAX Performer Commands
 * Registration and polling for Performer role
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult, Task, Instance } from '../types/index.js';
import { KallaxError, KallaxErrorCode, InstanceRole } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { SQLiteManager } from '../core/sqlite-manager.js';
import type { InstanceRegistry } from '../core/instance-registry.js';
import type { TaskAssigner } from '../core/task-assigner.js';
import type { WorktreeManager } from '../core/worktree-manager.js';

// ============================================================================
// Performer Register
// ============================================================================

export interface PerformerRegisterOptions {
  readonly name?: string;
  readonly capabilities?: string[];
  readonly maxConcurrentTasks?: number;
}

export interface PerformerRegisterResult {
  readonly instance: Instance;
  readonly registered: boolean;
}

export async function executePerformerRegister(
  instanceRegistry: InstanceRegistry,
  options: PerformerRegisterOptions = {}
): Promise<KallaxResult<PerformerRegisterResult>> {
  const { capabilities = [], name } = options;

  // Check if already registered
  const existing = instanceRegistry.getCurrentInstance();
  if (existing !== null) {
    logger.warn({ instanceId: existing.id }, 'performer already registered');
    return ok({
      instance: existing,
      registered: false,
    });
  }

  // Register new performer instance
  const registerResult = await instanceRegistry.register(InstanceRole.PERFORMER, capabilities);
  if (registerResult.isErr()) {
    return err(registerResult.error);
  }

  // Update status to active
  await instanceRegistry.updateStatus(registerResult.value.id, 'active');

  logger.info(
    {
      instanceId: registerResult.value.id,
      capabilities,
      name,
    },
    'performer registered'
  );

  return ok({
    instance: registerResult.value,
    registered: true,
  });
}

// ============================================================================
// Performer Poll
// ============================================================================

export interface PerformerPollOptions {
  readonly autoClaim?: boolean;
  readonly capabilities?: string[];
}

export interface PerformerPollResult {
  readonly status: Instance['status'];
  readonly currentTask: Task | null;
  readonly availableTasks: number;
  readonly claimedTask: Task | null;
}

export async function executePerformerPoll(
  db: SQLiteManager,
  instanceRegistry: InstanceRegistry,
  taskAssigner: TaskAssigner,
  worktreeManager: WorktreeManager,
  options: PerformerPollOptions = {}
): Promise<KallaxResult<PerformerPollResult>> {
  const { autoClaim = false, capabilities = [] } = options;

  const currentInstance = instanceRegistry.getCurrentInstance();
  if (currentInstance === null) {
    return err(
      new KallaxError(KallaxErrorCode.INSTANCE_NOT_FOUND, 'Performer not registered')
    );
  }

  if (currentInstance.role !== 'performer') {
    return err(
      new KallaxError(KallaxErrorCode.PERMISSION_DENIED, 'Not a performer instance', {
        metadata: { role: currentInstance.role },
      })
    );
  }

  // Update heartbeat
  await instanceRegistry.heartbeat(currentInstance.id);

  // Get current task if any
  let currentTask: Task | null = null;
  if (currentInstance.currentTaskId !== null) {
    const taskResult = db.getTask(currentInstance.currentTaskId);
    if (taskResult.isOk()) {
      currentTask = taskResult.value;
    }
  }

  // Get available task count
  const availableResult = await taskAssigner.getAssignableTasks();
  const availableTasks = availableResult.isOk() ? availableResult.value.length : 0;

  // Auto-claim if enabled and idle
  let claimedTask: Task | null = null;
  if (autoClaim && currentTask === null && currentInstance.status !== 'busy') {
    const claimResult = await taskAssigner.claimNextTask(currentInstance.id, capabilities);
    if (claimResult.isOk() && claimResult.value !== null) {
      claimedTask = claimResult.value;

      // Create worktree
      const worktreeResult = await worktreeManager.create(claimedTask.id);
      if (worktreeResult.isErr()) {
        // Rollback claim
        await taskAssigner.releaseTask(claimedTask.id);
        claimedTask = null;
        logger.warn({ taskId: claimResult.value.id }, 'failed to create worktree after claim');
      } else {
        // Update instance status
        await instanceRegistry.updateStatus(currentInstance.id, 'busy');
        logger.info(
          { taskId: claimedTask.id, worktreePath: worktreeResult.value.path },
          'task auto-claimed'
        );
      }
    }
  }

  logger.debug(
    {
      instanceId: currentInstance.id,
      status: currentInstance.status,
      currentTaskId: currentTask?.id ?? null,
      availableTasks,
      claimed: claimedTask !== null,
    },
    'performer poll completed'
  );

  return ok({
    status: currentInstance.status,
    currentTask,
    availableTasks,
    claimedTask,
  });
}

// ============================================================================
// Performer Status
// ============================================================================

export interface PerformerStatusResult {
  readonly instance: Instance | null;
  readonly currentTask: Task | null;
  readonly worktreePath: string | null;
  readonly uptime: number;
  readonly tasksCompleted: number;
}

export async function executePerformerStatus(
  db: SQLiteManager,
  instanceRegistry: InstanceRegistry,
  worktreeManager: WorktreeManager
): Promise<KallaxResult<PerformerStatusResult>> {
  const currentInstance = instanceRegistry.getCurrentInstance();

  if (currentInstance === null) {
    return ok({
      instance: null,
      currentTask: null,
      worktreePath: null,
      uptime: 0,
      tasksCompleted: 0,
    });
  }

  // Get current task
  let currentTask: Task | null = null;
  let worktreePath: string | null = null;

  if (currentInstance.currentTaskId !== null) {
    const taskResult = db.getTask(currentInstance.currentTaskId);
    if (taskResult.isOk()) {
      currentTask = taskResult.value;
    }

    // Get worktree path
    const worktreeResult = await worktreeManager.getByTaskId(currentInstance.currentTaskId);
    if (worktreeResult.isOk() && worktreeResult.value !== null) {
      worktreePath = worktreeResult.value.path;
    }
  }

  // Count completed tasks by this performer
  const tasksResult = db.listTasks({ performerId: currentInstance.id });
  const tasksCompleted = tasksResult.isOk()
    ? tasksResult.value.filter((t) => t.status === 'completed').length
    : 0;

  const uptime = Date.now() - currentInstance.startedAt;

  return ok({
    instance: currentInstance,
    currentTask,
    worktreePath,
    uptime,
    tasksCompleted,
  });
}

/**
 * KALLAX Claim Command
 * Atomically claim a task and create worktree isolation
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult, Task, Ticket } from '../types/index.js';
import { KallaxError, KallaxErrorCode, TaskStatus } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { SQLiteManager } from '../core/sqlite-manager.js';
import type { WorktreeManager } from '../core/worktree-manager.js';
import type { InstanceRegistry } from '../core/instance-registry.js';
import type { TaskAssigner } from '../core/task-assigner.js';

export interface ClaimCommandOptions {
  readonly taskId?: string;
  readonly ticketId?: string;
  readonly capabilities?: string[];
}

export interface ClaimResult {
  readonly task: Task;
  readonly ticket: Ticket;
  readonly worktreePath: string;
}

export async function executeClaimCommand(
  db: SQLiteManager,
  worktreeManager: WorktreeManager,
  instanceRegistry: InstanceRegistry,
  taskAssigner: TaskAssigner,
  options: ClaimCommandOptions
): Promise<KallaxResult<ClaimResult>> {
  const currentInstance = instanceRegistry.getCurrentInstance();

  if (currentInstance === null) {
    return err(
      new KallaxError(KallaxErrorCode.INSTANCE_NOT_FOUND, 'No active instance registered')
    );
  }

  if (currentInstance.role !== 'performer') {
    return err(
      new KallaxError(KallaxErrorCode.PERMISSION_DENIED, 'Only performers can claim tasks', {
        metadata: { role: currentInstance.role },
      })
    );
  }

  // Check if already working on a task
  if (currentInstance.currentTaskId !== null) {
    return err(
      new KallaxError(KallaxErrorCode.TASK_INVALID_STATE, 'Already working on a task', {
        metadata: { currentTaskId: currentInstance.currentTaskId },
      })
    );
  }

  let task: Task | null = null;

  // If taskId specified, claim that specific task
  if (options.taskId !== undefined) {
    const assignResult = await taskAssigner.assignTask(options.taskId, currentInstance.id);
    if (assignResult.isErr()) {
      return err(assignResult.error);
    }
    task = assignResult.value;
  }
  // If ticketId specified, find/create task for that ticket
  else if (options.ticketId !== undefined) {
    const ticketResult = db.getTicket(options.ticketId);
    if (ticketResult.isErr()) {
      return err(ticketResult.error);
    }
    if (ticketResult.value === null) {
      return err(
        new KallaxError(KallaxErrorCode.TICKET_NOT_FOUND, 'Ticket not found', {
          metadata: { ticketId: options.ticketId },
        })
      );
    }

    // Look for existing pending task
    const tasksResult = db.listTasks({ ticketId: options.ticketId, status: TaskStatus.PENDING });
    if (tasksResult.isErr()) {
      return err(tasksResult.error);
    }

    if (tasksResult.value.length > 0) {
      const pendingTask = tasksResult.value[0];
      if (pendingTask !== undefined) {
        const assignResult = await taskAssigner.assignTask(pendingTask.id, currentInstance.id);
        if (assignResult.isErr()) {
          return err(assignResult.error);
        }
        task = assignResult.value;
      }
    } else {
      // Create new task for ticket
      const createResult = taskAssigner.createTask(ticketResult.value);
      if (createResult.isErr()) {
        return err(createResult.error);
      }

      const assignResult = await taskAssigner.assignTask(createResult.value.id, currentInstance.id);
      if (assignResult.isErr()) {
        return err(assignResult.error);
      }
      task = assignResult.value;
    }
  }
  // Otherwise claim next available task
  else {
    const claimResult = await taskAssigner.claimNextTask(currentInstance.id, options.capabilities);
    if (claimResult.isErr()) {
      return err(claimResult.error);
    }
    task = claimResult.value;

    if (task === null) {
      return err(
        new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'No available tasks to claim')
      );
    }
  }

  if (task === null) {
    return err(
      new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Failed to claim task')
    );
  }

  // Get associated ticket
  const ticketResult = db.getTicket(task.ticketId);
  if (ticketResult.isErr()) {
    return err(ticketResult.error);
  }
  if (ticketResult.value === null) {
    return err(
      new KallaxError(KallaxErrorCode.TICKET_NOT_FOUND, 'Associated ticket not found', {
        metadata: { ticketId: task.ticketId },
      })
    );
  }

  const ticket = ticketResult.value;

  // Create worktree for isolation
  const worktreeResult = await worktreeManager.create(task.id);
  if (worktreeResult.isErr()) {
    // Rollback: release the task
    await taskAssigner.releaseTask(task.id);
    return err(worktreeResult.error);
  }

  // Update instance with current task
  const updateResult = await instanceRegistry.updateStatus(currentInstance.id, 'busy');
  if (updateResult.isErr()) {
    logger.warn({ instanceId: currentInstance.id }, 'failed to update instance status');
  }

  // Update task with worktree path
  db.updateTask(task.id, { status: TaskStatus.RUNNING });

  logger.info(
    {
      taskId: task.id,
      ticketId: ticket.id,
      worktreePath: worktreeResult.value.path,
      performerId: currentInstance.id,
    },
    'task claimed successfully'
  );

  return ok({
    task,
    ticket,
    worktreePath: worktreeResult.value.path,
  });
}

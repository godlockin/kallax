/**
 * KALLAX Claim Command
 * Atomically claim a task and create worktree isolation
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult, Task, Ticket } from '../types/index.js';
import { KallaxError, KallaxErrorCode, TaskStatus } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { SQLiteManager } from '../core/sqlite/index.js';
import type { WorktreeManager } from '../core/worktree-manager.js';
import type { InstanceRegistry } from '../core/instance-registry.js';
import type { TaskAssigner } from '../core/task-assigner.js';
import { writeBinding, readJiraTicket } from '../jira/ticket-binding.js';

export interface ClaimCommandOptions {
  readonly taskId?: string;
  readonly ticketId?: string;
  readonly capabilities?: string[];
  /** EPIC-157: Performer 实际 expert name (写 jira ticket.json binding) */
  readonly actualExpert?: string;
}

export interface ClaimResult {
  readonly task: Task;
  readonly ticket: Ticket;
  readonly worktreePath: string;
  /** EPIC-157: 是否写了 binding */
  readonly bindingWritten: boolean;
}

export async function executeClaimCommand(
  db: SQLiteManager,
  worktreeManager: WorktreeManager,
  instanceRegistry: InstanceRegistry,
  taskAssigner: TaskAssigner,
  options: ClaimCommandOptions
): Promise<KallaxResult<ClaimResult>> {
  let currentInstance = instanceRegistry.getCurrentInstance();

  // Auto-register performer if CLI invoked standalone (new process each time)
  if (currentInstance === null) {
    const regResult = await instanceRegistry.register('performer');
    if (regResult.isErr()) return err(regResult.error);
    currentInstance = regResult.value;
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

  // EPIC-157 AC3: 写 expert_binding 到 jira ticket.json
  // 读 suggested_expert (Master 拆卡建议), 写 actual_expert (Performer binding)
  let bindingWritten = false;
  if (options.actualExpert !== undefined && options.actualExpert.trim() !== '') {
    const jiraRead = readJiraTicket(ticket.id, process.cwd());
    if (jiraRead.isErr()) {
      logger.warn({ ticketId: ticket.id, error: jiraRead.error }, 'jira ticket.json not found, skip binding write');
    } else {
      const existing = jiraRead.value.ticket.expert_binding;
      const suggested = existing?.suggested_expert ?? null;
      const writeResult = writeBinding(
        ticket.id,
        {
          suggested_expert: suggested,
          actual_expert: options.actualExpert,
          expert_binding_at: new Date().toISOString(),
          binding_change_reason:
            suggested !== null && suggested !== options.actualExpert
              ? 'auto-set by claim (suggested vs actual diverge, run `kallax binding update --reason` to document)'
              : null,
        },
        process.cwd()
      );
      if (writeResult.isErr()) {
        logger.warn(
          { ticketId: ticket.id, error: writeResult.error },
          'failed to write expert_binding to jira ticket.json'
        );
      } else {
        bindingWritten = true;
        logger.info(
          { ticketId: ticket.id, actual: options.actualExpert, suggested },
          'EPIC-157 binding written'
        );
      }
    }
  }

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
    bindingWritten,
  });
}

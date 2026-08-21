/**
 * KALLAX Claim Command
 * Atomically claim a task and create worktree isolation
 */

import { createHash } from 'node:crypto';
import { err, ok } from 'neverthrow';
import type { KallaxResult, Task, Ticket } from '../types/index.js';
import { KallaxError, KallaxErrorCode, TaskStatus } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { SQLiteManager } from '../core/sqlite/index.js';
import type { WorktreeManager } from '../core/worktree-manager.js';
import type { InstanceRegistry } from '../core/instance-registry.js';
import type { TaskAssigner } from '../core/task-assigner.js';
import { writeBinding, readJiraTicket } from '../jira/ticket-binding.js';
import { loadExpertPrompt, type ExpertPromptContext } from '../core/expert-prompt.js';
import type { ExpertInvocationsQueue } from '../core/expert-invocations-queue/types.js';
import type { TraceLog } from '../core/span-tracer.js';

export interface ClaimCommandOptions {
  readonly taskId?: string;
  readonly ticketId?: string;
  readonly capabilities?: string[];
  /** EPIC-157: Performer 实际 expert name (写 jira ticket.json binding) */
  readonly actualExpert?: string;
  /** EPIC-277: DI hooks for expert activation and trace persistence. */
  readonly expertInvocationsQueue?: ExpertInvocationsQueue;
  readonly traceLog?: TraceLog;
  readonly projectRoot?: string;
  readonly resolvedExpertPath?: string;
}

export interface ClaimResult {
  readonly task: Task;
  readonly ticket: Ticket;
  readonly worktreePath: string;
  /** EPIC-157: 是否写了 binding */
  readonly bindingWritten: boolean;
  /** EPIC-277: prompt context passed to performer, when profile is configured. */
  readonly promptContext?: ExpertPromptContext;
}

function metadataString(task: Task, key: string): string | undefined {
  const value = task.metadata?.[key];
  return typeof value === 'string' && value.trim() !== '' ? value : undefined;
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

  let promptContext: ExpertPromptContext | undefined;
  const resolvedExpertPath = options.resolvedExpertPath ?? metadataString(task, 'resolvedExpertPath');
  if (resolvedExpertPath !== undefined) {
    const promptResult = await loadExpertPrompt({
      projectRoot: options.projectRoot ?? process.cwd(),
      resolvedExpertPath,
      task,
      ticket,
    });
    if (promptResult.isErr()) {
      return err(promptResult.error);
    }
    promptContext = promptResult.value;
  }

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

  if (options.expertInvocationsQueue !== undefined) {
    const expertId = options.actualExpert ?? metadataString(task, 'expertId') ?? currentInstance.id;
    const queueResult = await options.expertInvocationsQueue.emit({
      expertId,
      ticketId: ticket.id,
      timestamp: Date.now(),
    });
    if (queueResult.isErr()) {
      logger.warn({ taskId: task.id, ticketId: ticket.id, error: queueResult.error }, 'expert activation enqueue failed');
    }
  }
  if (options.traceLog !== undefined) {
    options.traceLog.record({
      actor: currentInstance.id,
      action: 'expert_activation',
      target: task.id,
      detail: {
        ticketId: ticket.id,
        expertId: options.actualExpert ?? metadataString(task, 'expertId') ?? currentInstance.id,
        profilePath: promptContext?.profilePath,
        profileSha256: promptContext === undefined
          ? undefined
          : createHash('sha256').update(promptContext.profile).digest('hex'),
        promptInjected: promptContext !== undefined,
      },
      result: 'success',
    });
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
    promptContext,
  });
}

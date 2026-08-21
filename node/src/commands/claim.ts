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
import type { ExpertResolverBridge } from '../core/expert-resolver-bridge.js';

/** EPIC-277-D: tri-state exit code mapping. */
export type ClaimExitCode = 0 | 2 | 3;
/** EPIC-277-D: outcome of writing expert_binding to jira ticket.json. */
export type BindingStatus = 'written' | 'skipped' | 'failed';
/** EPIC-277-D: outcome of loading expert profile (resolvedExpertPath). */
export type ProfileStatus = 'loaded' | 'none' | 'failed';

export interface ClaimCommandOptions {
  readonly taskId?: string;
  readonly ticketId?: string;
  readonly capabilities?: string[];
  /** EPIC-157: Performer 实际 expert name (写 jira ticket.json binding) */
  readonly actualExpert?: string;
  /** EPIC-277: DI hooks for expert activation and trace persistence. */
  readonly expertInvocationsQueue?: ExpertInvocationsQueue;
  readonly traceLog?: TraceLog;
  /** EPIC-277-D: optional ExpertResolverBridge used to resolve actualExpert → resolvedExpertPath. */
  readonly expertResolver?: ExpertResolverBridge;
  readonly projectRoot?: string;
  readonly resolvedExpertPath?: string;
}

export interface ClaimResult {
  readonly task: Task;
  readonly ticket: Ticket;
  readonly worktreePath: string;
  /** EPIC-157: 是否写了 binding (legacy single-bool, true ≡ bindingStatus==='written'). */
  readonly bindingWritten: boolean;
  /** EPIC-157 + EPIC-277-D: tri-state binding outcome. */
  readonly bindingStatus: BindingStatus;
  /** EPIC-277-D: profile load outcome for AC7 exit-code mapping. */
  readonly profileStatus: ProfileStatus;
  /** EPIC-277-D: prompt context passed to performer, when profile is configured. */
  readonly promptContext?: ExpertPromptContext;
  /** EPIC-277-D: process exit code recommended for the CLI wrapper (0 / 2 / 3). */
  readonly exitCode: ClaimExitCode;
  /** EPIC-277-D AC5: pre-formatted stdout affordance (3 lines). */
  readonly affordance: string;
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

  // EPIC-277-D AC3: path-first resolution of actualExpert via expertResolver.
  // Falls back to (a) caller-supplied resolvedExpertPath, (b) task metadata,
  // (c) currentInstance.id — preserving prior behavior when no resolver is wired.
  let promptContext: ExpertPromptContext | undefined;
  let profileStatus: ProfileStatus = 'none';
  let resolvedExpertPath = options.resolvedExpertPath ?? metadataString(task, 'resolvedExpertPath');
  if (resolvedExpertPath === undefined && options.expertResolver !== undefined && options.actualExpert !== undefined && options.actualExpert.trim() !== '') {
    try {
      const hit = await options.expertResolver.path(options.actualExpert);
      if (hit !== null) {
        resolvedExpertPath = hit.path;
      }
    } catch (resolveErr: unknown) {
      logger.warn({ taskId: task.id, error: resolveErr instanceof Error ? resolveErr.message : String(resolveErr) }, 'expertResolver.path failed, falling back');
    }
  }
  resolvedExpertPath ??= currentInstance.id;
  const promptResult = await loadExpertPrompt({
    projectRoot: options.projectRoot ?? process.cwd(),
    resolvedExpertPath,
    task,
    ticket,
  });
  if (promptResult.isErr()) {
    profileStatus = 'failed';
    logger.warn({ taskId: task.id, error: promptResult.error }, 'expert profile load failed');
  } else {
    promptContext = promptResult.value;
    profileStatus = 'loaded';
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
  let bindingStatus: BindingStatus = 'skipped';
  if (options.actualExpert !== undefined && options.actualExpert.trim() !== '') {
    const jiraRead = readJiraTicket(ticket.id, process.cwd());
    if (jiraRead.isErr()) {
      // Ticket.json unreadable (NOT_FOUND, PARSE_FAILED, WRITE_FAILED, VALIDATION_FAILED)
      // counts as a binding write failure for AC7 — caller asked us to bind, the
      // binding didn't take, distinguish from the "no actualExpert given" path.
      bindingStatus = 'failed';
      logger.warn({ ticketId: ticket.id, error: jiraRead.error }, 'jira ticket.json unreadable, binding write failed');
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
        bindingStatus = 'failed';
        logger.warn(
          { ticketId: ticket.id, error: writeResult.error },
          'failed to write expert_binding to jira ticket.json'
        );
      } else {
        bindingStatus = 'written';
        logger.info(
          { ticketId: ticket.id, actual: options.actualExpert, suggested },
          'EPIC-157 binding written'
        );
      }
    }
  }
  const bindingWritten = bindingStatus === 'written';

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
      bindingStatus,
      profileStatus,
    },
    'task claimed successfully'
  );

  // EPIC-277-D AC7: tri-state exit code.
  // 0 = binding written + profile loaded
  // 2 = profile OK but binding write failed (or skipped under expert specified)
  // 3 = profile load failed (binding state independent; bindingStatus decides 0/2 axis)
  let exitCode: ClaimExitCode = 0;
  if (profileStatus === 'failed') exitCode = 3;
  else if (bindingStatus === 'failed') exitCode = 2;

  // EPIC-277-D AC5: stdout affordance — three lines after success.
  // Caller (task-cmd.ts) writes the headline; we expose the per-binding detail.
  // Format: "     Expert bound: <X> (written|skipped|failed)" / Profile: <path|none> / SHA256: <sha[:12]|->.
  const expertLabel = options.actualExpert ?? currentInstance.id;
  const profileLabel = promptContext?.profilePath ?? 'none';
  const shaHex = promptContext === undefined
    ? '-'
    : createHash('sha256').update(promptContext.profile).digest('hex').slice(0, 12);
  const affordance =
    `     Expert bound: ${expertLabel} (${bindingStatus})\n`
    + `     Profile: ${profileLabel}\n`
    + `     SHA256: ${shaHex}\n`;

  return ok({
    task,
    ticket,
    worktreePath: worktreeResult.value.path,
    bindingWritten,
    bindingStatus,
    profileStatus,
    promptContext,
    exitCode,
    affordance,
  });
}

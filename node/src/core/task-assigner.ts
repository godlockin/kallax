/**
 * KALLAX Task Assigner
 * Intelligent task assignment with isolation validation + expertise-aware checkpoints (EPIC-118-C)
 *
 * Anthropic research: expert vs novice abandonment 5-7% vs 19%.
 * CheckpointInterval 根据 performer 历史 abandonment rate 差异化:
 *   L1 (abandonment > 15%): subtask checkpoint (每个子任务必验证)
 *   L2 (abandonment 5-15%): milestone checkpoint (关键节点验证)
 *   L3 (abandonment < 5%): final checkpoint (只验收最终 PR)
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult, Task, Ticket, IsolationScope } from '../types/index.js';
import { KallaxError, KallaxErrorCode, TaskStatus, TaskType } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { SQLiteManager } from './sqlite/index.js';
import type { IsolationChecker } from './isolation-checker.js';
import type { InstanceRegistry } from './instance-registry.js';

export type MasteryLevel = 'L1' | 'L2' | 'L3';
export type CheckpointInterval = 'subtask' | 'milestone' | 'final';

// Anthropic thresholds: novice >15%, intermediate 5-15%, expert <5%
const MASTERY_ABANDONMENT_L1_THRESHOLD = 15; // >15% → L1 (novice)
const MASTERY_ABANDONMENT_L2_THRESHOLD = 5;  // >5%  → L2 (intermediate)
const ABANDONMENT_LOOKBACK_DAYS = 30;

function masteryLevelFromAbandonment(rate: number): MasteryLevel {
  if (rate > MASTERY_ABANDONMENT_L1_THRESHOLD) return 'L1';
  if (rate > MASTERY_ABANDONMENT_L2_THRESHOLD) return 'L2';
  return 'L3';
}

function checkpointIntervalFromMastery(level: MasteryLevel): CheckpointInterval {
  switch (level) {
    case 'L1': return 'subtask';
    case 'L2': return 'milestone';
    case 'L3': return 'final';
  }
}

/**
 * Compute performer's mastery level from historical ticket abandonment rate.
 * Data source: SQLite tasks created for this performer within 30 days.
 */
async function computePerformerMastery(
  db: SQLiteManager,
  performerId: string
): Promise<MasteryLevel> {
  const tasksResult = db.listTasks({});
  if (tasksResult.isErr()) {
    logger.warn({ performerId, error: tasksResult.error.message }, 'computePerformerMastery: listTasks failed, defaulting to L2');
    return 'L2';
  }

  const now = Date.now();
  const lookbackMs = ABANDONMENT_LOOKBACK_DAYS * 24 * 60 * 60 * 1000;
  const cutoff = now - lookbackMs;

  const performerTasks = tasksResult.value.filter(
    (t) => t.performerId === performerId && t.createdAt >= cutoff
  );

  if (performerTasks.length === 0) return 'L2';

  const abandoned = performerTasks.filter((t) => t.status === TaskStatus.FAILED).length;
  const completed = performerTasks.filter((t) => t.status === TaskStatus.COMPLETED).length;
  const total = performerTasks.length;
  const abandonmentRate = total > 0 ? (abandoned / total) * 100 : 0;

  logger.info({ performerId, abandonmentRate: abandonmentRate.toFixed(1), abandoned, completed, total }, 'computePerformerMastery');
  return masteryLevelFromAbandonment(abandonmentRate);
}

export interface TaskAssigner {
  createTask: (ticket: Ticket, type?: TaskType) => KallaxResult<Task>;
  assignTask: (taskId: string, performerId: string) => Promise<KallaxResult<Task>>;
  claimNextTask: (performerId: string, capabilities?: string[]) => Promise<KallaxResult<Task | null>>;
  releaseTask: (taskId: string) => Promise<KallaxResult<void>>;
  completeTask: (taskId: string, output?: string) => Promise<KallaxResult<void>>;
  failTask: (taskId: string, error: string) => Promise<KallaxResult<void>>;
  getAssignableTasks: () => Promise<KallaxResult<Task[]>>;
}

function generateTaskId(): string {
  return `task_${String(Date.now())}_${Math.random().toString(36).slice(2, 8)}`;
}

export function createTaskAssigner(
  db: SQLiteManager,
  isolationChecker: IsolationChecker,
  instanceRegistry: InstanceRegistry
): TaskAssigner {
  return {
    createTask(ticket, type = TaskType.DEVELOPMENT): KallaxResult<Task> {
      const now = Date.now();
      const task: Task = {
        id: generateTaskId(),
        ticketId: ticket.id,
        type,
        status: TaskStatus.PENDING,
        performerId: null,
        createdAt: now,
        updatedAt: now,
        progress: 0,
      };

      const result = db.createTask(task);
      if (result.isErr()) {
        return err(result.error);
      }

      // Register isolation scope if ticket has fileScope
      if (ticket.fileScope !== undefined && ticket.fileScope.length > 0) {
        const scope: IsolationScope = {
          taskId: task.id,
          files: ticket.fileScope,
          directories: [],
          patterns: [],
          exclusive: true,
        };

        // Validate no conflicts
        const conflicts = isolationChecker.validateNewScope(scope);
        if (conflicts.isOk() && conflicts.value.length > 0) {
          logger.warn(
            { taskId: task.id, conflictCount: conflicts.value.length },
            'task has isolation conflicts'
          );
        }

        isolationChecker.registerScope(scope);
      }

      logger.info({ taskId: task.id, ticketId: ticket.id, type }, 'task created');
      return ok(task);
    },

    async assignTask(taskId, performerId): Promise<KallaxResult<Task>> {
      // Verify performer exists and is active
      const performerResult = await instanceRegistry.getById(performerId);
      if (performerResult.isErr()) {
        return err(performerResult.error);
      }

      if (performerResult.value === null) {
        return err(
          new KallaxError(KallaxErrorCode.INSTANCE_NOT_FOUND, 'Performer not found', {
            metadata: { performerId },
          })
        );
      }

      if (performerResult.value.status === 'shutdown' || performerResult.value.status === 'error') {
        return err(
          new KallaxError(KallaxErrorCode.INSTANCE_NOT_FOUND, 'Performer is not active', {
            metadata: { performerId, status: performerResult.value.status },
          })
        );
      }

      // Claim the task atomically
      const claimResult = db.claimTask(taskId, performerId);
      if (claimResult.isErr()) {
        return err(claimResult.error);
      }

      if (!claimResult.value) {
        return err(
          new KallaxError(KallaxErrorCode.TASK_ALREADY_CLAIMED, 'Task already claimed or not available', {
            metadata: { taskId },
          })
        );
      }

      // Get updated task
      const taskResult = db.getTask(taskId);
      if (taskResult.isErr()) {
        return err(taskResult.error);
      }

      if (taskResult.value === null) {
        return err(
          new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Task not found after claim', {
            metadata: { taskId },
          })
        );
      }

      // EPIC-118-C: expertise-aware checkpoints
      const mastery = await computePerformerMastery(db, performerId);
      const checkpointInterval = checkpointIntervalFromMastery(mastery);
      db.updateTask(taskId, { metadata: { checkpointInterval, masteryLevel: mastery } });

      logger.info({ taskId, performerId, mastery, checkpointInterval }, 'task assigned with expertise-aware checkpoints');
      return ok({ ...taskResult.value, metadata: { ...taskResult.value.metadata, ...metadataUpdate } });
    },

    async claimNextTask(performerId, _capabilities = []): Promise<KallaxResult<Task | null>> {
      // Get pending tasks
      const tasksResult = db.listTasks({ status: TaskStatus.PENDING, limit: 10 });
      if (tasksResult.isErr()) {
        return err(tasksResult.error);
      }

      // Find a task that can be claimed
      for (const task of tasksResult.value) {
        // Check capability match (if task has requirements)
        // For now, we assume all performers can handle all tasks

        // Check isolation conflicts
        const scopesResult = isolationChecker.listScopes();
        if (scopesResult.isOk()) {
          const hasConflict = scopesResult.value.some((scope) => {
            if (scope.taskId === task.id) return false;
            const conflictResult = isolationChecker.checkPairConflicts(task.id, scope.taskId);
            return conflictResult.isOk() && conflictResult.value !== null;
          });

          if (hasConflict) {
            logger.debug({ taskId: task.id }, 'skipping task due to isolation conflict');
            continue;
          }
        }

        // Try to assign
        const assignResult = await this.assignTask(task.id, performerId);
        if (assignResult.isOk()) {
          return ok(assignResult.value);
        }

        // If claim failed, try next task
        logger.debug({ taskId: task.id, error: assignResult.error.message }, 'failed to claim task');
      }

      return ok(null);
    },

    releaseTask(taskId): Promise<KallaxResult<void>> {
      const result = db.updateTask(taskId, {
        status: TaskStatus.PENDING,
        performerId: null,
        startedAt: undefined,
      });

      if (result.isErr()) {
        return Promise.resolve(err(result.error));
      }

      isolationChecker.unregisterScope(taskId);
      logger.info({ taskId }, 'task released');
      return Promise.resolve(ok(undefined));
    },

    completeTask(taskId, output): Promise<KallaxResult<void>> {
      const now = Date.now();
      const result = db.updateTask(taskId, {
        status: TaskStatus.COMPLETED,
        completedAt: now,
        progress: 100,
        output,
      });

      if (result.isErr()) {
        return Promise.resolve(err(result.error));
      }

      isolationChecker.unregisterScope(taskId);
      logger.info({ taskId }, 'task completed');
      return Promise.resolve(ok(undefined));
    },

    failTask(taskId, error): Promise<KallaxResult<void>> {
      const now = Date.now();
      const result = db.updateTask(taskId, {
        status: TaskStatus.FAILED,
        completedAt: now,
        error,
      });

      if (result.isErr()) {
        return Promise.resolve(err(result.error));
      }

      isolationChecker.unregisterScope(taskId);
      logger.error({ taskId, error }, 'task failed');
      return Promise.resolve(ok(undefined));
    },

    getAssignableTasks(): Promise<KallaxResult<Task[]>> {
      const tasksResult = db.listTasks({ status: TaskStatus.PENDING });
      if (tasksResult.isErr()) {
        return Promise.resolve(err(tasksResult.error));
      }

      // Filter out tasks with active isolation conflicts
      const assignable = tasksResult.value.filter((task) => {
        const scopesResult = isolationChecker.listScopes();
        if (scopesResult.isErr()) return true;

        return !scopesResult.value.some((scope) => {
          if (scope.taskId === task.id) return false;
          const conflictResult = isolationChecker.checkPairConflicts(task.id, scope.taskId);
          return conflictResult.isOk() && conflictResult.value !== null && conflictResult.value.severity === 'error';
        });
      });

      return Promise.resolve(ok(assignable));
    },
  };
}

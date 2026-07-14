/**
 * KALLAX Task Assigner
 * Intelligent task assignment with isolation validation
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult, Task, Ticket, IsolationScope } from '../types/index.js';
import { KallaxError, KallaxErrorCode, TaskStatus, TaskType } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { SQLiteManager } from './sqlite/index.js';
import type { IsolationChecker } from './isolation-checker.js';
import type { InstanceRegistry } from './instance-registry.js';

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

      logger.info({ taskId, performerId }, 'task assigned');
      return ok(taskResult.value);
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

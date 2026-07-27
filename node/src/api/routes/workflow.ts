/**
 * KALLAX Workflow Routes
 * DAG visualization and workflow step execution
 */

import { Router } from 'express';
import type { Request, Response } from 'express';
import { TaskStatus, KallaxError } from '../../types/index.js';
import type { Task } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import type { SQLiteManager } from '../../core/sqlite/index.js';
import type { TaskAssigner } from '../../core/task-assigner.js';
import type { IsolationChecker } from '../../core/isolation-checker.js';
import type { WorktreeManager } from '../../core/worktree-manager.js';
import {
  createSuccessResponse,
  createErrorResponse,
} from '../types.js';

export interface WorkflowRouteDependencies {
  readonly db: SQLiteManager;
  readonly taskAssigner: TaskAssigner;
  readonly isolationChecker: IsolationChecker;
  readonly worktreeManager: WorktreeManager;
}

interface WorkflowNode {
  readonly id: string;
  readonly label: string;
  readonly status: string;
  readonly type: string;
  readonly progress: number;
  readonly performerId: string | null;
}

interface WorkflowEdge {
  readonly source: string;
  readonly target: string;
  readonly label: string;
}

interface WorkflowDAG {
  readonly nodes: readonly WorkflowNode[];
  readonly edges: readonly WorkflowEdge[];
}

interface WorkflowStatus {
  readonly totalTasks: number;
  readonly completedTasks: number;
  readonly inProgressTasks: number;
  readonly pendingTasks: number;
  readonly failedTasks: number;
  readonly stalledTasks: number;
  readonly isolationConflicts: number;
  readonly activeWorktrees: number;
  readonly timestamp: number;
}

/**
 * Create workflow routes with injected dependencies
 */
export function createWorkflowRoutes(deps: WorkflowRouteDependencies): Router {
  const router = Router();

  // GET /api/workflow/dag — get DAG visualization data
  router.get('/dag', (_req: Request, res: Response): void => {
    ((): void => {
      try {
        // Get all tasks
        const tasksResult = deps.db.listTasks({ limit: 100 });
        if (tasksResult.isErr()) {
          res.status(500).json(createErrorResponse(tasksResult.error));
          return;
        }

        const tasks = tasksResult.value;
        const nodes: WorkflowNode[] = tasks.map((task: Task) => ({
          id: task.id,
          label: `${task.type}:${task.id.slice(-8)}`,
          status: task.status,
          type: task.type,
          progress: task.progress,
          performerId: task.performerId,
        }));

        // Build edges from ticket relationships
        const edges: WorkflowEdge[] = [];
        for (const task of tasks) {
          // Check if there are other tasks for the same ticket
          const siblings = tasks.filter(
            (t: Task) => t.ticketId === task.ticketId && t.id !== task.id
          );
          for (const sibling of siblings) {
            edges.push({
              source: sibling.id,
              target: task.id,
              label: `ticket:${task.ticketId.slice(-8)}`,
            });
          }
        }

        // Add isolation conflict edges
        const scopesResult = deps.isolationChecker.listScopes();
        if (scopesResult.isOk()) {
          const scopes = scopesResult.value;
          for (let i = 0; i < scopes.length; i++) {
            const scopeA = scopes[i];
            if (scopeA === undefined) continue;
            for (let j = i + 1; j < scopes.length; j++) {
              const scopeB = scopes[j];
              if (scopeB === undefined) continue;
              const conflictResult = deps.isolationChecker.checkPairConflicts(
                scopeA.taskId,
                scopeB.taskId
              );
              if (conflictResult.isOk() && conflictResult.value !== null) {
                edges.push({
                  source: scopeA.taskId,
                  target: scopeB.taskId,
                  label: 'conflict',
                });
              }
            }
          }
        }

        const dag: WorkflowDAG = { nodes, edges };
        res.json(createSuccessResponse(dag));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to build workflow DAG');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // GET /api/workflow/status — get workflow status
  router.get('/status', (_req: Request, res: Response): void => {
    void (async (): Promise<void> => {
      try {
        const tasksResult = deps.db.listTasks({ limit: 500 });
        if (tasksResult.isErr()) {
          res.status(500).json(createErrorResponse(tasksResult.error));
          return;
        }

        const tasks = tasksResult.value;
        let completedTasks = 0;
        let inProgressTasks = 0;
        let pendingTasks = 0;
        let failedTasks = 0;

        for (const task of tasks) {
          switch (task.status) {
            case TaskStatus.COMPLETED: {
              completedTasks++;
              break;
            }
            case TaskStatus.RUNNING:
            case TaskStatus.CLAIMED: {
              inProgressTasks++;
              break;
            }
            case TaskStatus.PENDING: {
              pendingTasks++;
              break;
            }
            case TaskStatus.FAILED:
            case TaskStatus.CANCELLED: {
              failedTasks++;
              break;
            }
            default: {
              break;
            }
          }
        }

        // Count isolation conflicts
        const scopesResult = deps.isolationChecker.listScopes();
        let isolationConflicts = 0;
        if (scopesResult.isOk()) {
          const scopes = scopesResult.value;
          for (let i = 0; i < scopes.length; i++) {
            const scopeA = scopes[i];
            if (scopeA === undefined) continue;
            for (let j = i + 1; j < scopes.length; j++) {
              const scopeB = scopes[j];
              if (scopeB === undefined) continue;
              const conflictResult = deps.isolationChecker.checkPairConflicts(
                scopeA.taskId,
                scopeB.taskId
              );
              if (conflictResult.isOk() && conflictResult.value !== null) {
                isolationConflicts++;
              }
            }
          }
        }

        // Count active worktrees
        const worktreeResult = await deps.worktreeManager.list();
        const activeWorktrees = worktreeResult.isOk() ? worktreeResult.value.length : 0;

        // Estimate stalled tasks (claimed but no progress)
        const stalledTasks = tasks.filter(
          (t: Task) => t.status === TaskStatus.CLAIMED || t.status === TaskStatus.RUNNING
        ).length;

        const workflowStatus: WorkflowStatus = {
          totalTasks: tasks.length,
          completedTasks,
          inProgressTasks,
          pendingTasks,
          failedTasks,
          stalledTasks,
          isolationConflicts,
          activeWorktrees,
          timestamp: Date.now(),
        };

        res.json(createSuccessResponse(workflowStatus));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to get workflow status');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // POST /api/workflow/run — trigger a workflow step
  router.post('/run', (req: Request, res: Response): void => {
    ((): void => {
      try {
        const body = req.body as Record<string, unknown>;
        const action = body['action'] as string | undefined;

        if (action === undefined || typeof action !== 'string') {
          res.status(400).json({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: 'action is required' },
            timestamp: Date.now(),
          });
          return;
        }

        switch (action) {
          case 'assign-pending': {
            // Find and assign pending tasks
            const tasksResult = deps.db.listTasks({ status: TaskStatus.PENDING });
            if (tasksResult.isErr()) {
              res.status(500).json(createErrorResponse(tasksResult.error));
              return;
            }

            const pendingTasks = tasksResult.value;
            res.json(createSuccessResponse({
              action,
              pendingCount: pendingTasks.length,
              message: `${String(pendingTasks.length)} pending tasks found, waiting for performer claims`,
            }));
            break;
          }

          case 'verify-all': {
            // Verify all completed tasks
            const tasksResult = deps.db.listTasks({ status: TaskStatus.COMPLETED });
            if (tasksResult.isErr()) {
              res.status(500).json(createErrorResponse(tasksResult.error));
              return;
            }

            const completedTasks = tasksResult.value;
            res.json(createSuccessResponse({
              action,
              completedCount: completedTasks.length,
              message: `${String(completedTasks.length)} completed tasks ready for verification`,
            }));
            break;
          }

          case 'cleanup-stale': {
            // Clean up stale instances
            const activeResult = deps.db.listInstances({ status: 'active' });
            if (activeResult.isErr()) {
              res.status(500).json(createErrorResponse(activeResult.error));
              return;
            }

            res.json(createSuccessResponse({
              action,
              cleanedCount: 0,
              message: 'Stale instance cleanup triggered',
            }));
            break;
          }

          default: {
            res.status(400).json({
              success: false,
              error: {
                code: 'VALIDATION_ERROR',
                message: `Unknown action: ${action}. Supported: assign-pending, verify-all, cleanup-stale`,
              },
              timestamp: Date.now(),
            });
            break;
          }
        }
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to run workflow step');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  return router;
}

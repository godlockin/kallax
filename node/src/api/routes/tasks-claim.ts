/**
 * KALLAX Task Claim/Complete Routes
 * Atomic claim, completion, and failure workflows via API
 * Uses mergeParams so :id from parent router is accessible
 */

import { Router } from 'express';
import type { Request, Response } from 'express';
import { KallaxError, KallaxErrorCode, EventType } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import type { TaskAssigner } from '../../core/task-assigner.js';
import type { SQLiteManager } from '../../core/sqlite/index.js';
import type { WorktreeManager } from '../../core/worktree-manager.js';
import type { OutputVerifier } from '../../core/output-verifier.js';
import type { IsolationChecker } from '../../core/isolation-checker.js';
import type { SSEBus } from '../../core/sse-bus.js';
import { createEvent } from '../../core/sse-bus.js';
import {
  createSuccessResponse,
  createErrorResponse,
  type ClaimTaskRequest,
} from '../types.js';

export interface ClaimRouteDependencies {
  readonly db: SQLiteManager;
  readonly taskAssigner: TaskAssigner;
  readonly worktreeManager: WorktreeManager;
  readonly outputVerifier: OutputVerifier;
  readonly isolationChecker: IsolationChecker;
  readonly sseBus: SSEBus;
}

/**
 * Create claim/complete/fail sub-routes mounted under /:id
 * mergeParams: true enables access to parent's :id param
 */
export function createClaimRoutes(deps: ClaimRouteDependencies): Router {
  const router = Router({ mergeParams: true });

  // POST /api/tasks/:id/claim — claim a task
  router.post('/claim', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const taskId = req.params['id'] as string;
        const body = req.body as ClaimTaskRequest;

        if (body.performerId === undefined || typeof body.performerId !== 'string') {
          res.status(400).json({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: 'performerId is required' },
            timestamp: Date.now(),
          });
          return;
        }

        const result = await deps.taskAssigner.assignTask(taskId, body.performerId);

        if (result.isErr()) {
          const err = result.error;
          if (err.code === KallaxErrorCode.TASK_ALREADY_CLAIMED) {
            res.status(409).json(createErrorResponse(err));
            return;
          }
          if (err.code === KallaxErrorCode.INSTANCE_NOT_FOUND || err.code === KallaxErrorCode.TASK_NOT_FOUND) {
            res.status(404).json(createErrorResponse(err));
            return;
          }
          res.status(500).json(createErrorResponse(err));
          return;
        }

        const event = createEvent(
          EventType.TASK_CLAIMED,
          { taskId, performerId: body.performerId },
          'api-server'
        );
        deps.sseBus.publish(event);

        logger.info({ taskId, performerId: body.performerId }, 'task claimed via API');
        res.status(200).json(createSuccessResponse(result.value));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to claim task');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // POST /api/tasks/:id/release — release a claimed task back to pending
  router.post('/release', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const taskId = req.params['id'] as string;

        const result = await deps.taskAssigner.releaseTask(taskId);
        if (result.isErr()) {
          res.status(500).json(createErrorResponse(result.error));
          return;
        }

        const event = createEvent(EventType.TASK_FAILED, { taskId }, 'api-server');
        deps.sseBus.publish(event);

        logger.info({ taskId }, 'task released via API');
        res.json(createSuccessResponse({ taskId }));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to release task');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // PUT /api/tasks/:id/complete — complete a task
  router.put('/complete', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const taskId = req.params['id'] as string;
        const output = (req.body as Record<string, unknown>)?.['output'] as string | undefined;

        const result = await deps.taskAssigner.completeTask(taskId, output);
        if (result.isErr()) {
          res.status(500).json(createErrorResponse(result.error));
          return;
        }

        const event = createEvent(EventType.TASK_COMPLETED, { taskId }, 'api-server');
        deps.sseBus.publish(event);

        logger.info({ taskId }, 'task completed via API');
        res.json(createSuccessResponse({ taskId, status: 'completed' }));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to complete task');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // PUT /api/tasks/:id/fail — fail a task
  router.put('/fail', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const taskId = req.params['id'] as string;
        const errorMsg = (req.body as Record<string, unknown>)?.['error'] as string | undefined ?? 'Task failed via API';

        const result = await deps.taskAssigner.failTask(taskId, errorMsg);
        if (result.isErr()) {
          res.status(500).json(createErrorResponse(result.error));
          return;
        }

        const event = createEvent(EventType.TASK_FAILED, { taskId, error: errorMsg }, 'api-server');
        deps.sseBus.publish(event);

        logger.info({ taskId }, 'task failed via API');
        res.json(createSuccessResponse({ taskId, status: 'failed' }));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to fail task');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  return router;
}

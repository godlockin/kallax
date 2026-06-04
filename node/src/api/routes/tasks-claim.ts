/**
 * KALLAX Task Claim & Complete Routes
 * Complex workflow: claim task (with worktree isolation) and complete task (with verification)
 */

import { Router } from 'express';
import type { Request, Response } from 'express';
import { TaskStatus, KallaxError } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import type { SQLiteManager } from '../../core/sqlite-manager.js';
import type { TaskAssigner } from '../../core/task-assigner.js';
import type { WorktreeManager } from '../../core/worktree-manager.js';
import type { OutputVerifier } from '../../core/output-verifier.js';
import type { SSEBus } from '../../core/sse-bus.js';
import { createEvent } from '../../core/sse-bus.js';
import { EventType, VerificationLevel } from '../../types/index.js';
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
  readonly sseBus: SSEBus;
}

/**
 * Create claim + complete sub-routes (mounted under /:id)
 * Uses mergeParams: true to inherit :id from parent router
 */
export function createClaimRoutes(deps: ClaimRouteDependencies): Router {
  const router = Router({ mergeParams: true });

  // PUT /:id/claim — claim task with worktree isolation
  router.put('/claim', (req: Request, res: Response): void => {
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

        // Verify task exists and is pending
        const taskResult = deps.db.getTask(taskId);
        if (taskResult.isErr()) {
          res.status(500).json(createErrorResponse(taskResult.error));
          return;
        }

        const task = taskResult.value;
        if (task === null) {
          res.status(404).json({
            success: false,
            error: { code: 'TASK_NOT_FOUND', message: `Task ${taskId} not found` },
            timestamp: Date.now(),
          });
          return;
        }

        if (task.status !== TaskStatus.PENDING) {
          res.status(409).json({
            success: false,
            error: {
              code: 'TASK_INVALID_STATE',
              message: `Task is in ${task.status} state, expected pending`,
            },
            timestamp: Date.now(),
          });
          return;
        }

        // Create worktree for isolation
        const worktreeResult = await deps.worktreeManager.create(taskId);
        if (worktreeResult.isErr()) {
          res.status(500).json(createErrorResponse(worktreeResult.error));
          return;
        }

        // Assign the task
        const assignResult = await deps.taskAssigner.assignTask(taskId, body.performerId);
        if (assignResult.isErr()) {
          // Clean up worktree on failure
          void deps.worktreeManager.remove(taskId);
          res.status(500).json(createErrorResponse(assignResult.error));
          return;
        }

        const claimedTask = assignResult.value;

        // Publish event
        const event = createEvent(
          EventType.TASK_CLAIMED,
          { taskId, performerId: body.performerId, worktree: worktreeResult.value },
          'api-server'
        );
        deps.sseBus.publish(event);

        logger.info({ taskId, performerId: body.performerId }, 'task claimed via API');

        res.json(createSuccessResponse({
          task: claimedTask,
          worktree: worktreeResult.value,
        }));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to claim task');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // PUT /:id/complete — complete task with output verification
  router.put('/complete', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const taskId = req.params['id'] as string;
        const levelStr = req.query['level'] as string | undefined;
        const level = levelStr !== undefined ? parseInt(levelStr, 10) || 4 : 4;

        // Verify task exists and is claimed
        const taskResult = deps.db.getTask(taskId);
        if (taskResult.isErr()) {
          res.status(500).json(createErrorResponse(taskResult.error));
          return;
        }

        const task = taskResult.value;
        if (task === null) {
          res.status(404).json({
            success: false,
            error: { code: 'TASK_NOT_FOUND', message: `Task ${taskId} not found` },
            timestamp: Date.now(),
          });
          return;
        }

        if (task.status !== TaskStatus.CLAIMED && task.status !== TaskStatus.RUNNING) {
          res.status(409).json({
            success: false,
            error: {
              code: 'TASK_INVALID_STATE',
              message: `Task is in ${task.status} state, expected claimed or running`,
            },
            timestamp: Date.now(),
          });
          return;
        }

        // Get worktree
        const worktreeResult = await deps.worktreeManager.getByTaskId(taskId);
        if (worktreeResult.isErr()) {
          res.status(500).json(createErrorResponse(worktreeResult.error));
          return;
        }

        const worktree = worktreeResult.value;
        if (worktree === null) {
          res.status(400).json({
            success: false,
            error: { code: 'WORKTREE_NOT_FOUND', message: 'No worktree found for task' },
            timestamp: Date.now(),
          });
          return;
        }

        // Run verification
        const verifyLevel = level as VerificationLevel;
        const verificationResult = await deps.outputVerifier.verify(
          taskId,
          worktree.path,
          verifyLevel
        );

        if (verificationResult.isErr()) {
          res.status(500).json(createErrorResponse(verificationResult.error));
          return;
        }

        const verification = verificationResult.value;

        if (!verification.passed) {
          res.status(400).json({
            success: false,
            error: {
              code: 'VERIFICATION_FAILED',
              message: 'Output verification failed',
              details: {
                level,
                evidence: verification.evidence,
              } as Record<string, unknown>,
            },
            timestamp: Date.now(),
          });
          return;
        }

        // Complete the task
        const completeResult = await deps.taskAssigner.completeTask(taskId);
        if (completeResult.isErr()) {
          res.status(500).json(createErrorResponse(completeResult.error));
          return;
        }

        // Publish event
        const event = createEvent(
          EventType.TASK_COMPLETED,
          { taskId, verification },
          'api-server'
        );
        deps.sseBus.publish(event);

        logger.info({ taskId, level, passed: verification.passed }, 'task completed via API');

        res.json(createSuccessResponse({ verification }));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to complete task');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  return router;
}

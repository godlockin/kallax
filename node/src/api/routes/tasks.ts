/**
 * KALLAX Task Routes
 * Task CRUD and lifecycle management
 */

import { Router } from 'express';
import type { Request, Response } from 'express';
import { TaskStatus, TaskType, KallaxError } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import type { SQLiteManager } from '../../core/sqlite-manager.js';
import type { TaskAssigner } from '../../core/task-assigner.js';
import type { WorktreeManager } from '../../core/worktree-manager.js';
import type { OutputVerifier } from '../../core/output-verifier.js';
import type { IsolationChecker } from '../../core/isolation-checker.js';
import type { SSEBus } from '../../core/sse-bus.js';
import { createEvent } from '../../core/sse-bus.js';
import { EventType, VerificationLevel } from '../../types/index.js';
import {
  createSuccessResponse,
  createErrorResponse,
  createPaginatedResponse,
  type CreateTaskRequest,
  type ClaimTaskRequest,
  type UpdateProgressRequest,
} from '../types.js';

export interface TaskRouteDependencies {
  readonly db: SQLiteManager;
  readonly taskAssigner: TaskAssigner;
  readonly worktreeManager: WorktreeManager;
  readonly outputVerifier: OutputVerifier;
  readonly isolationChecker: IsolationChecker;
  readonly sseBus: SSEBus;
}

/**
 * Create task routes with injected dependencies
 */
export function createTaskRoutes(deps: TaskRouteDependencies): Router {
  const router = Router();

  // GET /api/tasks — list tasks with filters
  router.get('/', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const status = req.query['status'] as string | undefined;
        const performerId = req.query['performerId'] as string | undefined;
        const ticketId = req.query['ticketId'] as string | undefined;
        const pageStr = req.query['page'] as string | undefined;
        const limitStr = req.query['limit'] as string | undefined;

        const page = Math.max(1, parseInt(pageStr ?? '1', 10) || 1);
        const limit = Math.min(100, Math.max(1, parseInt(limitStr ?? '20', 10) || 20));

        // Build filter conditionally to respect exactOptionalPropertyTypes
        const filter: Record<string, unknown> = {};
        if (status !== undefined) filter['status'] = status;
        if (performerId !== undefined) filter['performerId'] = performerId;
        if (ticketId !== undefined) filter['ticketId'] = ticketId;
        filter['limit'] = limit * page;

        const result = deps.db.listTasks(
          status !== undefined || performerId !== undefined || ticketId !== undefined
            ? {
                ...(status !== undefined ? { status } : {}),
                ...(performerId !== undefined ? { performerId } : {}),
                ...(ticketId !== undefined ? { ticketId } : {}),
                limit: limit * page,
              }
            : { limit: limit * page }
        );

        if (result.isErr()) {
          res.status(500).json(createErrorResponse(result.error));
          return;
        }

        const allTasks = result.value;
        const total = allTasks.length;
        const start = (page - 1) * limit;
        const items = allTasks.slice(start, start + limit);

        res.json(createSuccessResponse(
          createPaginatedResponse(items, total, page, limit)
        ));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to list tasks');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // POST /api/tasks — create task from ticket
  router.post('/', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const body = req.body as CreateTaskRequest;

        if (body.ticketId === undefined || typeof body.ticketId !== 'string') {
          res.status(400).json({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: 'ticketId is required' },
            timestamp: Date.now(),
          });
          return;
        }

        // Fetch the ticket
        const ticketResult = deps.db.getTicket(body.ticketId);
        if (ticketResult.isErr()) {
          res.status(500).json(createErrorResponse(ticketResult.error));
          return;
        }

        const ticket = ticketResult.value;
        if (ticket === null) {
          res.status(404).json({
            success: false,
            error: { code: 'TICKET_NOT_FOUND', message: `Ticket ${body.ticketId} not found` },
            timestamp: Date.now(),
          });
          return;
        }

        // Determine task type
        let taskType: TaskType = TaskType.DEVELOPMENT;
        if (body.type !== undefined && isValidTaskType(body.type)) {
          taskType = body.type;
        }

        // Create task via task assigner
        const taskResult = deps.taskAssigner.createTask(ticket, taskType);
        if (taskResult.isErr()) {
          res.status(500).json(createErrorResponse(taskResult.error));
          return;
        }

        const task = taskResult.value;

        // Publish event
        const event = createEvent(
          EventType.TASK_CREATED,
          { taskId: task.id, ticketId: ticket.id, type: taskType },
          'api-server'
        );
        deps.sseBus.publish(event);

        logger.info({ taskId: task.id, ticketId: body.ticketId }, 'task created via API');

        res.status(201).json(createSuccessResponse(task));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to create task');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // GET /api/tasks/:id — get task detail
  router.get('/:id', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const taskId = req.params['id'] as string;

        const result = deps.db.getTask(taskId);
        if (result.isErr()) {
          res.status(500).json(createErrorResponse(result.error));
          return;
        }

        const task = result.value;
        if (task === null) {
          res.status(404).json({
            success: false,
            error: { code: 'TASK_NOT_FOUND', message: `Task ${taskId} not found` },
            timestamp: Date.now(),
          });
          return;
        }

        // Enrich with ticket info
        const enriched: Record<string, unknown> = { task };

        const ticketResult = deps.db.getTicket(task.ticketId);
        if (ticketResult.isOk() && ticketResult.value !== null) {
          enriched['ticket'] = ticketResult.value;
        }

        res.json(createSuccessResponse(enriched));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to get task');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // PUT /api/tasks/:id/claim — claim task
  router.put('/:id/claim', (req: Request, res: Response): void => {
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

  // PUT /api/tasks/:id/complete — complete task
  router.put('/:id/complete', (req: Request, res: Response): void => {
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

  // PUT /api/tasks/:id/progress — update progress
  router.put('/:id/progress', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const taskId = req.params['id'] as string;
        const body = req.body as UpdateProgressRequest;

        if (body.progress === undefined || typeof body.progress !== 'number') {
          res.status(400).json({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: 'progress (0-100) is required' },
            timestamp: Date.now(),
          });
          return;
        }

        if (body.progress < 0 || body.progress > 100) {
          res.status(400).json({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: 'progress must be between 0 and 100' },
            timestamp: Date.now(),
          });
          return;
        }

        // Verify task exists
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

        // Update progress
        const updateResult = deps.db.updateTask(taskId, {
          progress: body.progress,
          status: body.progress >= 100 ? TaskStatus.COMPLETED : TaskStatus.RUNNING,
        });

        if (updateResult.isErr()) {
          res.status(500).json(createErrorResponse(updateResult.error));
          return;
        }

        // Publish progress event
        const event = createEvent(
          EventType.TASK_PROGRESS,
          { taskId, progress: body.progress, message: body.message },
          'api-server'
        );
        deps.sseBus.publish(event);

        logger.info({ taskId, progress: body.progress }, 'task progress updated via API');

        res.json(createSuccessResponse({ taskId, progress: body.progress }));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to update task progress');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // DELETE /api/tasks/:id — cancel task
  router.delete('/:id', (req: Request, res: Response): void => {
    void (async () => {
      try {
        const taskId = req.params['id'] as string;

        // Verify task exists
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

        if (task.status === TaskStatus.COMPLETED || task.status === TaskStatus.CANCELLED) {
          res.status(409).json({
            success: false,
            error: {
              code: 'TASK_INVALID_STATE',
              message: `Cannot cancel task in ${task.status} state`,
            },
            timestamp: Date.now(),
          });
          return;
        }

        // Cancel the task
        const updateResult = deps.db.updateTask(taskId, {
          status: TaskStatus.CANCELLED,
          completedAt: Date.now(),
        });

        if (updateResult.isErr()) {
          res.status(500).json(createErrorResponse(updateResult.error));
          return;
        }

        // Release isolation scope
        deps.isolationChecker.unregisterScope(taskId);

        // Clean up worktree if exists
        void deps.worktreeManager.remove(taskId);

        // Publish event
        const event = createEvent(
          EventType.TASK_FAILED,
          { taskId, reason: 'cancelled' },
          'api-server'
        );
        deps.sseBus.publish(event);

        logger.info({ taskId }, 'task cancelled via API');

        res.json(createSuccessResponse({ taskId, status: TaskStatus.CANCELLED }));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to cancel task');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  return router;
}

/**
 * Type guard for TaskType
 */
function isValidTaskType(value: string): value is TaskType {
  const validTypes = Object.values(TaskType) as string[];
  return validTypes.includes(value);
}

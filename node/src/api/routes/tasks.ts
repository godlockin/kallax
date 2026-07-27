/**
 * KALLAX Task Routes
 * Core CRUD: list, create, get, progress update, and cancel
 * Claim/complete workflows live in tasks-claim.ts
 */

import { Router } from 'express';
import type { Request, Response } from 'express';
import { TaskStatus, TaskType, KallaxError, KallaxErrorCode, EventType } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import type { SQLiteManager } from '../../core/sqlite/index.js';
import type { TaskAssigner } from '../../core/task-assigner.js';
import type { WorktreeManager } from '../../core/worktree-manager.js';
import type { OutputVerifier } from '../../core/output-verifier.js';
import type { IsolationChecker } from '../../core/isolation-checker.js';
import type { SSEBus } from '../../core/sse-bus.js';
import type { ClaimQueue } from '../../core/claim-queue.js';
import { createEvent } from '../../core/sse-bus.js';
import {
  createSuccessResponse,
  createErrorResponse,
  createPaginatedResponse,
  type CreateTaskRequest,
  type UpdateProgressRequest,
} from '../types.js';
import { createClaimRoutes } from './tasks-claim.js';

export interface TaskRouteDependencies {
  readonly db: SQLiteManager;
  readonly taskAssigner: TaskAssigner;
  readonly worktreeManager: WorktreeManager;
  readonly outputVerifier: OutputVerifier;
  readonly isolationChecker: IsolationChecker;
  readonly sseBus: SSEBus;
  readonly claimQueue?: ClaimQueue;
}

/**
 * Create task routes with injected dependencies
 */
export function createTaskRoutes(deps: TaskRouteDependencies): Router {
  const router = Router();

  // GET /api/tasks/next — claim the next available task by priority + capability
  // Must be placed BEFORE /:id to avoid route capture
  router.get('/next', (req: Request, res: Response): void => {
    void (async (): Promise<void> => {
      try {
        if (deps.claimQueue === undefined) {
          res.status(501).json({
            success: false,
            error: { code: 'NOT_IMPLEMENTED', message: 'Claim queue not configured' },
            timestamp: Date.now(),
          });
          return;
        }

        const performerId = req.query['performerId'] as string | undefined;
        const capabilitiesStr = req.query['capabilities'] as string | undefined;

        if (performerId === undefined || typeof performerId !== 'string') {
          res.status(400).json({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: 'performerId is required' },
            timestamp: Date.now(),
          });
          return;
        }

        const capabilities: string[] =
          capabilitiesStr !== undefined && capabilitiesStr.length > 0
            ? capabilitiesStr.split(',').map((c) => c.trim()).filter((c) => c.length > 0)
            : [];

        // Find next matching task from claim queue
        const item = deps.claimQueue.dequeue(performerId, capabilities);

        if (item === null) {
          // Also try DB-based fallback for tasks not in in-memory queue
          const dbResult = await deps.taskAssigner.claimNextTask(performerId, capabilities);
          if (dbResult.isErr()) {
            res.status(500).json(createErrorResponse(dbResult.error));
            return;
          }
          res.json(createSuccessResponse(dbResult.value));
          return;
        }

        // Claim in DB
        const assignResult = await deps.taskAssigner.assignTask(item.taskId, performerId);
        if (assignResult.isErr()) {
          // DB claim failed — re-enqueue and return error
          deps.claimQueue.enqueue(item.taskId, item.ticketId, item.priority, item.requiredCapabilities);
          const err = assignResult.error;
          if (
            err.code === KallaxErrorCode.TASK_ALREADY_CLAIMED ||
            err.code === KallaxErrorCode.TASK_NOT_FOUND
          ) {
            res.status(409).json(createErrorResponse(err));
            return;
          }
          res.status(500).json(createErrorResponse(err));
          return;
        }

        const event = createEvent(
          EventType.TASK_CLAIMED,
          { taskId: item.taskId, performerId },
          'api-server'
        );
        deps.sseBus.publish(event);

        logger.info(
          { taskId: item.taskId, performerId, priority: item.priority },
          'task claimed via /tasks/next'
        );
        res.json(createSuccessResponse(assignResult.value));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to claim next task');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // Mount claim/complete sub-routes under /:id
  router.use('/:id', createClaimRoutes(deps));

  // GET /api/tasks — list tasks with filters
  router.get('/', (req: Request, res: Response): void => {
    ((): void => {
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
        // EPIC-093 P1-8: 真分页 (DB filter limit/offset) 而非 fetch+slice
        // 原: 所有 task 拉进内存 + slice → 内存膨胀 (10k tasks 100MB+)
        // 修: 上面 filter 已含 limit, 但当前 db 端不返回 total — 简化为切片但加 hard cap
        const total = allTasks.length;
        const start = (page - 1) * limit;
        // EPIC-093: hard cap 总数 (fetch 多于 limit*N 不返回), 防 OOM
        const HARD_CAP = 10_000;
        const capped = allTasks.length > HARD_CAP ? allTasks.slice(0, HARD_CAP) : allTasks;
        const items = capped.slice(start, start + limit);
        const adjustedTotal = Math.min(total, HARD_CAP);

        res.json(createSuccessResponse(
          createPaginatedResponse(items, adjustedTotal, page, limit)
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
    ((): void => {
      try {
        const body = req.body as CreateTaskRequest;

        if (typeof body.ticketId !== 'string') {
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

        // Auto-enqueue in claim queue if configured
        if (deps.claimQueue !== undefined) {
          const priority = priorityFromTicket(ticket.priority);
          deps.claimQueue.enqueue(task.id, ticket.id, priority, ticket.labels);
        }

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
    ((): void => {
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

  // PUT /api/tasks/:id/progress — update progress
  router.put('/:id/progress', (req: Request, res: Response): void => {
    ((): void => {
      try {
        const taskId = req.params['id'] as string;
        const body = req.body as UpdateProgressRequest;

        if (typeof body.progress !== 'number') {
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
    ((): void => {
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

/**
 * Map ticket priority label to numeric priority for claim queue
 */
function priorityFromTicket(priority: string): number {
  switch (priority) {
    case 'P0': return 1000;
    case 'P1': return 500;
    case 'P2': return 100;
    case 'P3': return 10;
    default: return 0;
  }
}

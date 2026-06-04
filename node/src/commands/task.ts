/**
 * KALLAX Task Commands
 * Task creation, status, progress, and resume
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult, Task, Ticket } from '../types/index.js';
import { KallaxError, KallaxErrorCode, TaskStatus, TaskType, TicketSchema } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { SQLiteManager } from '../core/sqlite/index.js';
import type { TaskAssigner } from '../core/task-assigner.js';

// ============================================================================
// Task Create
// ============================================================================

export interface TaskCreateOptions {
  readonly ticketId: string;
  readonly type?: TaskType;
  readonly metadata?: Record<string, unknown>;
}

export interface TaskCreateResult {
  readonly task: Task;
  readonly ticket: Ticket;
}

export function executeTaskCreate(
  db: SQLiteManager,
  taskAssigner: TaskAssigner,
  options: TaskCreateOptions
): KallaxResult<TaskCreateResult> {
  const { ticketId, type = TaskType.DEVELOPMENT, metadata } = options;

  // Get ticket
  const ticketResult = db.getTicket(ticketId);
  if (ticketResult.isErr()) {
    return err(ticketResult.error);
  }
  if (ticketResult.value === null) {
    return err(
      new KallaxError(KallaxErrorCode.TICKET_NOT_FOUND, 'Ticket not found', {
        metadata: { ticketId },
      })
    );
  }

  const ticket = ticketResult.value;

  // Create task
  const createResult = taskAssigner.createTask(ticket, type);
  if (createResult.isErr()) {
    return err(createResult.error);
  }

  logger.info(
    { taskId: createResult.value.id, ticketId, type },
    'task created'
  );

  return ok({
    task: createResult.value,
    ticket,
  });
}

// ============================================================================
// Task Status
// ============================================================================

export interface TaskStatusOptions {
  readonly taskId?: string;
  readonly ticketId?: string;
  readonly performerId?: string;
  readonly statusFilter?: TaskStatus;
  readonly limit?: number;
}

export interface TaskStatusResult {
  readonly tasks: TaskWithTicket[];
  readonly summary: TaskSummary;
}

export interface TaskWithTicket {
  readonly task: Task;
  readonly ticket: Ticket | null;
}

export interface TaskSummary {
  readonly total: number;
  readonly byStatus: Record<string, number>;
  readonly byType: Record<string, number>;
}

export function executeTaskStatus(
  db: SQLiteManager,
  options: TaskStatusOptions = {}
): KallaxResult<TaskStatusResult> {
  const { taskId, ticketId, performerId, statusFilter, limit = 50 } = options;

  // If specific task requested
  if (taskId !== undefined) {
    const taskResult = db.getTask(taskId);
    if (taskResult.isErr()) {
      return err(taskResult.error);
    }
    if (taskResult.value === null) {
      return err(
        new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Task not found', {
          metadata: { taskId },
        })
      );
    }

    const task = taskResult.value;
    const ticketResult = db.getTicket(task.ticketId);
    const ticket = ticketResult.isOk() ? ticketResult.value : null;

    return ok({
      tasks: [{ task, ticket }],
      summary: {
        total: 1,
        byStatus: { [task.status]: 1 },
        byType: { [task.type]: 1 },
      },
    });
  }

  // List tasks with filters
  const tasksResult = db.listTasks({
    ticketId,
    performerId,
    status: statusFilter,
    limit,
  });

  if (tasksResult.isErr()) {
    return err(tasksResult.error);
  }

  const tasks = tasksResult.value;
  const tasksWithTickets: TaskWithTicket[] = [];

  // Fetch associated tickets
  const ticketCache = new Map<string, Ticket | null>();

  for (const task of tasks) {
    let ticket = ticketCache.get(task.ticketId);
    if (ticket === undefined) {
      const ticketResult = db.getTicket(task.ticketId);
      ticket = ticketResult.isOk() ? ticketResult.value : null;
      ticketCache.set(task.ticketId, ticket);
    }
    tasksWithTickets.push({ task, ticket });
  }

  // Build summary
  const byStatus: Record<string, number> = {};
  const byType: Record<string, number> = {};

  for (const task of tasks) {
    byStatus[task.status] = (byStatus[task.status] ?? 0) + 1;
    byType[task.type] = (byType[task.type] ?? 0) + 1;
  }

  return ok({
    tasks: tasksWithTickets,
    summary: {
      total: tasks.length,
      byStatus,
      byType,
    },
  });
}

// ============================================================================
// Task Progress
// ============================================================================

export interface TaskProgressOptions {
  readonly taskId: string;
  readonly progress: number;
  readonly message?: string;
}

export function executeTaskProgress(
  db: SQLiteManager,
  options: TaskProgressOptions
): KallaxResult<Task> {
  const { taskId, progress, message } = options;

  // Validate progress
  if (progress < 0 || progress > 100) {
    return err(
      new KallaxError(KallaxErrorCode.TASK_INVALID_STATE, 'Progress must be between 0 and 100', {
        metadata: { progress },
      })
    );
  }

  // Get current task
  const taskResult = db.getTask(taskId);
  if (taskResult.isErr()) {
    return err(taskResult.error);
  }
  if (taskResult.value === null) {
    return err(
      new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Task not found', {
        metadata: { taskId },
      })
    );
  }

  const task = taskResult.value;

  // Check task is in progress
  if (task.status !== TaskStatus.RUNNING && task.status !== TaskStatus.CLAIMED) {
    return err(
      new KallaxError(KallaxErrorCode.TASK_INVALID_STATE, 'Task is not in progress', {
        metadata: { taskId, status: task.status },
      })
    );
  }

  // Update progress
  const updateResult = db.updateTask(taskId, {
    progress,
    output: message ?? task.output,
  });

  if (updateResult.isErr()) {
    return err(updateResult.error);
  }

  logger.debug({ taskId, progress, message }, 'task progress updated');

  // Return updated task
  const updatedResult = db.getTask(taskId);
  if (updatedResult.isErr() || updatedResult.value === null) {
    return err(
      new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Failed to get updated task')
    );
  }

  return ok(updatedResult.value);
}

// ============================================================================
// Task Resume
// ============================================================================

export interface TaskResumeOptions {
  readonly taskId: string;
}

export interface TaskResumeResult {
  readonly task: Task;
  readonly ticket: Ticket;
  readonly previousState: TaskStatus;
}

export async function executeTaskResume(
  db: SQLiteManager,
  taskAssigner: TaskAssigner,
  options: TaskResumeOptions
): Promise<KallaxResult<TaskResumeResult>> {
  const { taskId } = options;

  // Get task
  const taskResult = db.getTask(taskId);
  if (taskResult.isErr()) {
    return err(taskResult.error);
  }
  if (taskResult.value === null) {
    return err(
      new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Task not found', {
        metadata: { taskId },
      })
    );
  }

  const task = taskResult.value;
  const previousState = task.status;

  // Check task can be resumed
  if (task.status !== TaskStatus.FAILED && task.status !== TaskStatus.CANCELLED) {
    return err(
      new KallaxError(KallaxErrorCode.TASK_INVALID_STATE, 'Task cannot be resumed', {
        metadata: { taskId, status: task.status },
      })
    );
  }

  // Get ticket
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

  // Reset task to pending
  const updateResult = db.updateTask(taskId, {
    status: TaskStatus.PENDING,
    performerId: null,
    progress: 0,
    error: undefined,
    startedAt: undefined,
    completedAt: undefined,
  });

  if (updateResult.isErr()) {
    return err(updateResult.error);
  }

  logger.info({ taskId, previousState }, 'task resumed');

  // Get updated task
  const updatedResult = db.getTask(taskId);
  if (updatedResult.isErr() || updatedResult.value === null) {
    return err(
      new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Failed to get updated task')
    );
  }

  return ok({
    task: updatedResult.value,
    ticket: ticketResult.value,
    previousState,
  });
}

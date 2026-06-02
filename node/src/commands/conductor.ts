/**
 * KALLAX Conductor Commands
 * Heartbeat and polling for Conductor role
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult, Task, Instance, Ticket } from '../types/index.js';
import { KallaxError, KallaxErrorCode, TicketStatus } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { SQLiteManager } from '../core/sqlite-manager.js';
import type { InstanceRegistry } from '../core/instance-registry.js';
import type { TaskAssigner } from '../core/task-assigner.js';
import type { IsolationChecker } from '../core/isolation-checker.js';
import { calculateAdaptiveTimeout } from '../core/heartbeat-monitor.js';

// ============================================================================
// Conductor Heartbeat
// ============================================================================

export interface ConductorHeartbeatOptions {
  readonly checkPerformers?: boolean;
  readonly checkTasks?: boolean;
  readonly checkInbox?: boolean;
}

export interface ConductorHeartbeatResult {
  readonly timestamp: number;
  readonly q1_priority: PriorityCheckResult;
  readonly q2_performers: PerformerCheckResult;
  readonly q3_progress: ProgressCheckResult;
  readonly q4_blocked: BlockedCheckResult;
  readonly q5_messages: MessageCheckResult;
}

export interface PriorityCheckResult {
  readonly highPriorityCount: number;
  readonly inboxCount: number;
  readonly backlogCount: number;
  readonly recommendations: string[];
}

export interface PerformerCheckResult {
  readonly activeCount: number;
  readonly busyCount: number;
  readonly idleCount: number;
  readonly staleCount: number;
  readonly performers: PerformerStatus[];
}

export interface PerformerStatus {
  readonly id: string;
  readonly status: string;
  readonly currentTaskId: string | null;
  readonly lastHeartbeat: number;
  readonly isStale: boolean;
}

export interface ProgressCheckResult {
  readonly totalTasks: number;
  readonly completedTasks: number;
  readonly inProgressTasks: number;
  readonly pendingTasks: number;
  readonly completionRate: number;
}

export interface BlockedCheckResult {
  readonly blockedTickets: Ticket[];
  readonly decisionRequired: boolean;
}

export interface MessageCheckResult {
  readonly pendingMessages: number;
  readonly criticalMessages: number;
}

export async function executeConductorHeartbeat(
  db: SQLiteManager,
  instanceRegistry: InstanceRegistry,
  taskAssigner: TaskAssigner,
  isolationChecker: IsolationChecker,
  options: ConductorHeartbeatOptions = {}
): Promise<KallaxResult<ConductorHeartbeatResult>> {
  const currentInstance = instanceRegistry.getCurrentInstance();

  if (currentInstance === null || currentInstance.role !== 'conductor') {
    return err(
      new KallaxError(KallaxErrorCode.PERMISSION_DENIED, 'Only conductors can run heartbeat', {
        metadata: { role: currentInstance?.role },
      })
    );
  }

  logger.info({ instanceId: currentInstance.id }, 'conductor heartbeat starting');

  // Q1: Task Priority Check
  const q1 = await checkTaskPriority(db);

  // Q2: Performer Status Check
  const q2 = await checkPerformers(instanceRegistry);

  // Q3: Project Progress Check
  const q3 = await checkProgress(db);

  // Q4: Blocked Decisions Check
  const q4 = await checkBlocked(db);

  // Q5: Message Queue Check
  const q5 = await checkMessages(db);

  const result: ConductorHeartbeatResult = {
    timestamp: Date.now(),
    q1_priority: q1,
    q2_performers: q2,
    q3_progress: q3,
    q4_blocked: q4,
    q5_messages: q5,
  };

  logger.info(
    {
      highPriority: q1.highPriorityCount,
      activePerformers: q2.activeCount,
      completionRate: q3.completionRate,
      blocked: q4.blockedTickets.length,
      pendingMessages: q5.pendingMessages,
    },
    'conductor heartbeat completed'
  );

  return ok(result);
}

async function checkTaskPriority(db: SQLiteManager): Promise<PriorityCheckResult> {
  const recommendations: string[] = [];

  // Check high priority tickets
  const p0Result = db.listTickets({ priority: 'P0', status: TicketStatus.TODO });
  const p1Result = db.listTickets({ priority: 'P1', status: TicketStatus.TODO });
  const backlogResult = db.listTickets({ status: TicketStatus.BACKLOG });

  const highPriorityCount = (p0Result.isOk() ? p0Result.value.length : 0) +
    (p1Result.isOk() ? p1Result.value.length : 0);
  const backlogCount = backlogResult.isOk() ? backlogResult.value.length : 0;

  if (p0Result.isOk() && p0Result.value.length > 0) {
    recommendations.push(`${p0Result.value.length} P0 tickets need immediate attention`);
  }

  if (backlogCount > 20) {
    recommendations.push('Backlog exceeds 20 items - consider grooming');
  }

  return {
    highPriorityCount,
    inboxCount: 0, // Would check inbox directory
    backlogCount,
    recommendations,
  };
}

async function checkPerformers(instanceRegistry: InstanceRegistry): Promise<PerformerCheckResult> {
  const STALE_THRESHOLD_MS = 60000; // 1 minute
  const now = Date.now();

  const performersResult = await instanceRegistry.listByRole('performer');
  if (performersResult.isErr()) {
    return {
      activeCount: 0,
      busyCount: 0,
      idleCount: 0,
      staleCount: 0,
      performers: [],
    };
  }

  const performers = performersResult.value;
  const statuses: PerformerStatus[] = [];
  let busyCount = 0;
  let idleCount = 0;
  let staleCount = 0;

  for (const performer of performers) {
    const isStale = (now - performer.lastHeartbeat) > STALE_THRESHOLD_MS;

    if (isStale) {
      staleCount++;
    } else if (performer.status === 'busy') {
      busyCount++;
    } else if (performer.status === 'idle' || performer.status === 'active') {
      idleCount++;
    }

    statuses.push({
      id: performer.id,
      status: performer.status,
      currentTaskId: performer.currentTaskId,
      lastHeartbeat: performer.lastHeartbeat,
      isStale,
    });
  }

  return {
    activeCount: performers.length - staleCount,
    busyCount,
    idleCount,
    staleCount,
    performers: statuses,
  };
}

async function checkProgress(db: SQLiteManager): Promise<ProgressCheckResult> {
  const allTasksResult = db.listTasks({});
  if (allTasksResult.isErr()) {
    return {
      totalTasks: 0,
      completedTasks: 0,
      inProgressTasks: 0,
      pendingTasks: 0,
      completionRate: 0,
    };
  }

  const tasks = allTasksResult.value;
  const completedTasks = tasks.filter((t) => t.status === 'completed').length;
  const inProgressTasks = tasks.filter((t) => t.status === 'running' || t.status === 'claimed').length;
  const pendingTasks = tasks.filter((t) => t.status === 'pending').length;

  return {
    totalTasks: tasks.length,
    completedTasks,
    inProgressTasks,
    pendingTasks,
    completionRate: tasks.length > 0 ? completedTasks / tasks.length : 0,
  };
}

async function checkBlocked(db: SQLiteManager): Promise<BlockedCheckResult> {
  const blockedResult = db.listTickets({ status: TicketStatus.BLOCKED });
  const blockedTickets = blockedResult.isOk() ? blockedResult.value : [];

  return {
    blockedTickets,
    decisionRequired: blockedTickets.length > 0,
  };
}

async function checkMessages(db: SQLiteManager): Promise<MessageCheckResult> {
  const messagesResult = db.peekMessages(100);
  if (messagesResult.isErr()) {
    return { pendingMessages: 0, criticalMessages: 0 };
  }

  const messages = messagesResult.value;
  const criticalMessages = messages.filter((m) => m.priority >= 3).length;

  return {
    pendingMessages: messages.length,
    criticalMessages,
  };
}

// ============================================================================
// Conductor Poll
// ============================================================================

export interface ConductorPollOptions {
  readonly autoAssign?: boolean;
  readonly maxAssignments?: number;
}

export interface ConductorPollResult {
  readonly assignableTasks: Task[];
  readonly availablePerformers: Instance[];
  readonly assignments: Assignment[];
  readonly isolationConflicts: number;
}

export interface Assignment {
  readonly taskId: string;
  readonly performerId: string;
  readonly success: boolean;
  readonly error?: string;
}

export async function executeConductorPoll(
  db: SQLiteManager,
  instanceRegistry: InstanceRegistry,
  taskAssigner: TaskAssigner,
  isolationChecker: IsolationChecker,
  options: ConductorPollOptions = {}
): Promise<KallaxResult<ConductorPollResult>> {
  const { autoAssign = false, maxAssignments = 5 } = options;

  logger.info({ autoAssign, maxAssignments }, 'conductor poll starting');

  // Get assignable tasks
  const tasksResult = await taskAssigner.getAssignableTasks();
  if (tasksResult.isErr()) {
    return err(tasksResult.error);
  }

  // Get available performers
  const performersResult = await instanceRegistry.listByRole('performer');
  if (performersResult.isErr()) {
    return err(performersResult.error);
  }

  const availablePerformers = performersResult.value.filter(
    (p) => p.status === 'idle' || p.status === 'active'
  );

  // Count isolation conflicts
  const scopesResult = isolationChecker.listScopes();
  let isolationConflicts = 0;
  if (scopesResult.isOk()) {
    const scopes = scopesResult.value;
    for (let i = 0; i < scopes.length; i++) {
      for (let j = i + 1; j < scopes.length; j++) {
        const scopeA = scopes[i];
        const scopeB = scopes[j];
        if (scopeA !== undefined && scopeB !== undefined) {
          const conflictResult = isolationChecker.checkPairConflicts(scopeA.taskId, scopeB.taskId);
          if (conflictResult.isOk() && conflictResult.value !== null) {
            isolationConflicts++;
          }
        }
      }
    }
  }

  const assignments: Assignment[] = [];

  // Auto-assign if enabled
  if (autoAssign && availablePerformers.length > 0 && tasksResult.value.length > 0) {
    let assignmentCount = 0;

    for (const performer of availablePerformers) {
      if (assignmentCount >= maxAssignments) break;
      if (performer.currentTaskId !== null) continue;

      // Find a task without isolation conflicts
      for (const task of tasksResult.value) {
        // Check if task already assigned in this round
        if (assignments.some((a) => a.taskId === task.id)) continue;

        const assignResult = await taskAssigner.assignTask(task.id, performer.id);

        assignments.push({
          taskId: task.id,
          performerId: performer.id,
          success: assignResult.isOk(),
          error: assignResult.isErr() ? assignResult.error.message : undefined,
        });

        if (assignResult.isOk()) {
          assignmentCount++;
          break;
        }
      }
    }
  }

  logger.info(
    {
      assignableTasks: tasksResult.value.length,
      availablePerformers: availablePerformers.length,
      assignmentsMade: assignments.filter((a) => a.success).length,
      isolationConflicts,
    },
    'conductor poll completed'
  );

  return ok({
    assignableTasks: tasksResult.value,
    availablePerformers,
    assignments,
    isolationConflicts,
  });
}

/**
 * KALLAX Claim Queue
 * Priority-based task dispatch with capability filtering.
 * Conductor enqueues tasks; Performers dequeue by priority + capability match.
 * FIFO within same priority level.
 */

import { logger } from '../utils/logger.js';

// ============================================================================
// Public Types
// ============================================================================

export interface ClaimQueueItem {
  readonly taskId: string;
  readonly ticketId: string;
  readonly priority: number;
  readonly requiredCapabilities: readonly string[];
  readonly createdAt: number;
  readonly deadline?: number;
}

export interface ClaimQueueStats {
  readonly total: number;
  readonly byPriority: Record<number, number>;
  readonly pendingClaimCount: number;
}

export interface ClaimQueue {
  /** Add task to queue */
  enqueue(
    taskId: string,
    ticketId: string,
    priority: number,
    capabilities: readonly string[]
  ): void;
  /** Performer claims next available task matching their capabilities */
  dequeue(performerId: string, capabilities: readonly string[]): ClaimQueueItem | null;
  /** Re-queue a task (e.g., after dead performer detected) */
  reQueue(taskId: string): void;
  /** Get queue stats */
  stats(): ClaimQueueStats;
  /** Remove task from queue */
  remove(taskId: string): void;
  /** Register callback for task release events */
  onTaskReleased: (handler: TaskReleasedHandler) => void;
}

export type TaskReleasedHandler = (item: ClaimQueueItem, performerId: string) => void;

// ============================================================================
// Internal Types
// ============================================================================

interface InternalItem {
  readonly item: ClaimQueueItem;
  readonly enqueueOrder: number;
}

interface ActiveClaim {
  readonly item: ClaimQueueItem;
  readonly performerId: string;
  readonly claimedAt: number;
}

// ============================================================================
// Factory
// ============================================================================

export function createClaimQueue(): ClaimQueue {
  const queue: InternalItem[] = [];
  const activeClaims = new Map<string, ActiveClaim>();
  let enqueueCounter = 0;
  let taskReleasedHandler: TaskReleasedHandler | null = null;

  /**
   * Sort by priority descending, then by insertion order ascending (FIFO)
   */
  function sortQueue(): void {
    queue.sort((a, b) => {
      const priorityDiff = b.item.priority - a.item.priority;
      if (priorityDiff !== 0) return priorityDiff;
      return a.enqueueOrder - b.enqueueOrder;
    });
  }

  /**
   * Check if performer has all required capabilities
   */
  function hasCapabilities(
    required: readonly string[],
    provided: readonly string[]
  ): boolean {
    if (required.length === 0) return true;
    const providedSet = new Set(provided);
    return required.every((c) => providedSet.has(c));
  }

  return {
    enqueue(
      taskId: string,
      ticketId: string,
      priority: number,
      capabilities: readonly string[]
    ): void {
      const item: ClaimQueueItem = {
        taskId,
        ticketId,
        priority,
        requiredCapabilities: [...capabilities],
        createdAt: Date.now(),
      };

      queue.push({ item, enqueueOrder: enqueueCounter++ });
      sortQueue();

      logger.debug(
        { taskId, ticketId, priority, capabilityCount: capabilities.length },
        'task enqueued in claim queue'
      );
    },

    dequeue(
      performerId: string,
      capabilities: readonly string[]
    ): ClaimQueueItem | null {
      for (let i = 0; i < queue.length; i++) {
        const entry = queue[i];
        if (entry === undefined) continue;
        if (hasCapabilities(entry.item.requiredCapabilities, capabilities)) {
          queue.splice(i, 1);
          activeClaims.set(entry.item.taskId, {
            item: entry.item,
            performerId,
            claimedAt: Date.now(),
          });

          logger.info(
            { taskId: entry.item.taskId, performerId, priority: entry.item.priority },
            'task dequeued by performer'
          );

          return entry.item;
        }
      }

      logger.debug({ performerId }, 'no matching task found in claim queue');
      return null;
    },

    reQueue(taskId: string): void {
      // Check active claims first
      const active = activeClaims.get(taskId);
      if (active !== undefined) {
        activeClaims.delete(taskId);
        const { item } = active;

        // Re-queue with fresh timestamp
        const refreshedItem: ClaimQueueItem = {
          ...item,
          createdAt: Date.now(),
        };
        queue.push({ item: refreshedItem, enqueueOrder: enqueueCounter++ });
        sortQueue();

        logger.info(
          { taskId: item.taskId, performerId: active.performerId },
          'task re-queued after release'
        );

        // Notify release handler
        if (taskReleasedHandler !== null) {
          taskReleasedHandler(refreshedItem, active.performerId);
        }
        return;
      }

      // Check if already in queue (pending)
      const inQueue = queue.find((e) => e.item.taskId === taskId);
      if (inQueue !== undefined) {
        logger.debug({ taskId }, 'task already in claim queue, skipping reQueue');
        return;
      }

      logger.warn(
        { taskId },
        'reQueue called for unknown task — not in queue or active claims'
      );
    },

    stats(): ClaimQueueStats {
      const byPriority: Record<number, number> = {};

      for (const entry of queue) {
        const p = entry.item.priority;
        byPriority[p] = (byPriority[p] ?? 0) + 1;
      }

      return {
        total: queue.length,
        byPriority,
        pendingClaimCount: activeClaims.size,
      };
    },

    remove(taskId: string): void {
      // Remove from pending queue
      const queueIdx = queue.findIndex((e) => e.item.taskId === taskId);
      if (queueIdx !== -1) {
        queue.splice(queueIdx, 1);
        logger.debug({ taskId }, 'task removed from claim queue');
      }

      // Remove from active claims
      const removed = activeClaims.delete(taskId);
      if (removed) {
        logger.debug({ taskId }, 'task removed from active claims');
      }
    },

    onTaskReleased(handler: TaskReleasedHandler): void {
      taskReleasedHandler = handler;
    },
  };
}

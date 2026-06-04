/**
 * KALLAX Agent Farm Server
 * Persistent service managing the Performer pool.
 *
 * SINGLETON — manages performer registration, heartbeat detection,
 * task allocation via ClaimQueue, and capability matching via ExpertMatcher.
 *
 * Lifecycle:
 *   start() → heartbeat check loop every 15s → stop()
 *
 * Dependencies: ClaimQueue, ExpertMatcher, InstanceRegistry
 */

import { logger } from '../utils/logger.js';
import type { ClaimQueue } from './claim-queue.js';
import type { ExpertMatcher, AgentProfile } from './expert-matcher.js';
import type { InstanceRegistry } from './instance-registry.js';

// ============================================================================
// Public Types
// ============================================================================

export interface FarmConfig {
  readonly maxPerformers: number;
  readonly minIdle: number;
  readonly heartbeatTimeoutMs: number;
  readonly autoScale: boolean;
}

export interface FarmState {
  readonly totalPerformers: number;
  readonly idlePerformers: number;
  readonly busyPerformers: number;
  readonly taskQueueDepth: number;
  readonly status: 'running' | 'degraded' | 'stopped';
}

export interface FarmStats {
  readonly uptime: number;
  readonly tasksCompleted: number;
  readonly tasksFailed: number;
  readonly avgCompletionMs: number;
}

export interface AgentFarm {
  start(config?: Partial<FarmConfig>): Promise<void>;
  stop(): Promise<void>;
  registerPerformer(capabilities: string[]): Promise<string>;
  unregisterPerformer(performerId: string): Promise<void>;
  getNextTask(performerId: string): Promise<{ taskId: string; ticketId: string } | null>;
  completeTask(performerId: string, taskId: string, success: boolean): Promise<void>;
  getState(): FarmState;
  getStats(): FarmStats;
}

// ============================================================================
// Internal Types
// ============================================================================

interface PerformerInfo {
  readonly id: string;
  readonly capabilities: string[];
  currentTaskId: string | null;
  taskStartedAt: number | null;
  readonly registeredAt: number;
  lastHeartbeatMs: number;
}

// ============================================================================
// Defaults
// ============================================================================

const DEFAULT_FARM_CONFIG: FarmConfig = {
  maxPerformers: 10,
  minIdle: 2,
  heartbeatTimeoutMs: 60_000,
  autoScale: false,
};

const HEARTBEAT_CHECK_INTERVAL_MS = 15_000;

// ============================================================================
// Factory
// ============================================================================

export function createAgentFarm(
  claimQueue: ClaimQueue,
  expertMatcher: ExpertMatcher,
  _instanceRegistry: InstanceRegistry,
  _instanceId: string,
  config: Partial<FarmConfig> = {}
): AgentFarm {
  const finalConfig: FarmConfig = { ...DEFAULT_FARM_CONFIG, ...config };

  const performers = new Map<string, PerformerInfo>();
  let heartbeatInterval: ReturnType<typeof setInterval> | null = null;
  let startTime = 0;
  let tasksCompleted = 0;
  let tasksFailed = 0;
  const completionTimes: number[] = [];
  let currentStatus: FarmState['status'] = 'stopped';

  /**
	 * Recalculate farm status based on performer counts, health, and queue.
	 */
  function recalcStatus(): FarmState['status'] {
    const now = Date.now();
    let staleCount = 0;
    let idleCount = 0;

    for (const p of performers.values()) {
      if (p.currentTaskId === null) idleCount++;
      if (now - p.lastHeartbeatMs > finalConfig.heartbeatTimeoutMs) staleCount++;
    }

    if (performers.size === 0) return 'stopped';

    const atCapacity = performers.size >= finalConfig.maxPerformers;
    if (atCapacity && staleCount === 0 && idleCount >= finalConfig.minIdle) {
      return 'running';
    }

    return 'degraded';
  }

  /**
	 * Periodic heartbeat check — detect stale performers and re-queue their tasks.
	 */
  async function checkStalePerformers(): Promise<void> {
    const now = Date.now();

    for (const performer of performers.values()) {
      const elapsed = now - performer.lastHeartbeatMs;
      if (elapsed <= finalConfig.heartbeatTimeoutMs) continue;

      // Stale performer detected
      logger.warn(
        { performerId: performer.id, elapsedMs: elapsed, currentTaskId: performer.currentTaskId },
        'stale performer detected — re-queuing task'
      );

      if (performer.currentTaskId !== null) {
        claimQueue.reQueue(performer.currentTaskId);
      }

      performer.currentTaskId = null;
      performer.taskStartedAt = null;
    }

    currentStatus = recalcStatus();
  }

  return {
    async start(configOverride?: Partial<FarmConfig>): Promise<void> {
      if (heartbeatInterval !== null) {
        logger.warn({}, 'agent farm already running');
        return;
      }

      if (configOverride !== undefined) {
        Object.assign(finalConfig, configOverride);
      }

      startTime = Date.now();
      currentStatus = 'running';

      heartbeatInterval = setInterval(() => {
        void checkStalePerformers();
      }, HEARTBEAT_CHECK_INTERVAL_MS);

      logger.info(
        {
          maxPerformers: finalConfig.maxPerformers,
          minIdle: finalConfig.minIdle,
          heartbeatTimeoutMs: finalConfig.heartbeatTimeoutMs,
          autoScale: finalConfig.autoScale,
        },
        'agent farm started'
      );
    },

    async stop(): Promise<void> {
      currentStatus = 'stopped';

      if (heartbeatInterval !== null) {
        clearInterval(heartbeatInterval);
        heartbeatInterval = null;
      }

      performers.clear();
      logger.info({ uptimeMs: startTime > 0 ? Date.now() - startTime : 0 }, 'agent farm stopped');
    },

    async registerPerformer(capabilities: string[]): Promise<string> {
      if (performers.size >= finalConfig.maxPerformers) {
        throw new Error(
          `Farm at capacity (${finalConfig.maxPerformers}). Cannot register more performers.`
        );
      }

      const performerId = `perf_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
      const now = Date.now();

      const info: PerformerInfo = {
        id: performerId,
        capabilities: [...capabilities],
        currentTaskId: null,
        taskStartedAt: null,
        registeredAt: now,
        lastHeartbeatMs: now,
      };

      performers.set(performerId, info);

      // Register in expert matcher for capability-aware assignment
      const profile: AgentProfile = {
        performerId,
        capabilities: [...capabilities],
        completedTasks: 0,
        successRate: 1,
        avgCompletionTimeMs: 0,
        preferredLanguages: [],
        specializedDomains: [],
        recentTaskIds: [],
      };
      expertMatcher.addAgentProfile(profile);

      currentStatus = recalcStatus();

      logger.info(
        { performerId, capabilityCount: capabilities.length, totalPerformers: performers.size },
        'performer registered in farm'
      );

      return performerId;
    },

    async unregisterPerformer(performerId: string): Promise<void> {
      const performer = performers.get(performerId);
      if (performer === undefined) {
        logger.warn({ performerId }, 'attempt to unregister unknown performer');
        return;
      }

      // Re-queue any active task before removing
      if (performer.currentTaskId !== null) {
        claimQueue.reQueue(performer.currentTaskId);
      }

      performers.delete(performerId);
      currentStatus = recalcStatus();

      logger.info(
        { performerId, remainingPerformers: performers.size },
        'performer unregistered from farm'
      );
    },

    async getNextTask(
      performerId: string
    ): Promise<{ taskId: string; ticketId: string } | null> {
      const performer = performers.get(performerId);
      if (performer === undefined) {
        logger.warn({ performerId }, 'unknown performer requested next task');
        return null;
      }

      // Touch heartbeat
      performer.lastHeartbeatMs = Date.now();

      // Performer already has a task — cannot claim another
      if (performer.currentTaskId !== null) {
        logger.debug(
          { performerId, taskId: performer.currentTaskId },
          'performer already busy with a task'
        );
        return null;
      }

      // Dequeue next matching task from claim queue
      const item = claimQueue.dequeue(performerId, performer.capabilities);
      if (item === null) {
        logger.debug({ performerId }, 'no matching task available');
        return null;
      }

      performer.currentTaskId = item.taskId;
      performer.taskStartedAt = Date.now();
      currentStatus = recalcStatus();

      logger.info(
        { performerId, taskId: item.taskId, ticketId: item.ticketId },
        'task assigned to performer'
      );

      return { taskId: item.taskId, ticketId: item.ticketId };
    },

    async completeTask(performerId: string, taskId: string, success: boolean): Promise<void> {
      const performer = performers.get(performerId);
      if (performer === undefined) {
        logger.warn({ performerId }, 'unknown performer completed task');
        return;
      }

      if (performer.currentTaskId !== taskId) {
        logger.warn(
          { performerId, taskId, assignedTaskId: performer.currentTaskId },
          'task id mismatch on completion — ignoring stale completion'
        );
        return;
      }

      if (success) {
        tasksCompleted++;
      } else {
        tasksFailed++;
      }

      // Track completion duration
      if (performer.taskStartedAt !== null) {
        const durationMs = Date.now() - performer.taskStartedAt;
        completionTimes.push(durationMs);
        if (completionTimes.length > 100) {
          completionTimes.splice(0, completionTimes.length - 100);
        }

        // Feed back to expert matcher for future assignments
        expertMatcher.updateAgentStats(performerId, {
          performerId,
          taskId,
          success,
          durationMs,
        });
      }

      // Reset performer slot
      performer.currentTaskId = null;
      performer.taskStartedAt = null;
      performer.lastHeartbeatMs = Date.now();
      currentStatus = recalcStatus();

      logger.info(
        { performerId, taskId, success, tasksCompleted, tasksFailed },
        'task completed in farm'
      );
    },

    getState(): FarmState {
      currentStatus = recalcStatus();

      let idleCount = 0;
      for (const p of performers.values()) {
        if (p.currentTaskId === null) idleCount++;
      }

      return {
        totalPerformers: performers.size,
        idlePerformers: idleCount,
        busyPerformers: performers.size - idleCount,
        taskQueueDepth: claimQueue.stats().total,
        status: currentStatus,
      };
    },

    getStats(): FarmStats {
      const avgMs =
        completionTimes.length > 0
          ? Math.round(
              completionTimes.reduce((sum, t) => sum + t, 0) / completionTimes.length
            )
          : 0;

      return {
        uptime: startTime > 0 ? Date.now() - startTime : 0,
        tasksCompleted,
        tasksFailed,
        avgCompletionMs: avgMs,
      };
    },
  };
}

// ============================================================================
// Singleton Accessor
// ============================================================================

let defaultFarm: AgentFarm | null = null;

/**
 * Get or create the singleton AgentFarm instance.
 *
 * Dependencies are required on the first call; subsequent calls return
 * the existing instance regardless of arguments passed.
 */
export function getAgentFarm(
  claimQueue?: ClaimQueue,
  expertMatcher?: ExpertMatcher,
  instanceRegistry?: InstanceRegistry,
  instanceId?: string,
  config?: Partial<FarmConfig>
): AgentFarm {
  if (defaultFarm === null) {
    if (claimQueue === undefined || expertMatcher === undefined || instanceRegistry === undefined || instanceId === undefined) {
      throw new Error(
        'AgentFarm not initialized. Pass all dependencies on first call.'
      );
    }
    defaultFarm = createAgentFarm(claimQueue, expertMatcher, instanceRegistry, instanceId, config);
  }
  return defaultFarm;
}

/**
 * Reset the singleton (for testing).
 */
export function resetAgentFarm(): void {
  defaultFarm = null;
}

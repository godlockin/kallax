/**
 * KALLAX Heartbeat Monitor
 * Monitor instance health and detect stale instances
 */

import { ok } from 'neverthrow';
import type { KallaxResult, Instance } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { InstanceRegistry } from './instance-registry.js';

export interface HeartbeatMonitorConfig {
  readonly heartbeatIntervalMs: number;
  readonly staleThresholdMs: number;
  readonly checkIntervalMs: number;
}

export interface HeartbeatMonitor {
  start: () => void;
  stop: () => void;
  isRunning: () => boolean;
  getStats: () => HeartbeatStats;
  onStaleInstance: (handler: StaleInstanceHandler) => void;
}

export interface HeartbeatStats {
  readonly isRunning: boolean;
  readonly lastHeartbeatSent: number | null;
  readonly lastCheckPerformed: number | null;
  readonly heartbeatsSent: number;
  readonly staleInstancesDetected: number;
}

export type StaleInstanceHandler = (instances: Instance[]) => Promise<void>;

const DEFAULT_CONFIG: HeartbeatMonitorConfig = {
  heartbeatIntervalMs: 10000, // 10 seconds
  staleThresholdMs: 60000, // 1 minute
  checkIntervalMs: 30000, // 30 seconds
};

export function createHeartbeatMonitor(
  registry: InstanceRegistry,
  config: Partial<HeartbeatMonitorConfig> = {}
): HeartbeatMonitor {
  const finalConfig: HeartbeatMonitorConfig = { ...DEFAULT_CONFIG, ...config };

  let heartbeatInterval: ReturnType<typeof setInterval> | null = null;
  let checkInterval: ReturnType<typeof setInterval> | null = null;
  let lastHeartbeatSent: number | null = null;
  let lastCheckPerformed: number | null = null;
  let heartbeatsSent = 0;
  let staleInstancesDetected = 0;
  let staleHandler: StaleInstanceHandler | null = null;

  async function sendHeartbeat(): Promise<void> {
    const currentInstance = registry.getCurrentInstance();
    if (currentInstance === null) {
      return;
    }

    const result = await registry.heartbeat(currentInstance.id);
    if (result.isOk()) {
      lastHeartbeatSent = Date.now();
      heartbeatsSent++;
      logger.debug({ instanceId: currentInstance.id }, 'heartbeat sent');
    } else {
      logger.error(
        { instanceId: currentInstance.id, error: result.error.message },
        'failed to send heartbeat'
      );
    }
  }

  async function checkStaleInstances(): Promise<void> {
    const result = await registry.markStaleInstances(finalConfig.staleThresholdMs);
    lastCheckPerformed = Date.now();

    if (result.isOk() && result.value.length > 0) {
      staleInstancesDetected += result.value.length;
      logger.warn({ count: result.value.length }, 'stale instances detected');

      if (staleHandler !== null) {
        try {
          await staleHandler(result.value);
        } catch (error: unknown) {
          logger.error(
            { error: error instanceof Error ? error.message : String(error) },
            'stale instance handler failed'
          );
        }
      }
    }
  }

  return {
    start(): void {
      if (heartbeatInterval !== null) {
        logger.warn({}, 'heartbeat monitor already running');
        return;
      }

      // Send initial heartbeat
      void sendHeartbeat();

      // Schedule periodic heartbeats
      heartbeatInterval = setInterval(() => {
        void sendHeartbeat();
      }, finalConfig.heartbeatIntervalMs);

      // Schedule periodic stale checks
      checkInterval = setInterval(() => {
        void checkStaleInstances();
      }, finalConfig.checkIntervalMs);

      logger.info(
        {
          heartbeatIntervalMs: finalConfig.heartbeatIntervalMs,
          checkIntervalMs: finalConfig.checkIntervalMs,
          staleThresholdMs: finalConfig.staleThresholdMs,
        },
        'heartbeat monitor started'
      );
    },

    stop(): void {
      if (heartbeatInterval !== null) {
        clearInterval(heartbeatInterval);
        heartbeatInterval = null;
      }

      if (checkInterval !== null) {
        clearInterval(checkInterval);
        checkInterval = null;
      }

      logger.info({}, 'heartbeat monitor stopped');
    },

    isRunning(): boolean {
      return heartbeatInterval !== null;
    },

    getStats(): HeartbeatStats {
      return {
        isRunning: heartbeatInterval !== null,
        lastHeartbeatSent,
        lastCheckPerformed,
        heartbeatsSent,
        staleInstancesDetected,
      };
    },

    onStaleInstance(handler: StaleInstanceHandler): void {
      staleHandler = handler;
    },
  };
}

/**
 * Calculate adaptive timeout based on estimated task duration
 */
export function calculateAdaptiveTimeout(estimatedMinutes: number | undefined): number {
  const DEFAULT_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes
  const MIN_TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes
  const MAX_TIMEOUT_MS = 4 * 60 * 60 * 1000; // 4 hours

  if (estimatedMinutes === undefined || estimatedMinutes <= 0) {
    return DEFAULT_TIMEOUT_MS;
  }

  // Timeout = min(estimated/10, 30min) as per KALLAX spec
  const calculated = Math.min(
    (estimatedMinutes / 10) * 60 * 1000,
    30 * 60 * 1000
  );

  return Math.max(MIN_TIMEOUT_MS, Math.min(MAX_TIMEOUT_MS, calculated));
}

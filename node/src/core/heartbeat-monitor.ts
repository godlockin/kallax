/**
 * KALLAX Heartbeat Monitor + Client
 *
 * Two interfaces in one module:
 *   HeartbeatMonitor — server-side: sends heartbeat to registry, detects stale instances
 *   HeartbeatClient  — client-side: sends HTTP heartbeats to API server, detects dead performers
 */

import { ok } from 'neverthrow';
import type { KallaxResult, Instance } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { InstanceRegistry } from './instance-registry.js';

// ============================================================================
// Heartbeat Payload
// ============================================================================

export interface HeartbeatPayload {
  readonly performerId: string;
  readonly currentTaskId: string | null;
  readonly status: string;
  readonly timestamp: number;
}

// ============================================================================
// Server-Side Monitor
// ============================================================================

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

// ============================================================================
// Client-Side Heartbeat Sender
// ============================================================================

export interface HeartbeatClientStats {
  readonly isRunning: boolean;
  readonly heartbeatsSent: number;
  readonly lastHeartbeatSent: number | null;
  readonly errors: number;
  readonly lastError: string | null;
}

export type DeadPerformerHandler = (performers: DeadPerformerInfo[]) => void;

export interface DeadPerformerInfo {
  readonly instanceId: string;
  readonly role: string;
  readonly status: string;
  readonly lastHeartbeat: number;
  readonly currentTaskId: string | null;
}

export interface HeartbeatClient {
  /** Start sending periodic heartbeats to the API server */
  startHeartbeat: (
    performerId: string,
    currentTaskId?: string | null,
    intervalMs?: number
  ) => void;
  /** Stop sending heartbeats and polling for dead performers */
  stopHeartbeat: () => void;
  /** Whether heartbeats are currently being sent */
  isRunning: () => boolean;
  /** Get client stats */
  getStats: () => HeartbeatClientStats;
  /** Register callback for when other performers are detected as dead */
  onPerformerDead: (handler: DeadPerformerHandler) => void;
}

const DEFAULT_CLIENT_INTERVAL_MS = 10000; // 10 seconds
const DEFAULT_DEAD_POLL_INTERVAL_MS = 15000; // 15 seconds

/**
 * Create a client-side heartbeat sender.
 * Sends HTTP POST heartbeats to the API server at the given interval.
 *
 * @param serverUrl - Base URL of the KALLAX API server (e.g. http://127.0.0.1:9877)
 * @param apiKey - API key for authentication (defaults to 'kallax-dev-key')
 * @param staleThresholdMs - How long without a heartbeat before a performer is considered dead (default 30s)
 */
export function createHeartbeatClient(
  serverUrl: string,
  apiKey: string = 'kallax-dev-key',
  staleThresholdMs: number = 30000
): HeartbeatClient {
  let heartbeatInterval: ReturnType<typeof setInterval> | null = null;
  let deadPollInterval: ReturnType<typeof setInterval> | null = null;

  let heartbeatsSent = 0;
  let lastHeartbeatSent: number | null = null;
  let errors = 0;
  let lastError: string | null = null;

  let deadHandler: DeadPerformerHandler | null = null;

  async function sendHeartbeat(
    performerId: string,
    currentTaskId: string | null,
    status: string
  ): Promise<void> {
    try {
      const payload: HeartbeatPayload = {
        performerId,
        currentTaskId,
        status,
        timestamp: Date.now(),
      };

      const response = await fetch(`${serverUrl}/api/heartbeat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-KALLAX-API-Key': apiKey,
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const body = await response.text();
        errors++;
        lastError = `HTTP ${response.status}: ${body}`;
        logger.warn(
          { performerId, statusCode: response.status },
          'heartbeat request failed'
        );
        return;
      }

      lastHeartbeatSent = Date.now();
      heartbeatsSent++;
    } catch (error: unknown) {
      errors++;
      lastError = error instanceof Error ? error.message : String(error);
      logger.warn(
        { performerId, error: lastError },
        'heartbeat request error'
      );
    }
  }

  async function pollDeadPerformers(): Promise<void> {
    try {
      const response = await fetch(`${serverUrl}/api/heartbeat/status`, {
        headers: {
          'Content-Type': 'application/json',
          'X-KALLAX-API-Key': apiKey,
        },
      });

      if (!response.ok) {
        return;
      }

      const body = (await response.json()) as Record<string, unknown>;
      if (body['success'] !== true) {
        return;
      }

      const statusList = body['data'] as Array<Record<string, unknown>> | undefined;
      if (!Array.isArray(statusList)) {
        return;
      }

      const deadPerformers: DeadPerformerInfo[] = [];

      for (const entry of statusList) {
        const status = entry['status'] as string | undefined;
        const lastHb = entry['lastHeartbeat'] as number | undefined;
        const isStale =
          status === 'error' ||
          (status !== 'shutdown' &&
            lastHb !== undefined &&
            Date.now() - lastHb > staleThresholdMs);

        if (isStale) {
          deadPerformers.push({
            instanceId: entry['instanceId'] as string,
            role: entry['role'] as string,
            status: status ?? 'unknown',
            lastHeartbeat: lastHb ?? 0,
            currentTaskId: (entry['currentTaskId'] as string | null) ?? null,
          });
        }
      }

      if (deadPerformers.length > 0 && deadHandler !== null) {
        try {
          deadHandler(deadPerformers);
        } catch (handlerError: unknown) {
          logger.error(
            { error: handlerError instanceof Error ? handlerError.message : String(handlerError) },
            'dead performer handler failed'
          );
        }
      }
    } catch {
      // Poll errors are expected if server is down; just ignore
    }
  }

  return {
    startHeartbeat(
      performerId: string,
      currentTaskId?: string | null,
      intervalMs?: number
    ): void {
      if (heartbeatInterval !== null) {
        logger.warn({}, 'heartbeat client already running');
        return;
      }

      const finalInterval = intervalMs ?? DEFAULT_CLIENT_INTERVAL_MS;
      const resolvedTaskId = currentTaskId ?? null;

      // Send initial heartbeat immediately
      void sendHeartbeat(performerId, resolvedTaskId, 'active');

      // Schedule periodic heartbeats
      heartbeatInterval = setInterval(() => {
        void sendHeartbeat(performerId, resolvedTaskId, 'active');
      }, finalInterval);

      // Schedule dead performer polling
      deadPollInterval = setInterval(() => {
        void pollDeadPerformers();
      }, DEFAULT_DEAD_POLL_INTERVAL_MS);

      logger.info({ performerId, intervalMs: finalInterval }, 'heartbeat client started');
    },

    stopHeartbeat(): void {
      if (heartbeatInterval !== null) {
        clearInterval(heartbeatInterval);
        heartbeatInterval = null;
      }

      if (deadPollInterval !== null) {
        clearInterval(deadPollInterval);
        deadPollInterval = null;
      }

      logger.info({}, 'heartbeat client stopped');
    },

    isRunning(): boolean {
      return heartbeatInterval !== null;
    },

    getStats(): HeartbeatClientStats {
      return {
        isRunning: heartbeatInterval !== null,
        heartbeatsSent,
        lastHeartbeatSent,
        errors,
        lastError,
      };
    },

    onPerformerDead(handler: DeadPerformerHandler): void {
      deadHandler = handler;
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

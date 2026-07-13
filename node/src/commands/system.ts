/**
 * KALLAX System Commands
 * System diagnostics and health checks
 */

import { ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { logger } from '../utils/logger.js';
import { getDefaultMemoryMonitor, type MemoryStats } from '../utils/memory-monitor.js';
import type { SQLiteManager, DatabaseStats } from '../core/sqlite/index.js';
import type { InstanceRegistry } from '../core/instance-registry.js';
import type { MessageQueue, MessageQueueStats } from '../core/message-queue.js';
import { getAllCircuitBreakerStats, type CircuitBreakerStats } from '../core/circuit-breaker.js';
import { getSSEBus, type SSEBusStats } from '../core/sse-bus.js';
import type { CacheStats } from '../core/cache-layer.js';
import { ticketCache, taskCache, instanceCache } from '../core/cache-layer.js';

export interface SystemDoctorResult {
  readonly healthy: boolean;
  readonly timestamp: number;
  readonly checks: HealthCheck[];
  readonly memory: MemoryStats;
  readonly database: DatabaseStats;
  readonly cache: CacheHealthStats;
  readonly circuitBreakers: Record<string, CircuitBreakerStats>;
  readonly sse: SSEBusStats;
  readonly messageQueue?: MessageQueueStats;
  readonly recommendations: string[];
}

export interface HealthCheck {
  readonly name: string;
  readonly status: 'healthy' | 'degraded' | 'unhealthy';
  readonly message: string;
  readonly duration: number;
}

export interface CacheHealthStats {
  readonly tickets: CacheStats;
  readonly tasks: CacheStats;
  readonly instances: CacheStats;
}

export function executeSystemDoctor(
  db: SQLiteManager,
  instanceRegistry: InstanceRegistry,
  messageQueue?: MessageQueue
): Promise<KallaxResult<SystemDoctorResult>> {
  logger.info({}, 'running system diagnostics');

  const checks: HealthCheck[] = [];
  const recommendations: string[] = [];
  let healthy = true;

  // Check 1: Database
  const dbStart = Date.now();
  try {
    const stats = db.getStats();
    checks.push({
      name: 'database',
      status: 'healthy',
      message: `Connected - ${String(stats.ticketCount)} tickets, ${String(stats.taskCount)} tasks`,
      duration: Date.now() - dbStart,
    });
  } catch (error: unknown) {
    healthy = false;
    checks.push({
      name: 'database',
      status: 'unhealthy',
      message: error instanceof Error ? error.message : String(error),
      duration: Date.now() - dbStart,
    });
    recommendations.push('Database connection failed - check SQLite configuration');
  }

  // Check 2: Instance Registry
  const instStart = Date.now();
  const currentInstance = instanceRegistry.getCurrentInstance();
  if (currentInstance !== null) {
    const heartbeatAge = Date.now() - currentInstance.lastHeartbeat;
    const status = heartbeatAge < 60000 ? 'healthy' : heartbeatAge < 300000 ? 'degraded' : 'unhealthy';

    if (status !== 'healthy') {
      healthy = status === 'degraded' ? healthy : false;
      recommendations.push(`Instance heartbeat is ${String(Math.round(heartbeatAge / 1000))}s old - consider restart`);
    }

    checks.push({
      name: 'instance',
      status,
      message: `Role: ${currentInstance.role}, Status: ${currentInstance.status}`,
      duration: Date.now() - instStart,
    });
  } else {
    checks.push({
      name: 'instance',
      status: 'degraded',
      message: 'No instance registered',
      duration: Date.now() - instStart,
    });
    recommendations.push('No instance registered - run performer:register or set KALLAX_ROLE');
  }

  // Check 3: Memory
  const memoryMonitor = getDefaultMemoryMonitor();
  const memoryStats = memoryMonitor.getStats();
  const heapUsedMb = memoryStats.current.heapUsed / 1024 / 1024;

  const memStatus = heapUsedMb < 256 ? 'healthy' : heapUsedMb < 512 ? 'degraded' : 'unhealthy';
  if (memStatus !== 'healthy') {
    healthy = memStatus === 'degraded' ? healthy : false;
    recommendations.push(`High memory usage: ${String(Math.round(heapUsedMb))}MB - consider restart`);
  }

  checks.push({
    name: 'memory',
    status: memStatus,
    message: `Heap: ${String(Math.round(heapUsedMb))}MB, Trend: ${memoryStats.trend}`,
    duration: 0,
  });

  // Check 4: Cache health
  const cacheStats: CacheHealthStats = {
    tickets: ticketCache.stats(),
    tasks: taskCache.stats(),
    instances: instanceCache.stats(),
  };

  const avgHitRate = (cacheStats.tickets.hitRate + cacheStats.tasks.hitRate + cacheStats.instances.hitRate) / 3;
  const cacheStatus = avgHitRate > 0.5 ? 'healthy' : avgHitRate > 0.2 ? 'degraded' : 'unhealthy';

  if (cacheStatus === 'unhealthy' && (cacheStats.tickets.hits + cacheStats.tickets.misses) > 100) {
    recommendations.push(`Low cache hit rate: ${String(Math.round(avgHitRate * 100))}% - review access patterns`);
  }

  checks.push({
    name: 'cache',
    status: cacheStatus,
    message: `Hit rate: ${String(Math.round(avgHitRate * 100))}%`,
    duration: 0,
  });

  // Check 5: Circuit Breakers
  const circuitBreakers = getAllCircuitBreakerStats();
  let openCircuits = 0;

  for (const [name, stats] of Object.entries(circuitBreakers)) {
    if (stats.state === 'open') {
      openCircuits++;
      recommendations.push(`Circuit breaker "${name}" is OPEN - check external service`);
    }
  }

  checks.push({
    name: 'circuit-breakers',
    status: openCircuits === 0 ? 'healthy' : openCircuits < 2 ? 'degraded' : 'unhealthy',
    message: `${String(Object.keys(circuitBreakers).length)} breakers, ${String(openCircuits)} open`,
    duration: 0,
  });

  if (openCircuits > 0) {
    healthy = false;
  }

  // Check 6: SSE Bus
  const sseBus = getSSEBus();
  const sseStats = sseBus.getStats();

  checks.push({
    name: 'sse',
    status: 'healthy',
    message: `${String(sseStats.clientCount)} clients, ${String(sseStats.eventsPublished)} events published`,
    duration: 0,
  });

  // Check 7: Message Queue (if available)
  let mqStats: MessageQueueStats | undefined;
  if (messageQueue !== undefined) {
    mqStats = messageQueue.getStats();
    const mqStatus = mqStats.pendingCount < 100 ? 'healthy' : mqStats.pendingCount < 1000 ? 'degraded' : 'unhealthy';

    if (mqStatus !== 'healthy') {
      healthy = mqStatus === 'degraded' ? healthy : false;
      recommendations.push(`${String(mqStats.pendingCount)} pending messages - check processing`);
    }

    checks.push({
      name: 'message-queue',
      status: mqStatus,
      message: `Mode: ${mqStats.mode}, Pending: ${String(mqStats.pendingCount)}`,
      duration: 0,
    });
  }

  const result: SystemDoctorResult = {
    healthy,
    timestamp: Date.now(),
    checks,
    memory: memoryStats,
    database: db.getStats(),
    cache: cacheStats,
    circuitBreakers,
    sse: sseStats,
    messageQueue: mqStats,
    recommendations,
  };

  logger.info(
    {
      healthy,
      checkCount: checks.length,
      unhealthyCount: checks.filter((c) => c.status === 'unhealthy').length,
      recommendationCount: recommendations.length,
    },
    'system diagnostics completed'
  );

  return Promise.resolve(ok(result));
}
// ============================================================================

export interface TeamStatusResult {
  readonly conductors: InstanceSummary[];
  readonly performers: InstanceSummary[];
  readonly tasks: TaskDistribution;
  readonly health: TeamHealth;
}

export interface InstanceSummary {
  readonly id: string;
  readonly role: string;
  readonly status: string;
  readonly currentTaskId: string | null;
  readonly uptime: number;
  readonly lastHeartbeat: number;
  readonly isStale: boolean;
}

export interface TaskDistribution {
  readonly total: number;
  readonly pending: number;
  readonly running: number;
  readonly completed: number;
  readonly failed: number;
}

export interface TeamHealth {
  readonly activeConductors: number;
  readonly activePerformers: number;
  readonly utilizationRate: number;
  readonly healthy: boolean;
}

export async function executeTeamStatus(
  db: SQLiteManager,
  instanceRegistry: InstanceRegistry
): Promise<KallaxResult<TeamStatusResult>> {
  const now = Date.now();
  const STALE_THRESHOLD = 60000;

  // Get conductors
  const conductorsResult = await instanceRegistry.listByRole('conductor');
  const conductors: InstanceSummary[] = (conductorsResult.isOk() ? conductorsResult.value : []).map((i) => ({
    id: i.id,
    role: i.role,
    status: i.status,
    currentTaskId: i.currentTaskId,
    uptime: now - i.startedAt,
    lastHeartbeat: i.lastHeartbeat,
    isStale: (now - i.lastHeartbeat) > STALE_THRESHOLD,
  }));

  // Get performers
  const performersResult = await instanceRegistry.listByRole('performer');
  const performers: InstanceSummary[] = (performersResult.isOk() ? performersResult.value : []).map((i) => ({
    id: i.id,
    role: i.role,
    status: i.status,
    currentTaskId: i.currentTaskId,
    uptime: now - i.startedAt,
    lastHeartbeat: i.lastHeartbeat,
    isStale: (now - i.lastHeartbeat) > STALE_THRESHOLD,
  }));

  // Get task distribution
  const tasksResult = db.listTasks({});
  const tasks = tasksResult.isOk() ? tasksResult.value : [];

  const taskDistribution: TaskDistribution = {
    total: tasks.length,
    pending: tasks.filter((t) => t.status === 'pending').length,
    running: tasks.filter((t) => t.status === 'running' || t.status === 'claimed').length,
    completed: tasks.filter((t) => t.status === 'completed').length,
    failed: tasks.filter((t) => t.status === 'failed').length,
  };

  // Calculate health
  const activeConductors = conductors.filter((c) => !c.isStale && c.status !== 'shutdown').length;
  const activePerformers = performers.filter((p) => !p.isStale && p.status !== 'shutdown').length;
  const busyPerformers = performers.filter((p) => p.status === 'busy' && !p.isStale).length;
  const utilizationRate = activePerformers > 0 ? busyPerformers / activePerformers : 0;

  const health: TeamHealth = {
    activeConductors,
    activePerformers,
    utilizationRate,
    healthy: activeConductors > 0 && activePerformers > 0,
  };

  logger.info(
    {
      conductors: conductors.length,
      performers: performers.length,
      activeConductors,
      activePerformers,
      utilizationRate: Math.round(utilizationRate * 100),
    },
    'team status retrieved'
  );

  return ok({
    conductors,
    performers,
    tasks: taskDistribution,
    health,
  });
}

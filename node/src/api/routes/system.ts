/**
 * KALLAX System Routes
 * Diagnostics, configuration, and system management
 */

import { Router } from 'express';
import type { Request, Response } from 'express';
import * as os from 'node:os';
import { KallaxError } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import { forceGC } from '../../utils/memory-monitor.js';
import type { SQLiteManager } from '../../core/sqlite/index.js';
import type { InstanceRegistry } from '../../core/instance-registry.js';
import type { SSEBus } from '../../core/sse-bus.js';
import type { HeartbeatMonitor } from '../../core/heartbeat-monitor.js';
import { getAllCircuitBreakerStats } from '../../core/circuit-breaker.js';
import {
  createSuccessResponse,
  createErrorResponse,
  type ServerConfig,
} from '../types.js';

export interface SystemRouteDependencies {
  readonly db: SQLiteManager;
  readonly instanceRegistry: InstanceRegistry;
  readonly sseBus: SSEBus;
  readonly heartbeatMonitor?: HeartbeatMonitor;
  readonly config: ServerConfig;
  readonly startTime: number;
}

/**
 * Create system routes with injected dependencies
 */
export function createSystemRoutes(deps: SystemRouteDependencies): Router {
  const router = Router();

  // GET /api/system/doctor — run diagnostics
  router.get('/doctor', (_req: Request, res: Response): void => {
    void (async (): Promise<void> => {
      try {
        const diagnostics: Record<string, unknown> = {
          timestamp: Date.now(),
          uptime: process.uptime(),
          memory: process.memoryUsage(),
          node: process.version,
          platform: process.platform,
          arch: process.arch,
          cpus: os.cpus().length,
          loadavg: os.loadavg(),
          freemem: os.freemem(),
          hostname: os.hostname(),
        };

        // Check database
        const stats = deps.db.getStats();
        diagnostics['database'] = {
          connected: true,
          stats,
        };

        // Check instances
        const activeResult = await deps.instanceRegistry.listActive();
        if (activeResult.isOk()) {
          diagnostics['instances'] = {
            active: activeResult.value.length,
            list: activeResult.value.map((i) => ({
              id: i.id,
              role: i.role,
              status: i.status,
              uptime: Date.now() - i.startedAt,
            })),
          };
        }

        // Check SSE bus
        const sseStats = deps.sseBus.getStats();
        diagnostics['sse'] = sseStats;

        // Check heartbeat monitor
        if (deps.heartbeatMonitor !== undefined) {
          diagnostics['heartbeatMonitor'] = deps.heartbeatMonitor.getStats();
        }

        // Check circuit breakers
        diagnostics['circuitBreakers'] = getAllCircuitBreakerStats();

        logger.info({}, 'system diagnostics completed');

        res.json(createSuccessResponse(diagnostics));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'system diagnostics failed');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // GET /api/system/config — get sanitized config
  router.get('/config', (_req: Request, res: Response): void => {
    try {
      // Sanitize config — never expose apiKey
      const sanitized: Record<string, unknown> = {
        port: deps.config.port,
        host: deps.config.host,
        corsOrigins: deps.config.corsOrigins,
        rateLimit: deps.config.rateLimit,
        bodyLimit: deps.config.bodyLimit,
        apiKeyConfigured: deps.config.apiKey.length > 0,
      };

      res.json(createSuccessResponse(sanitized));
    } catch (error: unknown) {
      const kallaxError = KallaxError.fromUnknown(error);
      logger.error({ error: kallaxError.message }, 'failed to get config');
      res.status(500).json(createErrorResponse(kallaxError));
    }
  });

  // GET /api/system/circuit-breakers — get all CB stats
  router.get('/circuit-breakers', (_req: Request, res: Response): void => {
    try {
      const stats = getAllCircuitBreakerStats();
      res.json(createSuccessResponse(stats));
    } catch (error: unknown) {
      const kallaxError = KallaxError.fromUnknown(error);
      logger.error({ error: kallaxError.message }, 'failed to get circuit breaker stats');
      res.status(500).json(createErrorResponse(kallaxError));
    }
  });

  // POST /api/system/gc — trigger garbage collection
  router.post('/gc', (_req: Request, res: Response): void => {
    try {
      const gcResult = forceGC();
      const before = process.memoryUsage();

      if (gcResult) {
        const after = process.memoryUsage();
        const freedMb = (before.heapUsed - after.heapUsed) / 1024 / 1024;

        logger.info({ freedMb: Math.round(freedMb * 100) / 100 }, 'garbage collection triggered');

        res.json(createSuccessResponse({
          gcTriggered: true,
          heapUsedBefore: before.heapUsed,
          heapUsedAfter: after.heapUsed,
          freedMb: Math.round(freedMb * 100) / 100,
        }));
      } else {
        res.json(createSuccessResponse({
          gcTriggered: false,
          message: 'GC not available. Start node with --expose-gc flag',
        }));
      }
    } catch (error: unknown) {
      const kallaxError = KallaxError.fromUnknown(error);
      logger.error({ error: kallaxError.message }, 'failed to trigger GC');
      res.status(500).json(createErrorResponse(kallaxError));
    }
  });

  return router;
}

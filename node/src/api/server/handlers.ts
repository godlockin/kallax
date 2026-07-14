import type { Request, Response, NextFunction } from 'express';
import { KallaxError } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import type { SSEClient } from '../../core/sse-bus.js';
import { createSuccessResponse, createErrorResponse } from '../types.js';
import type { ApiServerDependencies } from '../server.js';

export const VERSION = '1.0.0';
let sseClientCounter = 0;

export function handleHealth(deps: ApiServerDependencies, startTime: number) {
  return (_req: Request, res: Response): void => {
    try {
      let dbConnected = false;
      try { deps.db.getStats(); dbConnected = true; } catch { dbConnected = false; }
      res.json(createSuccessResponse({
        status: dbConnected ? 'healthy' : 'degraded', uptime: Date.now() - startTime,
        version: VERSION, dbConnected, timestamp: Date.now(),
      }));
    } catch (error: unknown) {
      res.status(503).json(createErrorResponse(KallaxError.fromUnknown(error)));
    }
  };
}

export function handleLiveness(startTime: number) {
  return (_req: Request, res: Response): void => {
    res.json(createSuccessResponse({ status: 'alive', uptime: Date.now() - startTime, timestamp: Date.now() }));
  };
}

export function handleReadiness(deps: ApiServerDependencies, startTime: number) {
  return (_req: Request, res: Response): void => {
    try {
      deps.db.getStats();
      res.json(createSuccessResponse({ status: 'ready', uptime: Date.now() - startTime, timestamp: Date.now() }));
    } catch (error: unknown) {
      res.status(503).json(createErrorResponse(KallaxError.fromUnknown(error)));
    }
  };
}

export function handleVersion(startTime: number) {
  return (_req: Request, res: Response): void => {
    res.json(createSuccessResponse({ version: VERSION, name: '@kallax/node', started: startTime }));
  };
}

export function handleStats(deps: ApiServerDependencies, startTime: number) {
  return (_req: Request, res: Response): void => {
    try {
      const dbStats = deps.db.getStats();
      const allTasksResult = deps.db.listTasks({ limit: 1000 });
      let pt = 0, ct = 0, ct2 = 0, ft = 0;
      if (allTasksResult.isOk()) {
        for (const t of allTasksResult.value) {
          switch (t.status) {
            case 'pending': pt++; break;
            case 'claimed': case 'running': ct++; break;
            case 'completed': ct2++; break;
            case 'failed': case 'cancelled': ft++; break;
          }
        }
      }
      const allInstancesResult = deps.db.listInstances({ limit: 100 });
      let ti = 0, ai = 0, pc = 0, cc = 0;
      if (allInstancesResult.isOk()) {
        const instances = allInstancesResult.value; ti = instances.length;
        ai = instances.filter((i: { status: string }) => i.status !== 'shutdown' && i.status !== 'error').length;
        for (const inst of instances) {
          if (inst.role === 'performer') pc++;
          if (inst.role === 'conductor') cc++;
        }
      }
      const mem = process.memoryUsage();
      res.json(createSuccessResponse({
        tasks: { total: dbStats.taskCount, pending: pt, claimed: ct, completed: ct2, failed: ft },
        instances: { total: ti, active: ai, performers: pc, conductors: cc },
        performance: { uptime: Date.now() - startTime, memoryUsageMb: Math.round((mem.heapUsed / 1024 / 1024) * 100) / 100, cpus: 1 },
      }));
    } catch (error: unknown) { res.status(500).json(createErrorResponse(KallaxError.fromUnknown(error))); }
  };
}

export function handleSSE(deps: ApiServerDependencies) {
  return (req: Request, res: Response): void => {
    res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive', 'X-Accel-Buffering': 'no' });
    const clientId = `sse_${String(++sseClientCounter)}_${String(Date.now())}`;
    res.write(`id: init\nevent: connected\ndata: ${JSON.stringify({ clientId })}\n\n`);
    const sseClient: SSEClient = { id: clientId, send: (data: string) => { res.write(data); }, close: () => { res.end(); } };
    deps.sseBus.addClient(sseClient);
    req.on('close', () => { deps.sseBus.removeClient(clientId); logger.debug({ clientId }, 'SSE client disconnected'); });
    const keepAliveInterval = setInterval(() => { try { res.write(': keepalive\n\n'); } catch { clearInterval(keepAliveInterval); } }, 30000);
    req.on('close', () => { clearInterval(keepAliveInterval); });
    logger.info({ clientId }, 'SSE client connected');
  };
}

export function notFoundHandler() {
  return (_req: Request, res: Response): void => {
    res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Endpoint not found' }, timestamp: Date.now() });
  };
}

export function createErrorHandler(isShuttingDownRef: () => boolean) {
  return (err: Error, _req: Request, res: Response, _next: NextFunction): void => {
    if (isShuttingDownRef()) {
      res.status(503).json({ success: false, error: { code: 'SHUTTING_DOWN', message: 'Server is shutting down' }, timestamp: Date.now() });
      return;
    }
    const ke = err instanceof KallaxError ? err : KallaxError.fromUnknown(err);
    logger.error({ errorCode: ke.code, errorMessage: ke.message }, 'unhandled error');
    res.status(500).json({ success: false, error: { code: ke.code, message: 'Internal server error' }, timestamp: Date.now() });
  };
}

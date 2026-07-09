/**
 * KALLAX API Server
 * Express-based HTTP server with structured error responses and SSE support
 */

import express from 'express';
import type { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import * as http from 'node:http';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';
import { registerCleanupHandler } from '../utils/process-cleanup.js';
import type { SQLiteManager } from '../core/sqlite/index.js';
import type { TaskAssigner } from '../core/task-assigner.js';
import type { InstanceRegistry } from '../core/instance-registry.js';
import type { WorktreeManager } from '../core/worktree-manager.js';
import type { OutputVerifier } from '../core/output-verifier.js';
import type { IsolationChecker } from '../core/isolation-checker.js';
import type { HeartbeatMonitor } from '../core/heartbeat-monitor.js';
import type { SSEBus } from '../core/sse-bus.js';
import type { ClaimQueue } from '../core/claim-queue.js';
import { createAuthMiddleware } from './middleware/auth.js';
import { createRateLimiter } from './middleware/rate-limiter.js';
import { createTaskRoutes } from './routes/tasks.js';
import { createAgentRoutes } from './routes/agents.js';
import { createSystemRoutes } from './routes/system.js';
import { createWorkflowRoutes } from './routes/workflow.js';
import { createKnowledgeRoutes } from './routes/knowledge.js';
import { createHeartbeatRoutes } from './routes/heartbeat.js';
import { ServerConfigSchema, type ServerConfig } from './types.js';
import {
  handleHealth, handleLiveness, handleReadiness, handleVersion,
  handleStats, handleSSE, notFoundHandler, createErrorHandler, VERSION,
} from './server/handlers.js';

export interface ApiServerDependencies {
  readonly db: SQLiteManager;
  readonly taskAssigner: TaskAssigner;
  readonly instanceRegistry: InstanceRegistry;
  readonly worktreeManager: WorktreeManager;
  readonly outputVerifier: OutputVerifier;
  readonly isolationChecker: IsolationChecker;
  readonly sseBus: SSEBus;
  readonly heartbeatMonitor?: HeartbeatMonitor;
  readonly claimQueue?: ClaimQueue;
}

export interface ApiServer {
  readonly start: () => Promise<void>;
  readonly stop: () => Promise<void>;
  readonly getServer: () => http.Server | null;
  readonly getConfig: () => ServerConfig;
}

export function createApiServer(
  configInput: Partial<ServerConfig>,
  deps: ApiServerDependencies
): ApiServer {
  const configResult = ServerConfigSchema.safeParse(configInput);
  if (!configResult.success) {
    throw new KallaxError(
      KallaxErrorCode.CONFIG_INVALID,
      'Invalid server configuration: ' + configResult.error.errors.map((e) => `${e.path.join('.')}: ${e.message}`).join('; ')
    );
  }
  const config: ServerConfig = configResult.data;

  if (!config.apiKey || config.apiKey.length < 32) {
    throw new KallaxError(KallaxErrorCode.CONFIG_INVALID, 'KALLAX_API_KEY must be set to a strong (>=32 char) secret');
  }

  let httpServer: http.Server | null = null;
  const startTime = Date.now();
  let isShuttingDown = false;
  const app: Express = express();

  app.use(helmet({ contentSecurityPolicy: false, crossOriginResourcePolicy: { policy: 'cross-origin' } }));

  // EPIC-070-P1-9: 显式拒绝 wildcard '*' — fail-closed 默认白名单
  // 配置必须显式列出允许的 origin, '*' 拒绝 (XSS + CSRF 攻击面)
  const isWildcardOrigin = config.corsOrigins.includes('*');
  if (isWildcardOrigin && process.env['NODE_ENV'] === 'production') {
    throw new Error('CORS wildcard "*" not allowed in production (EPIC-070-P1-9)');
  }
  const allowedOrigins = isWildcardOrigin
    ? config.corsOrigins.filter((o) => o !== '*')
    : config.corsOrigins;
  app.use(cors({
    origin: allowedOrigins.length > 0 ? allowedOrigins : false, // false = 拒绝所有 CORS
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'X-KALLAX-API-Key', 'X-KALLAX-Role'],
    credentials: true,
  }));

  app.use(express.json({ limit: config.bodyLimit }));
  app.use((req: Request, _res: Response, next: NextFunction): void => {
    logger.debug({ method: req.method, path: req.path, ip: req.ip }, 'API request');
    next();
  });
  app.use(createRateLimiter());
  app.use(createAuthMiddleware(config.apiKey));

  app.get('/health', handleHealth(deps, startTime));
  app.get('/live', handleLiveness(startTime));
  app.get('/ready', handleReadiness(deps, startTime));
  app.get('/version', handleVersion(startTime));
  app.get('/stats', handleStats(deps, startTime));
  app.get('/events', handleSSE(deps));

  app.use('/api/tasks', createTaskRoutes({
    db: deps.db, taskAssigner: deps.taskAssigner, worktreeManager: deps.worktreeManager,
    outputVerifier: deps.outputVerifier, isolationChecker: deps.isolationChecker,
    sseBus: deps.sseBus, claimQueue: deps.claimQueue,
  }));
  app.use('/api/agents', createAgentRoutes({ db: deps.db, instanceRegistry: deps.instanceRegistry, sseBus: deps.sseBus }));
  app.use('/api/system', createSystemRoutes({
    db: deps.db, instanceRegistry: deps.instanceRegistry, sseBus: deps.sseBus,
    config, startTime,
    ...(deps.heartbeatMonitor !== undefined ? { heartbeatMonitor: deps.heartbeatMonitor } : {}),
  }));
  app.use('/api/workflow', createWorkflowRoutes({ db: deps.db, taskAssigner: deps.taskAssigner, isolationChecker: deps.isolationChecker, worktreeManager: deps.worktreeManager }));
  app.use('/api/knowledge', createKnowledgeRoutes({}));
  app.use('/api/heartbeat', createHeartbeatRoutes({ db: deps.db, instanceRegistry: deps.instanceRegistry, taskAssigner: deps.taskAssigner, sseBus: deps.sseBus }));

  app.use(notFoundHandler());
  app.use(createErrorHandler(() => isShuttingDown));

  return {
    async start(): Promise<void> {
      if (httpServer !== null) { logger.warn({}, 'API server already running'); return; }
      return new Promise<void>((resolve) => {
        httpServer = app.listen(config.port, config.host, () => {
          logger.info({ host: config.host, port: config.port, version: VERSION }, 'KALLAX API server started');
          resolve();
        });
      });
    },
    async stop(): Promise<void> {
      if (httpServer === null) { logger.warn({}, 'API server not running'); return; }
      isShuttingDown = true;
      const serverToClose = httpServer;
      return new Promise<void>((resolve) => {
        const sseStats = deps.sseBus.getStats();
        logger.info({ sseClients: sseStats.clientCount }, 'closing SSE connections');
        serverToClose.close(() => {
          logger.info({}, 'API server stopped');
          httpServer = null; isShuttingDown = false; resolve();
        });
        setTimeout(() => {
          if (httpServer !== null) {
            logger.warn({}, 'API server force closing remaining connections');
            httpServer.closeAllConnections();
            httpServer = null; isShuttingDown = false; resolve();
          }
        }, 5000);
      });
    },
    getServer(): http.Server | null { return httpServer; },
    getConfig(): ServerConfig { return config; },
  };
}

export function registerApiServerCleanup(server: ApiServer): void {
  registerCleanupHandler('api-server', async () => { await server.stop(); });
}

import './server/standalone.js';

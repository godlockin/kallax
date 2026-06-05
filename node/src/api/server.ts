/**
 * KALLAX API Server
 * Express-based HTTP server with structured error responses and SSE support
 */

import express from 'express';
import type { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import * as http from 'node:http';
import * as path from 'node:path';
import * as fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { ok } from 'neverthrow';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';
import { registerCleanupHandler, setupProcessCleanup } from '../utils/process-cleanup.js';
import type { SQLiteManager } from '../core/sqlite/index.js';
import { createSQLiteManager } from '../core/sqlite/index.js';
import type { TaskAssigner } from '../core/task-assigner.js';
import { createTaskAssigner } from '../core/task-assigner.js';
import type { InstanceRegistry } from '../core/instance-registry.js';
import { createInstanceRegistry } from '../core/instance-registry.js';
import type { WorktreeManager } from '../core/worktree-manager.js';
import type { OutputVerifier } from '../core/output-verifier.js';
import { createOutputVerifier } from '../core/output-verifier.js';
import type { IsolationChecker } from '../core/isolation-checker.js';
import { getIsolationChecker } from '../core/isolation-checker.js';
import type { HeartbeatMonitor } from '../core/heartbeat-monitor.js';
import type { SSEBus, SSEClient } from '../core/sse-bus.js';
import { createSSEBus } from '../core/sse-bus.js';
import type { ClaimQueue } from '../core/claim-queue.js';
import { createClaimQueue } from '../core/claim-queue.js';
import { createAuthMiddleware } from './middleware/auth.js';
import { createRateLimiter } from './middleware/rate-limiter.js';
import { createTaskRoutes } from './routes/tasks.js';
import { createAgentRoutes } from './routes/agents.js';
import { createSystemRoutes } from './routes/system.js';
import { createWorkflowRoutes } from './routes/workflow.js';
import { createKnowledgeRoutes } from './routes/knowledge.js';
import { createHeartbeatRoutes } from './routes/heartbeat.js';
import {
  ServerConfigSchema,
  type ServerConfig,
  type HealthStatus,
  type SystemStats,
  createSuccessResponse,
  createErrorResponse,
  EndpointRole,
} from './types.js';


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

const VERSION = '1.0.0';

/**
 * Create and start the KALLAX API server
 */
export function createApiServer(
  configInput: Partial<ServerConfig>,
  deps: ApiServerDependencies
): ApiServer {
  // Validate config at startup (fail-fast)
  const configResult = ServerConfigSchema.safeParse(configInput);
  if (!configResult.success) {
    const message = configResult.error.errors
      .map((e) => `${e.path.join('.')}: ${e.message}`)
      .join('; ');
    throw new KallaxError(
      KallaxErrorCode.CONFIG_INVALID,
      `Invalid server configuration: ${message}`
    );
  }

  const config: ServerConfig = configResult.data;

  // HIGH-1: Warn if using default API key
  if (config.apiKey === 'kallax-dev-key') {
    logger.warn({}, 'Using default API key "kallax-dev-key". Set KALLAX_API_KEY env var for production.');
  }

  let httpServer: http.Server | null = null;
  let sseClientCounter = 0;
  const startTime = Date.now();
  let isShuttingDown = false;

  const app: Express = express();

  // ============================================================================
  // Middleware Stack
  // ============================================================================

  // Security headers
  app.use(helmet({
    contentSecurityPolicy: false, // Allow SSE connections
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  }));

  // CORS
  const isWildcardOrigin = config.corsOrigins.includes('*');
  app.use(cors({
    origin: isWildcardOrigin ? '*' : config.corsOrigins,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'X-KALLAX-API-Key', 'X-KALLAX-Role'],
    // credentials: true is illegal when origin is wildcard per CORS spec
    credentials: !isWildcardOrigin,
  }));

  // Body parsing
  app.use(express.json({ limit: config.bodyLimit }));

  // Request logging
  app.use((req: Request, _res: Response, next: NextFunction): void => {
    logger.debug(
      { method: req.method, path: req.path, ip: req.ip },
      'API request'
    );
    next();
  });

  // Rate limiting
  app.use(createRateLimiter());

  // Authentication
  app.use(createAuthMiddleware(config.apiKey));

  // ============================================================================
  // Health Check Endpoint (no auth required)
  // ============================================================================

  app.get('/health', (_req: Request, res: Response): void => {
    try {
      let dbConnected = false;
      try {
        deps.db.getStats();
        dbConnected = true;
      } catch {
        dbConnected = false;
      }

      const health: HealthStatus = {
        status: dbConnected ? 'healthy' : 'degraded',
        uptime: Date.now() - startTime,
        version: VERSION,
        dbConnected,
        timestamp: Date.now(),
      };

      res.json(createSuccessResponse(health));
    } catch (error: unknown) {
      const kallaxError = KallaxError.fromUnknown(error);
      res.status(503).json(createErrorResponse(kallaxError));
    }
  });

  // ============================================================================
  // Liveness Probe (no auth required) — returns 200 if process is alive
  // ============================================================================

  app.get('/live', (_req: Request, res: Response): void => {
    res.json(createSuccessResponse({
      status: 'alive',
      uptime: Date.now() - startTime,
      timestamp: Date.now(),
    }));
  });

  // ============================================================================
  // Readiness Probe (no auth required) — checks DB connectivity
  // ============================================================================

  app.get('/ready', (_req: Request, res: Response): void => {
    try {
      deps.db.getStats();
      res.json(createSuccessResponse({
        status: 'ready',
        uptime: Date.now() - startTime,
        timestamp: Date.now(),
      }));
    } catch (error: unknown) {
      const kallaxError = KallaxError.fromUnknown(error);
      res.status(503).json(createErrorResponse(kallaxError));
    }
  });

  // ============================================================================
  // Version Endpoint
  // ============================================================================

  app.get('/version', (_req: Request, res: Response): void => {
    res.json(createSuccessResponse({
      version: VERSION,
      name: '@kallax/node',
      started: startTime,
    }));
  });

  // ============================================================================
  // Stats Endpoint
  // ============================================================================

  app.get('/stats', (_req: Request, res: Response): void => {
    void (async () => {
      try {
        const dbStats = deps.db.getStats();

        // Count tasks by status
        const allTasksResult = deps.db.listTasks({ limit: 1000 });
        let pendingTasks = 0;
        let claimedTasks = 0;
        let completedTasks = 0;
        let failedTasks = 0;

        if (allTasksResult.isOk()) {
          for (const task of allTasksResult.value) {
            switch (task.status) {
              case 'pending': {
                pendingTasks++;
                break;
              }
              case 'claimed':
              case 'running': {
                claimedTasks++;
                break;
              }
              case 'completed': {
                completedTasks++;
                break;
              }
              case 'failed':
              case 'cancelled': {
                failedTasks++;
                break;
              }
              default: {
                break;
              }
            }
          }
        }

        // Count instances
        const allInstancesResult = deps.db.listInstances({ limit: 100 });

        let totalInstances = 0;
        let activeInstances = 0;
        let performerCount = 0;
        let conductorCount = 0;

        if (allInstancesResult.isOk()) {
          const instances = allInstancesResult.value;
          totalInstances = instances.length;
          activeInstances = instances.filter(
            (i) => i.status !== 'shutdown' && i.status !== 'error'
          ).length;

          for (const instance of instances) {
            if (instance.role === 'performer') performerCount++;
            if (instance.role === 'conductor') conductorCount++;
          }
        }

        const memoryUsage = process.memoryUsage();
        const memoryUsageMb = Math.round(
          (memoryUsage.heapUsed / 1024 / 1024) * 100
        ) / 100;

        const stats: SystemStats = {
          tasks: {
            total: dbStats.taskCount,
            pending: pendingTasks,
            claimed: claimedTasks,
            completed: completedTasks,
            failed: failedTasks,
          },
          instances: {
            total: totalInstances,
            active: activeInstances,
            performers: performerCount,
            conductors: conductorCount,
          },
          performance: {
            uptime: Date.now() - startTime,
            memoryUsageMb,
            cpus: 1,
          },
        };

        res.json(createSuccessResponse(stats));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // ============================================================================
  // SSE Endpoint: GET /events
  // ============================================================================

  app.get('/events', (req: Request, res: Response): void => {
    // Set SSE headers
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    });

    // Send initial connection event
    const clientId = `sse_${++sseClientCounter}_${Date.now()}`;
    res.write(`id: init\nevent: connected\ndata: ${JSON.stringify({ clientId })}\n\n`);

    // Create SSE client
    const sseClient: SSEClient = {
      id: clientId,
      send: (data: string) => {
        res.write(data);
      },
      close: () => {
        res.end();
      },
    };

    // Register with SSE bus
    deps.sseBus.addClient(sseClient);

    // Handle client disconnect
    req.on('close', () => {
      deps.sseBus.removeClient(clientId);
      logger.debug({ clientId }, 'SSE client disconnected');
    });

    // Keep-alive heartbeat every 30 seconds
    const keepAliveInterval = setInterval(() => {
      try {
        res.write(': keepalive\n\n');
      } catch {
        clearInterval(keepAliveInterval);
      }
    }, 30000);

    req.on('close', () => {
      clearInterval(keepAliveInterval);
    });

    logger.info({ clientId }, 'SSE client connected');
  });

  // ============================================================================
  // Mount Route Modules
  // ============================================================================

  app.use('/api/tasks', createTaskRoutes({
    db: deps.db,
    taskAssigner: deps.taskAssigner,
    worktreeManager: deps.worktreeManager,
    outputVerifier: deps.outputVerifier,
    isolationChecker: deps.isolationChecker,
    sseBus: deps.sseBus,
    claimQueue: deps.claimQueue,
  }));

  app.use('/api/agents', createAgentRoutes({
    db: deps.db,
    instanceRegistry: deps.instanceRegistry,
    sseBus: deps.sseBus,
  }));

  app.use('/api/system', createSystemRoutes({
    db: deps.db,
    instanceRegistry: deps.instanceRegistry,
    sseBus: deps.sseBus,
    config,
    startTime,
    ...(deps.heartbeatMonitor !== undefined ? { heartbeatMonitor: deps.heartbeatMonitor } : {}),
  }));

  app.use('/api/workflow', createWorkflowRoutes({
    db: deps.db,
    taskAssigner: deps.taskAssigner,
    isolationChecker: deps.isolationChecker,
    worktreeManager: deps.worktreeManager,
  }));

  app.use('/api/knowledge', createKnowledgeRoutes({}));

  app.use('/api/heartbeat', createHeartbeatRoutes({
    db: deps.db,
    instanceRegistry: deps.instanceRegistry,
    taskAssigner: deps.taskAssigner,
    sseBus: deps.sseBus,
  }));

  // ============================================================================
  // 404 Handler
  // ============================================================================

  app.use((_req: Request, res: Response): void => {
    res.status(404).json({
      success: false,
      error: {
        code: 'NOT_FOUND',
        message: 'Endpoint not found',
      },
      timestamp: Date.now(),
    });
  });

  // ============================================================================
  // Global Error Handler (never expose stack traces)
  // ============================================================================

  app.use((err: Error, _req: Request, res: Response, _next: NextFunction): void => {
    if (isShuttingDown) {
      res.status(503).json({
        success: false,
        error: {
          code: 'SHUTTING_DOWN',
          message: 'Server is shutting down',
        },
        timestamp: Date.now(),
      });
      return;
    }

    const kallaxError = err instanceof KallaxError
      ? err
      : KallaxError.fromUnknown(err);

    logger.error(
      { errorCode: kallaxError.code, errorMessage: kallaxError.message },
      'unhandled error'
    );

    res.status(500).json({
      success: false,
      error: {
        code: kallaxError.code,
        message: 'Internal server error',
      },
      timestamp: Date.now(),
    });
  });

  // ============================================================================
  // Server Lifecycle
  // ============================================================================

  return {
    async start(): Promise<void> {
      if (httpServer !== null) {
        logger.warn({}, 'API server already running');
        return;
      }

      return new Promise<void>((resolve) => {
        httpServer = app.listen(config.port, config.host, () => {
          logger.info(
            { host: config.host, port: config.port, version: VERSION },
            'KALLAX API server started'
          );
          resolve();
        });
      });
    },

    async stop(): Promise<void> {
      if (httpServer === null) {
        logger.warn({}, 'API server not running');
        return;
      }

      isShuttingDown = true;
      const serverToClose = httpServer;

      return new Promise<void>((resolve) => {
        // Close all SSE connections
        const sseStats = deps.sseBus.getStats();
        logger.info({ sseClients: sseStats.clientCount }, 'closing SSE connections');

        // Close HTTP server — stop accepting new connections, drain existing
        serverToClose.close(() => {
          logger.info({}, 'API server stopped');
          httpServer = null;
          isShuttingDown = false;
          resolve();
        });

        // Force close remaining connections after 5 seconds
        setTimeout(() => {
          if (httpServer !== null) {
            logger.warn({}, 'API server force closing remaining connections');
            httpServer.closeAllConnections();
            httpServer = null;
            isShuttingDown = false;
            resolve();
          }
        }, 5000);
      });
    },

    getServer(): http.Server | null {
      return httpServer;
    },

    getConfig(): ServerConfig {
      return config;
    },
  };
}

/**
 * Register the API server for graceful cleanup
 */
export function registerApiServerCleanup(server: ApiServer): void {
  registerCleanupHandler('api-server', async () => {
    await server.stop();
  });
}

// ============================================================================
// Self-execution — allows `npx tsx src/api/server.ts` or `node dist/api/server.js`
// ============================================================================

const __filename = fileURLToPath(import.meta.url);
if (process.argv[1] !== undefined && (process.argv[1] === __filename || process.argv[1].endsWith('/server.ts') || process.argv[1].endsWith('/server.js'))) {
  const serverPort = parseInt(process.env['KALLAX_API_PORT'] ?? '9877', 10);
  const serverHost = process.env['KALLAX_API_HOST'] ?? '127.0.0.1';
  const apiKey = process.env['KALLAX_API_KEY'] ?? 'kallax-dev-key';
  const dbPath = process.env['KALLAX_DB_PATH'] ?? '.kallax/data/kallax.db';

  // Ensure DB directory exists
  const dbDir = path.dirname(dbPath);
  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }

  const dbResult = createSQLiteManager({ path: dbPath });
  if (dbResult.isErr()) {
    logger.fatal({ error: dbResult.error.message }, 'failed to initialize database');
    process.exit(1);
  }
  const db = dbResult.value;

  const isolationChecker = getIsolationChecker();
  const instanceRegistry = createInstanceRegistry(db);
  const sseBus = createSSEBus();
  const taskAssigner = createTaskAssigner(db, isolationChecker, instanceRegistry);
  const outputVerifier = createOutputVerifier({
    projectRoot: process.cwd(),
    testCommand: 'echo ok',
    lintCommand: 'echo ok',
  });
  const mockWorktreeManager: WorktreeManager = {
    create: async () => ok({ path: '/tmp/wt', branch: 'kallax/t', commit: 'abc', taskId: 't' }),
    remove: async () => ok(undefined),
    list: async () => ok([]),
    getByTaskId: async () => ok(null),
    validateIsolation: async () => ok(true),
    getPath: () => '/tmp/wt',
  } as unknown as WorktreeManager;

  const server = createApiServer(
    { port: serverPort, host: serverHost, apiKey },
    {
      db,
      taskAssigner,
      instanceRegistry,
      worktreeManager: mockWorktreeManager,
      outputVerifier,
      isolationChecker,
      sseBus,
    },
  );

  // Install process signal handlers for graceful shutdown (standalone mode)
  setupProcessCleanup();
  registerApiServerCleanup(server);

  server.start().catch((err: unknown) => {
    logger.fatal({ error: err instanceof Error ? err.message : String(err) }, 'failed to start API server');
    process.exit(1);
  });
}

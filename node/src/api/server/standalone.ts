import * as path from 'node:path';
import * as fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { logger } from '../../utils/logger.js';
import { setupProcessCleanup } from '../../utils/process-cleanup.js';
import { createSQLiteManager } from '../../core/sqlite/index.js';
import { createTaskAssigner } from '../../core/task-assigner.js';
import { createInstanceRegistry } from '../../core/instance-registry.js';
import { createOutputVerifier } from '../../core/output-verifier.js';
import { ExpertResolverBridge } from '../../core/expert-resolver-bridge.js';
import { getIsolationChecker } from '../../core/isolation-checker.js';
import { createSSEBus } from '../../core/sse-bus.js';
import { createExpertInvocationsQueue } from '../../core/expert-invocations-queue/index.js';
import { createTraceLog } from '../../core/span-tracer.js';
import { createWorktreeManager } from '../../core/worktree-manager.js';
import { createApiServer, registerApiServerCleanup } from '../server.js';

const __filename = fileURLToPath(import.meta.url);
if (process.argv[1] !== undefined && (process.argv[1] === __filename || process.argv[1].endsWith('/server.ts') || process.argv[1].endsWith('/server.js'))) {
  const serverPort = parseInt(process.env['KALLAX_API_PORT'] ?? '9877', 10);
  const serverHost = process.env['KALLAX_API_HOST'] ?? '127.0.0.1';
  const apiKey = process.env['KALLAX_API_KEY'];
  if (apiKey === undefined) {
    logger.fatal({}, 'KALLAX_API_KEY required (set env var, e.g. export KALLAX_API_KEY=$(openssl rand -hex 32))');
    process.exit(1);
  }
  const dbPath = process.env['KALLAX_DB_PATH'] ?? '.kallax/data/kallax.db';
  const dbDir = path.dirname(dbPath);
  if (!fs.existsSync(dbDir)) { fs.mkdirSync(dbDir, { recursive: true }); }
  const dbResult = createSQLiteManager({ path: dbPath });
  if (dbResult.isErr()) { logger.fatal({ error: dbResult.error.message }, 'failed to initialize database'); process.exit(1); }
  const db = dbResult.value;
  const isolationChecker = getIsolationChecker();
  const instanceRegistry = createInstanceRegistry(db);
  const sseBus = createSSEBus();
  const projectRoot = process.env['KALLAX_PROJECT_ROOT']
    ?? path.resolve(path.dirname(__filename), '../../../..');
  const expertResolver = new ExpertResolverBridge({ repoRoot: projectRoot });
  const taskAssigner = createTaskAssigner(
    db,
    isolationChecker,
    instanceRegistry,
    expertResolver,
    projectRoot,
  );
  const outputVerifier = createOutputVerifier({ projectRoot, testCommand: 'echo ok', lintCommand: 'echo ok' });
  // EPIC-277-D AC4: replace mockWorktreeManager with real WorktreeManager.
  // KALLAX_WORKTREE_BASE_PATH env override lets tests pin a sandbox base;
  // default keeps previous .kallax/worktrees layout for prod.
  const worktreeBasePath = process.env['KALLAX_WORKTREE_BASE_PATH'] ?? '.kallax/worktrees';
  const wmResult = createWorktreeManager({ projectRoot, worktreeBasePath });
  if (wmResult.isErr()) {
    logger.fatal({ error: wmResult.error.message }, 'failed to initialize worktree manager');
    process.exit(1);
  }
  const worktreeManager = wmResult.value;
  const expertInvocationsQueue = createExpertInvocationsQueue();
  const traceLog = createTraceLog(db.traceOps);
  const server = createApiServer(
    { port: serverPort, host: serverHost, apiKey },
    {
      db, taskAssigner, instanceRegistry, worktreeManager,
      outputVerifier, isolationChecker, sseBus,
      expertResolver, expertInvocationsQueue, traceLog,
    },
  );
  setupProcessCleanup();
  registerApiServerCleanup(server);
  server.start().catch((err: unknown) => { logger.fatal({ error: err instanceof Error ? err.message : String(err) }, 'failed to start API server'); process.exit(1); });
}
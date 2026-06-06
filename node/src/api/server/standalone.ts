import * as path from 'node:path';
import * as fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { ok } from 'neverthrow';
import { logger } from '../../utils/logger.js';
import { setupProcessCleanup } from '../../utils/process-cleanup.js';
import { createSQLiteManager } from '../../core/sqlite/index.js';
import { createTaskAssigner } from '../../core/task-assigner.js';
import { createInstanceRegistry } from '../../core/instance-registry.js';
import { createOutputVerifier } from '../../core/output-verifier.js';
import { getIsolationChecker } from '../../core/isolation-checker.js';
import { createSSEBus } from '../../core/sse-bus.js';
import type { WorktreeManager } from '../../core/worktree-manager.js';
import { createApiServer, registerApiServerCleanup } from '../server.js';

const __filename = fileURLToPath(import.meta.url);
if (process.argv[1] !== undefined && (process.argv[1] === __filename || process.argv[1].endsWith('/server.ts') || process.argv[1].endsWith('/server.js'))) {
  const serverPort = parseInt(process.env['KALLAX_API_PORT'] ?? '9877', 10);
  const serverHost = process.env['KALLAX_API_HOST'] ?? '127.0.0.1';
  const apiKey = process.env['KALLAX_API_KEY'] ?? 'kallax-dev-key';
  const dbPath = process.env['KALLAX_DB_PATH'] ?? '.kallax/data/kallax.db';
  const dbDir = path.dirname(dbPath);
  if (!fs.existsSync(dbDir)) { fs.mkdirSync(dbDir, { recursive: true }); }
  const dbResult = createSQLiteManager({ path: dbPath });
  if (dbResult.isErr()) { logger.fatal({ error: dbResult.error.message }, 'failed to initialize database'); process.exit(1); }
  const db = dbResult.value;
  const isolationChecker = getIsolationChecker();
  const instanceRegistry = createInstanceRegistry(db);
  const sseBus = createSSEBus();
  const taskAssigner = createTaskAssigner(db, isolationChecker, instanceRegistry);
  const outputVerifier = createOutputVerifier({ projectRoot: process.cwd(), testCommand: 'echo ok', lintCommand: 'echo ok' });
  const mockWorktreeManager: WorktreeManager = {
    create: async () => ok({ path: '/tmp/wt', branch: 'kallax/t', commit: 'abc', taskId: 't' }),
    remove: async () => ok(undefined), list: async () => ok([]), getByTaskId: async () => ok(null),
    validateIsolation: async () => ok(true), getPath: () => '/tmp/wt',
  } as unknown as WorktreeManager;
  const server = createApiServer({ port: serverPort, host: serverHost, apiKey }, { db, taskAssigner, instanceRegistry, worktreeManager: mockWorktreeManager, outputVerifier, isolationChecker, sseBus });
  setupProcessCleanup();
  registerApiServerCleanup(server);
  server.start().catch((err: unknown) => { logger.fatal({ error: err instanceof Error ? err.message : String(err) }, 'failed to start API server'); process.exit(1); });
}

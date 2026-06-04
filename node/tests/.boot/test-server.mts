import { createSQLiteManager } from '../../src/core/sqlite/index.js';
import { createApiServer } from '../../src/api/server.js';
import { createTaskAssigner } from '../../src/core/task-assigner.js';
import { createInstanceRegistry } from '../../src/core/instance-registry.js';
import { createIsolationChecker } from '../../src/core/isolation-checker.js';
import { createSSEBus } from '../../src/core/sse-bus.js';
import { createOutputVerifier } from '../../src/core/output-verifier.js';
import { ok } from 'neverthrow';
(async () => {
const _dbR = createSQLiteManager({ path: '/tmp/kallax-test-server2.db' });
if (_dbR.isErr()) { console.error('DB FAIL:', _dbR.error.message); process.exit(1); }
const _db = _dbR.value;
const _isolation = createIsolationChecker();
const _registry = createInstanceRegistry(_db);
const _sseBus = createSSEBus();
const _assigner = createTaskAssigner(_db, _isolation, _registry);
const _ov = createOutputVerifier({ projectRoot: process.cwd(), testCommand: 'echo ok' });
const _wt = {
  create: async () => ok({ path: '/tmp/wt', branch: 'b', commit: 'c', taskId: 't' }),
  remove: async () => ok(undefined),
  list: async () => ok([]),
  getByTaskId: async () => ok(null),
  validateIsolation: async () => ok(true),
  getPath: () => '/tmp/wt',
};
const _server = createApiServer(
  { port: 28991, host: '127.0.0.1', apiKey: 'kallax-dev-key' },
  { db: _db, taskAssigner: _assigner, instanceRegistry: _registry, worktreeManager: _wt, outputVerifier: _ov, isolationChecker: _isolation, sseBus: _sseBus },
);
await _server.start();
console.log('KALLAX_READY');
process.on('SIGTERM', async () => { await _server.stop(); _db.close(); process.exit(0); });
process.on('SIGINT', async () => { await _server.stop(); _db.close(); process.exit(0); });
})();

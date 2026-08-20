/**
 * KALLAX CLI Entry Point
 */
import { Command } from 'commander';
import { logger } from './utils/logger.js';
import { setupProcessCleanup } from './utils/process-cleanup.js';
import { createSQLiteManager } from './core/sqlite/index.js';
import { createWorktreeManager } from './core/worktree-manager.js';
import { createOutputVerifier } from './core/output-verifier.js';
import { getIsolationChecker } from './core/isolation-checker.js';
import { createInstanceRegistry } from './core/instance-registry.js';
import { createTaskAssigner } from './core/task-assigner.js';
import { ExpertResolverBridge } from './core/expert-resolver-bridge.js';
import { getGitService } from './core/git-service.js';
import { validateStartup } from './utils/startup-validator.js';
import { KallaxError, KallaxErrorCode } from './types/index.js';
import * as fs from 'node:fs';
import * as path from 'node:path';
export * from './types/index.js';
export * from './core/index.js';
export * from './commands/index.js';
export * from './utils/index.js';
import { registerKnowledgeCommands } from './commands/knowledge-cmd.js';
import { registerDegradationCommands } from './commands/degradation-cmd.js';
import { registerDocCommands } from './commands/doc-cmd.js';
import { registerDbCommands } from './commands/db-cmd.js';
import { registerTaskCommands } from './commands/task-cmd.js';
import { registerConductorCommands } from './commands/conductor-cmd.js';
import { registerPerformerCommands } from './commands/performer-cmd.js';
import { registerIsolationCommands } from './commands/isolation-cmd.js';
import { registerVerifyCommands } from './commands/verify-cmd.js';
import { registerSystemCommands } from './commands/system-cmd.js';
import { registerStartCommands } from './commands/start-cmd.js';
import { registerEpicCommands } from './commands/epic-cmd.js';
import { registerBranchCommands } from './commands/branch-cmd.js';
import { registerInitCommands } from './commands/init.js';
import { registerInstallCommands } from './commands/install-cmd.js';

import { registerRouteCommands } from './commands/route-cmd.js';
import { registerRoleCommands } from './commands/role-cmd.js';
import { registerLoadCommands } from './commands/load-cmd.js';
import type { AppContext } from './cli-context.js';
function findProjectRoot(): string {
  let dir = process.cwd();
  while (dir !== '/') {
    if (fs.existsSync(`${dir}/.git`) || fs.existsSync(`${dir}/.kallax/IDENTITY.md`)) return dir;
    dir = path.dirname(dir);
  }
  return process.cwd();
}

function bootstrap(): Promise<AppContext> {
  const projectRoot = findProjectRoot();
  return (async (): Promise<AppContext> => {
    const validation = await validateStartup(projectRoot);
    if (validation.isErr()) { logger.fatal({ error: validation.error }, 'startup validation failed'); process.exit(1); }
    const dbResult = createSQLiteManager({ path: '.kallax/data/kallax.db' });
    if (dbResult.isErr()) { logger.fatal({ error: dbResult.error }, 'failed to initialize database'); process.exit(1); }
    const wmResult = createWorktreeManager({ projectRoot, worktreeBasePath: '.kallax/worktrees' });
    if (wmResult.isErr()) { logger.fatal({ error: wmResult.error }, 'failed to initialize worktree manager'); process.exit(1); }
    const db = dbResult.value;
    const worktreeManager = wmResult.value;
    const outputVerifier = createOutputVerifier({ projectRoot });
    const isolationChecker = getIsolationChecker();
    const instanceRegistry = createInstanceRegistry(db);
    const expertResolver = new ExpertResolverBridge({ repoRoot: projectRoot });
    const taskAssigner = createTaskAssigner(
      db,
      isolationChecker,
      instanceRegistry,
      expertResolver,
      projectRoot,
    );
    const gitService = getGitService();
    return { db, worktreeManager, outputVerifier, isolationChecker, instanceRegistry, taskAssigner, gitService };
  })();
}

setupProcessCleanup();
void (async (): Promise<void> => {
  const ctx = await bootstrap();
  const program = new Command();
  program.name('kallax').description('KALLAX — Knowledge-Augmented Leveraged Learning Agent eXecutor').version('1.0.0');
  registerKnowledgeCommands(program, ctx);
  registerDegradationCommands(program, ctx);
  registerDocCommands(program, ctx);
  registerDbCommands(program, ctx);
  registerTaskCommands(program, ctx);
  registerConductorCommands(program, ctx);
  registerPerformerCommands(program, ctx);
  registerIsolationCommands(program, ctx);
  registerVerifyCommands(program, ctx);
  registerSystemCommands(program, ctx);
  registerStartCommands(program, ctx);
  registerEpicCommands(program, ctx);
  registerBranchCommands(program);
  registerRouteCommands(program);
  registerInitCommands(program);
  registerInstallCommands(program);
  registerLoadCommands(program, ctx);
  registerRoleCommands(program, ctx);

  program.parseAsync(process.argv).catch((error: unknown) => {
    logger.kallaxError(KallaxError.fromUnknown(error, KallaxErrorCode.INTERNAL_ERROR));
    process.exit(1);
  });
})();

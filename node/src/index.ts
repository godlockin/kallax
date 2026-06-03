/**
 * KALLAX CLI Entry Point
 */
import { Command } from 'commander';
import { logger } from './utils/logger.js';
import { setupProcessCleanup } from './utils/process-cleanup.js';
import { createSQLiteManager } from './core/sqlite-manager.js';
import { createWorktreeManager } from './core/worktree-manager.js';
import { createOutputVerifier } from './core/output-verifier.js';
import { getIsolationChecker } from './core/isolation-checker.js';
import { createInstanceRegistry } from './core/instance-registry.js';
import { createTaskAssigner } from './core/task-assigner.js';
import { getGitService } from './core/git-service.js';
import { validateStartup } from './utils/startup-validator.js';
<<<<<<< HEAD
import { KallaxError, KallaxErrorCode } from './types/index.js';
||||||| 0834c04
import { KallaxError, KallaxErrorCode, TaskStatus, TaskType } from './types/index.js';
import * as fs from 'node:fs';

// Commands
import { executeClaimCommand } from './commands/claim.js';
import { executeCompleteCommand } from './commands/complete.js';
import { executeConductorHeartbeat, executeConductorPoll } from './commands/conductor.js';
import { executeIsolationCheck } from './commands/isolation-check.js';
import {
  executePerformerRegister,
  executePerformerPoll,
  executePerformerStatus,
} from './commands/performer.js';
import {
  executeTaskCreate,
  executeTaskStatus,
  executeTaskProgress,
  executeTaskResume,
} from './commands/task.js';
import { executeVerifyOutput } from './commands/verify-output.js';
import { executeSystemDoctor, executeTeamStatus } from './commands/system.js';
import { analyzeComplexity, calculateDependencyDepth, countCrossModules } from './core/complexity-analyzer.js';
import { generateDagYaml, topologicalSort } from './core/dag-generator.js';
import { createDagExecutor } from './core/dag-executor.js';
import { renderDagTree, renderDagSummary } from './core/dag-visualizer.js';

// Re-export types and core modules
=======
import { KallaxError, KallaxErrorCode } from './types/index.js';
import * as fs from 'node:fs';
import * as path from 'node:path';
>>>>>>> worktree-kallax-refactor-complete
export * from './types/index.js';
export * from './core/index.js';
export * from './commands/index.js';
export * from './utils/index.js';
<<<<<<< HEAD
import { registerTicketCommands } from './commands/ticket-cmd.js';
import { registerKnowledgeCommands } from './commands/knowledge-cmd.js';
import { registerDegradationCommands } from './commands/degradation-cmd.js';
import { registerSubmitCommands } from './commands/submit-cmd.js';
import { registerDependencyCommands } from './commands/dependency-cmd.js';
import { registerAlertsCommands } from './commands/alerts-cmd.js';
import { registerExpertCommands } from './commands/expert-cmd.js';
import { registerDocCommands } from './commands/doc-cmd.js';
import { registerSpikeCommands } from './commands/spike-cmd.js';
import { registerDbCommands } from './commands/db-cmd.js';
import { registerMemoryCommands } from './commands/memory-cmd.js';
import { registerTaskCommands } from './commands/task-cmd.js';
import { registerConductorCommands } from './commands/conductor-cmd.js';
import { registerPerformerCommands } from './commands/performer-cmd.js';
import { registerIsolationCommands } from './commands/isolation-cmd.js';
import { registerVerifyCommands } from './commands/verify-cmd.js';
import { registerSystemCommands } from './commands/system-cmd.js';
import { registerStartCommands } from './commands/start-cmd.js';
import { registerEpicCommands } from './commands/epic-cmd.js';
||||||| 0834c04

// ---------------------------------------------------------------------------
// Bootstrap — fail-fast: validate at startup, not at 2 AM
// ---------------------------------------------------------------------------
=======
import { registerTicketCommands } from './commands/ticket-cmd.js';
import { registerKnowledgeCommands } from './commands/knowledge-cmd.js';
import { registerDegradationCommands } from './commands/degradation-cmd.js';
import { registerSubmitCommands } from './commands/submit-cmd.js';
import { registerDependencyCommands } from './commands/dependency-cmd.js';
import { registerAlertsCommands } from './commands/alerts-cmd.js';
import { registerExpertCommands } from './commands/expert-cmd.js';
import { registerDocCommands } from './commands/doc-cmd.js';
import { registerSpikeCommands } from './commands/spike-cmd.js';
import { registerDbCommands } from './commands/db-cmd.js';
import { registerMemoryCommands } from './commands/memory-cmd.js';
import { registerTaskCommands } from './commands/task-cmd.js';
import { registerConductorCommands } from './commands/conductor-cmd.js';
import { registerPerformerCommands } from './commands/performer-cmd.js';
import { registerIsolationCommands } from './commands/isolation-cmd.js';
import { registerVerifyCommands } from './commands/verify-cmd.js';
import { registerSystemCommands } from './commands/system-cmd.js';
import { registerStartCommands } from './commands/start-cmd.js';
import { registerEpicCommands } from './commands/epic-cmd.js';

function findProjectRoot(): string {
  let dir = process.cwd();
  while (dir !== '/') {
    if (fs.existsSync(`${dir}/.git`) || fs.existsSync(`${dir}/.kallax/IDENTITY.md`)) return dir;
    dir = path.dirname(dir);
  }
  return process.cwd();
}
>>>>>>> worktree-kallax-refactor-complete

function bootstrap() {
<<<<<<< HEAD
  const projectRoot = process.cwd();
||||||| 0834c04
  const projectRoot = process.cwd();

  // Fail-fast: validate environment before anything else
=======
  const projectRoot = findProjectRoot();
>>>>>>> worktree-kallax-refactor-complete
  const validation = validateStartup(projectRoot);
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
  const taskAssigner = createTaskAssigner(db, isolationChecker, instanceRegistry);
  const gitService = getGitService();
  return { db, worktreeManager, outputVerifier, isolationChecker, instanceRegistry, taskAssigner, gitService };
}

setupProcessCleanup();
const ctx = bootstrap();
const program = new Command();
program.name('kallax').description('KALLAX — Knowledge-Augmented Leveraged Learning Agent eXecutor').version('1.0.0');
registerTicketCommands(program, ctx);
registerKnowledgeCommands(program, ctx);
registerDegradationCommands(program, ctx);
registerSubmitCommands(program, ctx);
registerDependencyCommands(program, ctx);
registerAlertsCommands(program, ctx);
registerExpertCommands(program, ctx);
registerDocCommands(program, ctx);
registerSpikeCommands(program, ctx);
registerDbCommands(program, ctx);
registerMemoryCommands(program, ctx);
registerTaskCommands(program, ctx);
registerConductorCommands(program, ctx);
registerPerformerCommands(program, ctx);
registerIsolationCommands(program, ctx);
registerVerifyCommands(program, ctx);
registerSystemCommands(program, ctx);
registerStartCommands(program, ctx);
registerEpicCommands(program, ctx);

program.parseAsync(process.argv).catch((error: unknown) => {
  logger.kallaxError(KallaxError.fromUnknown(error, KallaxErrorCode.INTERNAL_ERROR));
  process.exit(1);
});

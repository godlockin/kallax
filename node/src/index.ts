/**
 * KALLAX CLI Entry Point
 * ESM module with strict TypeScript — zero `any`, zero `@ts-ignore`
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
import { createRoleSelector } from './core/role-selector.js';
import { getGitService } from './core/git-service.js';
import { validateStartup } from './utils/startup-validator.js';
import { KallaxError, KallaxErrorCode, TaskStatus, TaskType } from './types/index.js';

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

// Re-export types and core modules
export * from './types/index.js';
export * from './core/index.js';
export * from './commands/index.js';
export * from './utils/index.js';

// ---------------------------------------------------------------------------
// Bootstrap — fail-fast: validate at startup, not at 2 AM
// ---------------------------------------------------------------------------

function bootstrap() {
  const projectRoot = process.cwd();

  // Fail-fast: validate environment before anything else
  const validation = validateStartup(projectRoot);
  if (validation.isErr()) {
    logger.fatal({ error: validation.error }, 'startup validation failed');
    process.exit(1);
  }

  const dbResult = createSQLiteManager({ path: '.kallax/data/kallax.db' });
  if (dbResult.isErr()) {
    logger.fatal({ error: dbResult.error }, 'failed to initialize database');
    process.exit(1);
  }

  const wmResult = createWorktreeManager({
    projectRoot,
    worktreeBasePath: '.kallax/worktrees',
  });
  if (wmResult.isErr()) {
    logger.fatal({ error: wmResult.error }, 'failed to initialize worktree manager');
    process.exit(1);
  }

  const db = dbResult.value;
  const worktreeManager = wmResult.value;
  const outputVerifier = createOutputVerifier({ projectRoot });
  const isolationChecker = getIsolationChecker();
  const instanceRegistry = createInstanceRegistry(db);
  const taskAssigner = createTaskAssigner(db, isolationChecker, instanceRegistry);
  const gitService = getGitService();

  return { db, worktreeManager, outputVerifier, isolationChecker, instanceRegistry, taskAssigner, gitService };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

setupProcessCleanup();

const ctx = bootstrap();
const program = new Command();

program
  .name('kallax')
  .description('KALLAX — Knowledge-Augmented Leveraged Learning Agent eXecutor')
  .version('1.0.0');

// ── Ticket commands ──────────────────────────────────────────────────────

const ticketCmd = program.command('ticket').description('Ticket management');

ticketCmd
  .command('create <title>')
  .description('Create a new ticket')
  .option('-d, --description <desc>', 'Ticket description', '')
  .option('-p, --priority <priority>', 'Priority (P0/P1/P2/P3)', 'P2')
  .option('-s, --scope <files>', 'File scope (comma-separated)', '')
  .action((title: string, opts?: { description?: string; priority?: string; scope?: string }) => {
    try {
      const now = Date.now();
      const id = `TICKET-${now.toString(36).toUpperCase()}`;
      const ticket = {
        id,
        title,
        description: opts?.['description'] ?? '',
        status: 'todo' as const,
        priority: (opts?.['priority'] ?? 'P2') as 'P0' | 'P1' | 'P2' | 'P3',
        assigneeId: null,
        createdAt: now,
        updatedAt: now,
        acceptanceCriteria: [],
        labels: [],
        fileScope: opts?.['scope'] ? opts['scope'].split(',').map((s: string) => s.trim()) : undefined,
      };
      const result = ctx.db.createTicket(ticket);
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify({ id, title, status: 'created' }) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Task commands ──────────────────────────────────────────────────────────

const task = program.command('task').description('Task management');

task
  .command('claim [taskId]')
  .description('Claim a task — auto-creates isolated worktree')
  .option('-t, --ticket <ticketId>', 'Claim task for specific ticket')
  .action(async (taskId?: string, opts?: { ticket?: string }) => {
    try {
      const result = await executeClaimCommand(
        ctx.db, ctx.worktreeManager, ctx.instanceRegistry, ctx.taskAssigner,
        { taskId, ticketId: opts?.['ticket'] },
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info({ taskId: result.value.task.id, worktree: result.value.worktreePath }, 'task claimed');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

task
  .command('complete <taskId>')
  .description('Complete a task — Saga 5-step atomic completion')
  .option('--skip-tests', 'Skip test verification')
  .option('--skip-lint', 'Skip lint verification')
  .option('-l, --level <level>', 'Verification level (1-4)', '4')
  .action(async (taskId: string, opts?: { skipTests?: boolean; skipLint?: boolean; level?: string }) => {
    try {
      const result = await executeCompleteCommand(
        ctx.db, ctx.worktreeManager, ctx.outputVerifier,
        ctx.instanceRegistry, ctx.taskAssigner, ctx.gitService,
        {
          taskId,
          skipTests: opts?.['skipTests'],
          skipLint: opts?.['skipLint'],
          verificationLevel: (parseInt(opts?.['level'] ?? '4', 10) as 1 | 2 | 3 | 4),
        },
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info(
        { taskId, commitHash: result.value.commitHash, prNumber: result.value.prNumber },
        'task completed',
      );
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

task
  .command('create <ticketId>')
  .description('Create a new task for a ticket')
  .option('-t, --type <type>', 'Task type (development, review, testing)', 'development')
  .action(async (ticketId: string, opts?: { type?: string }) => {
    try {
      const result = executeTaskCreate(ctx.db, ctx.taskAssigner, {
        ticketId,
        type: opts?.['type'] as TaskType | undefined,
      });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info({ taskId: result.value.task.id, ticketId }, 'task created');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

task
  .command('status [taskId]')
  .description('Show task status')
  .option('-t, --ticket <ticketId>', 'Filter by ticket')
  .option('-p, --performer <performerId>', 'Filter by performer')
  .option('-s, --status <status>', 'Filter by status')
  .action(async (taskId?: string, opts?: Record<string, string>) => {
    try {
      const result = executeTaskStatus(ctx.db, {
        taskId,
        ticketId: opts?.['ticket'],
        performerId: opts?.['performer'],
        statusFilter: opts?.['status'] as TaskStatus | undefined,
      });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify(result.value, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

task
  .command('progress <taskId> <progress>')
  .description('Update task progress (0-100)')
  .option('-m, --message <message>', 'Progress message')
  .action(async (taskId: string, progress: string, opts?: { message?: string }) => {
    try {
      const result = executeTaskProgress(ctx.db, {
        taskId,
        progress: parseInt(progress, 10),
        message: opts?.['message'],
      });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info({ taskId, progress }, 'task progress updated');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

task
  .command('resume <taskId>')
  .description('Resume a failed or cancelled task')
  .action(async (taskId: string) => {
    try {
      const result = await executeTaskResume(ctx.db, ctx.taskAssigner, { taskId });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info({ taskId }, 'task resumed');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Conductor commands ─────────────────────────────────────────────────────

const conductor = program.command('conductor').description('Conductor (orchestrator) commands');

conductor
  .command('heartbeat')
  .description('Run conductor heartbeat — 5-question health check')
  .action(async () => {
    try {
      const result = await executeConductorHeartbeat(
        ctx.db, ctx.instanceRegistry, ctx.taskAssigner, ctx.isolationChecker, {},
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      const hr = result.value;
      process.stdout.write(JSON.stringify({
        q1_priority: hr.q1_priority,
        q2_performers: hr.q2_performers,
        q3_progress: hr.q3_progress,
        q4_blocked: hr.q4_blocked,
        q5_messages: hr.q5_messages,
      }, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

conductor
  .command('poll')
  .description('Poll for task assignments')
  .option('-a, --auto-assign', 'Automatically assign tasks to performers')
  .option('-m, --max <count>', 'Maximum assignments per poll', '5')
  .action(async (opts?: { autoAssign?: boolean; max?: string }) => {
    try {
      const result = await executeConductorPoll(
        ctx.db, ctx.instanceRegistry, ctx.taskAssigner, ctx.isolationChecker,
        {
          autoAssign: opts?.['autoAssign'],
          maxAssignments: parseInt(opts?.['max'] ?? '5', 10),
        },
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify(result.value, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Performer commands ─────────────────────────────────────────────────────

const performer = program.command('performer').description('Performer (executor) commands');

performer
  .command('register')
  .description('Register as a performer')
  .option('-n, --name <name>', 'Performer name')
  .option('-c, --capabilities <caps>', 'Comma-separated capabilities')
  .action(async (opts?: { name?: string; capabilities?: string }) => {
    try {
      const caps = opts?.['capabilities']?.split(',').map((c) => c.trim()) ?? [];
      const result = await executePerformerRegister(ctx.instanceRegistry, {
        name: opts?.['name'],
        capabilities: caps,
      });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info(
        { instanceId: result.value.instance.id, role: result.value.instance.role },
        'performer registered',
      );
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

performer
  .command('poll')
  .description('Poll for available tasks')
  .option('-a, --auto-claim', 'Automatically claim first available task')
  .action(async (opts?: { autoClaim?: boolean }) => {
    try {
      const result = await executePerformerPoll(
        ctx.db, ctx.instanceRegistry, ctx.taskAssigner, ctx.worktreeManager,
        { autoClaim: opts?.['autoClaim'] },
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify(result.value, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

performer
  .command('status')
  .description('Get performer status')
  .action(async () => {
    try {
      const result = await executePerformerStatus(ctx.db, ctx.instanceRegistry, ctx.worktreeManager);
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify(result.value, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Isolation command ──────────────────────────────────────────────────────

program
  .command('isolation:check <taskIdA> [taskIdB]')
  .description('Check file-scope overlap between tasks')
  .option('-f, --files <files>', 'Comma-separated file paths')
  .action(async (taskIdA: string, taskIdB?: string, opts?: { files?: string }) => {
    try {
      const files = opts?.['files']?.split(',').map((f) => f.trim()) ?? [];
      const result = executeIsolationCheck(ctx.isolationChecker, ctx.db, {
        taskIdA,
        taskIdB,
        files: files.length > 0 ? files : undefined,
      });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      const r = result.value;
      process.stdout.write(JSON.stringify({
        hasConflicts: r.hasConflicts,
        conflicts: r.conflicts,
        recommendations: r.recommendations,
      }, null, 2) + '\n');
      process.exit(r.hasConflicts ? 1 : 0);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Verify command ─────────────────────────────────────────────────────────

program
  .command('verify:output <taskId>')
  .description('Verify task output — Fact-Forcing 4-Level check')
  .option('-l, --level <level>', 'Verification level (1-4)', '4')
  .option('-v, --verbose', 'Show detailed evidence')
  .action(async (taskId: string, opts?: { level?: string; verbose?: boolean }) => {
    try {
      const level = (parseInt(opts?.['level'] ?? '4', 10) as 1 | 2 | 3 | 4);
      const result = await executeVerifyOutput(
        ctx.db, ctx.worktreeManager, ctx.outputVerifier,
        { taskId, level, verbose: opts?.['verbose'] },
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify({
        verification: result.value.verification,
        summary: result.value.summary,
        recommendations: result.value.recommendations,
      }, null, 2) + '\n');
      process.exit(result.value.verification.passed ? 0 : 1);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── System commands ────────────────────────────────────────────────────────

const system = program.command('system').description('System management');

system
  .command('doctor')
  .description('Run full system diagnostics')
  .action(async () => {
    try {
      const result = await executeSystemDoctor(ctx.db, ctx.instanceRegistry);
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      const doc = result.value;
      process.stdout.write(JSON.stringify({
        healthy: doc.healthy,
        checks: doc.checks,
        database: doc.database,
        cache: doc.cache,
        circuitBreakers: doc.circuitBreakers,
        recommendations: doc.recommendations,
      }, null, 2) + '\n');
      process.exit(doc.healthy ? 0 : 1);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

program
  .command('team:status')
  .description('Show team overview')
  .action(async () => {
    try {
      const result = await executeTeamStatus(ctx.db, ctx.instanceRegistry);
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify(result.value, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Start command ──────────────────────────────────────────────────────────

program
  .command('start')
  .description('Start KALLAX in interactive mode')
  .option('-r, --role <role>', 'Role: conductor | performer')
  .action(async (opts?: { role?: string }) => {
    try {
      const roleSelector = createRoleSelector();

      if (opts?.['role']) {
        const setResult = await roleSelector.setRole(process.cwd(), opts.role as 'conductor' | 'performer');
        if (setResult.isErr()) {
          logger.kallaxError(setResult.error);
          process.exit(1);
        }
      }

      const detectResult = await roleSelector.detectRole(process.cwd());
      if (detectResult.isErr()) {
        logger.kallaxError(detectResult.error);
        process.exit(1);
      }

      const { role } = detectResult.value;
      logger.info({ role }, 'KALLAX starting');

      const regResult = await ctx.instanceRegistry.register(role);
      if (regResult.isErr()) {
        logger.kallaxError(regResult.error);
        process.exit(1);
      }

      const instance = regResult.value;
      logger.info(
        { instanceId: instance.id, role, hostname: instance.hostname },
        'instance registered — KALLAX is running',
      );
      process.stdout.write(`KALLAX ${role} started — instance: ${instance.id}\n`);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Parse ──────────────────────────────────────────────────────────────────

program.parseAsync(process.argv).catch((error: unknown) => {
  logger.kallaxError(KallaxError.fromUnknown(error, KallaxErrorCode.INTERNAL_ERROR));
  process.exit(1);
});

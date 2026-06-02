/**
 * KALLAX CLI Entry Point
 * ESM module with strict TypeScript
 */

import { Command } from 'commander';
import { logger } from './utils/logger.js';
import { setupProcessCleanup } from './utils/process-cleanup.js';

// Re-export types and core modules
export * from './types/index.js';
export * from './core/index.js';
export * from './commands/index.js';
export * from './utils/index.js';

// Setup process cleanup
setupProcessCleanup();

const program = new Command();

program
  .name('kallax')
  .description('KALLAX - Knowledge-Augmented Leveraged Learning Agent eXecutor')
  .version('1.0.0');

// Task commands
const task = program
  .command('task')
  .description('Task management commands');

task
  .command('claim [taskId]')
  .description('Claim a task (creates worktree)')
  .option('-t, --ticket <ticketId>', 'Claim task for specific ticket')
  .action(async (taskId?: string, opts?: { ticket?: string }) => {
    logger.info({ taskId, ticketId: opts?.ticket }, 'Claiming task');
    // Implementation in commands/claim.ts
  });

task
  .command('complete <taskId>')
  .description('Complete a task (Saga 5-step)')
  .option('--skip-tests', 'Skip test verification')
  .option('--skip-lint', 'Skip lint verification')
  .option('-l, --level <level>', 'Verification level (1-4)', '4')
  .action(async (taskId: string, opts?: { skipTests?: boolean; skipLint?: boolean; level?: string }) => {
    logger.info({ taskId, opts }, 'Completing task');
    // Implementation in commands/complete.ts
  });

task
  .command('create <ticketId>')
  .description('Create a new task for a ticket')
  .option('-t, --type <type>', 'Task type (development, review, testing)', 'development')
  .action(async (ticketId: string, opts?: { type?: string }) => {
    logger.info({ ticketId, type: opts?.type }, 'Creating task');
    // Implementation in commands/task.ts
  });

task
  .command('status [taskId]')
  .description('Show task status')
  .option('-t, --ticket <ticketId>', 'Filter by ticket')
  .option('-p, --performer <performerId>', 'Filter by performer')
  .option('-s, --status <status>', 'Filter by status')
  .action(async (taskId?: string, opts?: Record<string, string>) => {
    logger.info({ taskId, opts }, 'Checking task status');
    // Implementation in commands/task.ts
  });

task
  .command('progress <taskId> <progress>')
  .description('Update task progress (0-100)')
  .option('-m, --message <message>', 'Progress message')
  .action(async (taskId: string, progress: string, opts?: { message?: string }) => {
    logger.info({ taskId, progress, message: opts?.message }, 'Updating task progress');
    // Implementation in commands/task.ts
  });

task
  .command('resume <taskId>')
  .description('Resume a failed or cancelled task')
  .action(async (taskId: string) => {
    logger.info({ taskId }, 'Resuming task');
    // Implementation in commands/task.ts
  });

// Conductor commands
const conductor = program
  .command('conductor')
  .description('Conductor (orchestrator) commands');

conductor
  .command('heartbeat')
  .description('Run conductor heartbeat check (5 questions)')
  .action(async () => {
    logger.info({}, 'Running conductor heartbeat');
    // Implementation in commands/conductor.ts
  });

conductor
  .command('poll')
  .description('Poll for task assignments')
  .option('-a, --auto-assign', 'Automatically assign tasks to performers')
  .option('-m, --max <count>', 'Maximum assignments per poll', '5')
  .action(async (opts?: { autoAssign?: boolean; max?: string }) => {
    logger.info({ opts }, 'Polling for tasks');
    // Implementation in commands/conductor.ts
  });

// Performer commands
const performer = program
  .command('performer')
  .description('Performer (executor) commands');

performer
  .command('register')
  .description('Register as a performer')
  .option('-n, --name <name>', 'Performer name')
  .option('-c, --capabilities <caps>', 'Comma-separated capabilities')
  .action(async (opts?: { name?: string; capabilities?: string }) => {
    logger.info({ opts }, 'Registering performer');
    // Implementation in commands/performer.ts
  });

performer
  .command('poll')
  .description('Poll for tasks')
  .option('-a, --auto-claim', 'Automatically claim available task')
  .action(async (opts?: { autoClaim?: boolean }) => {
    logger.info({ opts }, 'Performer polling');
    // Implementation in commands/performer.ts
  });

performer
  .command('status')
  .description('Get performer status')
  .action(async () => {
    logger.info({}, 'Getting performer status');
    // Implementation in commands/performer.ts
  });

// Isolation commands
program
  .command('isolation:check <taskIdA> [taskIdB]')
  .description('Check file scope overlap between tasks')
  .option('-f, --files <files>', 'Comma-separated file paths to check')
  .action(async (taskIdA: string, taskIdB?: string, opts?: { files?: string }) => {
    logger.info({ taskIdA, taskIdB, files: opts?.files }, 'Checking isolation');
    // Implementation in commands/isolation-check.ts
  });

// Verify commands
program
  .command('verify:output <taskId>')
  .description('Verify task output authenticity (4-Level Fact-Forcing)')
  .option('-l, --level <level>', 'Verification level (1-4)', '4')
  .option('-v, --verbose', 'Show detailed evidence')
  .action(async (taskId: string, opts?: { level?: string; verbose?: boolean }) => {
    logger.info({ taskId, level: opts?.level }, 'Verifying output');
    // Implementation in commands/verify-output.ts
  });

// System commands
const system = program
  .command('system')
  .description('System management commands');

system
  .command('doctor')
  .description('Run system diagnostics')
  .action(async () => {
    logger.info({}, 'Running system diagnostics');
    // Implementation in commands/system.ts
  });

// Team status
program
  .command('team:status')
  .description('Show team overview')
  .action(async () => {
    logger.info({}, 'Getting team status');
    // Implementation in commands/system.ts
  });

// Start command (interactive)
program
  .command('start')
  .description('Start KALLAX in interactive mode')
  .option('-r, --role <role>', 'Role (conductor, performer)')
  .action(async (opts?: { role?: string }) => {
    logger.info({ role: opts?.role }, 'Starting KALLAX');
    // Interactive mode implementation
  });

// Parse and execute
program.parseAsync(process.argv).catch((error: unknown) => {
  logger.error({ error }, 'CLI error');
  process.exit(1);
});

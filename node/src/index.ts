/**
 * KALLAX CLI Entry Point
 * ESM module with strict TypeScript
 */

import { Command } from 'commander';
import { version } from '../package.json' with { type: 'json' };
import { logger } from './utils/logger.js';
import { setupProcessCleanup } from './utils/process-cleanup.js';

// Import commands
import { claimCommand } from './commands/claim.js';
import { completeCommand } from './commands/complete.js';
import { conductorHeartbeatCommand } from './commands/conductor-heartbeat.js';
import { performerRegisterCommand } from './commands/performer-register.js';
import { systemDoctorCommand } from './commands/system-doctor.js';
import { isolationCheckCommand } from './commands/isolation-check.js';
import { verifyOutputCommand } from './commands/verify-output.js';

// Setup process cleanup
setupProcessCleanup();

const program = new Command();

program
  .name('kallax')
  .description('KALLAX - Multi-Agent Collaboration Framework')
  .version(version);

// Task commands
const task = program
  .command('task')
  .description('Task management commands');

task
  .command('claim [ticketId]')
  .description('Claim a task (creates worktree)')
  .option('-f, --force', 'Force claim even if already claimed')
  .action(claimCommand);

task
  .command('complete <ticketId>')
  .description('Complete a task (Saga 5-step)')
  .option('--skip-tests', 'Skip test verification')
  .action(completeCommand);

task
  .command('create <title>')
  .description('Create a new ticket')
  .option('-t, --type <type>', 'Task type (feature, bug, chore)', 'feature')
  .option('-p, --priority <priority>', 'Priority (P0, P1, P2, P3)', 'P2')
  .action(async (title: string, options: Record<string, unknown>) => {
    logger.info({ title, options }, 'Creating task');
    // TODO: Implement
  });

task
  .command('status [ticketId]')
  .description('Show task status')
  .action(async (ticketId?: string) => {
    logger.info({ ticketId }, 'Checking task status');
    // TODO: Implement
  });

task
  .command('progress')
  .description('Show DAG progress with critical path')
  .action(async () => {
    logger.info('Showing task progress');
    // TODO: Implement
  });

// Conductor commands
const conductor = program
  .command('conductor')
  .description('Conductor (orchestrator) commands');

conductor
  .command('heartbeat')
  .description('Run conductor heartbeat check (5 questions)')
  .action(conductorHeartbeatCommand);

conductor
  .command('poll')
  .description('Poll for performer reports')
  .option('-t, --timeout <ms>', 'Poll timeout in milliseconds', '30000')
  .action(async (options: { timeout: string }) => {
    logger.info({ timeout: options.timeout }, 'Polling for performer reports');
    // TODO: Implement
  });

// Performer commands
const performer = program
  .command('performer')
  .description('Performer (executor) commands');

performer
  .command('register')
  .description('Register as a performer')
  .option('-s, --specialty <specialty>', 'Specialization (frontend, backend, etc.)')
  .action(performerRegisterCommand);

performer
  .command('poll')
  .description('Long-poll mailbox for tasks')
  .option('-t, --timeout <ms>', 'Poll timeout in milliseconds', '60000')
  .action(async (options: { timeout: string }) => {
    logger.info({ timeout: options.timeout }, 'Polling mailbox');
    // TODO: Implement
  });

// Knowledge commands
const knowledge = program
  .command('knowledge')
  .description('Knowledge base commands');

knowledge
  .command('index')
  .description('Build FTS index')
  .option('-d, --dir <directory>', 'Directory to index', 'jira/')
  .action(async (options: { dir: string }) => {
    logger.info({ dir: options.dir }, 'Building knowledge index');
    // TODO: Implement
  });

knowledge
  .command('search <query>')
  .description('Search knowledge base')
  .option('-l, --limit <number>', 'Max results', '10')
  .action(async (query: string, options: { limit: string }) => {
    logger.info({ query, limit: options.limit }, 'Searching knowledge base');
    // TODO: Implement
  });

// Isolation commands
const isolation = program
  .command('isolation')
  .description('Isolation and conflict detection');

isolation
  .command('check <ticketIds...>')
  .description('Check file scope overlap between tickets')
  .action(isolationCheckCommand);

// Verify commands
const verify = program
  .command('verify')
  .description('Output verification commands');

verify
  .command('output <ticketId>')
  .description('Verify performer output (4-Level Fact-Forcing)')
  .action(verifyOutputCommand);

// System commands
const system = program
  .command('system')
  .description('System management commands');

system
  .command('doctor')
  .description('Run system diagnostics')
  .action(systemDoctorCommand);

system
  .command('status')
  .description('Show system status')
  .action(async () => {
    logger.info('Checking system status');
    // TODO: Implement
  });

// Web commands
const web = program
  .command('web')
  .description('Web dashboard commands');

web
  .command('dashboard')
  .description('Start web dashboard')
  .option('-p, --port <port>', 'Port number', '3000')
  .action(async (options: { port: string }) => {
    logger.info({ port: options.port }, 'Starting web dashboard');
    // TODO: Implement
  });

// Team commands
program
  .command('team:status')
  .description('Show team overview')
  .action(async () => {
    logger.info('Showing team status');
    // TODO: Implement
  });

// Start command (interactive)
program
  .command('start')
  .description('Start KALLAX in interactive mode')
  .option('-r, --role <role>', 'Role (conductor, performer)')
  .option('-s, --specialty <specialty>', 'Performer specialty')
  .action(async (options: { role?: string; specialty?: string }) => {
    logger.info({ options }, 'Starting KALLAX');
    // TODO: Implement interactive start
  });

// Parse and execute
program.parseAsync(process.argv).catch((error: unknown) => {
  logger.error({ error }, 'CLI error');
  process.exit(1);
});

/**
 * KALLAX Conductor Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';
import { executeConductorHeartbeat, executeConductorPoll } from './conductor.js';

export function registerConductorCommands(program: Command, ctx: AppContext): void {
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
}

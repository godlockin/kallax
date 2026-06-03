/**
 * KALLAX System Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';
import { executeSystemDoctor, executeTeamStatus } from './system.js';

export function registerSystemCommands(program: Command, ctx: AppContext): void {
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
}

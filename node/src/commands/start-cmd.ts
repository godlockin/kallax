/**
 * KALLAX Start Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';
import { createRoleSelector } from '../core/role-selector.js';

export function registerStartCommands(program: Command, ctx: AppContext): void {
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
}

/**
 * KALLAX Performer Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';
import {
  executePerformerRegister,
  executePerformerPoll,
  executePerformerStatus,
} from './performer.js';

export function registerPerformerCommands(program: Command, ctx: AppContext): void {
  const performer = program.command('performer').description('Performer (executor) commands');

  performer
    .command('register')
    .description('Register as a performer')
    .option('-n, --name <name>', 'Performer name')
    .option('-c, --capabilities <caps>', 'Comma-separated capabilities')
    .action(async (opts?: { name?: string; capabilities?: string }) => {
      try {
        const caps = opts?.['capabilities']?.split(',').map((c: string) => c.trim()) ?? [];
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
}

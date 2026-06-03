/**
 * KALLAX Verify Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';
import { executeVerifyOutput } from './verify-output.js';

export function registerVerifyCommands(program: Command, ctx: AppContext): void {
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
}

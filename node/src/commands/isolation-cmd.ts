/**
 * KALLAX Isolation Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';
import { executeIsolationCheck } from './isolation-check.js';

export function registerIsolationCommands(program: Command, ctx: AppContext): void {
  program
    .command('isolation:check <taskIdA> [taskIdB]')
    .description('Check file-scope overlap between tasks')
    .option('-f, --files <files>', 'Comma-separated file paths')
    .action((taskIdA: string, taskIdB?: string, opts?: { files?: string }): void => {
      try {
        const files = opts?.['files']?.split(',').map((f: string) => f.trim()) ?? [];
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
}

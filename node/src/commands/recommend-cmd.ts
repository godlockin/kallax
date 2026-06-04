/**
 * KALLAX Recommend Command Registration
 *
 * CLI: kallax recommend match <taskId>
 * Uses TF-IDF capability matching to recommend the best performer for a task.
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { matchPerformer } from '../core/recommender/matcher.js';
import type { PerformerProfile } from '../core/recommender/matcher.js';

export function registerRecommendCommands(program: Command, ctx: AppContext): void {
  program
    .command('recommend')
    .description('Recommendation engine — match tasks to performers')
    .argument('<subcommand>', 'match')
    .argument('[taskId]', 'Task ID to match performers for')
    .option('-n, --top <n>', 'Number of top recommendations', '10')
    .action(async (subcommand: string, taskId: string | undefined, opts?: { top?: string }) => {
      try {
        if (subcommand !== 'match') {
          logger.error({ subcommand }, 'unknown recommend subcommand — use "match"');
          process.exit(1);
        }
        if (!taskId) {
          logger.error({}, 'taskId is required for "recommend match"');
          process.exit(1);
        }

        // Fetch task
        const taskResult = ctx.db.getTask(taskId);
        if (taskResult.isErr()) {
          logger.kallaxError(taskResult.error);
          process.exit(1);
        }
        const task = taskResult.value;
        if (!task) {
          logger.error({ taskId }, 'task not found');
          process.exit(1);
        }

        // Extract required capabilities from task metadata
        const rawCaps = task.metadata?.capabilities;
        const taskCaps: string[] = Array.isArray(rawCaps)
          ? rawCaps.filter((c): c is string => typeof c === 'string')
          : [];

        if (taskCaps.length === 0) {
          logger.warn({ taskId }, 'task has no capabilities in metadata — recommendations will be poor');
        }

        // Fetch active performer instances
        const instResult = ctx.db.listInstances({ role: 'performer', status: 'active' });
        if (instResult.isErr()) {
          logger.kallaxError(instResult.error);
          process.exit(1);
        }

        const performers: PerformerProfile[] = instResult.value.map((inst) => ({
          id: inst.id,
          capabilities: inst.capabilities,
        }));

        // Run matcher
        const topN = Math.max(1, parseInt(opts?.top ?? '10', 10));
        const matchResult = matchPerformer(taskCaps, performers, { topN });
        if (matchResult.isErr()) {
          logger.error({ error: matchResult.error.message }, 'matching failed');
          process.exit(1);
        }

        process.stdout.write(JSON.stringify({
          taskId,
          requiredCapabilities: taskCaps,
          recommendations: matchResult.value,
          totalCandidates: performers.length,
        }, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}

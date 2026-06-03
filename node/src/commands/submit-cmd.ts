/**
 * KALLAX Submit and Gate Review Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';

export function registerSubmitCommands(program: Command, ctx: AppContext): void {
  program
    .command('submit:pr')
    .description('Submit a pull request — stage, commit, push, and create PR')
    .option('-t, --title <title>', 'PR title (defaults to branch name)')
    .option('-b, --body <body>', 'PR description body')
    .option('--base <branch>', 'Base branch', 'main')
    .option('--no-gate', 'Skip gate review before submission')
    .action(async (opts?: { title?: string; body?: string; base?: string; gate?: boolean }) => {
      try {
        const cwd = process.cwd();
        const branchResult = await ctx.gitService.getCurrentBranch(cwd);
        if (branchResult.isErr()) {
          logger.kallaxError(branchResult.error);
          process.exit(1);
        }
        const branch = branchResult.value;
        const prTitle = opts?.['title'] ?? branch;
        const prBody = opts?.['body'] ?? '';

        // Optional gate check
        const runGate = opts?.['gate'] !== false;
        if (runGate) {
          const { getGateReviewer } = await import('../core/gate-reviewer.js');
          const reviewer = getGateReviewer();
          const gateResult = await reviewer.review({ cwd, maxLevel: 2 });
          if (gateResult.isErr()) {
            logger.kallaxError(gateResult.error);
            process.exit(1);
          }
          if (!gateResult.value.passed) {
            logger.error({ checks: gateResult.value.checks }, 'gate review failed — aborting PR submission');
            process.exit(1);
          }
          logger.info({}, 'gate review passed');
        }

        // Stage, commit, push
        const stageResult = await ctx.gitService.stageAll(cwd);
        if (stageResult.isErr()) { logger.kallaxError(stageResult.error); process.exit(1); }

        const commitResult = await ctx.gitService.commit(cwd, `PR: ${prTitle}`);
        if (commitResult.isErr()) { logger.kallaxError(commitResult.error); process.exit(1); }

        const pushResult = await ctx.gitService.push(cwd, branch);
        if (pushResult.isErr()) { logger.kallaxError(pushResult.error); process.exit(1); }

        const prResult = await ctx.gitService.createPr(cwd, prTitle, prBody, opts?.['base']);
        if (prResult.isErr()) { logger.kallaxError(prResult.error); process.exit(1); }

        process.stdout.write(JSON.stringify({
          branch, commitHash: commitResult.value.hash, prNumber: prResult.value.number,
          prUrl: prResult.value.url, base: opts?.['base'] ?? 'main',
        }) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  program
    .command('gate:review')
    .description('Run gate review checks (4 levels)')
    .option('-l, --level <level>', 'Max gate level (1-4)', '4')
    .option('--ci', 'CI mode — exit with code 1 on failure')
    .action(async (opts?: { level?: string; ci?: boolean }) => {
      try {
        const { getGateReviewer } = await import('../core/gate-reviewer.js');
        const reviewer = getGateReviewer();
        const maxLevel = parseInt(opts?.['level'] ?? '4', 10) as 1 | 2 | 3 | 4;

        const result = await reviewer.review({ maxLevel, cwd: process.cwd() });
        if (result.isErr()) {
          logger.kallaxError(result.error);
          process.exit(1);
        }

        const r = result.value;
        process.stdout.write(JSON.stringify({
          passed: r.passed, maxLevel: r.maxLevel,
          checks: r.checks, summary: r.summary,
        }, null, 2) + '\n');

        if (opts?.['ci'] && !r.passed) process.exit(1);
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}

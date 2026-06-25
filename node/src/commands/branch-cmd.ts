/**
 * KALLAX Branch Commands — feature/* → testing → miao pipeline.
 */
import type { Command } from 'commander';
import { execFileSync } from 'node:child_process';
import * as path from 'node:path';
import { logger } from '../utils/logger.js';

const SCRIPTS_DIR = path.resolve(import.meta.dirname, '../../../scripts');

function runScript(script: string, ...args: string[]): void {
  const scriptPath = path.join(SCRIPTS_DIR, script);
  execFileSync('bash', [scriptPath, ...args], { stdio: 'inherit' });
}

export function registerBranchCommands(program: Command): void {
  const branch = program.command('branch').description('Git branch pipeline: feature/* → testing → miao');

  branch.command('feature <name>')
    .description('Create feature/<name> from miao with worktree')
    .option('--skip-worktree', 'Branch only, no worktree')
    .action((name: string, opts: { skipWorktree?: boolean }) => {
      const args = opts.skipWorktree ? ['--skip-worktree'] : [];
      runScript('branch-feature.sh', name, ...args);
    });

  branch.command('merge <feature>')
    .description('Merge feature/<name> → testing, run tests')
    .option('--skip-tests', 'Skip tests')
    .option('--dry-run', 'Preview only')
    .action((feature: string, opts: { skipTests?: boolean; dryRun?: boolean }) => {
      const args: string[] = [];
      if (opts.skipTests) args.push('--skip-tests');
      if (opts.dryRun) args.push('--dry-run');
      runScript('branch-merge-epic.sh', feature, ...args);
    });

  branch.command('promote')
    .description('Create PR: testing → miao (requires Master approval)')
    .option('--emergency', 'Bypass expert panel')
    .option('--dry-run', 'Preview only')
    .action((opts: { emergency?: boolean; dryRun?: boolean }) => {
      const args: string[] = [];
      if (opts.emergency) args.push('--emergency');
      if (opts.dryRun) args.push('--dry-run');
      runScript('branch-promote.sh', ...args);
    });

  branch.command('status')
    .description('Show branch pipeline status')
    .action(() => {
      execFileSync('git', ['branch', '-a'], { stdio: 'inherit' });
      logger.info({}, '\nPipeline: feature/<name> → testing → miao');
      logger.info({}, '  feature → testing:  Conductor merges (提测)');
      logger.info({}, '  testing → miao:     Master approves PR (发版)');
    });
}

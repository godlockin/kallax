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
    .action((name: string, opts: { skipWorktree?: boolean }): void => {
      const args = opts.skipWorktree === true ? ['--skip-worktree'] : [];
      runScript('branch-feature.sh', name, ...args);
    });

  branch.command('merge <feature>')
    .description('Merge feature/<name> → testing, run tests')
    .option('--skip-tests', 'Skip tests')
    .option('--dry-run', 'Preview only')
    .action((feature: string, opts: { skipTests?: boolean; dryRun?: boolean }): void => {
      const args: string[] = [];
      if (opts.skipTests === true) args.push('--skip-tests');
      if (opts.dryRun === true) args.push('--dry-run');
      runScript('branch-merge-epic.sh', feature, ...args);
    });

  branch.command('promote')
    .description('Create PR: testing → miao (requires Master approval)')
    .option('--emergency', 'Bypass expert panel')
    .option('--dry-run', 'Preview only')
    .action((opts: { emergency?: boolean; dryRun?: boolean }): void => {
      const args: string[] = [];
      if (opts.emergency === true) args.push('--emergency');
      if (opts.dryRun === true) args.push('--dry-run');
      runScript('branch-promote.sh', ...args);
    });

  branch.command('status')
    .description('Show branch pipeline status')
    .action((): void => {
      execFileSync('git', ['branch', '-a'], { stdio: 'inherit' });
      logger.info({}, '\nPipeline: feature/<name> → testing → miao');
      logger.info({}, '  feature → testing:  Conductor merges (提测)');
      logger.info({}, '  testing → miao:     Master approves PR (发版)');
    });

  // EPIC-074 + Sprint 6/7: 4-PR 流程新规 (feature → testing → main → miao)
  // 跟 v3.8.0 red-blue review "miao → main 阻塞" fix
  branch.command('pr <feature>')
    .description('4-PR 流程: feature/<name> → testing → main → miao (新规首次实战)')
    .option('--skip-tests', 'Skip test verification (5-Level Verify 强制, 慎用)')
    .option('--emergency', 'Bypass gate (主公明确批准时)')
    .option('--dry-run', 'Preview only, do not push')
    .action((feature: string, opts: { skipTests?: boolean; emergency?: boolean; dryRun?: boolean }): void => {
      const args: string[] = [feature];
      if (opts.skipTests === true) args.push('--skip-tests');
      if (opts.emergency === true) args.push('--emergency');
      if (opts.dryRun === true) args.push('--dry-run');
      runScript('branch-4pr.sh', ...args);
    });
}

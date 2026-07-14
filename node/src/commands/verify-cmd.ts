/**
 * KALLAX Verify Command Registration
 *
 * 武器 2 (Iter 5): `kallax verify <level> TICKET-001`
 *   - verify:output  (legacy, 1-5 numeric level)
 *   - verify l1..l5  (武器 2, 调 scripts/verify/level-{1..5}.sh)
 *   - verify all     (L1-L5 一次跑)
 *
 * 跟 docs/5-levels.md §1:1  (L1 git / L2 stdout / L3 4-expert / L4 independent / L5 boundary)
 */

import { Command } from 'commander';
import { execFileSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';
import { executeVerifyOutput } from './verify-output.js';

function findProjectRoot(): string {
  let dir = process.cwd();
  while (dir !== '/') {
    if (fs.existsSync(`${dir}/.git`) || fs.existsSync(`${dir}/.kallax/IDENTITY.md`)) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  return process.cwd();
}

function findVerifyScript(projectRoot: string, levelNum: number): string {
  return path.join(projectRoot, 'scripts', 'verify', `level-${String(levelNum)}.sh`);
}

interface LevelResult {
  readonly level: number;
  readonly passed: boolean;
  readonly rc: number;
  readonly stdout: string;
  readonly durationMs: number;
}

function runLevelScript(projectRoot: string, levelNum: number, ticketId: string, dryRun: boolean): LevelResult {
  const script = findVerifyScript(projectRoot, levelNum);
  if (!fs.existsSync(script)) {
    return {
      level: levelNum,
      passed: false,
      rc: 127,
      stdout: `ERROR: script not found: ${script}\n`,
      durationMs: 0,
    };
  }
  const args: string[] = [ticketId];
  if (dryRun) args.push('--dry-run');
  const start = Date.now();
  let stdout = '';
  let rc = 0;
  try {
    stdout = execFileSync('bash', [script, ...args], {
      cwd: projectRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      maxBuffer: 4 * 1024 * 1024,
    });
    rc = 0;
  } catch (err: unknown) {
    const e = err as { status?: number | null; stdout?: Buffer | string; stderr?: Buffer | string };
    rc = typeof e.status === 'number' ? e.status : 1;
    stdout = (e.stdout != null ? e.stdout.toString() : '') + (e.stderr != null ? `\n[STDERR]\n${e.stderr.toString()}` : '');
  }
  return {
    level: levelNum,
    passed: rc === 0,
    rc,
    stdout,
    durationMs: Date.now() - start,
  };
}

function formatResult(result: LevelResult): string {
  const status = result.passed ? 'PASS' : 'FAIL';
  const lines: string[] = [
    `--- L${String(result.level)} ${status} (rc=${String(result.rc)}, ${String(result.durationMs)}ms) ---`,
    result.stdout.trimEnd(),
  ];
  return lines.join('\n');
}

function summary(results: readonly LevelResult[]): {
  totalPass: number;
  totalFail: number;
  overallPassed: boolean;
} {
  let totalPass = 0;
  let totalFail = 0;
  for (const r of results) {
    if (r.passed) totalPass += 1;
    else totalFail += 1;
  }
  return { totalPass, totalFail, overallPassed: totalFail === 0 };
}

function emitOutput(
  level: string,
  ticketId: string,
  results: readonly LevelResult[],
  dryRun: boolean,
): void {
  const { totalPass, totalFail, overallPassed } = summary(results);
  for (const r of results) {
    process.stdout.write(formatResult(r) + '\n');
  }
  process.stdout.write('\n');
  process.stdout.write(`==========================================\n`);
  process.stdout.write(`verify ${level} ${ticketId}${dryRun ? ' --dry-run' : ''}\n`);
  process.stdout.write(`Total: ${String(totalPass)} PASS, ${String(totalFail)} FAIL (of ${String(results.length)})\n`);
  process.stdout.write(`Overall: ${overallPassed ? 'PASS' : 'FAIL'}\n`);
  process.stdout.write(`==========================================\n`);
}

export function registerVerifyCommands(program: Command, _ctx: AppContext): void {
  // Legacy: verify:output <taskId>  (numeric level 1-5)
  program
    .command('verify:output <taskId>')
    .description('Verify task output — Fact-Forcing 5 levels check (legacy, numeric level)')
    .option('-l, --level <level>', 'Verification level (1-5)', '5')
    .option('-v, --verbose', 'Show detailed evidence')
    .action(async (taskId: string, opts?: { level?: string; verbose?: boolean }) => {
      try {
        const parsed = parseInt(opts?.['level'] ?? '4', 10);
        const level = (parsed >= 1 && parsed <= 4 ? parsed : 4) as 1 | 2 | 3 | 4;
        const result = await executeVerifyOutput(
          _ctx.db, _ctx.worktreeManager, _ctx.outputVerifier,
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

  // 武器 2: verify <level> <TICKET_ID>  (调 level-{N}.sh)
  const verifyCmd = program
    .command('verify <level> <ticketId>')
    .description('KALLAX 5-Level Fact-Forcing verify (武器 2: l1..l5 / all)');

  verifyCmd
    .option('--dry-run', 'Skip actual execution, just verify structure (CI / smoke)');

  verifyCmd.action((levelArg: string, ticketId: string, opts?: { dryRun?: boolean }) => {
    const projectRoot = findProjectRoot();
    const level = levelArg.trim().toLowerCase();
    const dryRun = opts?.['dryRun'] === true;

    if (!ticketId || ticketId.trim() === '') {
      process.stderr.write("error: TICKET_ID required (e.g. 'kallax verify l1 EPIC-053-A')\n");
      process.exit(2);
    }

    if (level === 'l1' || level === '1') {
      const r = runLevelScript(projectRoot, 1, ticketId, dryRun);
      emitOutput('l1', ticketId, [r], dryRun);
      process.exit(r.passed ? 0 : 1);
    }
    if (level === 'l2' || level === '2') {
      const r = runLevelScript(projectRoot, 2, ticketId, dryRun);
      emitOutput('l2', ticketId, [r], dryRun);
      process.exit(r.passed ? 0 : 1);
    }
    if (level === 'l3' || level === '3') {
      const r = runLevelScript(projectRoot, 3, ticketId, dryRun);
      emitOutput('l3', ticketId, [r], dryRun);
      process.exit(r.passed ? 0 : 1);
    }
    if (level === 'l4' || level === '4') {
      const r = runLevelScript(projectRoot, 4, ticketId, dryRun);
      emitOutput('l4', ticketId, [r], dryRun);
      process.exit(r.passed ? 0 : 1);
    }
    if (level === 'l5' || level === '5') {
      const r = runLevelScript(projectRoot, 5, ticketId, dryRun);
      emitOutput('l5', ticketId, [r], dryRun);
      process.exit(r.passed ? 0 : 1);
    }
    if (level === 'all') {
      const results: LevelResult[] = [];
      for (let i = 1; i <= 5; i += 1) {
        results.push(runLevelScript(projectRoot, i, ticketId, dryRun));
      }
      emitOutput('all', ticketId, results, dryRun);
      const { overallPassed } = summary(results);
      process.exit(overallPassed ? 0 : 1);
    }

    process.stderr.write(`error: unknown level '${levelArg}' (use l1..l5 or all)\n`);
    process.exit(2);
  });
}

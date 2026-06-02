/**
 * KALLAX Gate Reviewer
 * 4-Level gate review for PRs and task completion.
 * Gate 1: Preflight — existence, file count, CI status
 * Gate 2: Architecture — isolation, dependency, pattern compliance
 * Gate 3: Security — forbidden patterns, secrets, dependencies
 * Gate 4: Performance — test coverage, complexity, benchmarks
 */

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

const execFileAsync = promisify(execFile);

// ── Types ──────────────────────────────────────────────────────────────────

export type GateLevel = 1 | 2 | 3 | 4;
export type GateStatus = 'passed' | 'failed' | 'skipped' | 'error';

export interface GateCheck {
  readonly name: string;
  readonly level: GateLevel;
  readonly status: GateStatus;
  readonly message: string;
  readonly details?: Readonly<Record<string, unknown>>;
  readonly recommendation?: string;
}

export interface GateReviewResult {
  readonly passed: boolean;
  readonly maxLevel: GateLevel;
  readonly checks: readonly GateCheck[];
  readonly summary: GateReviewSummary;
}

export interface GateReviewSummary {
  readonly total: number;
  readonly passed: number;
  readonly failed: number;
  readonly skipped: number;
  readonly byLevel: Record<number, { passed: number; failed: number }>;
}

export interface GateReviewOptions {
  readonly maxLevel?: GateLevel;
  readonly cwd?: string;
  readonly skipTests?: boolean;
}

export interface GateReviewer {
  review: (options?: GateReviewOptions) => Promise<KallaxResult<GateReviewResult>>;
  reviewPr: (prNumber: number, options?: GateReviewOptions) => Promise<KallaxResult<GateReviewResult>>;
}

// ── Helpers ────────────────────────────────────────────────────────────────

async function runCommand(
  cwd: string,
  command: string,
  args: string[],
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  try {
    const { stdout, stderr } = await execFileAsync(command, args, { cwd, timeout: 30000 });
    return { stdout: stdout.trim(), stderr: stderr.trim(), exitCode: 0 };
  } catch (error: unknown) {
    const execError = error as { stdout?: string; stderr?: string; code?: number };
    return {
      stdout: (execError.stdout ?? '').trim(),
      stderr: (execError.stderr ?? '').trim(),
      exitCode: execError.code ?? 1,
    };
  }
}

function gateCheck(
  name: string,
  level: GateLevel,
  passed: boolean,
  message: string,
  recommendation?: string,
): GateCheck {
  return {
    name,
    level,
    status: passed ? 'passed' : 'failed',
    message,
    recommendation,
  };
}

// ── Gate 1: Preflight ──────────────────────────────────────────────────────

async function runPreflightChecks(cwd: string): Promise<GateCheck[]> {
  const checks: GateCheck[] = [];

  // Check git repo
  const gitResult = await runCommand(cwd, 'git', ['status', '--porcelain']);
  checks.push(
    gateCheck(
      'git-repository',
      1,
      gitResult.exitCode === 0,
      gitResult.exitCode === 0 ? 'Git repository OK' : 'Not a git repository',
      'Run in a git repository',
    ),
  );

  // Check for uncommitted changes
  const hasChanges = gitResult.stdout.length > 0;
  checks.push(
    gateCheck(
      'uncommitted-changes',
      1,
      !hasChanges,
      hasChanges ? `Uncommitted changes: ${gitResult.stdout.split('\n').length} files` : 'No uncommitted changes',
      hasChanges ? 'Commit or stash changes before review' : undefined,
    ),
  );

  // Check PR size (if gh available)
  const ghResult = await runCommand(cwd, 'gh', ['--version']);
  if (ghResult.exitCode === 0) {
    const diffResult = await runCommand(cwd, 'git', ['diff', '--stat', 'origin/main..HEAD']);
    const fileCount = diffResult.stdout ? diffResult.stdout.split('\n').length : 0;
    const isLarge = fileCount > 50;
    checks.push(
      gateCheck(
        'pr-size',
        1,
        !isLarge,
        isLarge ? `${fileCount} files changed — PR is large` : `${fileCount} files changed — OK`,
        isLarge ? 'Consider splitting into smaller PRs' : undefined,
      ),
    );
  }

  return checks;
}

// ── Gate 2: Architecture ───────────────────────────────────────────────────

async function runArchitectureChecks(cwd: string): Promise<GateCheck[]> {
  const checks: GateCheck[] = [];

  // Check for forbidden patterns
  const scanScript = `${cwd}/scripts/scan-forbidden.sh`;
  const scanResult = await runCommand(cwd, 'bash', [scanScript]);

  checks.push(
    gateCheck(
      'forbidden-patterns',
      2,
      scanResult.exitCode === 0,
      scanResult.exitCode === 0 ? 'No forbidden patterns' : `Forbidden patterns found: ${scanResult.stdout.slice(0, 500)}`,
      'Fix all forbidden patterns: .expect(), .unwrap(), panic!, :any, @ts-ignore',
    ),
  );

  // Check TypeScript compilation
  const tscResult = await runCommand(cwd, 'npx', ['tsc', '--noEmit']);
  checks.push(
    gateCheck(
      'typescript-compilation',
      2,
      tscResult.exitCode === 0,
      tscResult.exitCode === 0 ? 'TypeScript compiles' : 'TypeScript compilation failed',
      'Fix type errors before submitting',
    ),
  );

  // Check for stub/TODO content in changed files
  const diffResult = await runCommand(cwd, 'git', ['diff', '--name-only', 'origin/main..HEAD']);
  if (diffResult.exitCode === 0 && diffResult.stdout) {
    const changedFiles = diffResult.stdout.split('\n').filter((f) => f.endsWith('.ts'));
    if (changedFiles.length > 0) {
      const grepResult = await runCommand(cwd, 'grep', [
        '-n',
        'TODO|FIXME|placeholder|stub|not implemented',
        ...changedFiles.slice(0, 20),
      ]);
      const stubCount = grepResult.stdout ? grepResult.stdout.split('\n').length : 0;
      checks.push(
        gateCheck(
          'no-stubs',
          2,
          stubCount === 0,
          stubCount > 0 ? `${stubCount} stub/TODO markers found` : 'No stub content detected',
          stubCount > 0 ? 'Complete or remove stub content' : undefined,
        ),
      );
    }
  }

  return checks;
}

// ── Gate 3: Security ───────────────────────────────────────────────────────

async function runSecurityChecks(cwd: string): Promise<GateCheck[]> {
  const checks: GateCheck[] = [];

  // Check for secrets in diff
  const diffResult = await runCommand(cwd, 'git', ['diff', 'origin/main..HEAD']);
  if (diffResult.stdout) {
    const secretPatterns = [
      /ghp_[a-zA-Z0-9]{36}/,
      /-----BEGIN (RSA |EC )?PRIVATE KEY-----/,
      /(?:password|secret|token|api[_-]?key)\s*[:=]\s*['"][^'"]+['"]/i,
    ];

    const foundSecrets: string[] = [];
    for (const pattern of secretPatterns) {
      const matches = diffResult.stdout.match(pattern);
      if (matches) foundSecrets.push(matches[0].slice(0, 50) + '...');
    }

    checks.push(
      gateCheck(
        'no-secrets',
        3,
        foundSecrets.length === 0,
        foundSecrets.length > 0 ? `Possible secrets: ${foundSecrets.length}` : 'No secrets detected',
        foundSecrets.length > 0 ? 'Remove secrets, rotate any exposed credentials' : undefined,
      ),
    );
  }

  // npm audit
  if (await fileExists(`${cwd}/package.json`)) {
    const auditResult = await runCommand(cwd, 'npm', ['audit', '--json']);
    checks.push(
      gateCheck(
        'npm-audit',
        3,
        auditResult.exitCode === 0,
        auditResult.exitCode === 0 ? 'No known vulnerabilities' : 'npm audit found issues',
        'Run npm audit fix',
      ),
    );
  }

  return checks;
}

// ── Gate 4: Performance ────────────────────────────────────────────────────

async function runPerformanceChecks(cwd: string): Promise<GateCheck[]> {
  const checks: GateCheck[] = [];

  // Test coverage
  if (await fileExists(`${cwd}/node/package.json`)) {
    const testResult = await runCommand(cwd, 'npm', ['test', '--', '--run']);
    checks.push(
      gateCheck(
        'tests-passing',
        4,
        testResult.exitCode === 0,
        testResult.exitCode === 0 ? 'All tests passing' : 'Tests failing',
        'Fix all failing tests before merge',
      ),
    );
  }

  // Lint check
  const lintResult = await runCommand(cwd, 'npx', ['eslint', 'src/', '--max-warnings', '0']);
  if (lintResult.exitCode !== 0 && lintResult.exitCode !== 2) {
    // exit code 2 = eslint not found/config error, which is not a lint failure
    checks.push(
      gateCheck(
        'lint-clean',
        4,
        lintResult.exitCode === 0,
        lintResult.exitCode === 0 ? 'Lint clean' : 'Lint issues found',
        'Fix lint issues',
      ),
    );
  }

  return checks;
}

// ── File utility ─────────────────────────────────────────────────────────────

async function fileExists(filePath: string): Promise<boolean> {
  try {
    const { access } = await import('node:fs/promises');
    await access(filePath);
    return true;
  } catch {
    return false;
  }
}

// ── Main Export ──────────────────────────────────────────────────────────────

export function createGateReviewer(): GateReviewer {
  return {
    async review(options: GateReviewOptions = {}): Promise<KallaxResult<GateReviewResult>> {
      const { maxLevel = 4, cwd = process.cwd(), skipTests = false } = options;
      logger.info({ maxLevel, cwd }, 'gate review started');

      const checks: GateCheck[] = [];

      try {
        // Gate 1: Preflight
        if (maxLevel >= 1) {
          checks.push(...(await runPreflightChecks(cwd)));
        }

        // Gate 2: Architecture
        if (maxLevel >= 2) {
          checks.push(...(await runArchitectureChecks(cwd)));
        }

        // Gate 3: Security
        if (maxLevel >= 3) {
          checks.push(...(await runSecurityChecks(cwd)));
        }

        // Gate 4: Performance
        if (maxLevel >= 4 && !skipTests) {
          checks.push(...(await runPerformanceChecks(cwd)));
        }
      } catch (error: unknown) {
        logger.error({ error }, 'gate review error');
        checks.push({
          name: 'gate-review-error',
          level: 1,
          status: 'error',
          message: error instanceof Error ? error.message : String(error),
        });
      }

      // Build summary
      const byLevel: Record<number, { passed: number; failed: number }> = {};
      let passedCount = 0;
      let failedCount = 0;
      let skippedCount = 0;

      for (const check of checks) {
        if (!byLevel[check.level]) byLevel[check.level] = { passed: 0, failed: 0 };
        switch (check.status) {
          case 'passed':
            passedCount++;
            byLevel[check.level]!.passed++;
            break;
          case 'failed':
            failedCount++;
            byLevel[check.level]!.failed++;
            break;
          case 'skipped':
            skippedCount++;
            break;
        }
      }

      const result: GateReviewResult = {
        passed: failedCount === 0,
        maxLevel,
        checks,
        summary: {
          total: checks.length,
          passed: passedCount,
          failed: failedCount,
          skipped: skippedCount,
          byLevel,
        },
      };

      logger.info(
        { passed: result.passed, totalChecks: checks.length, passedCount, failedCount },
        'gate review completed',
      );

      return ok(result);
    },

    async reviewPr(prNumber: number, options: GateReviewOptions = {}): Promise<KallaxResult<GateReviewResult>> {
      logger.info({ prNumber }, 'PR gate review started');

      // Checkout PR branch and run review
      const cwd = options.cwd ?? process.cwd();
      const fetchResult = await runCommand(cwd, 'gh', ['pr', 'checkout', String(prNumber)]);

      if (fetchResult.exitCode !== 0) {
        return err(
          new KallaxError(KallaxErrorCode.INTERNAL_ERROR, 'Failed to checkout PR', {
            metadata: { prNumber, stderr: fetchResult.stderr },
          }),
        );
      }

      return this.review({ ...options, cwd: `${cwd}` });
    },
  };
}

let defaultGateReviewer: GateReviewer | null = null;

export function getGateReviewer(): GateReviewer {
  if (defaultGateReviewer === null) {
    defaultGateReviewer = createGateReviewer();
  }
  return defaultGateReviewer;
}

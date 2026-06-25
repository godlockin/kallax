/**
 * KALLAX Master Verify — Helpers (跟 v2.7.4 D4 联合, 跟 Rule 8 联合)
 * Helper functions for the 6-dimension verification.
 */

import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { logger } from '../utils/logger.js';
import { EXIT_FAIL } from './constants.js';

const KPI_FAB_BLACKLIST_PATTERNS = [
  'fake_pass',
  'verifies_artifact',
  'mocks_real_check',
  'snapshot_only',
  'always_passes',
];

// ============================================================================
// Types
// ============================================================================

export interface DimensionResult {
  readonly passed: boolean;
  readonly dimension: string;
  readonly description: string;
  readonly evidence: readonly string[];
}

// ============================================================================
// Helpers
// ============================================================================

export function die(msg: string, code: number = EXIT_FAIL): never {
  logger.error({}, `ERROR: ${msg}`);
  process.exit(code);
}

export function runGit(args: readonly string[]): string {
  try {
    return execFileSync('git', args, { encoding: 'utf-8' }).trim();
  } catch (err: unknown) {
    die(`git ${args.join(' ')} failed: ${err instanceof Error ? err.message : String(err)}`);
  }
}

export function runShell(scriptPath: string, args: readonly string[] = []): { stdout: string; rc: number } {
  try {
    const stdout = execFileSync('bash', [join(scriptPath), ...args], {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return { stdout, rc: 0 };
  } catch (err: unknown) {
    const e = err as { stdout?: Buffer | string; status?: number };
    const stdout = typeof e.stdout === 'string' ? e.stdout : e.stdout?.toString() ?? '';
    return { stdout, rc: e.status ?? 1 };
  }
}

export function isValidSha(sha: string): boolean {
  return /^[0-9a-f]{7,40}$/i.test(sha);
}

export function getCommitMessage(): string {
  return runGit(['log', '-1', '--pretty=%B']);
}

export function detectKpiFab(msg: string): string | null {
  for (const pattern of KPI_FAB_BLACKLIST_PATTERNS) {
    if (msg.toLowerCase().includes(pattern)) return pattern;
  }
  return null;
}

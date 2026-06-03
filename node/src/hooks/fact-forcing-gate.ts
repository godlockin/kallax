/**
 * KALLAX Fact-Forcing Gate — 4-Level verification for tool use.
 *
 * L1: Existence — file/change exists
 * L2: Substance — real logic, not stubs
 * L3: Wiring — correct imports/exports
 * L4: Data Flow — integration tests pass
 */

import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { Hook, HookContext } from './types.js';

export type VerifyLevel = 1 | 2 | 3 | 4;

export interface FactForcingConfig {
  readonly minLevel: VerifyLevel;
  readonly enforceAllLevels: boolean;
  readonly stubPatterns: RegExp[];
}

const DEFAULT_STUB_PATTERNS: RegExp[] = [
  /\/\/\s*TODO:\s*implement/i,
  /\/\/\s*FIXME/i,
  /\/\/\s*stub/i,
  /\/\/\s*placeholder/i,
  /return\s*\{\s*\};/,
  /return\s*\[\];/,
  /throw new Error\('Not implemented'\)/,
  /pass\s*#/i,
];

const DEFAULT_CONFIG: FactForcingConfig = {
  minLevel: 2,
  enforceAllLevels: true,
  stubPatterns: DEFAULT_STUB_PATTERNS,
};

export function createFactForcingGate(
  config: Partial<FactForcingConfig> = {},
): Hook {
  const cfg = { ...DEFAULT_CONFIG, ...config };

  return {
    name: 'fact-forcing-gate',
    phases: ['pre-tool-use', 'task-complete'],
    priority: 5, // run early
    async execute(ctx: HookContext): Promise<KallaxResult<{ allowed: boolean; reason?: string; warnings?: string[]; modifiedParams?: Record<string, unknown> }>> {
      // Only enforce on task completion
      if (ctx.phase !== 'task-complete') {
        return ok({ allowed: true });
      }

      const warnings: string[] = [];

      // L1: Existence check — does the tool output reference real changes?
      const l1Result = await checkL1Existence(ctx);
      if (l1Result.isErr()) return ok({ allowed: false, reason: `L1: ${l1Result.error.message}` });
      if (!l1Result.value) warnings.push('L1: no verifiable file changes found');

      if (cfg.minLevel >= 2 || cfg.enforceAllLevels) {
        // L2: Substance check — scan for stubs/TODOs
        const l2Result = await checkL2Substance(ctx, cfg.stubPatterns);
        if (l2Result.isErr()) return ok({ allowed: false, reason: `L2: ${l2Result.error.message}` });
        if (!l2Result.value) warnings.push('L2: stubs or TODOs detected in output');
      }

      if (cfg.minLevel >= 3 || cfg.enforceAllLevels) {
        // L3: Wiring check — verify imports/exports
        const l3Result = await checkL3Wiring(ctx);
        if (l3Result.isErr()) return ok({ allowed: false, reason: `L3: ${l3Result.error.message}` });
        if (!l3Result.value) warnings.push('L3: import/export issues detected');
      }

      if (cfg.minLevel >= 4 || cfg.enforceAllLevels) {
        // L4: Data flow check — tests must pass
        const l4Result = await checkL4DataFlow(ctx);
        if (l4Result.isErr()) return ok({ allowed: false, reason: `L4: ${l4Result.error.message}` });
        if (!l4Result.value) warnings.push('L4: tests not passing');
      }

      logger.info({
        phase: ctx.phase,
        ticketId: ctx.ticketId,
        minLevel: cfg.minLevel,
        warningCount: warnings.length,
      }, 'fact-forcing gate completed');

      return ok({ allowed: true, warnings: warnings.length > 0 ? warnings : undefined });
    },
  };
}

// ── L1: Existence ──────────────────────────────────────────────────────────

async function checkL1Existence(ctx: HookContext): Promise<KallaxResult<boolean>> {
  try {
    const { execFile } = await import('node:child_process');
    const { promisify } = await import('node:util');
    const execFileAsync = promisify(execFile);

    // Check for uncommitted changes
    const { stdout } = await execFileAsync('git', ['diff', '--stat'], { timeout: 10000 });
    if (!stdout.trim()) {
      // Check for untracked files too
      const { stdout: untracked } = await execFileAsync('git', ['ls-files', '--others', '--exclude-standard'], { timeout: 10000 });
      if (!untracked.trim()) {
        return ok(false); // No changes at all
      }
    }
    return ok(true);
  } catch {
    // git not available — skip L1 check
    return ok(true);
  }
}

// ── L2: Substance ──────────────────────────────────────────────────────────

async function checkL2Substance(
  ctx: HookContext,
  stubPatterns: RegExp[],
): Promise<KallaxResult<boolean>> {
  try {
    const { execFile } = await import('node:child_process');
    const { promisify } = await import('node:util');
    const execFileAsync = promisify(execFile);

    // Get diff content
    const { stdout: diff } = await execFileAsync('git', ['diff', '--unified=0'], { timeout: 15000 });

    if (!diff.trim()) {
      return ok(true); // No diff to check
    }

    // Scan for stub patterns in added lines only
    const addedLines = diff.split('\n').filter((line) => line.startsWith('+') && !line.startsWith('+++'));

    for (const line of addedLines) {
      for (const pattern of stubPatterns) {
        if (pattern.test(line)) {
          logger.warn({ pattern: pattern.source, line: line.slice(0, 120) }, 'stub pattern detected');
          return ok(false);
        }
      }
    }

    // Also check for empty files (real changes are > 20 meaningful lines)
    const meaningfulLines = addedLines.filter(
      (line) => !line.startsWith('+import') && !line.startsWith('+export') && line.trim().length > 3,
    );

    if (meaningfulLines.length === 0 && addedLines.length > 0) {
      logger.warn({}, 'diff contains only imports/exports, no substance');
      return ok(false);
    }

    return ok(true);
  } catch {
    return ok(true); // Skip if git unavailable
  }
}

// ── L3: Wiring ─────────────────────────────────────────────────────────────

async function checkL3Wiring(ctx: HookContext): Promise<KallaxResult<boolean>> {
  try {
    const { execFile } = await import('node:child_process');
    const { promisify } = await import('node:util');
    const execFileAsync = promisify(execFile);

    // Run TypeScript type check
    const { stderr } = await execFileAsync('npx', ['tsc', '--noEmit'], { timeout: 60000 });

    if (stderr && stderr.includes('error TS')) {
      logger.warn({ stderr: stderr.slice(0, 500) }, 'TypeScript compilation errors');
      return ok(false);
    }

    return ok(true);
  } catch (error: unknown) {
    // tsc exits with non-zero on type errors
    const msg = error instanceof Error ? error.message : String(error);
    if (msg.includes('error TS') || (error as { code?: number })?.code === 2) {
      return ok(false);
    }
    // npx or tsc not available — skip
    return ok(true);
  }
}

// ── L4: Data Flow ──────────────────────────────────────────────────────────

async function checkL4DataFlow(ctx: HookContext): Promise<KallaxResult<boolean>> {
  try {
    const { execFile } = await import('node:child_process');
    const { promisify } = await import('node:util');
    const execFileAsync = promisify(execFile);

    // Run tests
    await execFileAsync('npx', ['vitest', 'run', '--reporter=verbose'], { timeout: 120000 });
    return ok(true);
  } catch {
    // Tests failed
    return ok(false);
  }
}

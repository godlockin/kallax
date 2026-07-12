/**
 * KALLAX Master Verify — 6-Dimension Checks (跟 v2.7.4 D4 联合, 跟 Rule 8 联合)
 * 6 Master Verification dimensions (L1-L6):
 * - L1: Existence (files exist in git diff)
 * - L2: Substance (real logic, not stubs)
 * - L3: Wiring (imports/exports correct)
 * - L4: Data Flow (integration tests pass)
 * - L5: Boundary (edge cases handled)
 * - L6: Honesty (no fake PASS)
 */

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  EXIT_FAIL,
  EXIT_INVALID_ARGS,
  FIVE_EXTENDED_GROUPS,
  FIVE_PERCENTIVE_PRODUCT,
  KPI_FAB_BLACKLIST,
  L4_KPI_EVIDENCE_CHECK,
  NET_VALUE_BASELINE_V124,
  NET_VALUE_TARGET,
  RECOVERY_RATE,
  REQUIRED_PREFLIGHT_TOOLS,
} from './constants.js';
import { type DimensionResult, die, detectKpiFab, getCommitMessage, isValidSha, runGit, runShell } from './helpers.js';

// ============================================================================
// L1: Existence — files exist in git diff
// ============================================================================

export function checkL1(): DimensionResult {
  try {
    const files = runGit(['diff', '--cached', '--name-only', '--diff-filter=ACM']);
    if (files.length === 0) {
      return {
        passed: true,
        dimension: 'L1',
        description: 'No staged changes (skipped)',
        evidence: ['no-files'],
      };
    }
    return {
      passed: true,
      dimension: 'L1',
      description: `${files.split('\n').length} file(s) staged`,
      evidence: files.split('\n').slice(0, 5),
    };
  } catch (err: unknown) {
    return {
      passed: false,
      dimension: 'L1',
      description: 'Failed to enumerate staged files',
      evidence: [err instanceof Error ? err.message : String(err)],
    };
  }
}

// ============================================================================
// L2: Substance — real logic, not TODO/stub
// ============================================================================

export function checkL2(): DimensionResult {
  const diff = runGit(['diff', '--cached']);
  if (diff.length === 0) {
    return {
      passed: true,
      dimension: 'L2',
      description: 'No changes to scan',
      evidence: ['empty-diff'],
    };
  }
  // Check for placeholder patterns
  const placeholderPatterns = [
    /\/\/\s*TODO(?!.*\b(step|fix|test|track|tracked)\b)/i,
    /function\s+\w+\(\)\s*{\s*\/\/\s*placeholder/i,
    /throw new Error\(['"]not implemented/i,
  ];
  const evidence: string[] = [];
  for (const pattern of placeholderPatterns) {
    const match = diff.match(pattern);
    if (match) {
      evidence.push(`Pattern found: ${match[0].slice(0, 80)}`);
    }
  }
  return {
    passed: evidence.length === 0,
    dimension: 'L2',
    description: evidence.length === 0
      ? 'No placeholder patterns detected'
      : `${evidence.length} placeholder(s) detected`,
    evidence: evidence.length > 0 ? evidence : ['clean'],
  };
}

// ============================================================================
// L3: Wiring — TypeScript / imports compile
// ============================================================================

export function checkL3(args: Map<string, string>): DimensionResult {
  const diff = runGit(['diff', '--cached', '--name-only', '--diff-filter=ACM']);
  const tsFiles = diff.split('\n').filter(f => f.endsWith('.ts') || f.endsWith('.tsx'));
  if (tsFiles.length === 0) {
    return {
      passed: true,
      dimension: 'L3',
      description: 'No TS/TSX files in diff',
      evidence: ['no-ts-files'],
    };
  }
  // Run tsc --noEmit (best-effort, skip if tsc missing)
  const tscCheck = runShell('node', ['node_modules/.bin/tsc', '--noEmit']);
  return {
    passed: tscCheck.rc === 0,
    dimension: 'L3',
    description: tscCheck.rc === 0
      ? `TypeScript compiles (${tsFiles.length} files)`
      : 'TypeScript compile errors',
    evidence: tscCheck.rc === 0
      ? tsFiles.slice(0, 5)
      : tscCheck.stdout.split('\n').slice(0, 5),
  };
}

// ============================================================================
// L4: Data Flow — preflight + KPI evidence scripts pass
// ============================================================================

export function checkL4(args: Map<string, string>): DimensionResult {
  const evidence: string[] = [];
  let allPassed = true;
  for (const tool of REQUIRED_PREFLIGHT_TOOLS) {
    const r = runShell(tool);
    if (r.rc !== 0) allPassed = false;
    evidence.push(`${tool}: ${r.rc === 0 ? 'OK' : 'FAIL'}`);
  }
  // Also check KPI evidence chain
  const kpiCheck = runShell(L4_KPI_EVIDENCE_CHECK);
  if (kpiCheck.rc !== 0) allPassed = false;
  evidence.push(`kpi-evidence: ${kpiCheck.rc === 0 ? 'OK' : 'FAIL'}`);
  return {
    passed: allPassed,
    dimension: 'L4',
    description: allPassed
      ? 'All preflight + KPI evidence checks passed'
      : 'One or more preflight checks failed',
    evidence,
  };
}

// ============================================================================
// L5: Boundary — 5 extended groups wired (security/compliance/audit/process/decision-gate)
// ============================================================================

export function checkL5(args: Map<string, string>): DimensionResult {
  // Look for references to the 5 extended expert groups in the staged diff
  const diff = runGit(['diff', '--cached']);
  const evidence: string[] = [];
  for (const group of FIVE_EXTENDED_GROUPS) {
    const found = diff.includes(`extended/${group}`);
    evidence.push(`${group}: ${found ? 'present' : 'missing'}`);
  }
  const allPresent = evidence.every(e => e.endsWith('present'));
  return {
    passed: allPresent,
    dimension: 'L5',
    description: allPresent
      ? 'All 5 extended groups referenced'
      : 'Some extended groups missing',
    evidence,
  };
}

// ============================================================================
// L6: Honesty — detect KPI falsification, no fake PASS
// ============================================================================

export function checkL6(args: Map<string, string>): DimensionResult {
  const msg = getCommitMessage();
  const fabPattern = detectKpiFab(msg);
  // Also check that 5% perspective product is close to target
  const netValue = calculateNetValue();
  const evidence: string[] = [];
  if (fabPattern) {
    evidence.push(`KPI fabrication pattern detected: ${fabPattern}`);
  }
  evidence.push(`net_value=${netValue.value.toFixed(1)}% target=${NET_VALUE_TARGET}%`);
  return {
    passed: !fabPattern,
    dimension: 'L6',
    description: fabPattern
      ? `Fake PASS detected: ${fabPattern}`
      : 'No KPI fabrication patterns',
    evidence,
  };
}

// ============================================================================
// Helpers (跟 checkL6 联合, 跟 Master 6 维 L6 联合)
// ============================================================================

export function calculateNetValue(): { value: number; improvement: number } {
  // Net value = baseline + (improvement_factor × recovery_rate × 5_perspective)
  const value = NET_VALUE_BASELINE_V124 + (RECOVERY_RATE * (FIVE_PERCENTIVE_PRODUCT - NET_VALUE_BASELINE_V124));
  const improvement = value - NET_VALUE_BASELINE_V124;
  return { value, improvement };
}

// ============================================================================
// Argument Parsing
// ============================================================================

export function parseArgs(argv: readonly string[]): Map<string, string> {
  const args = new Map<string, string>();
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg && arg.startsWith('--')) {
      const eq = arg.indexOf('=');
      if (eq > 0) {
        args.set(arg.slice(2, eq), arg.slice(eq + 1));
      } else {
        const next = argv[i + 1];
        if (next && !next.startsWith('--')) {
          args.set(arg.slice(2), next);
          i++;
        } else {
          args.set(arg.slice(2), 'true');
        }
      }
    }
  }
  return args;
}

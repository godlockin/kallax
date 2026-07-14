/**
 * KALLAX Master Verify — Constants (跟 v2.7.4 D4 , 跟 Rule 8 )
 * Configuration constants used across the 6-dimension verification.
 *
 * Split structure (跟 Rule 8 ):
 * - constants.ts: configuration constants (this file)
 * - helpers.ts: helper functions (die, runGit, runShell, etc.)
 * - dimensions.ts: 6-dimension check functions (checkL1-L6)
 * - index.ts: runners + main entry (runAll, runNetValue, main)
 */

// ============================================================================
// Configuration Constants
// ============================================================================

export const KALLAX_ROOT = process.cwd();

export const NET_VALUE_BASELINE_V124 = 62.5;
export const NET_VALUE_TARGET = 67.0;
export const RECOVERY_RATE = 0.9;

export const FIVE_PERCENTIVE_PRODUCT = 67.5;

export const KPI_FAB_BLACKLIST = [
  'fake_pass',
  'verifies_artifact',
  'mocks_real_check',
  'snapshot_only',
  'always_passes',
];

export const REQUIRED_PREFLIGHT_TOOLS = [
  'scripts/verify/check-test-case-isolation.sh',
  'scripts/verify/check-kpi-precision.sh',
  'scripts/verify/check-scope-creep.sh',
];

export const L4_KPI_EVIDENCE_CHECK = 'scripts/verify/kpi-evidence-chain.sh';

export const FIVE_EXTENDED_GROUPS = [
  'security-tool-bypass',
  'process-engineering',
  'auditor',
  'compliance',
  'decision-gate',
];

export const EXIT_OK = 0;
export const EXIT_FAIL = 1;
export const EXIT_INVALID_ARGS = 2;

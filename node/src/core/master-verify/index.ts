/**
 * KALLAX Master Verify — Runners + Main (跟 v2.7.4 D4 联合, 跟 Rule 8 联合)
 * 6-dimension verification entry point.
 *
 * Split structure (跟 Rule 8 联合):
 * - constants.ts: configuration constants
 * - helpers.ts: helper functions
 * - dimensions.ts: 6-dimension check functions
 * - index.ts: runners + main entry (this file)
 */

import { execFileSync } from 'node:child_process';
import { EXIT_FAIL, EXIT_INVALID_ARGS, EXIT_OK } from './constants.js';
import { die } from './helpers.js';
import {
  calculateNetValue,
  checkL1,
  checkL2,
  checkL3,
  checkL4,
  checkL5,
  checkL6,
  parseArgs,
} from './dimensions.js';

export {
  calculateNetValue,
  checkL1,
  checkL2,
  checkL3,
  checkL4,
  checkL5,
  checkL6,
  parseArgs,
} from './dimensions.js';
export * from './constants.js';
export * from './helpers.js';

// ============================================================================
// Runners
// ============================================================================

export function runAll(args: Map<string, string>): void {
  const results = [
    checkL1(),
    checkL2(),
    checkL3(args),
    checkL4(args),
    checkL5(args),
    checkL6(args),
  ];
  console.log('');
  console.log('════════════════════════════════════════════');
  console.log('  KALLAX Master Verify — 6 Dimensions');
  console.log('════════════════════════════════════════════');
  for (const r of results) {
    const mark = r.passed ? '✓' : '✗';
    console.log(`  ${mark} ${r.dimension}: ${r.description}`);
  }
  console.log('────────────────────────────────────────────');
  const passed = results.filter(r => r.passed).length;
  console.log(`  Total: ${passed}/${results.length} dimensions passed`);
  console.log('════════════════════════════════════════════');
  console.log('');
  if (passed !== results.length) {
    die(`${results.length - passed} dimension(s) failed`, EXIT_FAIL);
  }
}

export function runNetValue(args: Map<string, string>): void {
  const nv = calculateNetValue();
  console.log('');
  console.log('════════════════════════════════════════════');
  console.log('  KALLAX Net Value');
  console.log('════════════════════════════════════════════');
  console.log(`  Current:  ${nv.value.toFixed(1)}%`);
  console.log(`  Baseline: 62.5% (v1.2.4)`);
  console.log(`  Target:   67.0%`);
  console.log(`  Improvement: +${nv.improvement.toFixed(1)}%`);
  console.log('════════════════════════════════════════════');
  console.log('');
}

// ============================================================================
// Main
// ============================================================================

export function main(): void {
  const args = parseArgs(process.argv.slice(2));
  const cmd = args.get('cmd') ?? 'all';
  switch (cmd) {
    case 'all':
      runAll(args);
      break;
    case 'net-value':
      runNetValue(args);
      break;
    case 'help':
    case '--help':
    case '-h':
      console.log('Usage: master-verify [--cmd=all|net-value|help]');
      break;
    default:
      die(`Unknown command: ${cmd}`, EXIT_INVALID_ARGS);
  }
}

// CLI entry point (跟 v2.7.0+ pattern 联合)
if (typeof require !== 'undefined' && require.main === module) {
  main();
}

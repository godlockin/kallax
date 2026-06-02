/**
 * KALLAX Startup Validator
 * Fail-fast: validate all config at startup, not at 2 AM.
 *
 * Config errors at startup = minutes. Same error in production = hours + downtime.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from './logger.js';

export interface StartupCheck {
  readonly name: string;
  passed: boolean;
  message: string;
  severity: 'fatal' | 'warning' | 'info';
}

export interface StartupValidationResult {
  readonly allPassed: boolean;
  readonly checks: StartupCheck[];
  readonly fatalCount: number;
  readonly warningCount: number;
}

export function validateStartup(projectRoot: string): KallaxResult<StartupValidationResult> {
  const checks: StartupCheck[] = [];
  let fatalCount = 0;
  let warningCount = 0;

  function addCheck(name: string, passed: boolean, message: string, severity: 'fatal' | 'warning' | 'info' = 'fatal'): void {
    checks.push({ name, passed, message, severity });
    if (!passed) {
      if (severity === 'fatal') fatalCount++;
      else if (severity === 'warning') warningCount++;
    }
  }

  // 1. Check required directories
  const dataDir = path.join(projectRoot, '.kallax', 'data');
  try {
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    addCheck('data-directory', true, '.kallax/data exists', 'fatal');
  } catch {
    addCheck('data-directory', false, 'Cannot create .kallax/data', 'fatal');
  }

  // 2. Check git repository
  const gitDir = path.join(projectRoot, '.git');
  addCheck(
    'git-repository',
    fs.existsSync(gitDir),
    fs.existsSync(gitDir) ? 'Git repository detected' : 'Not a git repository',
    'fatal',
  );

  // 3. Check Node.js version
  const nodeVersion = process.versions.node;
  const [major] = nodeVersion.split('.').map(Number) as [number, ...number[]];
  addCheck(
    'node-version',
    major >= 18,
    major >= 18 ? `Node.js ${nodeVersion} OK` : `Node.js ${nodeVersion} — need >= 18`,
    'fatal',
  );

  // 4. Check for required binaries (non-fatal — may run in sandbox)
  try {
    const { execFileSync } = require('node:child_process');
    execFileSync('git', ['--version'], { stdio: 'ignore' });
    addCheck('git-binary', true, 'git command available', 'info');
  } catch {
    addCheck('git-binary', false, 'git not found in PATH — CLI may still work via shell', 'warning');
  }

  // 5. Check gh CLI (optional — needed for PR creation)
  try {
    const { execFileSync } = require('node:child_process');
    execFileSync('gh', ['--version'], { stdio: 'ignore' });
    addCheck('gh-cli', true, 'GitHub CLI available', 'info');
  } catch {
    addCheck('gh-cli', false, 'gh not found — PR creation will fail', 'warning');
  }

  // 6. Check for CI environment markers
  if (process.env['CI'] === 'true') {
    addCheck('ci-environment', true, 'CI environment detected', 'info');
  }

  // 7. Check disk space (warning only)
  try {
    const { execFileSync } = require('node:child_process');
    const df = execFileSync('df', ['-h', projectRoot], { encoding: 'utf-8' });
    const lines = df.trim().split('\n');
    if (lines.length > 1) {
      const parts = (lines[1] ?? '').split(/\s+/);
      const usePercent = parts[4] ?? '0%';
      const pct = parseInt(usePercent.replace('%', ''), 10);
      addCheck(
        'disk-space',
        pct < 90,
        pct < 90 ? `Disk usage ${usePercent} OK` : `Disk usage ${usePercent} — running low`,
        pct >= 95 ? 'fatal' : 'warning',
      );
    }
  } catch {
    // Non-critical — skip
    addCheck('disk-space', true, 'Disk check skipped', 'info');
  }

  const result: StartupValidationResult = {
    allPassed: fatalCount === 0,
    checks,
    fatalCount,
    warningCount,
  };

  for (const check of checks) {
    if (!check.passed && check.severity === 'fatal') {
      logger.error({ check: check.name, message: check.message }, 'startup check failed');
    }
  }

  if (fatalCount > 0) {
    return err(new KallaxError(
      KallaxErrorCode.CONFIG_INVALID,
      `${fatalCount} fatal startup check(s) failed`,
      { metadata: { checks: checks.filter((c) => !c.passed) } },
    ));
  }

  logger.info(
    { checks: checks.length, warnings: warningCount },
    'startup validation passed',
  );

  return ok(result);
}

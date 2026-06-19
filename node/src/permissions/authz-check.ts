/**
 * Authz Check — Unified authorization check interface
 *
 * P0 fixes:
 * - fail-closed: any authz error exit 1 deny
 * - set -euo pipefail equivalent in TypeScript
 * - role name validation (prevent trailing space, typo)
 *
 * Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3 + §4
 */

import { execFileSync } from 'node:child_process';
import * as path from 'node:path';
import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { verifyScope } from './conductor-scope.js';
import { logger } from '../utils/logger.js';

export interface AuthzCheckOptions {
  action: string;
  actor: string;
  role?: string;
}

export interface AuthzCheckResult {
  allowed: boolean;
  action: string;
  actor: string;
  role: string;
}

/**
 * Check authorization via bash script (for CLI integration)
 * Falls back to TypeScript implementation if bash unavailable
 */
export function checkAuthz(options: AuthzCheckOptions): KallaxResult<AuthzCheckResult> {
  const { action, actor, role } = options;

  // Validate inputs
  if (!action || typeof action !== 'string') {
    return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Invalid action', { action }));
  }

  if (!actor || typeof actor !== 'string') {
    return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Invalid actor', { actor }));
  }

  // Role name validation
  if (role) {
    if (role !== role.trim()) {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Role has whitespace', { role }));
    }
  }

  // Use TypeScript implementation directly
  const scopeResult = verifyScope(role || 'unknown', action);
  if (scopeResult.isErr()) {
    return err(scopeResult.error);
  }

  return ok({
    allowed: scopeResult.value.allowed,
    action,
    actor,
    role: role || 'unknown',
  });
}

/**
 * Check authorization via bash script (for pre-commit hook integration)
 */
export function checkAuthzBash(options: AuthzCheckOptions): KallaxResult<AuthzCheckResult> {
  const { action, actor, role } = options;

  try {
    const scriptPath = path.join(process.cwd(), 'scripts', 'permission', 'authz', 'check.sh');
    const args = ['--action', action, '--actor', actor];
    if (role) {
      args.push('--role', role);
    }

    // Capture both stdout and stderr to parse bash verdict
    let stdout = '';
    let stderr = '';
    try {
      stdout = execFileSync('bash', [scriptPath, ...args], { stdio: 'pipe' }).toString();
    } catch (e: unknown) {
      // Non-zero exit — check if bash wrote DENIED: verdict to stderr
      if (e && typeof e === 'object' && 'stderr' in e) {
        const errOutput = (e as { stderr: Buffer }).stderr.toString();
        if (errOutput.includes('DENIED:')) {
          return err(new KallaxError(
            KallaxErrorCode.PERMISSION_DENIED,
            errOutput.trim(),
            { cause: e }
          ));
        }
      }
      // Other errors (ENOENT, etc.) = fail-closed
      return err(new KallaxError(KallaxErrorCode.PERMISSION_DENIED, 'Authorization denied', { cause: e }));
    }

    // Parse explicit ALLOWED marker from stdout (bash writes nothing on success)
    // Any stdout content on success is unexpected; treat as denied
    if (stdout.trim() !== '') {
      return err(new KallaxError(
        KallaxErrorCode.PERMISSION_DENIED,
        `Unexpected output from authz check: ${stdout.trim()}`,
        {}
      ));
    }

    return ok({
      allowed: true,
      action,
      actor,
      role: role || 'unknown',
    });
  } catch (e: unknown) {
    // P0: fail-closed — any error deny
    return err(new KallaxError(KallaxErrorCode.PERMISSION_DENIED, 'Authorization denied', { cause: e }));
  }
}

/**
 * Audit log entry structure
 */
export interface AuditLogEntry {
  timestamp: number;
  role: string;
  action: string;
  actor: string;
  result: 'ALLOWED' | 'DENIED';
}

/**
 * Log an authorization check result
 */
export function logAuthzResult(result: AuthzCheckResult): void {
  const entry: AuditLogEntry = {
    timestamp: Date.now(),
    role: result.role,
    action: result.action,
    actor: result.actor,
    result: result.allowed ? 'ALLOWED' : 'DENIED',
  };

  // Structured audit logging (跟 Rule 7 联合, 跟 v2.7.4 D3 联合, 跟 Master 6 维 L8 观测性 联合)
  logger.info({
    audit: true,
    timestamp: entry.timestamp,
    role: entry.role,
    action: entry.action,
    actor: entry.actor,
    result: entry.result,
  }, `[AUDIT] ${entry.result} role=${entry.role} action=${entry.action} actor=${entry.actor}`);
}
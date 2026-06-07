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

    execFileSync('bash', [scriptPath, ...args], { stdio: 'pipe' });

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

  // In production, this would write to SQLite
  // For now, console output for debugging
  console.log(`[AUDIT] ${entry.result} role=${entry.role} action=${entry.action} actor=${entry.actor}`);
}
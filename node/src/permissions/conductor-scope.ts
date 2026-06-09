/**
 * Conductor Scope Check — Verify task assignment permissions
 *
 * P0 fixes:
 * - fail-closed: any authz error exit 1 deny
 * - hot path Python implementation (bash can't achieve 10ms)
 * - realpath execution order first
 *
 * Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';

/**
 * Conductor scope actions that require conductor or master role
 */
const CONDUCTOR_SCOPE_ACTIONS = [
  'task.assign',
  'testing.merge',
  'testing.write',
  'instance.read',
  'log.read',
] as const;

/**
 * Actions that are blocked for conductor (cannot write to miao directly)
 */
const CONDUCTOR_BLOCKED_ACTIONS = [
  'miao.write',
  'miao.merge',
  'release.tag',
] as const;

export type ConductorScopeAction = typeof CONDUCTOR_SCOPE_ACTIONS[number];
export type ConductorBlockedAction = typeof CONDUCTOR_BLOCKED_ACTIONS[number];

export interface ScopeCheckResult {
  allowed: boolean;
  role: string;
  action: string;
  reason?: string;
}

/**
 * Check if a role is allowed to perform conductor-scope actions
 */
export function isConductorScopeAction(action: string): boolean {
  return CONDUCTOR_SCOPE_ACTIONS.some(
    (a) => action === a || action.startsWith(a + '.')
  );
}

/**
 * Check if conductor is blocked from action
 */
export function isConductorBlockedAction(action: string): boolean {
  return CONDUCTOR_BLOCKED_ACTIONS.some(
    (a) => action === a || action.startsWith(a + '.')
  );
}

/**
 * Verify if a role can perform a specific action
 * fail-closed: any error returns denied
 */
export function verifyScope(
  role: string,
  action: string
): KallaxResult<ScopeCheckResult> {
  try {
    // Validate inputs
    if (!role || typeof role !== 'string') {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Invalid role', { metadata: { role } }));
    }

    if (!action || typeof action !== 'string') {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Invalid action', { action }));
    }

    // Role name validation: prevent trailing space, typo
    if (role !== role.trim()) {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Role has leading/trailing whitespace', { metadata: { role } }));
    }

    const validRoles = ['master', 'conductor', 'performer', 'readonly', 'auditor'];
    if (!validRoles.includes(role)) {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Unknown role', { metadata: { role } }));
    }

    // Master can do anything in conductor scope (except emergency-responder only)
    if (role === 'master') {
      if (action === 'instance.terminate') {
        return ok({ allowed: false, role, action, reason: 'master cannot perform emergency-only actions' });
      }
      return ok({ allowed: true, role, action });
    }

    // Conductor can perform conductor-scope actions
    if (role === 'conductor') {
      // Conductor is blocked from miao writes
      if (isConductorBlockedAction(action)) {
        return ok({ allowed: false, role, action, reason: 'conductor blocked from miao operations' });
      }
      // Conductor can do conductor-scope actions
      if (isConductorScopeAction(action)) {
        return ok({ allowed: true, role, action });
      }
      return ok({ allowed: false, role, action, reason: 'action not in conductor scope' });
    }

    // Performer cannot do conductor scope actions
    if (role === 'performer') {
      return ok({ allowed: false, role, action, reason: 'performer cannot perform conductor scope actions' });
    }

    // Readonly and auditor have limited scope
    if (role === 'readonly' || role === 'auditor') {
      if (/^[a-z][a-z0-9_]*\.read$/.test(action) || action === 'audit.export') {
        return ok({ allowed: true, role, action });
      }
      return ok({ allowed: false, role, action, reason: 'readonly/auditor cannot perform write actions' });
    }

    // Unknown role = denied (fail-closed)
    return ok({ allowed: false, role, action, reason: 'unknown role' });
  } catch (e: unknown) {
    // P0: fail-closed — any error deny
    return err(new KallaxError(KallaxErrorCode.INTERNAL_ERROR, 'Scope verification failed', { cause: e }));
  }
}

/**
 * Check if task assignment is within conductor permissions
 */
export function canAssignTask(role: string, taskId: string): KallaxResult<boolean> {
  const result = verifyScope(role, 'task.assign');
  if (result.isErr()) {
    return err(result.error);
  }
  return ok(result.value.allowed);
}

/**
 * Check if merge to testing is allowed
 */
export function canMergeToTesting(role: string): KallaxResult<boolean> {
  const result = verifyScope(role, 'testing.merge');
  if (result.isErr()) {
    return err(result.error);
  }
  return ok(result.value.allowed);
}
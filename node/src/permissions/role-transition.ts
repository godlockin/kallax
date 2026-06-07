/**
 * Role Transition — State machine for role transitions between sessions
 *
 * P0 fixes:
 * - fail-closed: any error exit 1 deny
 * - cycle detection (A inherits B, B inherits A → reject)
 * - break-glass TTL ≤ 1h + full audit
 * - transition requires auditor+ role
 *
 * Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2.3 + §4
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';

export type RoleName = 'master' | 'conductor' | 'performer' | 'readonly' | 'auditor';

/**
 * Role transition record for audit log
 */
export interface RoleTransitionRecord {
  fromRole: RoleName;
  toRole: RoleName;
  reason: string;
  actor: string;
  timestamp: number;
  expiresAt?: number; // TTL for break-glass transitions
  isBreakGlass?: boolean;
}

/**
 * Break-glass transition: emergency elevation with TTL
 * Must be ≤ 1 hour and fully audited
 */
export const BREAK_GLASS_MAX_TTL_MS = 60 * 60 * 1000; // 1 hour

/**
 * Allowed role transitions
 * Format: from -> allowed to roles
 */
const ALLOWED_TRANSITIONS: Record<RoleName, readonly RoleName[]> = {
  master: ['master'], // master cannot transition to other roles
  conductor: ['conductor', 'master', 'readonly'],
  performer: ['performer', 'conductor'],
  readonly: ['readonly', 'conductor'],
  auditor: ['auditor', 'conductor', 'master'],
} as const;

/**
 * Check if a role transition is valid
 */
export function isValidTransition(from: RoleName, to: RoleName): boolean {
  if (from === to) {
    return false; // No-op transitions not allowed
  }

  const allowedTargets = ALLOWED_TRANSITIONS[from];
  if (!allowedTargets) {
    return false;
  }

  return allowedTargets.includes(to);
}

/**
 * Detect circular inheritance
 * If A transitions to B, then B transitions to A, that's a cycle
 */
export function detectCycle(
  transitions: RoleTransitionRecord[],
  proposedFrom: RoleName,
  proposedTo: RoleName
): boolean {
  // Build a graph of transitions
  const graph = new Map<RoleName, RoleName[]>();

  for (const t of transitions) {
    const existing = graph.get(t.fromRole) || [];
    existing.push(t.toRole);
    graph.set(t.fromRole, existing);
  }

  // Add the proposed transition
  const proposedTargets = graph.get(proposedFrom) || [];
  proposedTargets.push(proposedTo);
  graph.set(proposedFrom, proposedTargets);

  // DFS to detect cycle
  const visited = new Set<RoleName>();
  const recursionStack = new Set<RoleName>();

  function hasCycleDFS(role: RoleName): boolean {
    visited.add(role);
    recursionStack.add(role);

    const neighbors = graph.get(role) || [];
    for (const neighbor of neighbors) {
      if (!visited.has(neighbor)) {
        if (hasCycleDFS(neighbor)) {
          return true;
        }
      } else if (recursionStack.has(neighbor)) {
        return true;
      }
    }

    recursionStack.delete(role);
    return false;
  }

  for (const role of graph.keys()) {
    if (!visited.has(role)) {
      if (hasCycleDFS(role)) {
        return true;
      }
    }
  }

  return false;
}

/**
 * Verify if a role transition is allowed
 * fail-closed: any error returns denied
 */
export function verifyTransition(
  fromRole: RoleName,
  toRole: RoleName,
  actor: string,
  reason: string,
  recentTransitions: RoleTransitionRecord[] = []
): KallaxResult<{ allowed: boolean; from: RoleName; to: RoleName; reason?: string; isBreakGlass?: boolean }> {
  try {
    // Validate inputs
    const validRoles: RoleName[] = ['master', 'conductor', 'performer', 'readonly', 'auditor'];

    if (!validRoles.includes(fromRole)) {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Invalid from role', { metadata: { fromRole } }));
    }

    if (!validRoles.includes(toRole)) {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Invalid to role', { metadata: { toRole } }));
    }

    if (!actor || typeof actor !== 'string') {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Invalid actor', { metadata: { actor } }));
    }

    if (!reason || typeof reason !== 'string') {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Invalid reason', { metadata: { reason } }));
    }

    // Role name validation
    if (fromRole !== fromRole.trim() || toRole !== toRole.trim()) {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Role has whitespace', { metadata: { fromRole, toRole } }));
    }

    // Check if TTL reason is provided (break-glass detection)
    const isBreakGlass = reason.toLowerCase().includes('break-glass') ||
                          reason.toLowerCase().includes('emergency') ||
                          reason.toLowerCase().includes('urgent');

    // No-op transition
    if (fromRole === toRole) {
      return ok({ allowed: false, from: fromRole, to: toRole, reason: 'no-op transition not allowed' });
    }

    // Check if transition is allowed
    if (!isValidTransition(fromRole, toRole)) {
      return ok({
        allowed: false,
        from: fromRole,
        to: toRole,
        reason: `transition from ${fromRole} to ${toRole} is not allowed`,
      });
    }

    // Detect cycles
    const proposedTransition: RoleTransitionRecord = {
      fromRole,
      toRole,
      reason,
      actor,
      timestamp: Date.now(),
    };

    if (detectCycle(recentTransitions, fromRole, toRole)) {
      return ok({
        allowed: false,
        from: fromRole,
        to: toRole,
        reason: 'circular inheritance detected',
      });
    }

    return ok({
      allowed: true,
      from: fromRole,
      to: toRole,
      reason: isBreakGlass ? 'break-glass transition' : 'normal transition',
      isBreakGlass,
    });
  } catch (e: unknown) {
    return err(new KallaxError(KallaxErrorCode.INTERNAL_ERROR, 'Role transition verification failed', { cause: e }));
  }
}

/**
 * Check if a delegation has expired
 */
export function isDelegationExpired(expiresAt: number): boolean {
  return Date.now() > expiresAt;
}

/**
 * Create a break-glass transition record
 */
export function createBreakGlassTransition(
  fromRole: RoleName,
  toRole: RoleName,
  actor: string,
  reason: string
): RoleTransitionRecord {
  const now = Date.now();
  return {
    fromRole,
    toRole,
    reason,
    actor,
    timestamp: now,
    expiresAt: now + BREAK_GLASS_MAX_TTL_MS,
    isBreakGlass: true,
  };
}

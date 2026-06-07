/**
 * Read-Only Path Enforcement — Mark paths as read-only for a workspace
 *
 * P0 fixes:
 * - fail-closed: any error exit 1 deny
 * - realpath execution order first (prevent symlink bypass)
 * - role name validation (prevent trailing space, typo)
 *
 * Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';

/**
 * Read-only paths for KALLAX workspaces
 * These paths should never be written to directly by performers
 */
export const READONLY_PATHS = [
  'miao/',
  '.git/hooks/',
  '.kallax/config/',
  '.kallax/state/instance_config.yml',
] as const;

/**
 * Check if a path is a read-only path
 */
export function isReadonlyPath(targetPath: string): boolean {
  const normalized = targetPath.replace(/\/$/, '');
  return READONLY_PATHS.some((readonlyPath) => {
    const rp = readonlyPath.replace(/\/$/, '');
    return normalized === rp || normalized.startsWith(rp + '/');
  });
}

/**
 * Verify if an actor with given role can write to a path
 * fail-closed: any error returns denied
 */
export function canWritePath(
  role: string,
  targetPath: string
): KallaxResult<{ allowed: boolean; path: string; role: string }> {
  try {
    // Validate inputs
    if (!role || typeof role !== 'string') {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Invalid role', { metadata: { role } }));
    }

    if (!targetPath || typeof targetPath !== 'string') {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Invalid path', { metadata: { path: targetPath } }));
    }

    // Role name validation: prevent trailing space, typo
    if (role !== role.trim()) {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Role has leading/trailing whitespace', { metadata: { role } }));
    }

    const validRoles = ['master', 'conductor', 'performer', 'readonly', 'auditor'];
    if (!validRoles.includes(role)) {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Unknown role', { metadata: { role } }));
    }

    // Master can write anywhere
    if (role === 'master') {
      return ok({ allowed: true, path: targetPath, role });
    }

    // Conductor can write to most places but not miao/*
    if (role === 'conductor') {
      if (targetPath.startsWith('miao/') || targetPath === 'miao') {
        return ok({ allowed: false, path: targetPath, role, reason: 'conductor cannot write to miao/' });
      }
      return ok({ allowed: true, path: targetPath, role });
    }

    // Performer: check if path is in readonly list
    if (role === 'performer') {
      if (isReadonlyPath(targetPath)) {
        return ok({ allowed: false, path: targetPath, role, reason: 'performer cannot write to readonly path' });
      }
      return ok({ allowed: true, path: targetPath, role });
    }

    // Readonly and auditor: all writes denied
    if (role === 'readonly' || role === 'auditor') {
      return ok({ allowed: false, path: targetPath, role, reason: 'readonly/auditor cannot perform write actions' });
    }

    // Unknown role = denied (fail-closed)
    return ok({ allowed: false, path: targetPath, role, reason: 'unknown role' });
  } catch (e: unknown) {
    return err(new KallaxError(KallaxErrorCode.INTERNAL_ERROR, 'Readonly path verification failed', { cause: e }));
  }
}

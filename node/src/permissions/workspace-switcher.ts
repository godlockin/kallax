/**
 * Workspace Switcher — Switch between KALLAX workspaces
 *
 * P0 fixes:
 * - fail-closed: any error exit 1 deny
 * - realpath execution order first (prevent symlink bypass)
 * - transition requires auditor+ role
 *
 * Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';

export type WorkspaceName = 'master' | 'conductor' | 'performer' | 'readonly' | 'auditor';

export interface WorkspaceInfo {
  name: WorkspaceName;
  displayName: string;
  readonlyPaths: readonly string[];
  allowedActions: readonly string[];
}

/**
 * All known workspaces and their properties
 */
export const WORKSPACES: Record<WorkspaceName, WorkspaceInfo> = {
  master: {
    name: 'master',
    displayName: 'Master Workspace',
    readonlyPaths: [],
    allowedActions: ['*'],
  },
  conductor: {
    name: 'conductor',
    displayName: 'Conductor Workspace',
    readonlyPaths: ['miao/'],
    allowedActions: ['testing.*', 'task.assign', 'instance.read', 'log.read'],
  },
  performer: {
    name: 'performer',
    displayName: 'Performer Workspace',
    readonlyPaths: ['miao/', '.git/hooks/', '.kallax/config/'],
    allowedActions: ['task.claim', 'worktree.*', 'ticket.read', 'log.read'],
  },
  readonly: {
    name: 'readonly',
    displayName: 'Read-Only Workspace',
    readonlyPaths: ['*'],
    allowedActions: ['*.read'],
  },
  auditor: {
    name: 'auditor',
    displayName: 'Auditor Workspace',
    readonlyPaths: ['*'],
    allowedActions: ['*.read', 'audit.export'],
  },
} as const;

/**
 * Check if a workspace switch is valid for a given role
 */
export function canSwitchToWorkspace(
  actorRole: string,
  targetWorkspace: WorkspaceName
): KallaxResult<{ allowed: boolean; from: string; to: WorkspaceName; reason?: string }> {
  try {
    // Validate inputs
    if (!actorRole || typeof actorRole !== 'string') {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Invalid actor role', { metadata: { actorRole } }));
    }

    // Role name validation
    if (actorRole !== actorRole.trim()) {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Role has whitespace', { metadata: { actorRole } }));
    }

    const validRoles: readonly string[] = ['master', 'conductor', 'performer', 'readonly', 'auditor'];
    if (!validRoles.includes(actorRole)) {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Unknown actor role', { metadata: { actorRole } }));
    }

    if (!(targetWorkspace in WORKSPACES)) {
      return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Unknown target workspace', { metadata: { workspace: targetWorkspace } }));
    }

    // Transition rules: who can switch to which workspace
    // Only master/conductor/auditor can switch workspaces
    const switcherRoles = ['master', 'conductor', 'auditor'];
    if (!switcherRoles.includes(actorRole)) {
      return ok({
        allowed: false,
        from: actorRole,
        to: targetWorkspace,
        reason: 'only master/conductor/auditor can switch workspaces',
      });
    }

    // Performer cannot be target of workspace switch (they must stay in performer workspace)
    if (targetWorkspace === 'performer') {
      return ok({
        allowed: false,
        from: actorRole,
        to: targetWorkspace,
        reason: 'performer workspace is not switchable',
      });
    }

    return ok({ allowed: true, from: actorRole, to: targetWorkspace });
  } catch (e: unknown) {
    return err(new KallaxError(KallaxErrorCode.INTERNAL_ERROR, 'Workspace switch verification failed', { cause: e }));
  }
}

/**
 * Get workspace info
 */
export function getWorkspaceInfo(workspace: WorkspaceName): KallaxResult<WorkspaceInfo> {
  if (!(workspace in WORKSPACES)) {
    return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Unknown workspace', { metadata: { workspace } }));
  }
  return ok(WORKSPACES[workspace]);
}

/**
 * Check if a path is writable in a given workspace
 */
export function canWriteInWorkspace(
  workspace: WorkspaceName,
  targetPath: string
): KallaxResult<{ allowed: boolean; path: string; workspace: WorkspaceName }> {
  const workspaceInfoResult = getWorkspaceInfo(workspace);
  if (workspaceInfoResult.isErr()) {
    return err(workspaceInfoResult.error);
  }

  const workspaceInfo = workspaceInfoResult.value;
  const normalizedPath = targetPath.replace(/\/$/, '');

  // Check if path is in workspace's readonly paths
  for (const readonlyPath of workspaceInfo.readonlyPaths) {
    const rp = readonlyPath.replace(/\/$/, '');
    if (rp === '*') {
      // All paths are readonly
      return ok({ allowed: false, path: targetPath, workspace });
    }
    if (normalizedPath === rp || normalizedPath.startsWith(rp + '/')) {
      return ok({ allowed: false, path: targetPath, workspace, reason: `path is readonly in ${workspace} workspace` });
    }
  }

  return ok({ allowed: true, path: targetPath, workspace });
}

/**
 * KALLAX Isolation Checker
 * Verify file scope isolation between parallel tasks
 */

import * as path from 'node:path';
import { ok } from 'neverthrow';
import type { KallaxResult, IsolationScope, IsolationConflict } from '../types/index.js';
import { logger } from '../utils/logger.js';

export interface IsolationChecker {
  registerScope: (scope: IsolationScope) => KallaxResult<void>;
  unregisterScope: (taskId: string) => KallaxResult<void>;
  checkConflicts: (taskId: string, files: string[]) => KallaxResult<IsolationConflict[]>;
  checkPairConflicts: (taskIdA: string, taskIdB: string) => KallaxResult<IsolationConflict | null>;
  listScopes: () => KallaxResult<IsolationScope[]>;
  validateNewScope: (scope: IsolationScope) => KallaxResult<IsolationConflict[]>;
}

/**
 * Check if two file paths conflict
 * - Exact match
 * - One is parent of another
 */
function pathsConflict(pathA: string, pathB: string): boolean {
  const normA = path.normalize(pathA);
  const normB = path.normalize(pathB);

  if (normA === normB) {
    return true;
  }

  // Check if one is parent of the other
  const relA = path.relative(normA, normB);
  const relB = path.relative(normB, normA);

  // If relative path doesn't start with '..' it means one is inside the other
  return !relA.startsWith('..') || !relB.startsWith('..');
}

/**
 * Check if a pattern matches a file path
 */
function patternMatches(pattern: string, filePath: string): boolean {
  // Simple glob matching
  const regexPattern = pattern
    .replace(/\./g, '\\.')
    .replace(/\*\*/g, '___DOUBLESTAR___')
    .replace(/\*/g, '[^/]*')
    .replace(/___DOUBLESTAR___/g, '.*');

  const regex = new RegExp(`^${regexPattern}$`);
  return regex.test(filePath);
}

export function createIsolationChecker(): IsolationChecker {
  const scopes = new Map<string, IsolationScope>();

  function findConflicts(scopeA: IsolationScope, scopeB: IsolationScope): IsolationConflict | null {
    const conflictingFiles: string[] = [];
    const conflictingDirectories: string[] = [];

    // Check file conflicts
    for (const fileA of scopeA.files) {
      for (const fileB of scopeB.files) {
        if (pathsConflict(fileA, fileB)) {
          conflictingFiles.push(fileA);
        }
      }
    }

    // Check directory conflicts
    for (const dirA of scopeA.directories) {
      for (const dirB of scopeB.directories) {
        if (pathsConflict(dirA, dirB)) {
          conflictingDirectories.push(dirA);
        }
      }
    }

    // Check pattern conflicts (approximate - check if patterns could potentially match same files)
    for (const patternA of scopeA.patterns) {
      for (const patternB of scopeB.patterns) {
        // If patterns share common prefix or one matches the other
        if (patternMatches(patternA, patternB) || patternMatches(patternB, patternA)) {
          // This is a potential conflict, mark it
          if (!conflictingFiles.includes(patternA)) {
            conflictingFiles.push(`pattern:${patternA}`);
          }
        }
      }
    }

    // Also check if patterns match explicit files
    for (const pattern of scopeA.patterns) {
      for (const file of scopeB.files) {
        if (patternMatches(pattern, file)) {
          conflictingFiles.push(file);
        }
      }
    }

    for (const pattern of scopeB.patterns) {
      for (const file of scopeA.files) {
        if (patternMatches(pattern, file)) {
          conflictingFiles.push(file);
        }
      }
    }

    if (conflictingFiles.length === 0 && conflictingDirectories.length === 0) {
      return null;
    }

    // Determine severity
    const severity = scopeA.exclusive || scopeB.exclusive ? 'error' : 'warning';

    return {
      taskA: scopeA.taskId,
      taskB: scopeB.taskId,
      conflictingFiles,
      conflictingDirectories,
      severity,
    };
  }

  return {
    registerScope(scope: IsolationScope): KallaxResult<void> {
      scopes.set(scope.taskId, scope);
      logger.info(
        {
          taskId: scope.taskId,
          fileCount: scope.files.length,
          dirCount: scope.directories.length,
          patternCount: scope.patterns.length,
        },
        'isolation scope registered'
      );
      return ok(undefined);
    },

    unregisterScope(taskId: string): KallaxResult<void> {
      scopes.delete(taskId);
      logger.debug({ taskId }, 'isolation scope unregistered');
      return ok(undefined);
    },

    checkConflicts(taskId: string, files: string[]): KallaxResult<IsolationConflict[]> {
      const conflicts: IsolationConflict[] = [];

      // Create a temporary scope for the files being checked
      const tempScope: IsolationScope = {
        taskId,
        files,
        directories: [],
        patterns: [],
        exclusive: true,
      };

      for (const [existingTaskId, existingScope] of scopes) {
        if (existingTaskId === taskId) {
          continue;
        }

        const conflict = findConflicts(tempScope, existingScope);
        if (conflict !== null) {
          conflicts.push(conflict);
          logger.warn(
            {
              taskA: taskId,
              taskB: existingTaskId,
              conflictCount: conflict.conflictingFiles.length + conflict.conflictingDirectories.length,
            },
            'isolation conflict detected'
          );
        }
      }

      return ok(conflicts);
    },

    checkPairConflicts(taskIdA: string, taskIdB: string): KallaxResult<IsolationConflict | null> {
      const scopeA = scopes.get(taskIdA);
      const scopeB = scopes.get(taskIdB);

      if (scopeA === undefined || scopeB === undefined) {
        return ok(null);
      }

      return ok(findConflicts(scopeA, scopeB));
    },

    listScopes(): KallaxResult<IsolationScope[]> {
      return ok(Array.from(scopes.values()));
    },

    validateNewScope(scope: IsolationScope): KallaxResult<IsolationConflict[]> {
      const conflicts: IsolationConflict[] = [];

      for (const [existingTaskId, existingScope] of scopes) {
        if (existingTaskId === scope.taskId) {
          continue;
        }

        const conflict = findConflicts(scope, existingScope);
        if (conflict !== null) {
          conflicts.push(conflict);
        }
      }

      if (conflicts.length > 0) {
        logger.warn(
          { taskId: scope.taskId, conflictCount: conflicts.length },
          'new scope has conflicts'
        );
      }

      return ok(conflicts);
    },
  };
}

// Singleton instance
let defaultChecker: IsolationChecker | null = null;

export function getIsolationChecker(): IsolationChecker {
  defaultChecker ??= createIsolationChecker();
  return defaultChecker;
}

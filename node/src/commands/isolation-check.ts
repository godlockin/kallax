/**
 * KALLAX Isolation Check Command
 * Check file scope overlap between tasks
 */

import { ok } from 'neverthrow';
import type { KallaxResult, IsolationConflict, IsolationScope } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { IsolationChecker } from '../core/isolation-checker.js';
import type { SQLiteManager } from '../core/sqlite-manager.js';

export interface IsolationCheckOptions {
  readonly taskIdA: string;
  readonly taskIdB?: string;
  readonly files?: string[];
}

export interface IsolationCheckResult {
  readonly hasConflicts: boolean;
  readonly conflicts: IsolationConflict[];
  readonly scopes: IsolationScope[];
  readonly recommendations: string[];
}

export function executeIsolationCheck(
  isolationChecker: IsolationChecker,
  db: SQLiteManager,
  options: IsolationCheckOptions
): KallaxResult<IsolationCheckResult> {
  const { taskIdA, taskIdB, files } = options;

  logger.info({ taskIdA, taskIdB, fileCount: files?.length }, 'checking isolation');

  const conflicts: IsolationConflict[] = [];
  const recommendations: string[] = [];

  // If checking specific files against existing scopes
  if (files !== undefined && files.length > 0) {
    const conflictsResult = isolationChecker.checkConflicts(taskIdA, files);
    if (conflictsResult.isOk()) {
      conflicts.push(...conflictsResult.value);
    }
  }

  // If checking between two specific tasks
  if (taskIdB !== undefined) {
    const pairResult = isolationChecker.checkPairConflicts(taskIdA, taskIdB);
    if (pairResult.isOk() && pairResult.value !== null) {
      conflicts.push(pairResult.value);
    }
  }

  // If no specific comparison, check task against all others
  if (taskIdB === undefined && (files === undefined || files.length === 0)) {
    const scopesResult = isolationChecker.listScopes();
    if (scopesResult.isOk()) {
      for (const scope of scopesResult.value) {
        if (scope.taskId === taskIdA) continue;

        const pairResult = isolationChecker.checkPairConflicts(taskIdA, scope.taskId);
        if (pairResult.isOk() && pairResult.value !== null) {
          conflicts.push(pairResult.value);
        }
      }
    }
  }

  // Get all scopes
  const scopesResult = isolationChecker.listScopes();
  const scopes = scopesResult.isOk() ? scopesResult.value : [];

  // Generate recommendations
  if (conflicts.length > 0) {
    const errorConflicts = conflicts.filter((c) => c.severity === 'error');
    const warningConflicts = conflicts.filter((c) => c.severity === 'warning');

    if (errorConflicts.length > 0) {
      recommendations.push(
        `${errorConflicts.length} blocking conflict(s) found - tasks cannot run in parallel`
      );
      for (const conflict of errorConflicts) {
        recommendations.push(
          `  - ${conflict.taskA} and ${conflict.taskB}: ${conflict.conflictingFiles.length} file(s)`
        );
      }
    }

    if (warningConflicts.length > 0) {
      recommendations.push(
        `${warningConflicts.length} warning(s) found - review before proceeding`
      );
    }
  } else {
    recommendations.push('No isolation conflicts detected - safe to run in parallel');
  }

  const result: IsolationCheckResult = {
    hasConflicts: conflicts.length > 0,
    conflicts,
    scopes,
    recommendations,
  };

  logger.info(
    {
      taskIdA,
      taskIdB,
      hasConflicts: result.hasConflicts,
      conflictCount: conflicts.length,
    },
    'isolation check completed'
  );

  return ok(result);
}

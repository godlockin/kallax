/**
 * KALLAX Verify Output Command
 * Verify task output authenticity using Fact-Forcing 4-Level verification
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult, VerificationResult, VerificationLevel } from '../types/index.js';
import { KallaxError, KallaxErrorCode, VerificationLevel as VL } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { OutputVerifier } from '../core/output-verifier.js';
import type { SQLiteManager } from '../core/sqlite/index.js';
import type { WorktreeManager } from '../core/worktree-manager.js';

export interface VerifyOutputOptions {
  readonly taskId: string;
  readonly level?: VerificationLevel;
  readonly verbose?: boolean;
}

export interface VerifyOutputResult {
  readonly verification: VerificationResult;
  readonly summary: VerificationSummary;
  readonly recommendations: string[];
}

export interface VerificationSummary {
  readonly level: VerificationLevel;
  readonly passed: boolean;
  readonly evidenceCount: number;
  readonly passedCount: number;
  readonly failedCount: number;
}

export async function executeVerifyOutput(
  db: SQLiteManager,
  worktreeManager: WorktreeManager,
  outputVerifier: OutputVerifier,
  options: VerifyOutputOptions
): Promise<KallaxResult<VerifyOutputResult>> {
  const { taskId, level = VL.L4_DATA_FLOW, verbose = false } = options;

  logger.info({ taskId, level, verbose }, 'starting output verification');

  // Get task
  const taskResult = db.getTask(taskId);
  if (taskResult.isErr()) {
    return err(taskResult.error);
  }
  if (taskResult.value === null) {
    return err(
      new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Task not found', {
        metadata: { taskId },
      })
    );
  }

  const task = taskResult.value;

  // Get worktree
  const worktreeResult = await worktreeManager.getByTaskId(taskId);
  if (worktreeResult.isErr()) {
    return err(worktreeResult.error);
  }
  if (worktreeResult.value === null) {
    return err(
      new KallaxError(KallaxErrorCode.WORKTREE_NOT_FOUND, 'Worktree not found for task', {
        metadata: { taskId },
      })
    );
  }

  const worktree = worktreeResult.value;

  // Run verification
  const verifyResult = await outputVerifier.verify(taskId, worktree.path, level);
  if (verifyResult.isErr()) {
    return err(verifyResult.error);
  }

  const verification = verifyResult.value;

  // Build summary
  const passedCount = verification.evidence.filter((e) => e.passed).length;
  const failedCount = verification.evidence.filter((e) => !e.passed).length;

  const summary: VerificationSummary = {
    level,
    passed: verification.passed,
    evidenceCount: verification.evidence.length,
    passedCount,
    failedCount,
  };

  // Generate recommendations
  const recommendations: string[] = [];

  if (verification.passed) {
    recommendations.push(`Task ${taskId} passed L${level} verification`);
    recommendations.push('Output is authentic and meets quality requirements');
  } else {
    recommendations.push(`Task ${taskId} FAILED L${level} verification`);

    for (const evidence of verification.evidence) {
      if (!evidence.passed) {
        recommendations.push(`  - ${evidence.description}`);
      }
    }

    // Level-specific recommendations
    if (level >= VL.L1_EXISTENCE && failedCount > 0) {
      const existenceFailures = verification.evidence.filter(
        (e) => !e.passed && (e.type === 'file' || e.type === 'git')
      );
      if (existenceFailures.length > 0) {
        recommendations.push('L1 Existence: Some expected files are missing or unchanged');
      }
    }

    if (level >= VL.L2_SUBSTANCE && failedCount > 0) {
      const substanceFailures = verification.evidence.filter(
        (e) => !e.passed && e.description.includes('stub')
      );
      if (substanceFailures.length > 0) {
        recommendations.push('L2 Substance: Some files appear to be stubs or placeholders');
      }
    }

    if (level >= VL.L3_WIRING && failedCount > 0) {
      const lintFailures = verification.evidence.filter(
        (e) => !e.passed && e.type === 'lint'
      );
      if (lintFailures.length > 0) {
        recommendations.push('L3 Wiring: Lint errors detected - check imports/exports');
      }
    }

    if (level >= VL.L4_DATA_FLOW && failedCount > 0) {
      const testFailures = verification.evidence.filter(
        (e) => !e.passed && e.type === 'test'
      );
      if (testFailures.length > 0) {
        recommendations.push('L4 Data Flow: Tests failed - verify integration');
      }
    }
  }

  const result: VerifyOutputResult = {
    verification,
    summary,
    recommendations,
  };

  logger.info(
    {
      taskId,
      level,
      passed: verification.passed,
      evidenceCount: verification.evidence.length,
      passedCount,
      failedCount,
    },
    'output verification completed'
  );

  return ok(result);
}

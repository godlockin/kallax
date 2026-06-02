/**
 * KALLAX Complete Command
 * Saga-based 5-step task completion
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { SQLiteManager } from '../core/sqlite-manager.js';
import type { WorktreeManager } from '../core/worktree-manager.js';
import type { OutputVerifier } from '../core/output-verifier.js';
import type { InstanceRegistry } from '../core/instance-registry.js';
import type { TaskAssigner } from '../core/task-assigner.js';
import { createSagaExecutor, type TaskCompletionState } from '../core/saga-executor.js';
import { VerificationLevel } from '../types/index.js';

export interface CompleteCommandOptions {
  readonly taskId: string;
  readonly skipTests?: boolean;
  readonly skipLint?: boolean;
  readonly verificationLevel?: VerificationLevel;
}

export interface CompleteResult {
  readonly taskId: string;
  readonly commitHash?: string;
  readonly prNumber?: number;
  readonly worktreeCleaned: boolean;
  readonly sagaSteps: string[];
}

export async function executeCompleteCommand(
  db: SQLiteManager,
  worktreeManager: WorktreeManager,
  outputVerifier: OutputVerifier,
  instanceRegistry: InstanceRegistry,
  taskAssigner: TaskAssigner,
  options: CompleteCommandOptions
): Promise<KallaxResult<CompleteResult>> {
  const { taskId, skipTests = false, skipLint = false, verificationLevel = VerificationLevel.L4_DATA_FLOW } = options;

  logger.info({ taskId, verificationLevel }, 'starting task completion');

  // Get task
  const taskResult = db.getTask(taskId);
  if (taskResult.isErr()) {
    return err(taskResult.error);
  }
  if (taskResult.value === null) {
    return err(
      new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Task not found', { metadata: { taskId } })
    );
  }

  const task = taskResult.value;

  // Verify ownership
  const currentInstance = instanceRegistry.getCurrentInstance();
  if (currentInstance === null || task.performerId !== currentInstance.id) {
    return err(
      new KallaxError(KallaxErrorCode.PERMISSION_DENIED, 'Not the owner of this task', {
        metadata: { taskPerformer: task.performerId, currentInstance: currentInstance?.id },
      })
    );
  }

  // Get ticket
  const ticketResult = db.getTicket(task.ticketId);
  if (ticketResult.isErr()) {
    return err(ticketResult.error);
  }
  if (ticketResult.value === null) {
    return err(
      new KallaxError(KallaxErrorCode.TICKET_NOT_FOUND, 'Ticket not found', { metadata: { ticketId: task.ticketId } })
    );
  }

  // Get worktree
  const worktreeResult = await worktreeManager.getByTaskId(taskId);
  if (worktreeResult.isErr()) {
    return err(worktreeResult.error);
  }
  if (worktreeResult.value === null) {
    return err(
      new KallaxError(KallaxErrorCode.WORKTREE_NOT_FOUND, 'Worktree not found for task', { metadata: { taskId } })
    );
  }

  const worktree = worktreeResult.value;

  // Initialize saga state
  const initialState: TaskCompletionState = {
    taskId,
    ticketId: task.ticketId,
    worktreePath: worktree.path,
    branchName: worktree.branch,
    testsRun: false,
    lintPassed: false,
  };

  // Create completion saga
  const saga = createSagaExecutor<TaskCompletionState>({ name: 'task-completion', timeoutMs: 600000 });

  // Step 1: Run tests (unless skipped)
  if (!skipTests) {
    saga.addStep({
      name: 'run-tests',
      async execute(state) {
        logger.info({ taskId: state.taskId }, 'running tests');
        const verifyResult = await outputVerifier.verifyTests(state.worktreePath);
        if (verifyResult.isErr()) {
          throw new Error(`Test verification failed: ${verifyResult.error.message}`);
        }
        if (!verifyResult.value.passed) {
          throw new Error('Tests failed');
        }
        return { ...state, testsRun: true };
      },
      async compensate(state) {
        logger.info({ taskId: state.taskId }, 'compensating test step (no-op)');
      },
    });
  }

  // Step 2: Run lint (unless skipped)
  if (!skipLint) {
    saga.addStep({
      name: 'run-lint',
      async execute(state) {
        logger.info({ taskId: state.taskId }, 'running lint');
        const verifyResult = await outputVerifier.verifyLint(state.worktreePath);
        if (verifyResult.isErr()) {
          throw new Error(`Lint verification failed: ${verifyResult.error.message}`);
        }
        if (!verifyResult.value.passed) {
          throw new Error('Lint failed');
        }
        return { ...state, lintPassed: true };
      },
      async compensate(state) {
        logger.info({ taskId: state.taskId }, 'compensating lint step (no-op)');
      },
    });
  }

  // Step 3: Verify output authenticity
  saga.addStep({
    name: 'verify-output',
    async execute(state) {
      logger.info({ taskId: state.taskId, level: verificationLevel }, 'verifying output');
      const verifyResult = await outputVerifier.verify(state.taskId, state.worktreePath, verificationLevel);
      if (verifyResult.isErr()) {
        throw new Error(`Output verification failed: ${verifyResult.error.message}`);
      }
      if (!verifyResult.value.passed) {
        const failedEvidence = verifyResult.value.evidence.filter((e) => !e.passed);
        throw new Error(`Output verification failed: ${failedEvidence.map((e) => e.description).join(', ')}`);
      }
      return state;
    },
    async compensate(state) {
      logger.info({ taskId: state.taskId }, 'compensating verify step (no-op)');
    },
  });

  // Step 4: Commit changes (placeholder - actual git operations)
  saga.addStep({
    name: 'commit-changes',
    async execute(state) {
      logger.info({ taskId: state.taskId }, 'committing changes');
      // In real implementation, this would run git commit
      // For now, return mock commit hash
      return { ...state, commitHash: `commit_${Date.now().toString(36)}` };
    },
    async compensate(state) {
      if (state.commitHash !== undefined) {
        logger.info({ taskId: state.taskId, commitHash: state.commitHash }, 'reverting commit');
        // In real implementation, this would run git reset
      }
    },
  });

  // Step 5: Create/Update PR (placeholder)
  saga.addStep({
    name: 'create-pr',
    async execute(state) {
      logger.info({ taskId: state.taskId }, 'creating pull request');
      // In real implementation, this would use gh CLI or GitHub API
      // For now, return mock PR number
      return { ...state, prNumber: Math.floor(Math.random() * 1000) };
    },
    async compensate(state) {
      if (state.prNumber !== undefined) {
        logger.info({ taskId: state.taskId, prNumber: state.prNumber }, 'closing pull request');
        // In real implementation, this would close the PR
      }
    },
  });

  // Execute saga
  const sagaResult = await saga.execute(initialState);

  if (sagaResult.isErr()) {
    // Saga failed and compensated
    logger.error({ taskId, error: sagaResult.error.message }, 'task completion saga failed');
    return err(sagaResult.error);
  }

  const finalState = sagaResult.value.finalState;

  // Mark task as completed
  const completeResult = await taskAssigner.completeTask(taskId, JSON.stringify({
    commitHash: finalState.commitHash,
    prNumber: finalState.prNumber,
  }));

  if (completeResult.isErr()) {
    logger.warn({ taskId }, 'failed to mark task as completed in database');
  }

  // Update instance status
  await instanceRegistry.updateStatus(currentInstance.id, 'idle');

  logger.info(
    {
      taskId,
      commitHash: finalState.commitHash,
      prNumber: finalState.prNumber,
      completedSteps: sagaResult.value.completedSteps,
    },
    'task completion successful'
  );

  return ok({
    taskId,
    commitHash: finalState.commitHash,
    prNumber: finalState.prNumber,
    worktreeCleaned: false, // Worktree preserved for review
    sagaSteps: sagaResult.value.completedSteps as string[],
  });
}

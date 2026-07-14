/**
 * KALLAX Complete Command
 * Saga-based 5-step task completion with real git/PR operations
 */

import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode, VerificationLevel } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { SQLiteManager } from '../core/sqlite/index.js';
import type { WorktreeManager } from '../core/worktree-manager.js';
import type { OutputVerifier } from '../core/output-verifier.js';
import type { InstanceRegistry } from '../core/instance-registry.js';
import type { TaskAssigner } from '../core/task-assigner.js';
import type { GitService } from '../core/git-service.js';
import { createSagaExecutor, type TaskCompletionState } from '../core/saga-executor.js';

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
  gitService: GitService,
  options: CompleteCommandOptions,
): Promise<KallaxResult<CompleteResult>> {
  const {
    taskId,
    skipTests = false,
    skipLint = false,
    verificationLevel = VerificationLevel.L4_DATA_FLOW,
  } = options;

  logger.info({ taskId, verificationLevel }, 'starting task completion');

  // Get task
  const taskResult = db.getTask(taskId);
  if (taskResult.isErr()) return err(taskResult.error);
  if (taskResult.value === null) {
    return err(new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Task not found', { metadata: { taskId } }));
  }
  const task = taskResult.value;

  // Verify task is claimed (stateless CLI: each invocation is new process)
  let currentInstance = instanceRegistry.getCurrentInstance();
  if (currentInstance === null) {
    const regResult = await instanceRegistry.register('performer');
    if (regResult.isErr()) return err(regResult.error);
    currentInstance = regResult.value;
  }
  // Allow completion if task is claimed by any performer (verification step handles quality)
  if (task.performerId === null) {
    return err(new KallaxError(KallaxErrorCode.PERMISSION_DENIED, 'Task must be claimed before completion', {
      metadata: { taskPerformer: null },
    }));
  }

  // Get ticket
  const ticketResult = db.getTicket(task.ticketId);
  if (ticketResult.isErr()) return err(ticketResult.error);
  if (ticketResult.value === null) {
    return err(new KallaxError(KallaxErrorCode.TICKET_NOT_FOUND, 'Ticket not found', {
      metadata: { ticketId: task.ticketId },
    }));
  }
  const ticket = ticketResult.value;

  // Get worktree
  const worktreeResult = await worktreeManager.getByTaskId(taskId);
  if (worktreeResult.isErr()) return err(worktreeResult.error);
  if (worktreeResult.value === null) {
    return err(new KallaxError(KallaxErrorCode.WORKTREE_NOT_FOUND, 'Worktree not found for task', {
      metadata: { taskId },
    }));
  }
  const worktree = worktreeResult.value;

  const initialState: TaskCompletionState = {
    taskId,
    ticketId: task.ticketId,
    worktreePath: worktree.path,
    branchName: worktree.branch,
    testsRun: false,
    lintPassed: false,
  };

  const saga = createSagaExecutor<TaskCompletionState>({
    name: 'task-completion',
    timeoutMs: 600000, // 10 min
  });

  // ── Step 1: Run tests ──────────────────────────────────────────────────

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
      async compensate(state): Promise<void> {
        logger.info({ taskId: state.taskId }, 'compensating test step (no-op)');
        return Promise.resolve();
      },
    });
  }

  // ── Step 2: Run lint ───────────────────────────────────────────────────

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
      async compensate(state): Promise<void> {
        logger.info({ taskId: state.taskId }, 'compensating lint step (no-op)');
        return Promise.resolve();
      },
    });
  }

  // ── Step 3: Verify output ──────────────────────────────────────────────

  saga.addStep({
    name: 'verify-output',
    async execute(state) {
      logger.info({ taskId: state.taskId, level: verificationLevel }, 'verifying output');
      const verifyResult = await outputVerifier.verify(
        state.taskId, state.worktreePath, verificationLevel,
      );
      if (verifyResult.isErr()) {
        throw new Error(`Output verification failed: ${verifyResult.error.message}`);
      }
      if (!verifyResult.value.passed) {
        const failed = verifyResult.value.evidence
          .filter((e) => !e.passed)
          .map((e) => e.description)
          .join(', ');
        throw new Error(`Output verification failed: ${failed}`);
      }
      return state;
    },
    async compensate(state): Promise<void> {
      logger.info({ taskId: state.taskId }, 'compensating verify step (no-op)');
      return Promise.resolve();
    },
  });

  // ── Step 4: Stage & commit ─────────────────────────────────────────────

  saga.addStep({
    name: 'commit-changes',
    async execute(state) {
      logger.info({ taskId: state.taskId, worktree: state.worktreePath }, 'committing changes');

      // Stage all changes
      const stageResult = await gitService.stageAll(state.worktreePath);
      if (stageResult.isErr()) throw new Error(stageResult.error.message);

      // Build commit message
      const commitMsg = [
        `feat: ${ticket.title}`,
        '',
        `Ticket: ${ticket.id}`,
        `Task: ${state.taskId}`,
      ].join('\n');

      const commitResult = await gitService.commit(state.worktreePath, commitMsg);
      if (commitResult.isErr()) throw new Error(commitResult.error.message);

      const { hash } = commitResult.value;
      logger.info({ taskId: state.taskId, hash }, 'changes committed');
      return { ...state, commitHash: hash || undefined };
    },
    async compensate(state) {
      if (state.commitHash !== undefined && state.commitHash !== '') {
        logger.info({ taskId: state.taskId, commitHash: state.commitHash }, 'reverting commit');
        const resetResult = await gitService.resetSoft(state.worktreePath, state.commitHash + '^');
        if (resetResult.isErr()) {
          logger.error(
            { taskId: state.taskId, error: resetResult.error.message },
            'compensation: failed to revert commit',
          );
        }
      }
    },
  });

  // ── Step 5: Push branch ──────────────────────────────────────────────

  saga.addStep({
    name: 'push-branch',
    async execute(state) {
      logger.info({ taskId: state.taskId, branch: state.branchName }, 'pushing branch');
      const pushResult = await gitService.push(state.worktreePath, state.branchName);
      if (pushResult.isErr()) throw new Error(pushResult.error.message);
      return state;
    },
    async compensate(state) {
      logger.info({ taskId: state.taskId, branchName: state.branchName }, 'compensating: deleting remote branch');
      const deleteResult = await gitService.deleteRemoteBranch(state.worktreePath, state.branchName);
      if (deleteResult.isErr()) {
        logger.error(
          { taskId: state.taskId, error: deleteResult.error.message },
          'compensation: failed to delete remote branch',
        );
      }
    },
  });

  // ── Step 6: Create PR ───────────────────────────────────────────────

  saga.addStep({
    name: 'create-pr',
    async execute(state) {
      logger.info({ taskId: state.taskId }, 'creating pull request');

      const prTitle = `feat: ${ticket.title}`;
      const prBody = [
        `## Summary`,
        `- Implements ticket ${ticket.id}`,
        `- Task: ${state.taskId}`,
        '',
        `### Acceptance Criteria`,
        ...ticket.acceptanceCriteria.map((ac) => `- [x] ${ac}`),
        '',
        `🤖 Generated with [KALLAX](https://github.com/kallax)`,
      ].join('\n');

      const prResult = await gitService.createPr(
        state.worktreePath,
        prTitle,
        prBody,
        'main',
        state.branchName,
      );
      if (prResult.isErr()) throw new Error(prResult.error.message);

      logger.info(
        { taskId: state.taskId, prNumber: prResult.value.number, url: prResult.value.url },
        'PR created',
      );
      return { ...state, prNumber: prResult.value.number };
    },
    async compensate(state) {
      if (state.prNumber !== undefined && state.prNumber > 0) {
        logger.info({ taskId: state.taskId, prNumber: state.prNumber }, 'closing PR');
        const closeResult = await gitService.closePr(state.prNumber);
        if (closeResult.isErr()) {
          logger.error(
            { taskId: state.taskId, error: closeResult.error.message },
            'compensation: failed to close PR',
          );
        }
      }
      // Clean up worktree
      logger.info({ taskId: state.taskId }, 'removing worktree');
      const removeResult = await worktreeManager.remove(state.taskId);
      if (removeResult.isErr()) {
        logger.warn(
          { taskId: state.taskId, error: removeResult.error.message },
          'compensation: failed to remove worktree',
        );
      }
    },
  });

  // ── Execute ────────────────────────────────────────────────────────────

  const sagaResult = await saga.execute(initialState);

  if (sagaResult.isErr()) {
    logger.error(
      { taskId, error: sagaResult.error.message },
      'task completion saga failed — all steps compensated',
    );
    return err(sagaResult.error);
  }

  const finalState = sagaResult.value.finalState;

  // Persist completion
  const completeResult = await taskAssigner.completeTask(
    taskId,
    JSON.stringify({
      commitHash: finalState.commitHash,
      prNumber: finalState.prNumber,
    }),
  );
  if (completeResult.isErr()) {
    logger.warn({ taskId }, 'failed to mark task as completed in database');
  }

  await instanceRegistry.updateStatus(currentInstance.id, 'idle');

  logger.info(
    {
      taskId,
      commitHash: finalState.commitHash,
      prNumber: finalState.prNumber,
      completedSteps: sagaResult.value.completedSteps,
    },
    'task completion successful',
  );

  return ok({
    taskId,
    commitHash: finalState.commitHash,
    prNumber: finalState.prNumber,
    worktreeCleaned: false, // Worktree preserved for review
    sagaSteps: sagaResult.value.completedSteps as string[],
  });
}

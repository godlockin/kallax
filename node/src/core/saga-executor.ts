/**
 * KALLAX Saga Executor
 * Atomic multi-step operations with automatic compensation
 */

import { err, ok } from 'neverthrow';
import { KallaxError, KallaxErrorCode, type KallaxResult, type SagaStep } from '../types/index.js';
import { logger } from '../utils/logger.js';
import type { GitService } from './git-service.js';

export interface SagaConfig {
  readonly name: string;
  readonly timeoutMs?: number;
}

export interface SagaExecutionResult<TState> {
  readonly sagaName: string;
  readonly success: boolean;
  readonly finalState: TState;
  readonly completedSteps: readonly string[];
  readonly failedStep?: string;
  readonly compensatedSteps?: readonly string[];
  readonly error?: KallaxError;
  readonly durationMs: number;
}

export interface SagaExecutor<TState> {
  addStep: (step: SagaStep<TState>) => SagaExecutor<TState>;
  execute: (initialState: TState) => Promise<KallaxResult<SagaExecutionResult<TState>>>;
}

export function createSagaExecutor<TState>(config: SagaConfig): SagaExecutor<TState> {
  const steps: SagaStep<TState>[] = [];

  return {
    addStep(step: SagaStep<TState>): SagaExecutor<TState> {
      steps.push(step);
      logger.debug({ sagaName: config.name, stepName: step.name }, 'saga step added');
      return this;
    },

    async execute(initialState: TState): Promise<KallaxResult<SagaExecutionResult<TState>>> {
      const startTime = Date.now();
      const completedSteps: string[] = [];
      let currentState = initialState;

      logger.info(
        { sagaName: config.name, stepCount: steps.length },
        'saga execution started'
      );

      // Execute forward steps
      for (const step of steps) {
        try {
          logger.debug({ sagaName: config.name, stepName: step.name }, 'executing saga step');

          if (config.timeoutMs !== undefined) {
            const timeoutPromise = new Promise<never>((_, reject) => {
              setTimeout(() => {
                reject(new Error(`Step ${step.name} timed out`));
              }, config.timeoutMs);
            });
            currentState = await Promise.race([step.execute(currentState), timeoutPromise]);
          } else {
            currentState = await step.execute(currentState);
          }

          completedSteps.push(step.name);
          logger.debug({ sagaName: config.name, stepName: step.name }, 'saga step completed');
        } catch (error: unknown) {
          const kallaxError = KallaxError.fromUnknown(error, KallaxErrorCode.SAGA_STEP_FAILED);
          logger.error(
            { sagaName: config.name, stepName: step.name, error: kallaxError.message },
            'saga step failed, starting compensation'
          );

          // Execute compensation in reverse order
          const compensatedSteps: string[] = [];
          for (let i = completedSteps.length - 1; i >= 0; i--) {
            const completedStepName = completedSteps[i];
            const completedStep = steps.find((s) => s.name === completedStepName);

            if (completedStep !== undefined) {
              try {
                logger.debug(
                  { sagaName: config.name, stepName: completedStep.name },
                  'executing compensation'
                );
                await completedStep.compensate(currentState);
                compensatedSteps.push(completedStep.name);
                logger.debug(
                  { sagaName: config.name, stepName: completedStep.name },
                  'compensation completed'
                );
              } catch (compensateError: unknown) {
                const compError = KallaxError.fromUnknown(
                  compensateError,
                  KallaxErrorCode.SAGA_COMPENSATE_FAILED
                );
                logger.error(
                  { sagaName: config.name, stepName: completedStep.name, error: compError.message },
                  'compensation failed'
                );
                // Continue compensating other steps
              }
            }
          }

          const result: SagaExecutionResult<TState> = {
            sagaName: config.name,
            success: false,
            finalState: currentState,
            completedSteps,
            failedStep: step.name,
            compensatedSteps,
            error: kallaxError,
            durationMs: Date.now() - startTime,
          };

          return err(
            new KallaxError(KallaxErrorCode.SAGA_STEP_FAILED, `Saga ${config.name} failed at step ${step.name}`, {
              cause: error,
              metadata: { result },
            })
          );
        }
      }

      const result: SagaExecutionResult<TState> = {
        sagaName: config.name,
        success: true,
        finalState: currentState,
        completedSteps,
        durationMs: Date.now() - startTime,
      };

      logger.info(
        { sagaName: config.name, durationMs: result.durationMs, completedSteps: completedSteps.length },
        'saga execution completed successfully'
      );

      return ok(result);
    },
  };
}

/**
 * Create a task completion saga with standard 5 steps
 */
export interface TaskCompletionState {
  taskId: string;
  ticketId: string;
  worktreePath: string;
  branchName: string;
  commitHash?: string;
  prNumber?: number;
  testsRun: boolean;
  lintPassed: boolean;
}

export function createTaskCompletionSaga(gitService: GitService): SagaExecutor<TaskCompletionState> {
  return createSagaExecutor<TaskCompletionState>({ name: 'task-completion', timeoutMs: 300000 })
    .addStep({
      name: 'run-tests',
      async execute(state) {
        await Promise.resolve();
        logger.info({ taskId: state.taskId }, 'running tests');
        // Test execution would happen here
        return { ...state, testsRun: true };
      },
      async compensate(state) {
        await Promise.resolve();
        logger.info({ taskId: state.taskId }, 'compensating test step (no-op)');
        // Nothing to undo for tests
      },
    })
    .addStep({
      name: 'run-lint',
      async execute(state) {
        await Promise.resolve();
        logger.info({ taskId: state.taskId }, 'running lint');
        // Lint execution would happen here
        return { ...state, lintPassed: true };
      },
      async compensate(state) {
        await Promise.resolve();
        logger.info({ taskId: state.taskId }, 'compensating lint step (no-op)');
      },
    })
    .addStep({
      name: 'commit-changes',
      async execute(state) {
        await Promise.resolve();
        logger.info({ taskId: state.taskId }, 'committing changes');
        // Git commit would happen here
        return { ...state, commitHash: 'abc123' };
      },
      async compensate(state) {
        await Promise.resolve();
        if (state.commitHash !== undefined && state.commitHash !== '') {
          logger.info({ taskId: state.taskId, commitHash: state.commitHash }, 'reverting commit');
          const resetResult = await gitService.resetSoft(state.worktreePath, state.commitHash + '^');
          if (resetResult.isErr()) {
            logger.error({ taskId: state.taskId, error: resetResult.error.message }, 'compensation failed: could not revert commit');
          }
        }
      },
    })
    .addStep({
      name: 'push-branch',
      async execute(state) {
        await Promise.resolve();
        logger.info({ taskId: state.taskId, branchName: state.branchName }, 'pushing branch');
        // Git push would happen here
        return state;
      },
      async compensate(state) {
        await Promise.resolve();
        logger.info({ taskId: state.taskId, branchName: state.branchName }, 'compensating: deleting remote branch');
        const deleteResult = await gitService.deleteRemoteBranch(state.worktreePath, state.branchName);
        if (deleteResult.isErr()) {
          logger.error({ taskId: state.taskId, error: deleteResult.error.message }, 'compensation failed: could not delete remote branch');
        }
      },
    })
    .addStep({
      name: 'create-pr',
      async execute(state) {
        await Promise.resolve();
        logger.info({ taskId: state.taskId }, 'creating pull request');
        // PR creation would happen here
        return { ...state, prNumber: 123 };
      },
      async compensate(state) {
        await Promise.resolve();
        if (state.prNumber !== undefined) {
          logger.info({ taskId: state.taskId, prNumber: state.prNumber }, 'closing pull request');
          const closeResult = await gitService.closePr(state.prNumber);
          if (closeResult.isErr()) {
            logger.error({ taskId: state.taskId, error: closeResult.error.message }, 'compensation: failed to close PR');
          }
        }
        // Also delete remote branch as safety cleanup
        const deleteResult = await gitService.deleteRemoteBranch(state.worktreePath, state.branchName);
        if (deleteResult.isErr()) {
          logger.warn({ taskId: state.taskId, error: deleteResult.error.message }, 'compensation: failed to delete remote branch');
        }
      },
    });
}

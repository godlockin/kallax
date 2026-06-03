/**
 * KALLAX Task Command Registration
 * Wraps core task command handlers with CLI registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError, KallaxErrorCode, TaskStatus, TaskType } from '../types/index.js';
import { executeClaimCommand } from './claim.js';
import { executeCompleteCommand } from './complete.js';
import {
  executeTaskCreate,
  executeTaskStatus,
  executeTaskProgress,
  executeTaskResume,
} from './task.js';

export function registerTaskCommands(program: Command, ctx: AppContext): void {
  const task = program.command('task').description('Task management');

  task
    .command('claim [taskId]')
    .description('Claim a task — auto-creates isolated worktree')
    .option('-t, --ticket <ticketId>', 'Claim task for specific ticket')
    .action(async (taskId?: string, opts?: { ticket?: string }) => {
      try {
        const result = await executeClaimCommand(
          ctx.db, ctx.worktreeManager, ctx.instanceRegistry, ctx.taskAssigner,
          { taskId, ticketId: opts?.['ticket'] },
        );
        if (result.isErr()) {
          process.stderr.write(`Claim failed: ${result.error.message}\n`);
          process.exit(1);
        }
        process.stdout.write(`[OK] Task ${result.value.task.id} claimed\n`);
        process.stdout.write(`     Worktree: ${result.value.worktreePath}\n`);
        process.stdout.write(`     Ticket: ${result.value.ticket.title}\n`);
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  task
    .command('complete <taskId>')
    .description('Complete a task — Saga 5-step atomic completion')
    .option('--skip-tests', 'Skip test verification')
    .option('--skip-lint', 'Skip lint verification')
    .option('-l, --level <level>', 'Verification level (1-4)', '4')
    .action(async (taskId: string, opts?: { skipTests?: boolean; skipLint?: boolean; level?: string }) => {
      try {
        const result = await executeCompleteCommand(
          ctx.db, ctx.worktreeManager, ctx.outputVerifier,
          ctx.instanceRegistry, ctx.taskAssigner, ctx.gitService,
          {
            taskId,
            skipTests: opts?.['skipTests'],
            skipLint: opts?.['skipLint'],
            verificationLevel: (parseInt(opts?.['level'] ?? '4', 10) as 1 | 2 | 3 | 4),
          },
        );
        if (result.isErr()) {
          logger.kallaxError(result.error);
          process.exit(1);
        }
        logger.info(
          { taskId, commitHash: result.value.commitHash, prNumber: result.value.prNumber },
          'task completed',
        );
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  task
    .command('create <ticketId>')
    .description('Create a new task for a ticket')
    .option('-t, --type <type>', 'Task type (development, review, testing)', 'development')
    .action(async (ticketId: string, opts?: { type?: string }) => {
      try {
        const result = executeTaskCreate(ctx.db, ctx.taskAssigner, {
          ticketId,
          type: opts?.['type'] as TaskType | undefined,
        });
        if (result.isErr()) {
          logger.kallaxError(result.error);
          process.exit(1);
        }
        logger.info({ taskId: result.value.task.id, ticketId }, 'task created');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  task
    .command('status [taskId]')
    .description('Show task status')
    .option('-t, --ticket <ticketId>', 'Filter by ticket')
    .option('-p, --performer <performerId>', 'Filter by performer')
    .option('-s, --status <status>', 'Filter by status')
    .action(async (taskId?: string, opts?: Record<string, string>) => {
      try {
        const result = executeTaskStatus(ctx.db, {
          taskId,
          ticketId: opts?.['ticket'],
          performerId: opts?.['performer'],
          statusFilter: opts?.['status'] as TaskStatus | undefined,
        });
        if (result.isErr()) {
          logger.kallaxError(result.error);
          process.exit(1);
        }
        process.stdout.write(JSON.stringify(result.value, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  task
    .command('progress <taskId> <progress>')
    .description('Update task progress (0-100)')
    .option('-m, --message <message>', 'Progress message')
    .action(async (taskId: string, progress: string, opts?: { message?: string }) => {
      try {
        const result = executeTaskProgress(ctx.db, {
          taskId,
          progress: parseInt(progress, 10),
          message: opts?.['message'],
        });
        if (result.isErr()) {
          logger.kallaxError(result.error);
          process.exit(1);
        }
        logger.info({ taskId, progress }, 'task progress updated');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  task
    .command('resume <taskId>')
    .description('Resume a failed or cancelled task')
    .action(async (taskId: string) => {
      try {
        const result = await executeTaskResume(ctx.db, ctx.taskAssigner, { taskId });
        if (result.isErr()) {
          logger.kallaxError(result.error);
          process.exit(1);
        }
        logger.info({ taskId }, 'task resumed');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  task
    .command('handoff <taskId> <toPerformerId>')
    .description('Handoff a task to another performer')
    .option('-m, --message <message>', 'Handoff message')
    .action(async (taskId: string, toPerformerId: string, opts?: { message?: string }) => {
      try {
        const taskResult = ctx.db.getTask(taskId);
        if (taskResult.isErr()) {
          logger.kallaxError(taskResult.error);
          process.exit(1);
        }
        const taskValue = taskResult.value;
        if (!taskValue) {
          logger.error({ taskId }, 'task not found');
          process.exit(1);
        }

        const oldPerformerId = taskValue.performerId;
        const now = Date.now();

        // Update task performer
        const updateResult = ctx.db.updateTask(taskId, {
          performerId: toPerformerId,
          status: 'pending',   // reset so new performer must claim
          progress: taskValue.progress,
          updatedAt: now,
        });
        if (updateResult.isErr()) {
          logger.kallaxError(updateResult.error);
          process.exit(1);
        }

        // Unset old performer's current task if they held this one
        if (oldPerformerId) {
          const oldInstResult = ctx.db.listInstances({ role: 'performer' });
          if (oldInstResult.isOk()) {
            for (const inst of oldInstResult.value) {
              if (inst.currentTaskId === taskId) {
                await ctx.instanceRegistry.updateStatus(inst.id, 'idle');
              }
            }
          }
        }

        process.stdout.write(JSON.stringify({
          taskId, fromPerformer: oldPerformerId, toPerformer: toPerformerId,
          progress: taskValue.progress, message: opts?.['message'] ?? '',
          status: 'handoff_ok',
        }) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}

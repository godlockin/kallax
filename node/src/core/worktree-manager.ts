/**
 * KALLAX Worktree Manager
 * Git worktree management with forced isolation
 */

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import * as path from 'node:path';
import * as fs from 'node:fs/promises';
import { err, ok } from 'neverthrow';
import { KallaxError, KallaxErrorCode, type KallaxResult } from '../types/index.js';
import { logger } from '../utils/logger.js';

const execFileAsync = promisify(execFile);

export interface WorktreeConfig {
  readonly projectRoot: string;
  readonly worktreeBasePath: string;
  readonly maxWorktrees?: number;
}

export interface Worktree {
  readonly path: string;
  readonly branch: string;
  readonly commit: string;
  readonly taskId?: string;
}

export interface WorktreeManager {
  create: (taskId: string, baseBranch?: string) => Promise<KallaxResult<Worktree>>;
  remove: (taskIdOrPath: string) => Promise<KallaxResult<void>>;
  list: () => Promise<KallaxResult<Worktree[]>>;
  getByTaskId: (taskId: string) => Promise<KallaxResult<Worktree | null>>;
  validateIsolation: (taskId: string, files: string[]) => Promise<KallaxResult<boolean>>;
  getPath: (taskId: string) => string;
}

/**
 * Execute git command safely
 */
async function gitCommand(
  cwd: string,
  args: string[]
): Promise<KallaxResult<string>> {
  try {
    const { stdout } = await execFileAsync('git', args, { cwd });
    return ok(stdout.trim());
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return err(
      new KallaxError(KallaxErrorCode.INTERNAL_ERROR, `Git command failed: ${message}`, {
        cause: error,
        metadata: { args },
      })
    );
  }
}

export function createWorktreeManager(config: WorktreeConfig): KallaxResult<WorktreeManager> {
  const { projectRoot, worktreeBasePath } = config;
  const maxWorktrees = config.maxWorktrees ?? 200;

  // Generate worktree path for a task
  function getWorktreePath(taskId: string): string {
    const sanitizedId = taskId.replace(/[^a-zA-Z0-9-_]/g, '_');
    return path.join(worktreeBasePath, sanitizedId);
  }

  /**
   * Validate that a resolved worktree path stays within the allowed base directory.
   * Prevents path traversal attacks.
   */
  function validateWorktreePath(worktreePath: string): KallaxResult<string> {
    const relative = path.relative(worktreeBasePath, worktreePath);
    if (relative.startsWith('..') || path.isAbsolute(relative)) {
      return err(
        new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Path traversal detected', {
          metadata: { worktreePath, worktreeBasePath },
        })
      );
    }
    return ok(worktreePath);
  }

  // Generate branch name for a task
  function getBranchName(taskId: string): string {
    return `kallax/${taskId}`;
  }

  const manager: WorktreeManager = {
    async create(taskId: string, baseBranch = 'main'): Promise<KallaxResult<Worktree>> {
      const worktreePath = getWorktreePath(taskId);
      const branchName = getBranchName(taskId);

      logger.info({ taskId, worktreePath, branchName, baseBranch }, 'creating worktree');

      // Ensure base path exists
      try {
        await fs.mkdir(worktreeBasePath, { recursive: true });
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.WORKTREE_CREATE_FAILED, 'Failed to create worktree base directory', {
            cause: error,
            metadata: { worktreeBasePath },
          })
        );
      }

      // Check max worktrees limit
      const listResult = await manager.list();
      if (listResult.isOk() && listResult.value.length >= maxWorktrees) {
        return err(
          new KallaxError(KallaxErrorCode.WORKTREE_CREATE_FAILED, 'Max worktrees limit reached', {
            metadata: { maxWorktrees, current: listResult.value.length },
          })
        );
      }

      // Check if worktree already exists
      const existingResult = await manager.getByTaskId(taskId);
      if (existingResult.isOk() && existingResult.value !== null) {
        logger.warn({ taskId, worktreePath }, 'worktree already exists');
        return ok(existingResult.value);
      }

      // Create the worktree with a new branch
      const createResult = await gitCommand(projectRoot, [
        'worktree',
        'add',
        '-b',
        branchName,
        worktreePath,
        baseBranch,
      ]);

      if (createResult.isErr()) {
        return err(
          new KallaxError(KallaxErrorCode.WORKTREE_CREATE_FAILED, 'Failed to create git worktree', {
            cause: createResult.error,
            metadata: { taskId, worktreePath },
          })
        );
      }

      // Get the commit hash
      const commitResult = await gitCommand(worktreePath, ['rev-parse', 'HEAD']);
      if (commitResult.isErr()) {
        return err(
          new KallaxError(KallaxErrorCode.WORKTREE_CREATE_FAILED, 'Failed to get commit hash', {
            cause: commitResult.error,
          })
        );
      }

      const worktree: Worktree = {
        path: worktreePath,
        branch: branchName,
        commit: commitResult.value,
        taskId,
      };

      logger.info({ taskId, worktreePath, branch: branchName, commit: worktree.commit }, 'worktree created');
      return ok(worktree);
    },

    async remove(taskIdOrPath: string): Promise<KallaxResult<void>> {
      // Always sanitize through getWorktreePath — never accept raw paths.
      // The input is treated as a taskId; any path separators or dots are
      // stripped by the sanitizer, preventing path traversal.
      const worktreePath = getWorktreePath(taskIdOrPath);

      const pathValidation = validateWorktreePath(worktreePath);
      if (pathValidation.isErr()) {
        return err(pathValidation.error);
      }

      logger.info({ worktreePath }, 'removing worktree');

      // Remove the worktree
      const removeResult = await gitCommand(projectRoot, [
        'worktree',
        'remove',
        '--force',
        worktreePath,
      ]);

      if (removeResult.isErr()) {
        // Try to clean up the directory manually if git fails
        try {
          await fs.rm(worktreePath, { recursive: true, force: true });
          await gitCommand(projectRoot, ['worktree', 'prune']);
        } catch (cleanupError: unknown) {
          return err(
            new KallaxError(KallaxErrorCode.WORKTREE_CLEANUP_FAILED, 'Failed to remove worktree', {
              cause: removeResult.error,
              metadata: { worktreePath },
            })
          );
        }
      }

      // Also try to delete the branch
      const branchName = getBranchName(path.basename(worktreePath));
      await gitCommand(projectRoot, ['branch', '-D', branchName]);

      logger.info({ worktreePath }, 'worktree removed');
      return ok(undefined);
    },

    async list(): Promise<KallaxResult<Worktree[]>> {
      const result = await gitCommand(projectRoot, ['worktree', 'list', '--porcelain']);

      if (result.isErr()) {
        return err(result.error);
      }

      const worktrees: Worktree[] = [];
      const lines = result.value.split('\n');
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let current: Record<string, any> = {};

      for (const line of lines) {
        if (line.startsWith('worktree ')) {
          current['path'] = line.slice(9);
        } else if (line.startsWith('HEAD ')) {
          current['commit'] = line.slice(5);
        } else if (line.startsWith('branch ')) {
          current['branch'] = line.slice(7).replace('refs/heads/', '');
          if (current['branch']?.startsWith('kallax/')) {
            current['taskId'] = current['branch']!.replace('kallax/', '');
          }
        } else if (line === '') {
          // End of entry
          if (current['path'] !== undefined && current['branch'] !== undefined && current['commit'] !== undefined) {
            worktrees.push(current as Worktree);
          }
          current = {};
        }
      }

      return ok(worktrees);
    },

    async getByTaskId(taskId: string): Promise<KallaxResult<Worktree | null>> {
      const listResult = await manager.list();
      if (listResult.isErr()) {
        return err(listResult.error);
      }

      const worktree = listResult.value.find((w) => w.taskId === taskId);
      return ok(worktree ?? null);
    },

    async validateIsolation(taskId: string, files: string[]): Promise<KallaxResult<boolean>> {
      // Get worktree for task
      const worktreeResult = await manager.getByTaskId(taskId);
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

      // Check if all files exist within the worktree
      const worktreePath = worktreeResult.value.path;
      for (const file of files) {
        const fullPath = path.join(worktreePath, file);
        const relativePath = path.relative(worktreePath, fullPath);

        // Ensure file is within worktree (no path traversal)
        if (relativePath.startsWith('..') || path.isAbsolute(relativePath)) {
          logger.warn({ taskId, file, worktreePath }, 'file outside worktree');
          return ok(false);
        }
      }

      return ok(true);
    },

    getPath(taskId: string): string {
      return getWorktreePath(taskId);
    },
  };

  logger.info({ projectRoot, worktreeBasePath }, 'worktree manager initialized');
  return ok(manager);
}

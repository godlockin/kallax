/**
 * KALLAX Git Service
 * Real git operations with proper error handling — no mocks in production paths
 */

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

const execFileAsync = promisify(execFile);

export interface GitCommitResult {
  readonly hash: string;
  readonly message: string;
  readonly filesChanged: number;
}

export interface GitPushResult {
  readonly branch: string;
  readonly remote: string;
}

export interface PrCreateResult {
  readonly number: number;
  readonly url: string;
}

export interface GitService {
  stageAll: (cwd: string) => Promise<KallaxResult<void>>;
  commit: (cwd: string, message: string) => Promise<KallaxResult<GitCommitResult>>;
  push: (cwd: string, branch: string, remote?: string) => Promise<KallaxResult<GitPushResult>>;
  createPr: (
    cwd: string,
    title: string,
    body: string,
    base?: string,
    head?: string,
  ) => Promise<KallaxResult<PrCreateResult>>;
  resetSoft: (cwd: string, ref: string) => Promise<KallaxResult<void>>;
  deleteRemoteBranch: (cwd: string, branch: string, remote?: string) => Promise<KallaxResult<void>>;
  closePr: (prNumber: number) => Promise<KallaxResult<void>>;
  hasChanges: (cwd: string) => Promise<KallaxResult<boolean>>;
  getCurrentBranch: (cwd: string) => Promise<KallaxResult<string>>;
}

async function runGit(
  cwd: string,
  args: string[],
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  try {
    const { stdout, stderr } = await execFileAsync('git', args, { cwd });
    return { stdout: stdout.trim(), stderr: stderr.trim(), exitCode: 0 };
  } catch (error: unknown) {
    const execError = error as { stdout?: string; stderr?: string; code?: number };
    return {
      stdout: (execError.stdout ?? '').trim(),
      stderr: (execError.stderr ?? '').trim(),
      exitCode: execError.code ?? 1,
    };
  }
}

async function runGh(
  cwd: string,
  args: string[],
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  try {
    const { stdout, stderr } = await execFileAsync('gh', args, { cwd });
    return { stdout: stdout.trim(), stderr: stderr.trim(), exitCode: 0 };
  } catch (error: unknown) {
    const execError = error as { stdout?: string; stderr?: string; code?: number };
    return {
      stdout: (execError.stdout ?? '').trim(),
      stderr: (execError.stderr ?? '').trim(),
      exitCode: execError.code ?? 1,
    };
  }
}

export function createGitService(): GitService {
  return {
    async stageAll(cwd: string): Promise<KallaxResult<void>> {
      const result = await runGit(cwd, ['add', '-A']);
      if (result.exitCode !== 0) {
        return err(new KallaxError(
          KallaxErrorCode.INTERNAL_ERROR,
          'Failed to stage changes',
          { metadata: { cwd, stderr: result.stderr } },
        ));
      }
      logger.debug({ cwd }, 'all changes staged');
      return ok(undefined);
    },

    async commit(cwd: string, message: string): Promise<KallaxResult<GitCommitResult>> {
      const result = await runGit(cwd, ['commit', '-m', message]);
      if (result.exitCode !== 0) {
        // Check if nothing to commit (non-error case)
        if (result.stderr.includes('nothing to commit') || result.stdout.includes('nothing to commit')) {
          return ok({ hash: '', message, filesChanged: 0 });
        }
        return err(new KallaxError(
          KallaxErrorCode.INTERNAL_ERROR,
          'Failed to commit changes',
          { metadata: { cwd, stderr: result.stderr } },
        ));
      }

      // Extract commit hash
      const hashResult = await runGit(cwd, ['rev-parse', 'HEAD']);
      const hash = hashResult.stdout;

      // Count files changed
      const diffResult = await runGit(cwd, ['diff', '--stat', 'HEAD~1..HEAD']);
      const filesChanged = diffResult.stdout ? diffResult.stdout.split('\n').length : 0;

      logger.info({ cwd, hash, message }, 'changes committed');
      return ok({ hash, message, filesChanged });
    },

    async push(cwd: string, branch: string, remote = 'origin'): Promise<KallaxResult<GitPushResult>> {
      const result = await runGit(cwd, ['push', remote, branch]);
      if (result.exitCode !== 0) {
        return err(new KallaxError(
          KallaxErrorCode.INTERNAL_ERROR,
          'Failed to push branch',
          { metadata: { cwd, branch, remote, stderr: result.stderr } },
        ));
      }
      logger.info({ cwd, branch, remote }, 'branch pushed');
      return ok({ branch, remote });
    },

    async createPr(
      cwd: string,
      title: string,
      body: string,
      base = 'main',
    ): Promise<KallaxResult<PrCreateResult>> {
      const args = [
        'pr', 'create',
        '--title', title,
        '--body', body,
        '--base', base,
      ];

      const result = await runGh(cwd, args);
      if (result.exitCode !== 0) {
        return err(new KallaxError(
          KallaxErrorCode.INTERNAL_ERROR,
          'Failed to create pull request',
          { metadata: { cwd, title, stderr: result.stderr } },
        ));
      }

      // Parse PR URL to extract number: https://github.com/owner/repo/pull/123
      const urlMatch = result.stdout.match(/pull\/(\d+)/);
      const prNumber = urlMatch && urlMatch[1] ? parseInt(urlMatch[1], 10) : 0;

      logger.info({ cwd, prNumber, url: result.stdout }, 'pull request created');
      return ok({ number: prNumber, url: result.stdout });
    },

    async resetSoft(cwd: string, ref: string): Promise<KallaxResult<void>> {
      const result = await runGit(cwd, ['reset', '--soft', ref]);
      if (result.exitCode !== 0) {
        return err(new KallaxError(
          KallaxErrorCode.INTERNAL_ERROR,
          'Failed to reset changes',
          { metadata: { cwd, ref, stderr: result.stderr } },
        ));
      }
      logger.info({ cwd, ref }, 'soft reset done');
      return ok(undefined);
    },

    async deleteRemoteBranch(
      cwd: string,
      branch: string,
      remote = 'origin',
    ): Promise<KallaxResult<void>> {
      const result = await runGit(cwd, ['push', remote, '--delete', branch]);
      if (result.exitCode !== 0) {
        logger.warn({ cwd, branch, remote, stderr: result.stderr }, 'failed to delete remote branch');
        // Non-fatal — branch may not exist on remote
      } else {
        logger.info({ branch, remote }, 'remote branch deleted');
      }
      return ok(undefined);
    },

    async closePr(prNumber: number): Promise<KallaxResult<void>> {
      const result = await runGh(process.cwd(), ['pr', 'close', String(prNumber)]);
      if (result.exitCode !== 0) {
        logger.warn({ prNumber, stderr: result.stderr }, 'failed to close PR');
        // Non-fatal — PR may already be closed or not exist
      } else {
        logger.info({ prNumber }, 'PR closed');
      }
      return ok(undefined);
    },

    async hasChanges(cwd: string): Promise<KallaxResult<boolean>> {
      const result = await runGit(cwd, ['status', '--porcelain']);
      if (result.exitCode !== 0) {
        return err(new KallaxError(
          KallaxErrorCode.INTERNAL_ERROR,
          'Failed to check git status',
          { metadata: { cwd, stderr: result.stderr } },
        ));
      }
      return ok(result.stdout.length > 0);
    },

    async getCurrentBranch(cwd: string): Promise<KallaxResult<string>> {
      const result = await runGit(cwd, ['rev-parse', '--abbrev-ref', 'HEAD']);
      if (result.exitCode !== 0) {
        return err(new KallaxError(
          KallaxErrorCode.INTERNAL_ERROR,
          'Failed to get current branch',
          { metadata: { cwd, stderr: result.stderr } },
        ));
      }
      return ok(result.stdout);
    },
  };
}

let defaultGitService: GitService | null = null;

export function getGitService(): GitService {
  if (defaultGitService === null) {
    defaultGitService = createGitService();
  }
  return defaultGitService;
}

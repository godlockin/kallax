<<<<<<< HEAD
/**
 * Git Service tests: mock execFile for stage/commit/push flows.
 * Uses vi.hoisted for mock to work with vitest's ESM hoisting.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';

const mockExecFile = vi.hoisted(() => vi.fn());

vi.mock('node:child_process', () => ({
  execFile: mockExecFile,
}));

import { createGitService, type GitService } from '../src/core/git-service.js';

describe('GitService', () => {
  let git: GitService;

  beforeEach(() => {
    vi.clearAllMocks();
    git = createGitService();
  });

  function callCb(args: unknown[], err: null | Error, result?: { stdout: string; stderr: string }): void {
    const cb = args[args.length - 1] as (err: null | Error, res?: { stdout: string; stderr: string }) => void;
    cb(err, result);
  }

  it('stageAll returns ok on success', async () => {
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: '', stderr: '' }));

    const result = await git.stageAll('/repo');
    expect(result.isOk()).toBe(true);
    expect(mockExecFile).toHaveBeenCalledWith('git', ['add', '-A'], { cwd: '/repo' }, expect.any(Function));
  });

  it('stageAll returns err on git failure', async () => {
    const err = Object.assign(new Error('permission denied'), { stdout: '', stderr: 'permission denied', code: 128 });
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, err));

    const result = await git.stageAll('/repo');
    expect(result.isErr()).toBe(true);
  });

  it('commit returns hash and file count on success', async () => {
    mockExecFile
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: '1 file changed', stderr: '' }))
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: 'abc123', stderr: '' }))
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: 'src/index.ts', stderr: '' }));

    const result = await git.commit('/repo', 'feat: add feature');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().hash).toBe('abc123');
  });

  it('commit returns ok with empty hash when nothing to commit', async () => {
    const err = Object.assign(new Error('nothing to commit'), { stdout: '', stderr: 'nothing to commit, working tree clean', code: 1 });
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, err));

    const result = await git.commit('/repo', 'wip');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().filesChanged).toBe(0);
  });

  it('push returns ok on success', async () => {
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: '', stderr: '' }));

    const result = await git.push('/repo', 'feature-x');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toEqual({ branch: 'feature-x', remote: 'origin' });
  });

  it('push returns err on failure', async () => {
    const err = Object.assign(new Error('failed to push'), { stdout: '', stderr: 'failed to push', code: 1 });
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, err));

    const result = await git.push('/repo', 'feature-x');
    expect(result.isErr()).toBe(true);
  });

  it('hasChanges returns true when porcelain output is non-empty', async () => {
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: ' M src/index.ts', stderr: '' }));

    const result = await git.hasChanges('/repo');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe(true);
  });

  it('getCurrentBranch returns branch name', async () => {
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: 'main', stderr: '' }));

    const result = await git.getCurrentBranch('/repo');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe('main');
  });
});
||||||| 0834c04
=======
/**
 * Git Service tests: mock execFile for stage/commit/push flows.
 * Uses vi.hoisted for mock to work with vitest's ESM hoisting.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';

const mockExecFile = vi.hoisted(() => vi.fn());

vi.mock('node:child_process', () => ({
  execFile: mockExecFile,
}));

import { createGitService, type GitService } from '../src/core/git-service.js';

describe('GitService', () => {
  let git: GitService;

  beforeEach(() => {
    vi.clearAllMocks();
    git = createGitService();
  });

  function callCb(args: unknown[], err: null | Error, result?: { stdout: string; stderr: string }): void {
    const cb = args[args.length - 1] as (err: null | Error, res?: { stdout: string; stderr: string }) => void;
    cb(err, result);
  }

  it('stageAll returns ok on success', async () => {
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: '', stderr: '' }));

    const result = await git.stageAll('/repo');
    expect(result.isOk()).toBe(true);
    expect(mockExecFile).toHaveBeenCalledWith('git', ['add', '-A'], { cwd: '/repo' }, expect.any(Function));
  });

  it('stageAll returns err on git failure', async () => {
    const err = Object.assign(new Error('permission denied'), { stdout: '', stderr: 'permission denied', code: 128 });
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, err));

    const result = await git.stageAll('/repo');
    expect(result.isErr()).toBe(true);
  });

  it('commit returns hash and file count on success', async () => {
    mockExecFile
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: '1 file changed', stderr: '' }))
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: 'abc123', stderr: '' }))
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: 'src/index.ts', stderr: '' }));

    const result = await git.commit('/repo', 'feat: add feature');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().hash).toBe('abc123');
  });

  it('commit returns ok with empty hash when nothing to commit', async () => {
    const err = Object.assign(new Error('nothing to commit'), { stdout: '', stderr: 'nothing to commit, working tree clean', code: 1 });
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, err));

    const result = await git.commit('/repo', 'wip');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().filesChanged).toBe(0);
  });

  it('push returns ok on success', async () => {
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: '', stderr: '' }));

    const result = await git.push('/repo', 'feature-x');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toEqual({ branch: 'feature-x', remote: 'origin' });
  });

  it('push returns err on failure', async () => {
    const err = Object.assign(new Error('failed to push'), { stdout: '', stderr: 'failed to push', code: 1 });
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, err));

    const result = await git.push('/repo', 'feature-x');
    expect(result.isErr()).toBe(true);
  });

  it('hasChanges returns true when porcelain output is non-empty', async () => {
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: ' M src/index.ts', stderr: '' }));

    const result = await git.hasChanges('/repo');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe(true);
  });

  it('getCurrentBranch returns branch name', async () => {
    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: 'main', stderr: '' }));

    const result = await git.getCurrentBranch('/repo');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe('main');
  });
});
>>>>>>> worktree-kallax-refactor-complete

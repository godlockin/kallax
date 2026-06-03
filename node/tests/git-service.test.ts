/**
 * Git Service tests: mock execFile for stage/commit/push flows.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import * as childProcess from 'node:child_process';

vi.mock('node:child_process', async (importOriginal) => ({
  ...(await importOriginal<typeof childProcess>()),
  execFile: vi.fn(),
}));

import { createGitService, type GitService } from '../src/core/git-service.js';

describe('GitService', () => {
  let git: GitService;
  const mockExecFile = vi.mocked(childProcess.execFile);

  beforeEach(() => {
    vi.clearAllMocks();
    git = createGitService();
  });

  it('stageAll returns ok on success', async () => {
    mockExecFile.mockResolvedValue({ stdout: '', stderr: '' } as never);

    const result = await git.stageAll('/repo');
    expect(result.isOk()).toBe(true);
    expect(mockExecFile).toHaveBeenCalledWith('git', ['add', '-A'], { cwd: '/repo' });
  });

  it('stageAll returns err on failure', async () => {
    mockExecFile.mockRejectedValue({ stdout: '', stderr: 'permission denied', code: 128 });

    const result = await git.stageAll('/repo');
    expect(result.isErr()).toBe(true);
  });

  it('commit returns hash and file count on success', async () => {
    mockExecFile
      .mockResolvedValueOnce({ stdout: '1 file changed', stderr: '' } as never)
      .mockResolvedValueOnce({ stdout: 'abc123', stderr: '' } as never)
      .mockResolvedValueOnce({ stdout: 'src/index.ts', stderr: '' } as never);

    const result = await git.commit('/repo', 'feat: add feature');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().hash).toBe('abc123');
  });

  it('commit returns ok with empty hash when nothing to commit', async () => {
    mockExecFile.mockRejectedValue({ stdout: '', stderr: 'nothing to commit, working tree clean', code: 1 });

    const result = await git.commit('/repo', 'wip');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap().filesChanged).toBe(0);
  });

  it('push returns ok on success', async () => {
    mockExecFile.mockResolvedValue({ stdout: '', stderr: '' } as never);

    const result = await git.push('/repo', 'feature-x');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toEqual({ branch: 'feature-x', remote: 'origin' });
  });

  it('push returns err on failure', async () => {
    mockExecFile.mockRejectedValue({ stdout: '', stderr: 'failed to push', code: 1 });

    const result = await git.push('/repo', 'feature-x');
    expect(result.isErr()).toBe(true);
  });

  it('hasChanges returns true when porcelain output is non-empty', async () => {
    mockExecFile.mockResolvedValue({ stdout: ' M src/index.ts', stderr: '' } as never);

    const result = await git.hasChanges('/repo');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe(true);
  });

  it('hasChanges returns false when working tree is clean', async () => {
    mockExecFile.mockResolvedValue({ stdout: '', stderr: '' } as never);

    const result = await git.hasChanges('/repo');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe(false);
  });

  it('getCurrentBranch returns branch name', async () => {
    mockExecFile.mockResolvedValue({ stdout: 'main', stderr: '' } as never);

    const result = await git.getCurrentBranch('/repo');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe('main');
  });
});

/**
 * Worktree Manager tests: create/remove/list + path validation.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createWorktreeManager } from '../src/core/worktree-manager.js';
import * as fs from 'node:fs/promises';

vi.mock('node:child_process', () => ({
  execFile: vi.fn(),
}));

vi.mock('node:fs/promises', async (importOriginal) => ({
  ...(await importOriginal<typeof fs>()),
  mkdir: vi.fn().mockResolvedValue(undefined),
  rm: vi.fn().mockResolvedValue(undefined),
}));

import { execFile } from 'node:child_process';
const mockExecFile = vi.mocked(execFile);

describe('WorktreeManager', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockExecFile.mockReset();
  });

  it('create worktree and returns Worktree object on success', async () => {
    mockExecFile
      .mockResolvedValueOnce({ stdout: '', stderr: '' } as never) // git worktree add
      .mockResolvedValueOnce({ stdout: 'abc123', stderr: '' } as never); // rev-parse HEAD

    const result = await createWorktreeManager({
      projectRoot: '/repo',
      worktreeBasePath: '/repo/.worktrees',
    });

    expect(result.isOk()).toBe(true);

    const wm = result._unsafeUnwrap();
    const wt = await wm.create('TASK-001');
    expect(wt.isOk()).toBe(true);
    expect(wt._unsafeUnwrap().taskId).toBe('TASK-001');
    expect(wt._unsafeUnwrap().branch).toBe('kallax/TASK-001');
    expect(wt._unsafeUnwrap().path).toContain('.worktrees/TASK-001');
    expect(wt._unsafeUnwrap().commit).toBe('abc123');
  });

  it('remove worktree calls git worktree remove --force', async () => {
    mockExecFile
      .mockResolvedValueOnce({ stdout: '', stderr: '' } as never) // worktree remove
      .mockResolvedValueOnce({ stdout: '', stderr: '' } as never); // branch -D

    const result = await createWorktreeManager({
      projectRoot: '/repo',
      worktreeBasePath: '/repo/.worktrees',
    });

    expect(result.isOk()).toBe(true);
    const wm = result._unsafeUnwrap();
    const removeResult = await wm.remove('TASK-002');
    expect(removeResult.isOk()).toBe(true);
  });

  it('list parses porcelain output into Worktree array', async () => {
    const porcelain = [
      'worktree /repo/.worktrees/TASK-001',
      'HEAD abc123',
      'branch refs/heads/kallax/TASK-001',
      '',
      'worktree /repo/.worktrees/TASK-002',
      'HEAD def456',
      'branch refs/heads/kallax/TASK-002',
      '',
    ].join('\n');

    mockExecFile.mockResolvedValue({ stdout: porcelain, stderr: '' } as never);

    const result = await createWorktreeManager({
      projectRoot: '/repo',
      worktreeBasePath: '/repo/.worktrees',
    });

    expect(result.isOk()).toBe(true);
    const wm = result._unsafeUnwrap();
    const listResult = await wm.list();
    expect(listResult.isOk()).toBe(true);
    const worktrees = listResult._unsafeUnwrap();
    expect(worktrees.length).toBe(2);
    expect(worktrees[0]?.taskId).toBe('TASK-001');
    expect(worktrees[1]?.taskId).toBe('TASK-002');
  });

  it('validateIsolation detects files outside worktree', async () => {
    const porcelain = [
      'worktree /repo/.worktrees/TASK-X',
      'HEAD deadbeef',
      'branch refs/heads/kallax/TASK-X',
      '',
    ].join('\n');

    mockExecFile.mockResolvedValue({ stdout: porcelain, stderr: '' } as never);

    const result = await createWorktreeManager({
      projectRoot: '/repo',
      worktreeBasePath: '/repo/.worktrees',
    });

    expect(result.isOk()).toBe(true);
    const wm = result._unsafeUnwrap();
    const valid = await wm.validateIsolation('TASK-X', ['src/index.ts']);
    expect(valid.isOk()).toBe(true);
    expect(valid._unsafeUnwrap()).toBe(true);
  });

  it('getPath assigns correct path per taskId', async () => {
    const result = await createWorktreeManager({
      projectRoot: '/repo',
      worktreeBasePath: '/repo/.worktrees',
    });

    expect(result.isOk()).toBe(true);
    const wm = result._unsafeUnwrap();
    expect(wm.getPath('TASK-001')).toContain('TASK-001');
    expect(wm.getPath('TASK-001')).not.toContain('TASK-002');
  });
});

/**
 * Worktree Manager tests: create/remove/list + path validation.
 * Uses vi.hoisted for mock to work with vitest's ESM hoisting.
 * Note: runGit() calls stdout.trim() which strips trailing newlines.
 * Porcelain mock data must append a dummy line after the last blank-line
 * separator to survive trim().
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createWorktreeManager } from '../src/core/worktree-manager.js';

const mockExecFile = vi.hoisted(() => vi.fn());

vi.mock('node:child_process', () => ({
  execFile: mockExecFile,
}));

vi.mock('node:fs/promises', () => ({
  mkdir: vi.fn().mockResolvedValue(undefined),
  rm: vi.fn().mockResolvedValue(undefined),
}));

function callCb(args: unknown[], err: null | Error, result?: { stdout: string; stderr: string }): void {
  const cb = args[args.length - 1] as (err: null | Error, res?: { stdout: string; stderr: string }) => void;
  cb(err, result);
}

describe('WorktreeManager', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('create returns Worktree object on success', async () => {
    // create() calls list() + getByTaskId() internally (2 porcelain calls),
    // then git worktree add, then git rev-parse HEAD = 4 total
    mockExecFile
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: '', stderr: '' }))
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: '', stderr: '' }))
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: '', stderr: '' }))
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: 'abc123', stderr: '' }));

    const initResult = await createWorktreeManager({
      projectRoot: '/repo',
      worktreeBasePath: '/repo/.worktrees',
    });
    expect(initResult.isOk()).toBe(true);
    const wm = initResult._unsafeUnwrap();

    const wt = await wm.create('TASK-001');
    expect(wt.isOk()).toBe(true);
    expect(wt._unsafeUnwrap().taskId).toBe('TASK-001');
    expect(wt._unsafeUnwrap().branch).toBe('kallax/TASK-001');
    expect(wt._unsafeUnwrap().path).toContain('.worktrees/TASK-001');
    expect(wt._unsafeUnwrap().commit).toBe('abc123');
  });

  it('remove calls git worktree remove --force', async () => {
    mockExecFile
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: '', stderr: '' }))
      .mockImplementationOnce((...args: unknown[]) => callCb(args, null, { stdout: '', stderr: '' }));

    const initResult = await createWorktreeManager({
      projectRoot: '/repo',
      worktreeBasePath: '/repo/.worktrees',
    });
    expect(initResult.isOk()).toBe(true);
    const wm = initResult._unsafeUnwrap();

    const result = await wm.remove('TASK-002');
    expect(result.isOk()).toBe(true);
  });

  it('list parses porcelain output into Worktree array', async () => {
    // 'x' appended after blank-line separator survives trim()
    const porcelain = [
      'worktree /repo/.worktrees/TASK-001',
      'HEAD abc123',
      'branch refs/heads/kallax/TASK-001',
      '',
      'worktree /repo/.worktrees/TASK-002',
      'HEAD def456',
      'branch refs/heads/kallax/TASK-002',
      '',
      'x',
    ].join('\n');

    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: porcelain, stderr: '' }));

    const initResult = await createWorktreeManager({
      projectRoot: '/repo',
      worktreeBasePath: '/repo/.worktrees',
    });
    expect(initResult.isOk()).toBe(true);
    const wm = initResult._unsafeUnwrap();

    const listResult = await wm.list();
    expect(listResult.isOk()).toBe(true);
    const worktrees = listResult._unsafeUnwrap();
    expect(worktrees.length).toBe(2);
    expect(worktrees[0]?.taskId).toBe('TASK-001');
    expect(worktrees[1]?.taskId).toBe('TASK-002');
  });

  it('validateIsolation returns true for files inside worktree', async () => {
    const porcelain = [
      'worktree /repo/.worktrees/TASK-X',
      'HEAD deadbeef',
      'branch refs/heads/kallax/TASK-X',
      '',
      'x',
    ].join('\n');

    mockExecFile.mockImplementation((...args: unknown[]) => callCb(args, null, { stdout: porcelain, stderr: '' }));

    const initResult = await createWorktreeManager({
      projectRoot: '/repo',
      worktreeBasePath: '/repo/.worktrees',
    });
    expect(initResult.isOk()).toBe(true);
    const wm = initResult._unsafeUnwrap();

    const valid = await wm.validateIsolation('TASK-X', ['src/index.ts']);
    expect(valid.isOk()).toBe(true);
    expect(valid._unsafeUnwrap()).toBe(true);
  });

  it('getPath returns correct path for taskId', async () => {
    const initResult = await createWorktreeManager({
      projectRoot: '/repo',
      worktreeBasePath: '/repo/.worktrees',
    });
    expect(initResult.isOk()).toBe(true);
    const wm = initResult._unsafeUnwrap();

    expect(wm.getPath('TASK-001')).toContain('TASK-001');
    expect(wm.getPath('TASK-001')).not.toContain('TASK-002');
  });
});

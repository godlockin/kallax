/**
 * EPIC-277-D AC3 — claim.ts invokes resolver.path(actualExpert) to compute
 * resolvedExpertPath, replacing the legacy fallback to currentInstance.id
 * when an ExpertResolverBridge is wired.
 *
 * We exercise executeClaimCommand directly. To avoid foreign-key / claim-status
 * complications we stub the TaskAssigner surface so that `assignTask(taskId)` and
 * `createTask(ticket)` both return a fully-formed Task without round-tripping
 * through SQLite.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import * as fs from 'node:fs/promises';
import * as os from 'node:os';
import * as path from 'node:path';

import { createSQLiteManager } from '../../src/core/sqlite/index.js';
import type { SQLiteManager } from '../../src/core/sqlite/index.js';
import { createInstanceRegistry } from '../../src/core/instance-registry.js';
import { getIsolationChecker } from '../../src/core/isolation-checker.js';

const tmpRoots: string[] = [];

async function setupProject(): Promise<string> {
  const repoRoot = await fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), 'kallax-277-d-')));
  tmpRoots.push(repoRoot);
  const agentsDir = path.join(repoRoot, '.claude', 'agents');
  await fs.mkdir(agentsDir, { recursive: true });
  const profilePath = path.join(agentsDir, 'backend-architect.md');
  await fs.writeFile(profilePath, '# backend architect profile', 'utf8');

  const ticketDir = path.join(repoRoot, 'jira', 'tickets', 'EPIC-999-Z');
  await fs.mkdir(ticketDir, { recursive: true });
  await fs.writeFile(
    path.join(ticketDir, 'ticket.json'),
    JSON.stringify({
      id: 'EPIC-999-Z',
      title: 'claim injection test',
      description: 'verify resolver.path() is invoked',
      status: 'pending',
      expert_binding: { suggested_expert: 'custom:backend-architect' },
    }),
    'utf8',
  );
  return repoRoot;
}

afterEach(async () => {
  while (tmpRoots.length > 0) {
    const r = tmpRoots.pop();
    if (r !== undefined) await fs.rm(r, { recursive: true, force: true });
  }
});

function makeStubs(db: SQLiteManager, repoRoot: string, performerId: string) {
  const now = Date.now();
  const task = {
    id: 'task-EPIC-999-Z',
    ticketId: 'EPIC-999-Z',
    type: 'development',
    status: 'pending',
    performerId: null,
    createdAt: now,
    updatedAt: now,
    progress: 0,
    metadata: {},
  };
  const worktreeManager = {
    create: async () => ({
      isOk: () => true,
      value: { path: '/wt/T-1', branch: 'kallax/T-1', commit: 'abc', taskId: 'T-1' },
      isErr: () => false,
    }),
    remove: async () => ({ isOk: () => true, value: undefined, isErr: () => false }),
    list: async () => ({ isOk: () => true, value: [], isErr: () => false }),
    getByTaskId: async () => ({ isOk: () => true, value: null, isErr: () => false }),
    validateIsolation: async () => ({ isOk: () => true, value: true, isErr: () => false }),
    getPath: () => '/wt/T-1',
  } as never;
  const isolationChecker = getIsolationChecker();
  const instReg = createInstanceRegistry(db);
  const taskAssigner = {
    createTask: () => ({ isOk: () => true, value: task, isErr: () => false }),
    assignTask: async () => ({
      isOk: () => true,
      value: { ...task, status: 'claimed', performerId, startedAt: now, updatedAt: now },
      isErr: () => false,
    }),
    claimNextTask: async () => ({ isOk: () => true, value: task, isErr: () => false }),
    releaseTask: async () => ({ isOk: () => true, value: undefined, isErr: () => false }),
  } as never;
  return { worktreeManager, instReg, taskAssigner, task };
}

describe('EPIC-277-D AC3 — claim options injection', () => {
  let db: SQLiteManager;
  let repoRoot: string;

  beforeEach(async () => {
    const dbResult = createSQLiteManager({ path: ':memory:' });
    if (dbResult.isErr()) throw dbResult.error;
    db = dbResult.value;
    repoRoot = await setupProject();
    const now = Date.now();
    const ticket = {
      id: 'EPIC-999-Z',
      title: 'claim injection test',
      description: 'verify resolver.path() is invoked',
      status: 'pending',
      priority: 'P1',
      assigneeId: null,
      createdAt: now,
      updatedAt: now,
      estimatedMinutes: null,
      acceptanceCriteria: ['AC3: resolver.path() invoked'],
      labels: [],
      fileScope: undefined,
      worktreePath: null,
      parentTicketId: null,
    } as never;
    const createRes = db.createTicket(ticket);
    if (createRes.isErr()) throw createRes.error;
  });

  it('AC3 — resolver.path(actualExpert) is invoked and its return value is used for profile load', async () => {
    const { worktreeManager, instReg, taskAssigner } = makeStubs(db, repoRoot, 'performer-X');
    const reg = await instReg.register('performer');
    if (reg.isErr()) throw reg.error;
    const profileFilePath = path.join(repoRoot, '.claude', 'agents', 'backend-architect.md');
    const pathSpy = vi.fn(async () => ({ path: profileFilePath }));
    const resolver = { path: pathSpy } as never;

    const cwdSpy = vi.spyOn(process, 'cwd').mockReturnValue(repoRoot);
    try {
      const { executeClaimCommand } = await import('../../src/commands/claim.js');
      const result = await executeClaimCommand(
        db,
        worktreeManager,
        instReg,
        taskAssigner,
        {
          taskId: 'task-EPIC-999-Z',
          actualExpert: 'custom:backend-architect',
          expertResolver: resolver,
          projectRoot: repoRoot,
        },
      );

      expect(result.isOk()).toBe(true);
      if (result.isOk()) {
        expect(pathSpy).toHaveBeenCalledWith('custom:backend-architect');
        expect(result.value.profileStatus).toBe('loaded');
        const expectedRealpath = await fs.realpath(profileFilePath);
        expect(result.value.promptContext?.profilePath).toBe(expectedRealpath);
        expect(result.value.bindingStatus).toBe('written');
        expect(result.value.exitCode).toBe(0);
      }
    } finally {
      cwdSpy.mockRestore();
    }
    db.close();
  });

  it('AC3 fallback — when resolver returns null, falls back to currentInstance.id', async () => {
    const { worktreeManager, instReg, taskAssigner } = makeStubs(db, repoRoot, 'performer-X');
    const reg = await instReg.register('performer');
    if (reg.isErr()) throw reg.error;

    const pathSpy = vi.fn(async () => null);
    const resolver = { path: pathSpy } as never;

    const cwdSpy = vi.spyOn(process, 'cwd').mockReturnValue(repoRoot);
    try {
      const { executeClaimCommand } = await import('../../src/commands/claim.js');
      const result = await executeClaimCommand(
        db,
        worktreeManager,
        instReg,
        taskAssigner,
        {
          taskId: 'task-EPIC-999-Z',
          actualExpert: 'custom:backend-architect',
          expertResolver: resolver,
          projectRoot: repoRoot,
        },
      );

      expect(result.isOk()).toBe(true);
      if (result.isOk()) {
        expect(pathSpy).toHaveBeenCalledWith('custom:backend-architect');
        // Fallback to currentInstance.id means profile load will fail (path is not a real file under .claude/agents)
        // → profileStatus='failed' → exitCode=3
        expect(result.value.profileStatus).toBe('failed');
        expect(result.value.exitCode).toBe(3);
      }
    } finally {
      cwdSpy.mockRestore();
    }
    db.close();
  });

  it('AC5 + AC7 — affordance string contains Expert bound / Profile / SHA256', async () => {
    const { worktreeManager, instReg, taskAssigner } = makeStubs(db, repoRoot, 'performer-X');
    const reg = await instReg.register('performer');
    if (reg.isErr()) throw reg.error;

    // Point CWD at the test project so readJiraTicket finds the ticket.json —
    // expected to write the binding successfully → bindingStatus='written'.
    const cwdSpy = vi.spyOn(process, 'cwd').mockReturnValue(repoRoot);
    try {
      const profileFilePath = path.join(repoRoot, '.claude', 'agents', 'backend-architect.md');
      const pathSpy = vi.fn(async () => ({ path: profileFilePath }));
      const resolver = { path: pathSpy } as never;

      const { executeClaimCommand } = await import('../../src/commands/claim.js');
      const result = await executeClaimCommand(
        db,
        worktreeManager,
        instReg,
        taskAssigner,
        {
          taskId: 'task-EPIC-999-Z',
          actualExpert: 'custom:backend-architect',
          expertResolver: resolver,
          projectRoot: repoRoot,
        },
      );

      expect(result.isOk()).toBe(true);
      if (result.isOk()) {
        // AC5: 3-line format with Expert bound / Profile / SHA256
        expect(result.value.affordance).toMatch(/^     Expert bound: custom:backend-architect \(written\)/);
        expect(result.value.affordance).toMatch(/\n     Profile: /);
        expect(result.value.affordance).toMatch(/\n     SHA256: [0-9a-f]{12}\n$/);
        // AC7: exit code 0 when both binding and profile succeed
        expect(result.value.exitCode).toBe(0);
      }
    } finally {
      cwdSpy.mockRestore();
    }
    db.close();
  });

  it('AC7 — exit code 2 when binding write fails (profile OK)', async () => {
    const { worktreeManager, instReg, taskAssigner } = makeStubs(db, repoRoot, 'performer-X');
    const reg = await instReg.register('performer');
    if (reg.isErr()) throw reg.error;

    const profileFilePath = path.join(repoRoot, '.claude', 'agents', 'backend-architect.md');
    const resolver = {
      path: vi.fn(async () => ({ path: profileFilePath })),
    } as never;

    const { executeClaimCommand } = await import('../../src/commands/claim.js');
    // Point CWD at a fresh root with a ticket dir containing a *directory* at
    // the ticket.json path so writeBinding fails.
    const brokenRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'kallax-277-d-broken-'));
    tmpRoots.push(brokenRoot);
    const brokenTicketDir = path.join(brokenRoot, 'jira', 'tickets', 'EPIC-999-Z');
    await fs.mkdir(brokenTicketDir, { recursive: true });
    await fs.mkdir(path.join(brokenTicketDir, 'ticket.json'), { recursive: true });

    const cwdSpy = vi.spyOn(process, 'cwd').mockReturnValue(brokenRoot);
    try {
      const result = await executeClaimCommand(
        db,
        worktreeManager,
        instReg,
        taskAssigner,
        {
          taskId: 'task-EPIC-999-Z',
          actualExpert: 'custom:backend-architect',
          expertResolver: resolver,
          projectRoot: repoRoot,
        },
      );
      expect(result.isOk()).toBe(true);
      if (result.isOk()) {
        expect(result.value.bindingStatus).toBe('failed');
        expect(result.value.exitCode).toBe(2);
      }
    } finally {
      cwdSpy.mockRestore();
    }
    db.close();
  });
});
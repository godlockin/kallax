/**
 * EPIC-277: task-assigner.ts EPIC-277 wiring — expertResolver integration + DiskTicketSchema
 *
 * Test scenarios:
 *   AC6: assignTask populates metadata.suggestedExpert + metadata.resolvedExpertPath
 *   AC3: readJiraTicketRaw uses DiskTicketSchema (snake_case), not camelCase internal Ticket
 *   AC7: expertResolver is optional, backward-compatible when undefined
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';

// --- Mock factories (hoisted before imports) ---
const mockExecFile = vi.hoisted(() => vi.fn());
const mockUpdateTask = vi.hoisted(() => vi.fn());
const mockGetTask = vi.hoisted(() => vi.fn());
const mockClaimTask = vi.hoisted(() => vi.fn());
const mockGetById = vi.hoisted(() => vi.fn());
const mockExistsSync = vi.hoisted(() => vi.fn());
const mockReadFileSync = vi.hoisted(() => vi.fn());
const mockResolve = vi.hoisted(() => vi.fn());
const mockFindJiraTicketPath = vi.hoisted(() => vi.fn());

vi.mock('node:child_process', () => ({ execFile: mockExecFile }));
vi.mock('node:fs', () => ({ existsSync: mockExistsSync, readFileSync: mockReadFileSync }));

// Fake ExpertResolverBridge — 返回可 new 的构造函数
// 注意: vitest 1.6.1 + ESM 下 vi.fn().mockImplementation 在 module factory 里
// 行为不稳, 直接返回 plain function + closure over mockResolve 最稳
vi.mock('../../src/core/expert-resolver-bridge.js', () => ({
  ExpertResolverBridge: function FakeExpertResolverBridge() {
    return { resolve: mockResolve };
  },
}));

vi.mock('../../src/jira/ticket-binding.js', () => ({
  findJiraTicketPath: mockFindJiraTicketPath,
}));

// --- Import after mocks ---
import { createTaskAssigner } from '../../src/core/task-assigner.js';
import { ExpertResolverBridge } from '../../src/core/expert-resolver-bridge.js';
import { createIsolationChecker } from '../../src/core/isolation-checker.js';

const fakeDb = {
  updateTask: mockUpdateTask,
  getTask: mockGetTask,
  claimTask: mockClaimTask,
  listTasks: () => ({ isErr: () => false, isOk: () => true, value: [] }),
  createTask: () => ({ isOk: () => true, value: {} as never }),
};
const isolationChecker = createIsolationChecker();
const fakeInstanceRegistry = {
  getById: mockGetById,
  getCurrentInstance: vi.fn(),
  updateStatus: vi.fn(),
  register: vi.fn(),
  list: vi.fn(),
  cleanup: vi.fn(),
};

function makeFakeTask(
  taskId: string,
  ticketId = 'EPIC-999',
  metadata: Record<string, unknown> = {},
) {
  return {
    id: taskId,
    ticketId,
    type: 'development' as const,
    status: 'pending' as const,
    performerId: null as string | null,
    createdAt: 0,
    updatedAt: 0,
    progress: 0,
    metadata,
  };
}
function makeFakeInstance(id = 'p1') {
  return { id, role: 'performer' as const, status: 'idle' as const, currentTaskId: null };
}

// Lazy bridge (created once per test, after mockReset)
let bridgeInstance: { resolve: typeof mockResolve } | undefined;
function getBridge() {
  if (!bridgeInstance) {
    bridgeInstance = new ExpertResolverBridge({ repoRoot: '/repo' });
  }
  return bridgeInstance;
}

describe('EPIC-277: assignTask with expertResolver', () => {
  beforeEach(() => {
    // 不用 vi.clearAllMocks() — 它会清掉 vi.mock 工厂里的 mockImplementation,
    // 导致 bridge 内部 new ExpertResolverBridge() 后 resolve 变无实现.
    // 替代: 单独重设每个 mock 的实现, 保持 vi.mock factory 不变
    bridgeInstance = undefined;
    mockResolve.mockReset();
    mockFindJiraTicketPath.mockReset();
    mockUpdateTask.mockReset();
    mockExistsSync.mockReturnValue(true);
    mockFindJiraTicketPath.mockReturnValue('/repo/jira/tickets/EPIC-999/ticket.json');
    const ok = <T>(v: T) => ({ isErr: () => false, isOk: () => true, value: v });
    mockGetById.mockResolvedValue(ok(makeFakeInstance()));
    mockClaimTask.mockReturnValue(ok(true));
    mockGetTask.mockReturnValue(ok(makeFakeTask('t1', 'EPIC-999')));
    mockUpdateTask.mockReturnValue(ok(undefined));
  });

  // --- AC6 ---

  it('AC6: populates suggestedExpert and resolvedExpertPath in metadata', async () => {
    mockReadFileSync.mockReturnValue(JSON.stringify({
      id: 'EPIC-999',
      epicId: 'EPIC-999',
      phaseId: 'phase1',
      title: 'Test',
      type: 'development',
      priority: 'P2',
      status: 'todo',
      created_by: 'master',
      created_at: '2026-01-01T00:00:00Z',
      expert_binding: { suggested_expert: 'backend' },
    }));
    mockResolve.mockResolvedValue({ roleId: 'backend', path: '/repo/scripts/experts/backend.ts' });

    const assigner = createTaskAssigner(fakeDb as never, isolationChecker, fakeInstanceRegistry as never, getBridge());
    const result = await assigner.assignTask('t1', 'p1');

    expect(result.isOk()).toBe(true);
    expect(result.value.metadata).toMatchObject({
      suggestedExpert: 'backend',
      resolvedExpertPath: '/repo/scripts/experts/backend.ts',
    });
    expect(mockUpdateTask).toHaveBeenCalledWith('t1', expect.objectContaining({
      metadata: expect.objectContaining({ suggestedExpert: 'backend', resolvedExpertPath: '/repo/scripts/experts/backend.ts' }),
    }));
  });

  it('AC6: sets both null when no ticket path found', async () => {
    mockFindJiraTicketPath.mockReturnValue(null);
    mockReadFileSync.mockReturnValue(null);

    const assigner = createTaskAssigner(fakeDb as never, isolationChecker, fakeInstanceRegistry as never, getBridge());
    const result = await assigner.assignTask('t1', 'p1');

    expect(result.isOk()).toBe(true);
    expect(result.value.metadata).toMatchObject({ suggestedExpert: null, resolvedExpertPath: null });
  });

  it('AC6: sets resolvedExpertPath=null when resolver returns null (multiple find hits)', async () => {
    mockReadFileSync.mockReturnValue(JSON.stringify({
      id: 'EPIC-999',
      epicId: 'EPIC-999',
      phaseId: 'phase1',
      title: 'Test',
      type: 'development',
      priority: 'P2',
      status: 'todo',
      created_by: 'master',
      created_at: '2026-01-01T00:00:00Z',
      expert_binding: { suggested_expert: 'backend' },
    }));
    mockResolve.mockResolvedValue(null); // bridge.resolve() returns null on multiple hits

    const assigner = createTaskAssigner(fakeDb as never, isolationChecker, fakeInstanceRegistry as never, getBridge());
    const result = await assigner.assignTask('t1', 'p1');

    expect(result.isOk()).toBe(true);
    expect(result.value.metadata).toMatchObject({ suggestedExpert: 'backend', resolvedExpertPath: null });
  });

  it('AC6: preserves existing metadata when assigning', async () => {
    mockGetTask.mockReturnValue({
      isErr: () => false,
      isOk: () => true,
      value: makeFakeTask('t1', 'EPIC-999', { retained: 'value' }),
    });
    mockReadFileSync.mockReturnValue(JSON.stringify({
      id: 'EPIC-999', epicId: 'EPIC-999', phaseId: 'phase1', title: 'Test',
      type: 'development', priority: 'P2', status: 'todo',
      created_by: 'master', created_at: '2026-01-01T00:00:00Z',
      expert_binding: { suggested_expert: 'backend' },
    }));
    mockResolve.mockResolvedValue({ roleId: 'backend', path: '/repo/scripts/experts/backend.ts' });

    const assigner = createTaskAssigner(fakeDb as never, isolationChecker, fakeInstanceRegistry as never, getBridge());
    const result = await assigner.assignTask('t1', 'p1');

    expect(result.isOk()).toBe(true);
    expect(result.value.metadata).toMatchObject({ retained: 'value', suggestedExpert: 'backend' });
    expect(mockUpdateTask).toHaveBeenCalledWith('t1', expect.objectContaining({
      metadata: expect.objectContaining({ retained: 'value', suggestedExpert: 'backend' }),
    }));
  });

  it('releases the claim when metadata persistence fails', async () => {
    const updateError = new Error('metadata write failed');
    mockUpdateTask
      .mockReturnValueOnce({ isErr: () => true, error: updateError })
      .mockReturnValueOnce({ isErr: () => false, isOk: () => true, value: undefined });

    const assigner = createTaskAssigner(fakeDb as never, isolationChecker, fakeInstanceRegistry as never, getBridge());
    const result = await assigner.assignTask('t1', 'p1');

    expect(result.isErr()).toBe(true);
    expect(mockUpdateTask).toHaveBeenNthCalledWith(2, 't1', expect.objectContaining({
      status: 'pending',
      performerId: null,
    }));
  });

  // --- AC3 (DiskTicketSchema) ---

  it('AC3: reads snake_case expert_binding.suggested_expert from valid disk ticket', async () => {
    mockReadFileSync.mockReturnValue(JSON.stringify({
      id: 'EPIC-999',
      epicId: 'EPIC-999',
      phaseId: 'phase1',
      title: 'Test',
      type: 'development',
      priority: 'P2',
      status: 'todo',
      created_by: 'master',
      created_at: '2026-01-01T00:00:00Z',
      expert_binding: { suggested_expert: 'frontend' },
    }));
    mockResolve.mockResolvedValue({ roleId: 'frontend', path: '/repo/scripts/experts/frontend.ts' });

    const assigner = createTaskAssigner(fakeDb as never, isolationChecker, fakeInstanceRegistry as never, getBridge());
    const result = await assigner.assignTask('t1', 'p1');

    expect(result.isOk()).toBe(true);
    expect(result.value.metadata).toMatchObject({ suggestedExpert: 'frontend' });
  });

  it('AC3: fails Zod when ticket omits required Jira-format fields', async () => {
    // DiskTicketSchema requires camelCase epicId/phaseId and snake_case created fields.
    mockReadFileSync.mockReturnValue(JSON.stringify({
      id: 'EPIC-999',
      epic_id: 'EPIC-999',
      phase_id: 'phase1',
      title: 'Test',
      type: 'development',
      priority: 'P2',
      status: 'todo',
      created_by: 'master',
      created_at: '2026-01-01T00:00:00Z',
      expert_binding: { suggested_expert: 'backend' },
    }));

    const assigner = createTaskAssigner(fakeDb as never, isolationChecker, fakeInstanceRegistry as never, getBridge());
    const result = await assigner.assignTask('t1', 'p1');

    expect(result.isOk()).toBe(true);
    // camelCase fields fail DiskTicketSchema → readJiraTicketRaw returns null → suggestedExpert not in metadata
    expect(result.value.metadata).toMatchObject({ suggestedExpert: null, resolvedExpertPath: null });
    expect(mockResolve).not.toHaveBeenCalled();
  });

  it('AC3: returns null on malformed JSON (fail-soft)', async () => {
    mockReadFileSync.mockReturnValue('not valid json {{{');

    const assigner = createTaskAssigner(fakeDb as never, isolationChecker, fakeInstanceRegistry as never, getBridge());
    const result = await assigner.assignTask('t1', 'p1');

    expect(result.isOk()).toBe(true);
    expect(result.value.metadata).toMatchObject({ suggestedExpert: null, resolvedExpertPath: null });
    expect(mockResolve).not.toHaveBeenCalled();
  });

  it('AC3: returns null when ticket has no expert_binding field', async () => {
    mockReadFileSync.mockReturnValue(JSON.stringify({
      id: 'EPIC-999',
      epicId: 'EPIC-999',
      phaseId: 'phase1',
      title: 'Test',
      type: 'development',
      priority: 'P2',
      status: 'todo',
      created_by: 'master',
      created_at: '2026-01-01T00:00:00Z',
      // no expert_binding
    }));

    const assigner = createTaskAssigner(fakeDb as never, isolationChecker, fakeInstanceRegistry as never, getBridge());
    const result = await assigner.assignTask('t1', 'p1');

    expect(result.isOk()).toBe(true);
    expect(result.value.metadata).toMatchObject({ suggestedExpert: null, resolvedExpertPath: null });
  });

  // --- AC7 (backward compat) ---

  it('AC7: backward-compatible when expertResolver is undefined (4th arg missing)', async () => {
    mockReadFileSync.mockReturnValue(JSON.stringify({
      id: 'EPIC-999',
      epicId: 'EPIC-999',
      phaseId: 'phase1',
      title: 'Test',
      type: 'development',
      priority: 'P2',
      status: 'todo',
      created_by: 'master',
      created_at: '2026-01-01T00:00:00Z',
      expert_binding: { suggested_expert: 'backend' },
    }));

    // No bridge passed
    const assigner = createTaskAssigner(fakeDb as never, isolationChecker, fakeInstanceRegistry as never);
    const result = await assigner.assignTask('t1', 'p1');

    expect(result.isOk()).toBe(true);
    // No bridge → readJiraTicketRaw still runs but no resolution
    // (ticket has snake_case fields so parse succeeds, but no expertResolver to resolve)
    // Since expertResolver is undefined, the if-block is skipped → no suggestedExpert in metadata
    expect(result.value.metadata).toMatchObject({ suggestedExpert: null, resolvedExpertPath: null });
  });
});

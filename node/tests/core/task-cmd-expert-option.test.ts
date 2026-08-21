/**
 * EPIC-277 AC5: `task claim --expert <name>` forwards actualExpert.
 */

import { describe, expect, it, vi } from 'vitest';

const mockExecuteClaimCommand = vi.hoisted(() => vi.fn());

vi.mock('../../src/commands/claim.js', () => ({
  executeClaimCommand: mockExecuteClaimCommand,
}));

import { Command } from 'commander';
import { registerTaskCommands } from '../../src/commands/task-cmd.js';

describe('EPIC-277 AC5: task claim --expert', () => {
  it('registers --expert and forwards it as actualExpert', async () => {
    mockExecuteClaimCommand.mockResolvedValue({
      isErr: () => false,
      value: {
        task: { id: 'task-1' },
        worktreePath: '/tmp/task-1',
        ticket: { title: 'Test ticket' },
        bindingWritten: true,
        bindingStatus: 'written',
        profileStatus: 'none',
        exitCode: 0,
        affordance: '     Expert bound: Backend (written)\n     Profile: none\n     SHA256: -\n',
      },
    });

    const program = new Command();
    registerTaskCommands(program, {
      db: {},
      worktreeManager: {},
      instanceRegistry: {},
      taskAssigner: {},
    } as never);

    await program.parseAsync(
      ['task', 'claim', '--ticket', 'EPIC-999', '--expert', 'Backend'],
      { from: 'user' },
    );

    expect(mockExecuteClaimCommand).toHaveBeenCalledWith(
      expect.anything(),
      expect.anything(),
      expect.anything(),
      expect.anything(),
      { taskId: undefined, ticketId: 'EPIC-999', actualExpert: 'Backend' },
    );
  });
});

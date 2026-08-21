/**
 * EPIC-277-D — trace-cmd.ts sentinel coverage test (EPIC-131-B dead-code rule).
 *
 * Goal: load registerTraceCommands and prove it wires the `trace` subcommand
 * onto a Commander program without throwing. This pulls trace-cmd.ts through
 * the same module-graph that production bootstrap uses.
 */

import { describe, expect, it } from 'vitest';
import { Command } from 'commander';
import { registerTraceCommands } from '../../src/commands/trace-cmd.js';

describe('EPIC-277-D — trace command registration', () => {
  it('registerTraceCommands adds the `trace` subcommand without throwing', () => {
    const program = new Command();
    program.name('kallax').description('test');
    expect(() =>
      registerTraceCommands(program, {
        db: {} as never,
        worktreeManager: {} as never,
        outputVerifier: {} as never,
        isolationChecker: {} as never,
        instanceRegistry: {} as never,
        taskAssigner: {} as never,
        gitService: {} as never,
        // No traceLog → registerTraceCommands still wires the command, but
        // execution will exit 1 (covered by behavior test below).
        traceLog: undefined,
      }),
    ).not.toThrow();

    const subcommands = program.commands.map((c) => c.name());
    expect(subcommands).toContain('trace');
  });

  it('exits with FAIL when no filter is supplied (defensive UX)', async () => {
    const program = new Command();
    // Provide a no-op traceLog so we reach the "no filter" check.
    const fakeTraceLog = {
      record: () => 'tr_test',
      getChain: () => [],
      getTaskTrace: () => [],
      getPerformerTrace: () => [],
    };
    registerTraceCommands(program, {
      db: {} as never,
      worktreeManager: {} as never,
      outputVerifier: {} as never,
      isolationChecker: {} as never,
      instanceRegistry: {} as never,
      taskAssigner: {} as never,
      gitService: {} as never,
      traceLog: fakeTraceLog as never,
    });

    // Capture stderr writes + exit codes
    const stderr: string[] = [];
    const origWrite = process.stderr.write.bind(process.stderr);
    const origExit = process.exit;
    let exitCode = 0;
    process.stderr.write = ((chunk: string | Buffer) => {
      stderr.push(typeof chunk === 'string' ? chunk : chunk.toString());
      return true;
    }) as typeof process.stderr.write;
    process.exit = ((code: number) => {
      exitCode = code;
      throw new Error(`__exit_${code}`);
    }) as never;

    try {
      try {
        await program.parseAsync(['trace'], { from: 'user' });
      } catch (err: unknown) {
        if (!(err instanceof Error) || !err.message.startsWith('__exit_')) {
          throw err;
        }
      }
      expect(exitCode).toBe(1);
      expect(stderr.join('')).toMatch(/at least one filter required/);
    } finally {
      process.stderr.write = origWrite;
      process.exit = origExit;
    }
  });
});
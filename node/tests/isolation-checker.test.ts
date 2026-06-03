/**
 * Isolation Checker tests: scope registration, conflict detection.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createIsolationChecker } from '../src/core/isolation-checker.js';
import type { IsolationChecker } from '../src/core/isolation-checker.js';

describe('IsolationChecker', () => {
  let checker: IsolationChecker;

  beforeEach(() => {
    checker = createIsolationChecker();
  });

  it('registers and lists scopes', () => {
    checker.registerScope({ taskId: 'T1', files: ['src/a.ts'], directories: ['src/'], patterns: [], exclusive: true });
    checker.registerScope({ taskId: 'T2', files: ['src/b.ts'], directories: ['tests/'], patterns: ['*.test.ts'], exclusive: false });

    const scopes = checker.listScopes();
    expect(scopes._unsafeUnwrap().length).toBe(2);
  });

  it('unregisterScope removes scope', () => {
    checker.registerScope({ taskId: 'T1', files: ['x.ts'], directories: [], patterns: [], exclusive: true });
    checker.unregisterScope('T1');

    const scopes = checker.listScopes();
    expect(scopes._unsafeUnwrap().length).toBe(0);
  });

  it('no conflicts when scopes touch different files', () => {
    checker.registerScope({ taskId: 'T1', files: ['src/a.ts'], directories: ['src/mod-a/'], patterns: [], exclusive: true });
    checker.registerScope({ taskId: 'T2', files: ['src/b.ts'], directories: ['src/mod-b/'], patterns: [], exclusive: true });

    const conflicts = checker.checkConflicts('T2', ['src/b.ts']);
    expect(conflicts._unsafeUnwrap().length).toBe(0);
  });

  it('detects exact file conflict between two scopes', () => {
    checker.registerScope({ taskId: 'TA', files: ['src/shared.ts'], directories: [], patterns: [], exclusive: true });

    const conflicts = checker.checkConflicts('TB', ['src/shared.ts']);
    expect(conflicts._unsafeUnwrap().length).toBe(1);
    expect(conflicts._unsafeUnwrap()[0]?.severity).toBe('error'); // both exclusive
  });

  it('detects nested directory conflict', () => {
    checker.registerScope({ taskId: 'TA', files: [], directories: ['src/core/'], patterns: [], exclusive: false });
    checker.registerScope({ taskId: 'TB', files: ['src/core/engine.ts'], directories: [], patterns: [], exclusive: false });

    // TA has src/core/, TB has a file under it -> conflict
    const pairConflict = checker.checkPairConflicts('TA', 'TB');
    expect(pairConflict._unsafeUnwrap()).not.toBeNull();
  });

  it('pair conflict returns null for unknown taskId', () => {
    const result = checker.checkPairConflicts('NONEXISTENT_A', 'NONEXISTENT_B');
    expect(result._unsafeUnwrap()).toBeNull();
  });

  it('validateNewScope detects conflicts before registration', () => {
    checker.registerScope({ taskId: 'EXISTING', files: ['src/conflict.ts'], directories: [], patterns: [], exclusive: true });

    const result = checker.validateNewScope({ taskId: 'NEW', files: ['src/conflict.ts'], directories: [], patterns: [], exclusive: false });
    expect(result._unsafeUnwrap().length).toBe(1);
  });
});

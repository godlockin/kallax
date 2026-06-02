/**
 * KALLAX Core Module Tests
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { ok, err } from 'neverthrow';
import {
  KallaxError,
  KallaxErrorCode,
  TicketStatus,
  TaskStatus,
  InstanceRole,
  VerificationLevel,
} from '../src/types/index.js';
import { createCache } from '../src/core/cache-layer.js';
import { createCircuitBreaker, CircuitState } from '../src/core/circuit-breaker.js';
import { createSagaExecutor } from '../src/core/saga-executor.js';
import { createIsolationChecker } from '../src/core/isolation-checker.js';

describe('KallaxError', () => {
  it('should create error with code and message', () => {
    const error = new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Task not found');

    expect(error.code).toBe(KallaxErrorCode.TASK_NOT_FOUND);
    expect(error.message).toBe('Task not found');
    expect(error.timestamp).toBeGreaterThan(0);
  });

  it('should create error with metadata', () => {
    const error = new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, 'Task not found', {
      metadata: { taskId: 'task-123' },
    });

    expect(error.metadata).toEqual({ taskId: 'task-123' });
  });

  it('should convert unknown errors', () => {
    const originalError = new Error('Original error');
    const kallaxError = KallaxError.fromUnknown(originalError);

    expect(kallaxError.code).toBe(KallaxErrorCode.INTERNAL_ERROR);
    expect(kallaxError.message).toBe('Original error');
    expect(kallaxError.cause).toBe(originalError);
  });
});

describe('Cache Layer', () => {
  it('should create cache with TTL', () => {
    const cache = createCache<string, number>('test-cache', {
      max: 100,
      ttlMs: 5000,
    });

    expect(cache.size()).toBe(0);
  });

  it('should set and get values', () => {
    const cache = createCache<string, number>('test-cache', {
      max: 100,
      ttlMs: 5000,
    });

    cache.set('key1', 42);
    expect(cache.get('key1')).toBe(42);
    expect(cache.size()).toBe(1);
  });

  it('should track cache stats', () => {
    const cache = createCache<string, number>('test-cache', {
      max: 100,
      ttlMs: 5000,
    });

    cache.set('key1', 42);
    cache.get('key1'); // hit
    cache.get('key2'); // miss

    const stats = cache.stats();
    expect(stats.hits).toBe(1);
    expect(stats.misses).toBe(1);
    expect(stats.hitRate).toBe(0.5);
  });

  it('should delete values', () => {
    const cache = createCache<string, number>('test-cache', {
      max: 100,
      ttlMs: 5000,
    });

    cache.set('key1', 42);
    expect(cache.delete('key1')).toBe(true);
    expect(cache.get('key1')).toBeUndefined();
  });
});

describe('Circuit Breaker', () => {
  it('should start in closed state', () => {
    const breaker = createCircuitBreaker({ name: 'test-breaker' });
    expect(breaker.getState()).toBe(CircuitState.CLOSED);
  });

  it('should execute successful operations', async () => {
    const breaker = createCircuitBreaker({ name: 'test-breaker' });

    const result = await breaker.execute(async () => 42);

    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value).toBe(42);
    }
  });

  it('should track failures', async () => {
    const breaker = createCircuitBreaker({
      name: 'test-breaker',
      failureThreshold: 2,
    });

    await breaker.execute(async () => {
      throw new Error('fail');
    });
    await breaker.execute(async () => {
      throw new Error('fail');
    });

    expect(breaker.getState()).toBe(CircuitState.OPEN);
  });

  it('should provide stats', () => {
    const breaker = createCircuitBreaker({ name: 'test-breaker' });
    const stats = breaker.getStats();

    expect(stats.state).toBe(CircuitState.CLOSED);
    expect(stats.failures).toBe(0);
    expect(stats.successes).toBe(0);
  });
});

describe('Saga Executor', () => {
  interface TestState {
    value: number;
    steps: string[];
  }

  it('should execute steps in order', async () => {
    const saga = createSagaExecutor<TestState>({ name: 'test-saga' });

    saga.addStep({
      name: 'step1',
      async execute(state) {
        return { ...state, value: state.value + 1, steps: [...state.steps, 'step1'] };
      },
      async compensate() { /* no-op */ },
    });

    saga.addStep({
      name: 'step2',
      async execute(state) {
        return { ...state, value: state.value * 2, steps: [...state.steps, 'step2'] };
      },
      async compensate() { /* no-op */ },
    });

    const result = await saga.execute({ value: 5, steps: [] });

    expect(result.isOk()).toBe(true);
    if (result.isOk()) {
      expect(result.value.finalState.value).toBe(12); // (5+1)*2
      expect(result.value.completedSteps).toEqual(['step1', 'step2']);
    }
  });

  it('should compensate on failure', async () => {
    const compensated: string[] = [];

    const saga = createSagaExecutor<TestState>({ name: 'test-saga' });

    saga.addStep({
      name: 'step1',
      async execute(state) {
        return { ...state, steps: [...state.steps, 'step1'] };
      },
      async compensate() {
        compensated.push('step1');
      },
    });

    saga.addStep({
      name: 'step2',
      async execute() {
        throw new Error('Step 2 failed');
      },
      async compensate() {
        compensated.push('step2');
      },
    });

    const result = await saga.execute({ value: 0, steps: [] });

    expect(result.isErr()).toBe(true);
    expect(compensated).toContain('step1');
  });
});

describe('Isolation Checker', () => {
  it('should register and list scopes', () => {
    const checker = createIsolationChecker();

    checker.registerScope({
      taskId: 'task-1',
      files: ['src/index.ts'],
      directories: [],
      patterns: [],
      exclusive: true,
    });

    const scopes = checker.listScopes();
    expect(scopes.isOk()).toBe(true);
    if (scopes.isOk()) {
      expect(scopes.value).toHaveLength(1);
      expect(scopes.value[0]?.taskId).toBe('task-1');
    }
  });

  it('should detect file conflicts', () => {
    const checker = createIsolationChecker();

    checker.registerScope({
      taskId: 'task-1',
      files: ['src/index.ts', 'src/utils.ts'],
      directories: [],
      patterns: [],
      exclusive: true,
    });

    checker.registerScope({
      taskId: 'task-2',
      files: ['src/index.ts', 'src/api.ts'],
      directories: [],
      patterns: [],
      exclusive: true,
    });

    const conflict = checker.checkPairConflicts('task-1', 'task-2');
    expect(conflict.isOk()).toBe(true);
    if (conflict.isOk() && conflict.value !== null) {
      expect(conflict.value.conflictingFiles).toContain('src/index.ts');
    }
  });

  it('should allow non-overlapping scopes', () => {
    const checker = createIsolationChecker();

    checker.registerScope({
      taskId: 'task-1',
      files: ['src/feature-a/index.ts'],
      directories: [],
      patterns: [],
      exclusive: true,
    });

    checker.registerScope({
      taskId: 'task-2',
      files: ['src/feature-b/index.ts'],
      directories: [],
      patterns: [],
      exclusive: true,
    });

    const conflict = checker.checkPairConflicts('task-1', 'task-2');
    expect(conflict.isOk()).toBe(true);
    if (conflict.isOk()) {
      expect(conflict.value).toBeNull();
    }
  });
});

describe('Type Enums', () => {
  it('should have correct TicketStatus values', () => {
    expect(TicketStatus.BACKLOG).toBe('backlog');
    expect(TicketStatus.TODO).toBe('todo');
    expect(TicketStatus.IN_PROGRESS).toBe('in_progress');
    expect(TicketStatus.DONE).toBe('done');
  });

  it('should have correct TaskStatus values', () => {
    expect(TaskStatus.PENDING).toBe('pending');
    expect(TaskStatus.CLAIMED).toBe('claimed');
    expect(TaskStatus.RUNNING).toBe('running');
    expect(TaskStatus.COMPLETED).toBe('completed');
  });

  it('should have correct InstanceRole values', () => {
    expect(InstanceRole.CONDUCTOR).toBe('conductor');
    expect(InstanceRole.PERFORMER).toBe('performer');
  });

  it('should have correct VerificationLevel values', () => {
    expect(VerificationLevel.L1_EXISTENCE).toBe(1);
    expect(VerificationLevel.L2_SUBSTANCE).toBe(2);
    expect(VerificationLevel.L3_WIRING).toBe(3);
    expect(VerificationLevel.L4_DATA_FLOW).toBe(4);
  });
});

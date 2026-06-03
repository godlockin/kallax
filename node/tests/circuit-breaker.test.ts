/**
 * Circuit Breaker tests: CLOSED->OPEN->HALF_OPEN state transitions.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createCircuitBreaker } from '../src/core/circuit-breaker.js';

describe('CircuitBreaker', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('starts CLOSED and accepts calls', async () => {
    const cb = createCircuitBreaker({ name: 'test' });
    expect(cb.getState()).toBe('closed');

    const result = await cb.execute(async () => 'ok');
    expect(result.isOk()).toBe(true);
    expect(result._unsafeUnwrap()).toBe('ok');
  });

  it('transitions OPEN after failureThreshold failures', async () => {
    const cb = createCircuitBreaker({ name: 'test', failureThreshold: 2, resetTimeMs: 60000 });

    // 1st failure
    await cb.execute(async () => { throw new Error('fail'); });
    expect(cb.getState()).toBe('closed');

    // 2nd failure — hits threshold
    await cb.execute(async () => { throw new Error('fail'); });
    expect(cb.getState()).toBe('open');

    // Calls rejected while OPEN
    const rejected = await cb.execute(async () => 'should not run');
    expect(rejected.isErr()).toBe(true);
  });

  it('transitions HALF_OPEN after resetTimeMs, then CLOSED on success', async () => {
    const cb = createCircuitBreaker({ name: 'test', failureThreshold: 1, successThreshold: 1, resetTimeMs: 10000 });

    // Trip to OPEN
    await cb.execute(async () => { throw new Error('boom'); });
    expect(cb.getState()).toBe('open');

    // Advance time past reset
    vi.advanceTimersByTime(10000);

    // Should be HALF_OPEN now
    expect(cb.getState()).toBe('half_open');

    const result = await cb.execute(async () => 'recovered');
    expect(result.isOk()).toBe(true);
    expect(cb.getState()).toBe('closed');
  });

  it('single failure in HALF_OPEN reopens immediately', async () => {
    const cb = createCircuitBreaker({ name: 'test', failureThreshold: 3, successThreshold: 1, resetTimeMs: 5000 });

    // Trip to OPEN
    await cb.execute(async () => { throw new Error('fail1'); });
    await cb.execute(async () => { throw new Error('fail2'); });
    await cb.execute(async () => { throw new Error('fail3'); });
    expect(cb.getState()).toBe('open');

    vi.advanceTimersByTime(5000);
    expect(cb.getState()).toBe('half_open');

    // Fail in HALF_OPEN -> back to OPEN
    await cb.execute(async () => { throw new Error('half-open-fail'); });
    expect(cb.getState()).toBe('open');
  });

  it('forceOpen / forceClose override state', () => {
    const cb = createCircuitBreaker({ name: 'test' });
    cb.forceOpen();
    expect(cb.getState()).toBe('open');

    cb.forceClose();
    expect(cb.getState()).toBe('closed');
  });

  it('reset clears counters and goes to CLOSED', async () => {
    const cb = createCircuitBreaker({ name: 'test', failureThreshold: 1 });
    await cb.execute(async () => { throw new Error('fail'); });
    expect(cb.getState()).toBe('open');

    cb.reset();
    expect(cb.getState()).toBe('closed');

    const stats = cb.getStats();
    expect(stats.failures).toBe(0);
    expect(stats.successes).toBe(0);
  });
});

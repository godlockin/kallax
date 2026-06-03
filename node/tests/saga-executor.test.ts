/**
 * Saga Executor tests: compensation, timeout, error isolation.
 */

import { describe, it, expect } from 'vitest';
import { createSagaExecutor } from '../src/core/saga-executor.js';

describe('SagaExecutor', () => {

  it('executes 5 steps successfully', async () => {
    const order: string[] = [];
    const saga = createSagaExecutor<{ x: number }>({ name: 'test' })
      .addStep({ name: 'a', execute: async (s) => { order.push('a'); return { x: s.x + 1 }; }, compensate: async () => { order.push('ca'); } })
      .addStep({ name: 'b', execute: async (s) => { order.push('b'); return { x: s.x + 1 }; }, compensate: async () => { order.push('cb'); } })
      .addStep({ name: 'c', execute: async (s) => { order.push('c'); return { x: s.x + 1 }; }, compensate: async () => { order.push('cc'); } })
      .addStep({ name: 'd', execute: async (s) => { order.push('d'); return { x: s.x + 1 }; }, compensate: async () => { order.push('cd'); } })
      .addStep({ name: 'e', execute: async (s) => { order.push('e'); return { x: s.x + 1 }; }, compensate: async () => { order.push('ce'); } });

    const result = await saga.execute({ x: 0 });
    expect(result.isOk()).toBe(true);
    expect(result.value.success).toBe(true);
    expect(result.value.completedSteps).toEqual(['a', 'b', 'c', 'd', 'e']);
    expect(result.value.finalState.x).toBe(5);
  });

  it('compensates completed steps in reverse on step failure', async () => {
    const order: string[] = [];
    const saga = createSagaExecutor<{ x: number }>({ name: 'test' })
      .addStep({ name: 'a', execute: async (s) => { order.push('a'); return s; }, compensate: async () => { order.push('ca'); } })
      .addStep({ name: 'b', execute: async (s) => { order.push('b'); return s; }, compensate: async () => { order.push('cb'); } })
      .addStep({ name: 'c', execute: async () => { order.push('c'); throw new Error('fail-c'); }, compensate: async () => { order.push('cc'); } });

    const result = await saga.execute({ x: 0 });
    expect(result.isErr()).toBe(true);
    // Compensations run reverse: b then a
    expect(order).toEqual(['a', 'b', 'c', 'cb', 'ca']);
  });

  it('continues compensation even if one compensate throws', async () => {
    const order: string[] = [];
    const saga = createSagaExecutor<{ x: number }>({ name: 'test' })
      .addStep({ name: 'a', execute: async (s) => { order.push('a'); return s; }, compensate: async () => { order.push('ca'); throw new Error('comp-a-fail'); } })
      .addStep({ name: 'b', execute: async (s) => { order.push('b'); return s; }, compensate: async () => { order.push('cb'); } })
      .addStep({ name: 'c', execute: async () => { order.push('c'); throw new Error('fail-c'); }, compensate: async () => { order.push('cc'); } });

    const result = await saga.execute({ x: 0 });
    expect(result.isErr()).toBe(true);
    // Both compensates attempted; a threw but caught — b still ran
    expect(order).toEqual(['a', 'b', 'c', 'cb', 'ca']);
  });

  it('timeout kills slow step within configured limit', async () => {
    const saga = createSagaExecutor<{ x: number }>({ name: 'timeout', timeoutMs: 50 })
      .addStep({ name: 'fast', execute: async (s) => s, compensate: async () => {} })
      .addStep({ name: 'slow', execute: async () => { await new Promise(r => setTimeout(r, 1000)); return { x: 1 }; }, compensate: async () => {} });

    const result = await saga.execute({ x: 0 });
    expect(result.isErr()).toBe(true);
    expect(result.error.message).toContain('failed at step slow');
  });
});

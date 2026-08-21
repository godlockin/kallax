import { describe, it, expect } from 'vitest';
import { createSQLiteManager } from '../../../src/core/sqlite/index.js';

describe('SQLiteManager.traceOps', () => {
  it('exposes traceOps narrow surface (no raw handle leak)', () => {
    const mgrResult = createSQLiteManager({ path: ':memory:' });
    if (mgrResult.isErr()) throw mgrResult.error;
    const mgr = mgrResult.value;
    expect(mgr.traceOps).toBeDefined();
    expect(typeof mgr.traceOps.insertTrace).toBe('function');
    expect(typeof mgr.traceOps.getTraceById).toBe('function');
    expect(typeof mgr.traceOps.getTracesByTarget).toBe('function');
    expect(typeof mgr.traceOps.getTracesByActor).toBe('function');
    expect(typeof mgr.traceOps.getTraceChain).toBe('function');
    // EPIC-277-D: 防 raw handle 暴露 (security ADR)
    expect((mgr as unknown as { getRawDatabase?: unknown }).getRawDatabase).toBeUndefined();
    mgr.close();
  });

  it('insertTrace + getTraceById round-trip (no raw db needed)', () => {
    const mgrResult = createSQLiteManager({ path: ':memory:' });
    if (mgrResult.isErr()) throw mgrResult.error;
    const mgr = mgrResult.value;
    const row = {
      trace_id: 't_test_001',
      timestamp: Date.now(),
      actor: 'test',
      action: 'test_action',
      target: 'test_target',
      detail: '{}',
      result: 'success' as const,
      parent_trace_id: null,
    };
    mgr.traceOps.insertTrace(row);
    const got = mgr.traceOps.getTraceById('t_test_001');
    expect(got).toBeDefined();
    expect(got?.trace_id).toBe('t_test_001');
    expect(got?.action).toBe('test_action');
    mgr.close();
  });
});
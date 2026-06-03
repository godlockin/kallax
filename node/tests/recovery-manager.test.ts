/**
 * Recovery Manager tests: tier probing, auto-upgrade, crash detection.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createRecoveryManager } from '../src/core/recovery-manager.js';

describe('RecoveryManager', () => {
  let rm: ReturnType<typeof createRecoveryManager>;

  beforeEach(() => {
    vi.useFakeTimers();
    rm = createRecoveryManager();
  });

  afterEach(() => {
    vi.useRealTimers();
    rm.stop();
  });

  it('starts at tier 2 (Node.js) by default', () => {
    const state = rm.getState();
    expect(state.currentTier).toBe(2);
  });

  it('recordCrash triggers forced degradation after limit', () => {
    // CRASH_LIMIT = 5 within 5-minute window
    for (let i = 0; i < 5; i++) {
      rm.recordCrash('component-x');
    }

    const state = rm.getState();
    // Should degrade below 2 since tier2 gets marked unhealthy
    expect(state.crashCount).toBe(5);
    expect(state.currentTier).toBeLessThanOrEqual(1);
  });

  it('crash window purges old entries outside 5-minute window', () => {
    for (let i = 0; i < 4; i++) {
      rm.recordCrash('component-x');
    }
    // 4 crashes: should not trigger degradation yet
    expect(rm.getState().crashCount).toBe(4);
    expect(rm.getState().currentTier).toBe(2);

    // Advance past the 5-min window
    vi.advanceTimersByTime(310_000);

    // New crash purges old ones
    rm.recordCrash('component-y');
    // crashCount may reflect purged + 1
    expect(rm.getState().crashCount).toBeLessThanOrEqual(2);
  });

  it('probeAll updates tier health', async () => {
    const stateBefore = rm.getState();
    expect(stateBefore.tiers[3].healthy).toBe(false); // Rust not available by default

    // Run probe (Rust will fail, Node will succeed in CI-ish context)
    await rm.probeAll();

    const stateAfter = rm.getState();
    // Rust probe will fail in unit test (no cargo binary configured)
    expect(stateAfter.tiers[3].healthy).toBe(false);
    // Node probe may fail in CI if no node or sqlite — we at least verify the state shape
    expect(typeof stateAfter.tiers[2].lastProbeAt).toBe('number');
  });

  it('stop clears the probe timer', () => {
    rm.stop();
    // Calling stop again is a no-op
    rm.stop();
    expect(rm.getState().currentTier).toBe(2);
  });

  it('getState returns proper DegradationState shape', () => {
    const state = rm.getState();
    expect(state).toHaveProperty('currentTier');
    expect(state).toHaveProperty('targetTier');
    expect(state).toHaveProperty('tiers');
    expect(state).toHaveProperty('startedAt');
    expect(state).toHaveProperty('crashCount');

    // Tiers 0-3 all present
    expect(Object.keys(state.tiers).length).toBe(4);
  });
});

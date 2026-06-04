/**
 * KALLAX E2E: Auto-Scaler
 * Full auto-scaling lifecycle: initial steady state → queue spike triggers scale up
 * → task drain triggers scale down → cooldown prevents thrashing
 */

import { describe, it, expect, beforeEach } from 'vitest';
import {
  createAutoScaler,
  type AutoScaler,
  type ScaleConfig,
  type FarmState,
} from '../../src/core/auto-scaler.js';

// Fast cooldown for testing — all tests use this config
const TEST_CONFIG: Partial<ScaleConfig> = {
  minPerformers: 1,
  maxPerformers: 10,
  targetQueueDepth: 3,
  scaleUpThreshold: 5,
  scaleDownThreshold: 2,
  cooldownMs: 50,
};

describe('Auto-Scaler (E2E)', () => {
  let scaler: AutoScaler;

  beforeEach(() => {
    scaler = createAutoScaler(TEST_CONFIG);
  });

  function farm(overrides?: Partial<FarmState>): FarmState {
    return {
      taskQueueDepth: 0,
      activePerformers: 0,
      idlePerformers: 1,
      totalPerformers: 1,
      ...overrides,
    };
  }

  // ── Steady state ─────────────────────────────────────────────────────────

  it('returns no scaling when queue is empty and no idle performers', () => {
    const decision = scaler.evaluate(farm({ taskQueueDepth: 0, idlePerformers: 0, totalPerformers: 1 }));
    expect(decision.action).toBe('none');
    expect(decision.reason).toBe('Steady state');
  });

  it('returns no scaling when queue is under threshold', () => {
    const decision = scaler.evaluate(farm({ taskQueueDepth: 3 }));
    expect(decision.action).toBe('none');
  });

  // ── Scale up ─────────────────────────────────────────────────────────────

  it('scales up when queue depth exceeds threshold', () => {
    const decision = scaler.evaluate(farm({ taskQueueDepth: 20, totalPerformers: 1, idlePerformers: 0 }));
    expect(decision.action).toBe('scale_up');
    // targetQueueDepth=3 → ceil(20/3)=7 → min(7,10)=7
    expect(decision.targetCount).toBe(7);
    expect(decision.currentCount).toBe(1);
    expect(decision.queueDepth).toBe(20);
  });

  it('includes reason containing queue depth on scale up', () => {
    const decision = scaler.evaluate(farm({ taskQueueDepth: 14, totalPerformers: 1, idlePerformers: 0 }));
    expect(decision.action).toBe('scale_up');
    expect(decision.reason).toContain('14');
    expect(decision.reason).toContain('5'); // scaleUpThreshold
  });

  it('scales up by at least 1 even for borderline excess', () => {
    const decision = scaler.evaluate(farm({ taskQueueDepth: 6, totalPerformers: 1, idlePerformers: 0 }));
    expect(decision.action).toBe('scale_up');
    expect(decision.targetCount).toBeGreaterThan(decision.currentCount);
  });

  it('respects maxPerformers cap', () => {
    const cappedScaler = createAutoScaler({
      ...TEST_CONFIG,
      maxPerformers: 3,
    });
    const decision = cappedScaler.evaluate(farm({ taskQueueDepth: 50, totalPerformers: 1, idlePerformers: 0 }));
    expect(decision.action).toBe('scale_up');
    expect(decision.targetCount).toBe(3);
  });

  // ── Scale down ───────────────────────────────────────────────────────────

  it('scales down when idle performers exceed threshold and above minimum', () => {
    const decision = scaler.evaluate(farm({
      taskQueueDepth: 0,
      totalPerformers: 5,
      idlePerformers: 4,
      activePerformers: 1,
    }));
    expect(decision.action).toBe('scale_down');
    expect(decision.targetCount).toBeLessThan(decision.currentCount);
    expect(decision.currentCount).toBe(5);
    expect(decision.idleCount).toBe(4);
  });

  it('does not scale down below minPerformers', () => {
    // At minPerformers=1, totalPerformers=1 — scale-down condition skipped
    const decision = scaler.evaluate(farm({ taskQueueDepth: 0, totalPerformers: 1, idlePerformers: 1 }));
    expect(decision.action).toBe('none');
    expect(decision.currentCount).toBe(1);
    expect(decision.targetCount).toBe(1);
  });

  it('does not scale down when idle count is under threshold', () => {
    const decision = scaler.evaluate(farm({
      taskQueueDepth: 0,
      totalPerformers: 3,
      idlePerformers: 1,
      activePerformers: 2,
    }));
    expect(decision.action).toBe('none');
  });

  // ── Cooldown ─────────────────────────────────────────────────────────────

  it('enters cooldown after scale up and returns none on immediate re-evaluation', () => {
    const up = scaler.evaluate(farm({ taskQueueDepth: 20, totalPerformers: 1, idlePerformers: 0 }));
    expect(up.action).toBe('scale_up');

    // Same state immediately — should be in cooldown
    const again = scaler.evaluate(farm({ taskQueueDepth: 20, totalPerformers: 1, idlePerformers: 0 }));
    expect(again.action).toBe('none');
    expect(again.reason).toContain('Cooldown');
  });

  it('exits cooldown after sufficient time passes', async () => {
    const up = scaler.evaluate(farm({ taskQueueDepth: 20, totalPerformers: 1, idlePerformers: 0 }));
    expect(up.action).toBe('scale_up');

    // Wait for cooldown to expire (50ms)
    await new Promise((r) => setTimeout(r, 60));

    const later = scaler.evaluate(farm({ taskQueueDepth: 20, totalPerformers: 1, idlePerformers: 0 }));
    expect(later.action).toBe('scale_up');
  });

  it('enters cooldown after scale down', () => {
    const state: FarmState = { taskQueueDepth: 0, activePerformers: 1, idlePerformers: 4, totalPerformers: 5 };
    const down = scaler.evaluate(state);
    expect(down.action).toBe('scale_down');

    const again = scaler.evaluate(state);
    expect(again.action).toBe('none');
    expect(again.reason).toContain('Cooldown');
  });

  // ── History & Stats ─────────────────────────────────────────────────────

  it('records all decisions in history', () => {
    scaler.evaluate(farm({ taskQueueDepth: 20, totalPerformers: 1, idlePerformers: 0 }));
    scaler.evaluate(farm({ taskQueueDepth: 0, totalPerformers: 1, idlePerformers: 0 }));
    scaler.evaluate(farm({ taskQueueDepth: 0, totalPerformers: 1, idlePerformers: 0 }));

    const history = scaler.getHistory();
    expect(history.length).toBe(3);
    expect(history[0]!.action).toBe('scale_up');
    expect(history[1]!.action).toBe('none');
  });

  it('returns correct stats', () => {
    scaler.evaluate(farm({ taskQueueDepth: 20, totalPerformers: 1, idlePerformers: 0 })); // scale_up
    scaler.evaluate(farm({ taskQueueDepth: 20, totalPerformers: 1, idlePerformers: 0 })); // cooldown -> none

    const stats = scaler.getStats();
    expect(stats.totalScaleUps).toBe(1);
    expect(stats.totalScaleDowns).toBe(0);
    expect(stats.lastScaleAt).toBeGreaterThan(0);
  });

  it('history is immutable copy (push does not affect scaler)', () => {
    const h = scaler.getHistory();
    h.push({} as never);
    expect(scaler.getHistory().length).toBe(0);
  });

  // ── Configure ───────────────────────────────────────────────────────────

  it('supports runtime reconfiguration', () => {
    scaler.configure({ maxPerformers: 2 });
    const decision = scaler.evaluate(farm({ taskQueueDepth: 50, totalPerformers: 1, idlePerformers: 0 }));
    expect(decision.targetCount).toBe(2);
  });

  it('uses defaults when no config is provided', () => {
    const defaultScaler = createAutoScaler();
    defaultScaler.configure({ cooldownMs: 0 }); // disable cooldown for this test
    const decision = defaultScaler.evaluate(farm({ taskQueueDepth: 15, totalPerformers: 1, idlePerformers: 0 }));
    expect(decision.action).toBe('scale_up');
  });
});

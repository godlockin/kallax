import { describe, it, expect } from 'vitest';
import { createAutoScaler, type FarmState, type ScaleConfig } from '../src/core/auto-scaler.js';

const defaultConfig: ScaleConfig = {
  minPerformers: 2,
  maxPerformers: 10,
  targetQueueDepth: 5,
  scaleUpThreshold: 3,
  scaleDownThreshold: 1,
  cooldownMs: 60000,
};

describe('AutoScaler', () => {
  it('returns none when queue is empty and no idle excess', () => {
    const state: FarmState = { taskQueueDepth: 0, activePerformers: 3, idlePerformers: 0, totalPerformers: 3 };
    const scaler = createAutoScaler(defaultConfig);
    const result = scaler.evaluate(state);
    expect(result.action).toBe('none');
  });

  it('scales up when queue depth exceeds threshold', () => {
    const state: FarmState = { taskQueueDepth: 10, activePerformers: 4, idlePerformers: 0, totalPerformers: 4 };
    const result = createAutoScaler(defaultConfig).evaluate(state);
    expect(result.action).toBe('scale_up');
    expect(result.targetCount).toBeGreaterThan(state.totalPerformers);
  });

  it('scales down when idle performers exceed threshold', () => {
    const state: FarmState = { taskQueueDepth: 2, activePerformers: 1, idlePerformers: 5, totalPerformers: 6 };
    const result = createAutoScaler(defaultConfig).evaluate(state);
    expect(result.action).toBe('scale_down');
    expect(result.targetCount).toBeLessThan(state.totalPerformers);
  });

  it('respects maxPerformers cap', () => {
    const state: FarmState = { taskQueueDepth: 100, activePerformers: 10, idlePerformers: 0, totalPerformers: 10 };
    const result = createAutoScaler(defaultConfig).evaluate(state);
    expect(result.targetCount).toBeLessThanOrEqual(defaultConfig.maxPerformers);
  });

  it('respects minPerformers floor on scale down', () => {
    const state: FarmState = { taskQueueDepth: 0, activePerformers: 0, idlePerformers: 3, totalPerformers: 3 };
    const cfg = { ...defaultConfig, minPerformers: 2 };
    const result = createAutoScaler(cfg).evaluate(state);
    expect(result.targetCount).toBeGreaterThanOrEqual(cfg.minPerformers);
  });

  it('includes reason in decision', () => {
    const state: FarmState = { taskQueueDepth: 8, activePerformers: 2, idlePerformers: 0, totalPerformers: 2 };
    const result = createAutoScaler(defaultConfig).evaluate(state);
    expect(result.reason.length).toBeGreaterThan(0);
    expect(result.queueDepth).toBe(state.taskQueueDepth);
  });
});

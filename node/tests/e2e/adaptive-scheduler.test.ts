import { describe, it, expect, beforeEach } from 'vitest';
import { createAdaptiveScheduler, type AdaptiveScheduler } from '../../src/core/adaptive-scheduler.js';

describe('AdaptiveScheduler', () => {
  let scheduler: AdaptiveScheduler;
  beforeEach(() => { scheduler = createAdaptiveScheduler(); });

  it('returns standard tier for new performer', () => {
    const w = scheduler.getWeight('new-perf');
    expect(w).toBeNull(); // no history yet
  });

  it('computes high quality score for perfect performer', () => {
    for (let i = 0; i < 10; i++) {
      scheduler.recordCompletion('star', true, 5000, true);
    }
    const w = scheduler.getWeight('star');
    expect(w).not.toBeNull();
    expect(w!.qualityScore).toBe(100);
    expect(w!.tier).toBe('preferred');
  });

  it('downgrades to probation after repeated failures', () => {
    for (let i = 0; i < 10; i++) {
      scheduler.recordCompletion('struggler', false, 120000, false);
    }
    const w = scheduler.getWeight('struggler');
    expect(w).not.toBeNull();
    expect(w!.tier).toBe('probation');
  });

  it('maintains sliding window of last 10 results', () => {
    // 5 successes first
    for (let i = 0; i < 5; i++) scheduler.recordCompletion('mixed', true, 5000, true);
    // then 15 failures
    for (let i = 0; i < 15; i++) scheduler.recordCompletion('mixed', false, 5000, false);

    const h = scheduler.getHistory('mixed');
    expect(h).not.toBeNull();
    expect(h!.last10Results.length).toBe(10);
    expect(h!.totalTasks).toBe(20);
    // Last 10 should all be failures
    expect(h!.last10Results.filter(r => r).length).toBe(0);
  });

  it('sorts weight by totalWeight descending', () => {
    for (let i = 0; i < 10; i++) scheduler.recordCompletion('good', true, 3000, true);
    for (let i = 0; i < 5; i++) { scheduler.recordCompletion('mid', true, 5000, true); scheduler.recordCompletion('mid', false, 10000, false); }
    for (let i = 0; i < 10; i++) scheduler.recordCompletion('bad', false, 60000, false);

    const weights = scheduler.getAllWeights();
    expect(weights.length).toBe(3);
    expect(weights[0]!.performerId).toBe('good');
    expect(weights[2]!.performerId).toBe('bad');
  });

  it('returns standard tier for getPerformerTier on unknown', () => {
    expect(scheduler.getPerformerTier('unknown')).toBe('standard');
  });

  it('recommendation includes tier-specific advice', () => {
    for (let i = 0; i < 10; i++) scheduler.recordCompletion('top', true, 1000, true);
    const w = scheduler.getWeight('top')!;
    expect(w.recommendation).toContain('complex');
  });
});

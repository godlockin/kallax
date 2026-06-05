import { describe, it, expect, beforeEach } from 'vitest';
import { createAdaptiveScheduler, type AdaptiveScheduler } from '../../src/core/adaptive-scheduler.js';

describe('AdaptiveScheduler', () => {
  let sch: AdaptiveScheduler;
  beforeEach(() => { sch = createAdaptiveScheduler(); });
  it('null for new performer', () => { expect(sch.getWeight('new')).toBeNull(); });
  it('preferred tier for perfect', () => {
    for (let i=0;i<10;i++) sch.recordCompletion('star',true,5000,true);
    expect(sch.getWeight('star')!.tier).toBe('preferred');
  });
  it('probation after failures', () => {
    for (let i=0;i<10;i++) sch.recordCompletion('bad',false,120000,false);
    expect(sch.getWeight('bad')!.tier).toBe('probation');
  });
  it('sliding window of 10', () => {
    for (let i=0;i<5;i++) sch.recordCompletion('m',true,5,true);
    for (let i=0;i<15;i++) sch.recordCompletion('m',false,5,false);
    expect(sch.getHistory('m')!.last10Results.length).toBe(10);
    expect(sch.getHistory('m')!.totalTasks).toBe(20);
  });
  it('sorts by totalWeight', () => {
    for (let i=0;i<10;i++) sch.recordCompletion('g',true,1,true);
    for (let i=0;i<10;i++) { sch.recordCompletion('m',true,5,true); sch.recordCompletion('m',false,10,false); }
    for (let i=0;i<10;i++) sch.recordCompletion('b',false,60,false);
    const w = sch.getAllWeights();
    expect(w[0]!.performerId).toBe('g');
    expect(w[2]!.performerId).toBe('b');
  });
  it('standard for unknown', () => { expect(sch.getPerformerTier('?')).toBe('standard'); });
});

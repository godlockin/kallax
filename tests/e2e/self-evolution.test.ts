import { describe, it, expect, beforeEach } from 'vitest';
import { createSelfEvolution, type SelfEvolution } from '../../src/core/self-evolution.js';

describe('SelfEvolution', () => {
  let ev: SelfEvolution;
  beforeEach(() => { ev = createSelfEvolution(); });
  it('creates ticket', () => { expect(ev.createImprovement('Fix','desc','system-metric','').status).toBe('open'); });
  it('creates with priority', () => { expect(ev.createImprovement('C','','quality-trend','','P0').priority).toBe('P0'); });
  it('sorts by priority', () => {
    ev.createImprovement('L','','system-metric','','P2');
    ev.createImprovement('H','','quality-trend','','P0');
    ev.createImprovement('M','','performer-feedback','','P1');
    const o = ev.getOpenImprovements();
    expect(o[0]!.priority).toBe('P0'); expect(o[2]!.priority).toBe('P2');
  });
  it('claims and completes', () => {
    const t = ev.createImprovement('T','','system-metric','');
    expect(ev.claimImprovement(t.id,'p1')).toBe(true);
    expect(ev.claimImprovement(t.id,'p2')).toBe(false);
    expect(ev.completeImprovement(t.id)).toBe(true);
    expect(ev.completeImprovement('?')).toBe(false);
  });
  it('stats correct', () => {
    ev.createImprovement('A','','quality-trend','');
    const t = ev.createImprovement('B','','system-metric','');
    ev.claimImprovement(t.id,'p'); ev.completeImprovement(t.id);
    const s = ev.getStats();
    expect(s.totalImprovements).toBe(2); expect(s.openCount).toBe(1);
    expect(s.selfManagedRatio).toBe(50);
  });
  it('listAll', () => {
    ev.createImprovement('A','','q',''); ev.createImprovement('B','','s','');
    expect(ev.listAll().length).toBe(2);
  });
});

import { describe, it, expect, beforeEach } from 'vitest';
import { createSelfEvolution, type SelfEvolution } from '../../src/core/self-evolution.js';

describe('SelfEvolution', () => {
  let evo: SelfEvolution;
  beforeEach(() => { evo = createSelfEvolution(); });

  it('creates improvement ticket', () => {
    const t = evo.createImprovement('Fix memory leak', 'Agent pool not releasing', 'system-metric', 'heap 200MB+');
    expect(t.id).toBeTruthy();
    expect(t.status).toBe('open');
    expect(t.priority).toBe('P2');
  });

  it('creates with explicit priority', () => {
    const t = evo.createImprovement('Critical bug', 'Data loss', 'quality-trend', 'success rate 0%', 'P0');
    expect(t.priority).toBe('P0');
  });

  it('lists open improvements sorted by priority', () => {
    evo.createImprovement('Low', '', 'system-metric', '', 'P2');
    evo.createImprovement('High', '', 'quality-trend', '', 'P0');
    evo.createImprovement('Mid', '', 'performer-feedback', '', 'P1');

    const open = evo.getOpenImprovements();
    expect(open.length).toBe(3);
    expect(open[0]!.priority).toBe('P0');
    expect(open[1]!.priority).toBe('P1');
    expect(open[2]!.priority).toBe('P2');
  });

  it('claims and completes improvement', () => {
    const t = evo.createImprovement('Test', '', 'system-metric', '');
    expect(evo.claimImprovement(t.id, 'perf-1')).toBe(true);
    expect(evo.claimImprovement(t.id, 'perf-2')).toBe(false); // already claimed

    expect(evo.completeImprovement(t.id)).toBe(true);
    expect(evo.completeImprovement('nonexistent')).toBe(false);
  });

  it('returns correct stats', () => {
    evo.createImprovement('A', '', 'quality-trend', '');
    const t = evo.createImprovement('B', '', 'system-metric', '');
    evo.claimImprovement(t.id, 'p1');
    evo.completeImprovement(t.id);

    const stats = evo.getStats();
    expect(stats.totalImprovements).toBe(2);
    expect(stats.openCount).toBe(1);
    expect(stats.doneCount).toBe(1);
    expect(stats.selfManagedRatio).toBe(50);
  });

  it('listAll returns all tickets', () => {
    evo.createImprovement('A', '', 'quality-trend', '');
    evo.createImprovement('B', '', 'system-metric', '');
    expect(evo.listAll().length).toBe(2);
  });
});

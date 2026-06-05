import { describe, it, expect, beforeEach } from 'vitest';
import { createQualityTrend, type QualityTrend } from '../../src/core/quality-trend.js';

describe('QualityTrend', () => {
  let qt: QualityTrend;
  beforeEach(() => { qt = createQualityTrend(); });
  function s(sr=90,tc=10,d=5000,ot=85) { return {timestamp:Date.now(),successRate:sr,taskCount:tc,avgDurationMs:d,onTimeRate:ot}; }
  it('null for no history', () => { expect(qt.analyze('none')).toBeNull(); });
  it('stable for consistent', () => {
    for(let i=0;i<5;i++) qt.recordSnapshot('s',s(90));
    expect(qt.analyze('s')!.trend).toBe('stable');
  });
  it('improving trend', () => {
    for(let i=0;i<3;i++) qt.recordSnapshot('l',s(50));
    for(let i=0;i<5;i++) qt.recordSnapshot('l',s(90));
    expect(qt.analyze('l')!.trend).toBe('improving');
  });
  it('declining anomaly', () => {
    for(let i=0;i<3;i++) qt.recordSnapshot('d',s(95));
    for(let i=0;i<5;i++) qt.recordSnapshot('d',s(40));
    const a = qt.analyze('d')!;
    expect(a.trend).toBe('declining');
    expect(a.anomaly).toBe(true);
  });
  it('critical rate anomaly', () => {
    for(let i=0;i<10;i++) qt.recordSnapshot('c',s(30,10));
    expect(qt.analyze('c')!.anomaly).toBe(true);
  });
  it('detectAnomalies filters', () => {
    for(let i=0;i<8;i++) qt.recordSnapshot('ok',s(90));
    for(let i=0;i<8;i++) qt.recordSnapshot('bad',s(20,10));
    const an = qt.detectAnomalies();
    expect(an.length).toBe(1);
    expect(an[0]!.performerId).toBe('bad');
  });
  it('window aggregation', () => {
    qt.recordSnapshot('p',s()); qt.recordSnapshot('p',s());
    const a = qt.analyze('p')!;
    expect(a.windows.daily.taskCount).toBeGreaterThanOrEqual(0);
  });
  it('getSnapshots limit', () => {
    for(let i=0;i<30;i++) qt.recordSnapshot('m',s(80));
    expect(qt.getSnapshots('m',5).length).toBe(5);
    expect(qt.getSnapshots('m').length).toBe(20);
  });
});

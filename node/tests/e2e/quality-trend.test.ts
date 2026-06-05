import { describe, it, expect, beforeEach } from 'vitest';
import { createQualityTrend, type QualityTrend } from '../../src/core/quality-trend.js';

describe('QualityTrend', () => {
  let qt: QualityTrend;
  beforeEach(() => { qt = createQualityTrend(); });

  function snap(overrides: Partial<{ successRate: number; taskCount: number; avgDurationMs: number; onTimeRate: number }> = {}) {
    return {
      timestamp: Date.now(),
      successRate: overrides.successRate ?? 90,
      taskCount: overrides.taskCount ?? 10,
      avgDurationMs: overrides.avgDurationMs ?? 5000,
      onTimeRate: overrides.onTimeRate ?? 85,
    };
  }

  it('returns null for performer with no history', () => {
    expect(qt.analyze('nonexistent')).toBeNull();
  });

  it('detects stable trend for consistent performer', () => {
    for (let i = 0; i < 5; i++) qt.recordSnapshot('stable-perf', snap({ successRate: 90 }));
    const analysis = qt.analyze('stable-perf');
    expect(analysis).not.toBeNull();
    expect(analysis!.trend).toBe('stable');
  });

  it('detects improving trend', () => {
    // Start low
    for (let i = 0; i < 3; i++) qt.recordSnapshot('learner', snap({ successRate: 50 }));
    // Improve
    for (let i = 0; i < 5; i++) qt.recordSnapshot('learner', snap({ successRate: 90 }));
    const analysis = qt.analyze('learner');
    expect(analysis).not.toBeNull();
    expect(analysis!.trend).toBe('improving');
  });

  it('detects declining trend as anomaly', () => {
    for (let i = 0; i < 3; i++) qt.recordSnapshot('decliner', snap({ successRate: 95 }));
    for (let i = 0; i < 5; i++) qt.recordSnapshot('decliner', snap({ successRate: 40 }));
    const analysis = qt.analyze('decliner');
    expect(analysis).not.toBeNull();
    expect(analysis!.trend).toBe('declining');
    expect(analysis!.anomaly).toBe(true);
  });

  it('detects critical success rate anomaly', () => {
    for (let i = 0; i < 10; i++) qt.recordSnapshot('critical', snap({ successRate: 30, taskCount: 10 }));
    const analysis = qt.analyze('critical');
    expect(analysis).not.toBeNull();
    expect(analysis!.anomaly).toBe(true);
    expect(analysis!.anomalyReason).toContain('critical');
  });

  it('detectAnomalies returns only anomalous performers', () => {
    for (let i = 0; i < 8; i++) qt.recordSnapshot('normal', snap({ successRate: 90 }));
    for (let i = 0; i < 8; i++) qt.recordSnapshot('bad', snap({ successRate: 20, taskCount: 10 }));

    const anomalies = qt.detectAnomalies();
    expect(anomalies.length).toBe(1);
    expect(anomalies[0]!.performerId).toBe('bad');
  });

  it('computes daily, weekly, monthly windows', () => {
    qt.recordSnapshot("perf", snap()); qt.recordSnapshot("perf", snap());
    const analysis = qt.analyze('perf');
    expect(analysis).not.toBeNull();
    expect(analysis!.windows.daily.taskCount).toBeGreaterThanOrEqual(0);
    expect(analysis!.windows.weekly.successRate).toBeGreaterThanOrEqual(0);
    expect(analysis!.windows.monthly.onTimeRate).toBeGreaterThanOrEqual(0);
  });

  it('getSnapshots returns limited history', () => {
    for (let i = 0; i < 30; i++) qt.recordSnapshot('many', snap({ successRate: 80 }));
    expect(qt.getSnapshots('many').length).toBe(20); // default limit
    expect(qt.getSnapshots('many', 5).length).toBe(5);
  });
});

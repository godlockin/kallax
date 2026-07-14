/**
 * KALLAX Quality Trend — time-windowed agent quality tracking.
 * Detects trends (improving/declining/stable) and anomalies (sudden quality drops).
 */
import { logger } from '../utils/logger.js';

export interface QualitySnapshot {
  timestamp: number;
  successRate: number;
  taskCount: number;
  avgDurationMs: number;
  onTimeRate: number;
}

export interface TrendAnalysis {
  performerId: string;
  current: QualitySnapshot;
  trend: 'improving' | 'declining' | 'stable';
  trendStrength: number; // -100 to 100
  anomaly: boolean;
  anomalyReason?: string;
  windows: { daily: QualitySnapshot; weekly: QualitySnapshot; monthly: QualitySnapshot };
}

export interface QualityTrend {
  recordSnapshot(performerId: string, snapshot: QualitySnapshot): void;
  analyze(performerId: string): TrendAnalysis | null;
  detectAnomalies(): TrendAnalysis[];
  getSnapshots(performerId: string, limit?: number): QualitySnapshot[];
  getAllTrends(): TrendAnalysis[];
}

const MAX_SNAPSHOTS = 100;

function aggregateSnapshots(snapshots: QualitySnapshot[], since: number): QualitySnapshot {
  const filtered = snapshots.filter(s => s.timestamp >= since);
  if (filtered.length === 0) {
    return { timestamp: Date.now(), successRate: 0, taskCount: 0, avgDurationMs: 0, onTimeRate: 0 };
  }
  const total = filtered.length;
  const lastSnapshot = filtered[filtered.length - 1];
  return {
    timestamp: lastSnapshot.timestamp,
    successRate: Math.round(filtered.reduce((a, s) => a + s.successRate, 0) / total),
    taskCount: filtered.reduce((a, s) => a + s.taskCount, 0),
    avgDurationMs: Math.round(filtered.reduce((a, s) => a + s.avgDurationMs, 0) / total),
    onTimeRate: Math.round(filtered.reduce((a, s) => a + s.onTimeRate, 0) / total),
  };
}

function detectTrend(recent: QualitySnapshot[], older: QualitySnapshot[]): { trend: TrendAnalysis['trend']; strength: number } {
  if (recent.length < 2 || older.length < 2) return { trend: 'stable', strength: 0 };
  const recentAvg = recent.reduce((a, s) => a + s.successRate, 0) / recent.length;
  const olderAvg = older.reduce((a, s) => a + s.successRate, 0) / older.length;
  const diff = recentAvg - olderAvg;

  if (diff > 5) return { trend: 'improving', strength: Math.min(100, Math.round(diff * 10)) };
  if (diff < -5) return { trend: 'declining', strength: Math.max(-100, Math.round(diff * 10)) };
  return { trend: 'stable', strength: Math.round(diff * 5) };
}

export function createQualityTrend(): QualityTrend {
  const snapshots = new Map<string, QualitySnapshot[]>();

  return {
    recordSnapshot(performerId: string, snapshot: QualitySnapshot): void {
      let list = snapshots.get(performerId);
      if (!list) { list = []; snapshots.set(performerId, list); }
      list.push(snapshot);
      if (list.length > MAX_SNAPSHOTS) list.shift();
    },

    analyze(performerId: string): TrendAnalysis | null {
      const list = snapshots.get(performerId);
      if (!list || list.length < 2) return null;

      const now = Date.now();
      const current = list[list.length - 1];
      const daily = aggregateSnapshots(list, now - 86_400_000);
      const weekly = aggregateSnapshots(list, now - 604_800_000);
      const monthly = aggregateSnapshots(list, now - 2_592_000_000);

      const recent = list.slice(-5);
      const older = list.slice(0, Math.max(0, list.length - 5));
      const { trend, strength } = detectTrend(recent, older);

      let anomaly = false;
      let anomalyReason: string | undefined;
      if (trend === 'declining' && strength < -30) {
        anomaly = true;
        anomalyReason = `Quality declining sharply (strength: ${String(strength)}). Review performer assignment.`;
      }
      if (current.successRate < 50 && current.taskCount > 5) {
        anomaly = true;
        anomalyReason = `Success rate critical: ${String(current.successRate)}% over ${String(current.taskCount)} tasks.`;
      }

      const analysis: TrendAnalysis = {
        performerId, current, trend, trendStrength: strength, anomaly, anomalyReason,
        windows: { daily, weekly, monthly },
      };

      if (anomaly) logger.warn({ performerId, trend, anomalyReason }, 'quality anomaly detected');
      return analysis;
    },

    detectAnomalies(): TrendAnalysis[] {
      const results: TrendAnalysis[] = [];
      for (const pid of snapshots.keys()) {
        const a = this.analyze(pid);
        if (a?.anomaly === true) results.push(a);
      }
      return results;
    },

    getSnapshots(performerId: string, limit = 20): QualitySnapshot[] {
      const list = snapshots.get(performerId);
      return list ? list.slice(-limit) : [];
    },

    getAllTrends(): TrendAnalysis[] {
      const results: TrendAnalysis[] = [];
      for (const pid of snapshots.keys()) {
        const a = this.analyze(pid);
        if (a) results.push(a);
      }
      return results.sort((a, b) => b.trendStrength - a.trendStrength);
    },
  };
}

let instance: QualityTrend | null = null;
export function getQualityTrend(): QualityTrend {
  return instance ?? (instance = createQualityTrend());
}

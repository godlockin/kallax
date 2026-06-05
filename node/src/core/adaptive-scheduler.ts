/**
 * KALLAX Adaptive Scheduler — history-aware task assignment.
 * Tracks performer performance and adjusts scheduling weights dynamically.
 *
 * Rules:
 *   - High success rate (>90%) → priority boost, trusted with complex tasks
 *   - Low success rate (<70%) → priority penalty, require extra review
 *   - Fast completion → assigned more small tasks
 *   - Slow / late → reduced parallelism, simpler tasks
 */
import { logger } from '../utils/logger.js';

export interface PerformerHistory {
  performerId: string;
  totalTasks: number;
  successCount: number;
  failureCount: number;
  avgCompletionMs: number;
  onTimeCount: number;
  lateCount: number;
  last10Results: boolean[]; // sliding window of last 10
  recentCompletionTimes: number[]; // last 10 completion times
}

export interface ScheduleWeight {
  performerId: string;
  qualityScore: number;     // 0-100, based on success rate
  speedScore: number;       // 0-100, based on avg completion time
  reliabilityScore: number; // 0-100, based on on-time rate
  totalWeight: number;      // 0-100, combined score
  tier: 'preferred' | 'standard' | 'probation';
  recommendation: string;
}

export interface AdaptiveScheduler {
  recordCompletion(performerId: string, success: boolean, durationMs: number, onTime: boolean): void;
  getWeight(performerId: string): ScheduleWeight | null;
  getAllWeights(): ScheduleWeight[];
  getHistory(performerId: string): PerformerHistory | null;
  getPerformerTier(performerId: string): ScheduleWeight['tier'];
}

const WINDOW_SIZE = 10;
const PREFERRED_THRESHOLD = 85;
const PROBATION_THRESHOLD = 60;

function createEmptyHistory(performerId: string): PerformerHistory {
  return {
    performerId, totalTasks: 0, successCount: 0, failureCount: 0,
    avgCompletionMs: 0, onTimeCount: 0, lateCount: 0,
    last10Results: [], recentCompletionTimes: [],
  };
}

function computeWeight(history: PerformerHistory): ScheduleWeight {
  const qualityScore = history.totalTasks > 0
    ? Math.round((history.successCount / history.totalTasks) * 100)
    : 50;

  const speedScore = history.recentCompletionTimes.length > 0
    ? Math.max(0, 100 - Math.round(history.avgCompletionMs / 60000)) // penalize >1min avg
    : 50;

  const reliabilityScore = history.totalTasks > 0
    ? Math.round((history.onTimeCount / history.totalTasks) * 100)
    : 50;

  const totalWeight = Math.round((qualityScore * 0.5) + (speedScore * 0.2) + (reliabilityScore * 0.3));

  let tier: ScheduleWeight['tier'] = 'standard';
  if (totalWeight >= PREFERRED_THRESHOLD) tier = 'preferred';
  else if (totalWeight < PROBATION_THRESHOLD) tier = 'probation';

  const recommendation = tier === 'preferred'
    ? 'Assign complex/high-priority tasks. Trust with autonomy.'
    : tier === 'probation'
    ? 'Assign simple tasks only. Require extra review. Consider retraining.'
    : 'Standard assignment. Monitor for changes.';

  return { performerId: history.performerId, qualityScore, speedScore, reliabilityScore, totalWeight, tier, recommendation };
}

export function createAdaptiveScheduler(): AdaptiveScheduler {
  const histories = new Map<string, PerformerHistory>();

  return {
    recordCompletion(performerId: string, success: boolean, durationMs: number, onTime: boolean): void {
      let h = histories.get(performerId);
      if (!h) { h = createEmptyHistory(performerId); histories.set(performerId, h); }

      h.totalTasks++;
      if (success) h.successCount++; else h.failureCount++;
      if (onTime) h.onTimeCount++; else h.lateCount++;

      h.last10Results.push(success);
      if (h.last10Results.length > WINDOW_SIZE) h.last10Results.shift();

      h.recentCompletionTimes.push(durationMs);
      if (h.recentCompletionTimes.length > WINDOW_SIZE) h.recentCompletionTimes.shift();
      h.avgCompletionMs = Math.round(h.recentCompletionTimes.reduce((a, b) => a + b, 0) / h.recentCompletionTimes.length);

      const weight = computeWeight(h);
      logger.info({ performerId, tier: weight.tier, totalWeight: weight.totalWeight }, 'adaptive weight updated');
    },

    getWeight(performerId: string): ScheduleWeight | null {
      const h = histories.get(performerId);
      return h ? computeWeight(h) : null;
    },

    getAllWeights(): ScheduleWeight[] {
      return Array.from(histories.values()).map(computeWeight).sort((a, b) => b.totalWeight - a.totalWeight);
    },

    getHistory(performerId: string): PerformerHistory | null {
      return histories.get(performerId) ?? null;
    },

    getPerformerTier(performerId: string): ScheduleWeight['tier'] {
      const w = this.getWeight(performerId);
      return w?.tier ?? 'standard';
    },
  };
}

let instance: AdaptiveScheduler | null = null;
export function getAdaptiveScheduler(): AdaptiveScheduler {
  return instance ?? (instance = createAdaptiveScheduler());
}

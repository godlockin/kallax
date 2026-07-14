/**
 * KALLAX Context Tracker — monitors context window usage per performer session.
 */

import { logger } from '../../utils/logger.js';
import { getContextEstimator } from './estimator.js';
import { getContextCompressor } from './compressor.js';

export interface ContextUsage {
  performerId: string;
  currentTokens: number;
  maxTokens: number;
  compressionThreshold: number; // percentage
  compressionsTriggered: number;
  lastUpdated: number;
  sessionStart: number;
  history: Array<{ timestamp: number; tokens: number; event: string }>;
}

export type CompressionAction =
  | { type: 'none' }
  | { type: 'required'; current: number; target: number };

export interface ContextTracker {
  registerPerformer: (performerId: string, maxTokens?: number) => void;
  unregisterPerformer: (performerId: string) => void;
  updateTokens: (performerId: string, tokens: number, autoCompress?: boolean) => CompressionAction;
  addTokens: (performerId: string, text: string, type: 'text' | 'code' | 'json') => number;
  resetUsage: (performerId: string) => void;
  getUsage: (performerId: string) => ContextUsage | undefined;
  getAllUsages: () => ContextUsage[];
  getStats: () => TrackerStats;
  recordEvent: (performerId: string, event: string) => void;
}

export interface TrackerStats {
  readonly trackedPerformers: number;
  readonly totalTokens: number;
  readonly totalCapacity: number;
  readonly averageUsagePercent: number;
  readonly performersNearLimit: number;
  readonly totalCompressions: number;
}

const DEFAULT_MAX_TOKENS = 128_000;
const COMPRESSION_THRESHOLD = 80;
const MAX_HISTORY = 100;

export function createContextTracker(): ContextTracker {
  const usages = new Map<string, ContextUsage>();
  const estimator = getContextEstimator();
  const compressor = getContextCompressor();

  function getOrCreate(performerId: string): ContextUsage {
    let usage = usages.get(performerId);
    if (!usage) {
      usage = {
        performerId,
        currentTokens: 0,
        maxTokens: DEFAULT_MAX_TOKENS,
        compressionThreshold: COMPRESSION_THRESHOLD,
        compressionsTriggered: 0,
        lastUpdated: Date.now(),
        sessionStart: Date.now(),
        history: [],
      };
      usages.set(performerId, usage);
    }
    return usage;
  }

  return {
    registerPerformer(performerId: string, maxTokens = DEFAULT_MAX_TOKENS): void {
      usages.set(performerId, {
        performerId,
        currentTokens: 0,
        maxTokens,
        compressionThreshold: COMPRESSION_THRESHOLD,
        compressionsTriggered: 0,
        lastUpdated: Date.now(),
        sessionStart: Date.now(),
        history: [],
      });
      logger.info({ performerId, maxTokens }, 'context tracker registered performer');
    },

    unregisterPerformer(performerId: string): void {
      usages.delete(performerId);
      logger.info({ performerId }, 'context tracker unregistered performer');
    },

    updateTokens(performerId: string, tokens: number, autoCompress = true): CompressionAction {
      const usage = getOrCreate(performerId);
      usage.currentTokens = tokens;
      usage.lastUpdated = Date.now();

      // Record history
      usage.history.push({ timestamp: Date.now(), tokens, event: 'update' });
      if (usage.history.length > MAX_HISTORY) {
        usage.history.shift();
      }

      if (autoCompress && compressor.shouldCompress(tokens, usage.maxTokens, usage.compressionThreshold)) {
        usage.compressionsTriggered++;
        const targetTokens = usage.maxTokens * 0.5;
        logger.warn({
          performerId,
          currentTokens: tokens,
          maxTokens: usage.maxTokens,
          compressionsTriggered: usage.compressionsTriggered,
        }, 'context compression required');
        return { type: 'required', current: tokens, target: targetTokens };
      }

      return { type: 'none' };
    },

    addTokens(performerId: string, content: string, type: 'text' | 'code' | 'json'): number {
      const usage = getOrCreate(performerId);
      let added: number;
      switch (type) {
        case 'code': added = estimator.estimateCode(content); break;
        case 'json': added = estimator.estimateJson(content); break;
        default: added = estimator.estimateText(content); break;
      }
      usage.currentTokens += added;
      usage.lastUpdated = Date.now();
      return usage.currentTokens;
    },

    resetUsage(performerId: string): void {
      const usage = usages.get(performerId);
      if (usage) {
        usage.currentTokens = 0;
        usage.lastUpdated = Date.now();
        usage.history.push({ timestamp: Date.now(), tokens: 0, event: 'reset' });
      }
    },

    getUsage(performerId: string): ContextUsage | undefined {
      return usages.get(performerId);
    },

    getAllUsages(): ContextUsage[] {
      return Array.from(usages.values());
    },

    getStats(): TrackerStats {
      let totalTokens = 0;
      let totalCapacity = 0;
      let totalCompressions = 0;
      let nearLimit = 0;

      for (const usage of usages.values()) {
        totalTokens += usage.currentTokens;
        totalCapacity += usage.maxTokens;
        totalCompressions += usage.compressionsTriggered;
        if (usage.currentTokens > usage.maxTokens * 0.7) {
          nearLimit++;
        }
      }

      const averageUsagePercent = usages.size > 0
        ? Math.round((totalTokens / totalCapacity) * 100)
        : 0;

      return {
        trackedPerformers: usages.size,
        totalTokens,
        totalCapacity,
        averageUsagePercent,
        performersNearLimit: nearLimit,
        totalCompressions,
      };
    },

    recordEvent(performerId: string, event: string): void {
      const usage = usages.get(performerId);
      if (usage) {
        usage.history.push({ timestamp: Date.now(), tokens: usage.currentTokens, event });
        if (usage.history.length > MAX_HISTORY) {
          usage.history.shift();
        }
      }
    },
  };
}

let defaultTracker: ContextTracker | null = null;

export function getContextTracker(): ContextTracker {
  defaultTracker ??= createContextTracker();
  return defaultTracker;
}

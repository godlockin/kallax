/**
 * KALLAX Context Compressor — manages context window pressure.
 *
 * Strategies:
 *   - truncate: keep head + tail, drop middle
 *   - summarize: replace old content with summaries
 *   - prioritize: keep high-priority content, evict low-priority
 */

import { logger } from '../../utils/logger.js';

export type CompressionStrategy = 'truncate' | 'summarize' | 'prioritize';

export interface CompressionConfig {
  readonly maxTokens: number;
  readonly thresholdPercent: number; // compress at this % of max
  readonly targetPercent: number; // compress down to this % of max
  readonly strategy: CompressionStrategy;
  readonly keepRecent: number; // number of recent messages to always keep
}

export interface CompressionResult {
  readonly beforeTokens: number;
  readonly afterTokens: number;
  readonly removedItems: number;
  readonly strategy: CompressionStrategy;
  readonly items: unknown[];
}

export interface ContextCompressor {
  compress: (
    items: readonly { estimatedTokens?: number; priority?: number }[],
    config: Partial<CompressionConfig>,
  ) => CompressionResult;
  shouldCompress: (currentTokens: number, maxTokens: number, thresholdPercent?: number) => boolean;
}

const DEFAULT_CONFIG: CompressionConfig = {
  maxTokens: 128_000,
  thresholdPercent: 80,
  targetPercent: 50,
  strategy: 'prioritize',
  keepRecent: 10,
};

export function createContextCompressor(): ContextCompressor {
  return {
    shouldCompress(currentTokens: number, maxTokens: number, thresholdPercent = 80): boolean {
      const threshold = maxTokens * (thresholdPercent / 100);
      return currentTokens >= threshold;
    },

    compress(
      items: readonly { estimatedTokens?: number; priority?: number }[],
      config: Partial<CompressionConfig>,
    ): CompressionResult {
      type Item = { estimatedTokens?: number; priority?: number };
      const cfg = { ...DEFAULT_CONFIG, ...config };
      const targetTokens = cfg.maxTokens * (cfg.targetPercent / 100);

      // Calculate total
      let totalTokens = 0;
      for (const item of items) {
        totalTokens += item.estimatedTokens ?? 100; // default 100 tokens per item
      }

      if (totalTokens <= targetTokens) {
        return { beforeTokens: totalTokens, afterTokens: totalTokens, removedItems: 0, strategy: cfg.strategy, items: [...items] };
      }

      const keep = cfg.keepRecent > 0 ? items.slice(-cfg.keepRecent) : [];
      const middle = cfg.keepRecent > 0 ? items.slice(0, -cfg.keepRecent) : items;

      let keptItems: Item[];

      switch (cfg.strategy) {
        case 'truncate': {
          // Keep head items until we hit target
          let accumulated = 0;
          const head: Item[] = [];
          for (const item of middle) {
            const tokens = item.estimatedTokens ?? 100;
            if (accumulated + tokens > targetTokens) break;
            accumulated += tokens;
            head.push(item);
          }
          keptItems = [...head, ...keep];
          break;
        }

        case 'prioritize': {
          // Sort by priority (higher first), then keep until target
          const sorted = [...middle].sort((a, b) => (b.priority ?? 0) - (a.priority ?? 0));
          let accumulated = 0;
          const selected: Item[] = [];
          for (const item of sorted) {
            const tokens = item.estimatedTokens ?? 100;
            if (accumulated + tokens > targetTokens) break;
            accumulated += tokens;
            selected.push(item);
          }
          // Restore original order among selected
          const selectedSet = new Set(selected);
          const ordered = middle.filter((item) => selectedSet.has(item));
          keptItems = [...ordered, ...keep];
          break;
        }

        case 'summarize':
        default: {
          // Keep first few items as summary anchors + recent
          const anchors = middle.slice(0, Math.min(5, middle.length));
          keptItems = [...anchors, ...keep];
          break;
        }
      }

      const afterTokens = keptItems.reduce((sum, item) => sum + (item.estimatedTokens ?? 100), 0);
      const removedItems = items.length - keptItems.length;

      logger.info({
        beforeTokens: totalTokens,
        afterTokens,
        removedItems,
        strategy: cfg.strategy,
      }, 'context compressed');

      return { beforeTokens: totalTokens, afterTokens, removedItems, strategy: cfg.strategy, items: keptItems };
    },
  };
}

let defaultCompressor: ContextCompressor | null = null;

export function getContextCompressor(): ContextCompressor {
  defaultCompressor ??= createContextCompressor();
  return defaultCompressor;
}

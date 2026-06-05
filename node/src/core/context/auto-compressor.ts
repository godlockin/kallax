import * as fs from 'node:fs';
import * as path from 'node:path';
import { getContextTracker } from './tracker.js';
import { getContextCompressor } from './compressor.js';
import { logger } from '../../utils/logger.js';

export interface CompressResult {
  readonly performerId: string; readonly beforeTokens: number;
  readonly afterTokens: number; readonly savedToFile: string; readonly summary: string;
}
export interface AutoCompressor {
  processAll(): CompressResult[];
  process(performerId: string): CompressResult | null;
  listSavedFiles(performerId?: string): string[];
}
const CONTEXT_DIR = '.kallax/context';
function ensureDir(): string {
  if (!fs.existsSync(CONTEXT_DIR)) fs.mkdirSync(CONTEXT_DIR, { recursive: true });
  return CONTEXT_DIR;
}
export function createAutoCompressor(): AutoCompressor {
  const tracker = getContextTracker();
  const compressor = getContextCompressor();
  return {
    processAll(): CompressResult[] {
      const results: CompressResult[] = [];
      for (const u of tracker.getAllUsages()) { const r = this.process(u.performerId); if (r) results.push(r); }
      return results;
    },
    process(performerId: string): CompressResult | null {
      const usage = tracker.getUsage(performerId);
      if (!usage) return null;
      const threshold = usage.maxTokens * (usage.compressionThreshold / 100);
      if (usage.currentTokens < threshold) return null;
      const before = usage.currentTokens;
      const items = usage.history.map(h => ({ estimatedTokens: 50, priority: h.event === 'compression' ? 10 : 5, data: h }));
      const cr = compressor.compress(items, { maxTokens: usage.maxTokens, targetPercent: 50, strategy: 'prioritize' });
      const summary = `[${new Date().toISOString()}] ${performerId}: ${before}→${cr.afterTokens} tokens`;
      const dir = ensureDir();
      const fp = path.join(dir, `${performerId}-${Date.now().toString(36)}.json`);
      fs.writeFileSync(fp, JSON.stringify({ performerId, savedAt: new Date().toISOString(), beforeTokens: before, afterTokens: cr.afterTokens, itemCount: cr.items.length, summary }, null, 2));
      tracker.resetUsage(performerId);
      tracker.recordEvent(performerId, 'compression');
      logger.info({ performerId, before, after: cr.afterTokens, fp }, 'auto-compressed');
      return { performerId, beforeTokens: before, afterTokens: cr.afterTokens, savedToFile: fp, summary };
    },
    listSavedFiles(performerId?: string): string[] {
      const d = ensureDir();
      return fs.readdirSync(d).filter(f => f.endsWith('.json') && (!performerId || f.startsWith(performerId))).map(f => path.join(d, f));
    },
  };
}
let inst: AutoCompressor | null = null;
export function getAutoCompressor(): AutoCompressor { return inst ?? (inst = createAutoCompressor()); }

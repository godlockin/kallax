/**
 * KALLAX Context Budget Manager — session token budget with auto-compression.
 * Solves vision problem: "long context memory loss".
 */
import { getContextTracker } from './tracker.js';
import { getContextCompressor } from './compressor.js';
import { getContextAlertManager } from './alert.js';
import { logger } from '../../utils/logger.js';

export interface BudgetConfig { maxTokens: number; warningThreshold: number; criticalThreshold: number; autoCompress: boolean; compressionTarget: number; }
export interface BudgetState { performerId: string; currentTokens: number; maxTokens: number; usagePercent: number; status: 'normal' | 'warning' | 'critical'; compressionCount: number; }

export interface ContextBudget {
  register(performerId: string, config?: Partial<BudgetConfig>): void;
  consume(performerId: string, tokens: number): BudgetState;
  getState(performerId: string): BudgetState | null;
  getAlert(performerId: string): { level: 'warning' | 'critical'; message: string } | null;
  emergencyRecover(performerId: string): { saved: boolean; suggestion: string };
}

const DEFAULT_CONFIG: BudgetConfig = { maxTokens: 128_000, warningThreshold: 0.7, criticalThreshold: 0.85, autoCompress: true, compressionTarget: 0.5 };

export function createContextBudget(): ContextBudget {
  const configs = new Map<string, BudgetConfig>();
  const tracker = getContextTracker();
  const alertMgr = getContextAlertManager();

  return {
    register(performerId: string, config?: Partial<BudgetConfig>): void {
      const cfg = { ...DEFAULT_CONFIG, ...config };
      configs.set(performerId, cfg);
      tracker.registerPerformer(performerId, cfg.maxTokens);
      logger.info({ performerId, maxTokens: cfg.maxTokens }, 'budget registered');
    },

    consume(performerId: string, tokens: number): BudgetState {
      const cfg = configs.get(performerId) ?? DEFAULT_CONFIG;
      const total = tracker.addTokens(performerId, String(tokens), 'text');
      const usagePercent = Math.round((total / cfg.maxTokens) * 100);
      let status: BudgetState['status'] = 'normal';
      if (usagePercent >= cfg.criticalThreshold * 100) status = 'critical';
      else if (usagePercent >= cfg.warningThreshold * 100) status = 'warning';
      if (status !== 'normal') alertMgr.check(performerId);
      return { performerId, currentTokens: total, maxTokens: cfg.maxTokens, usagePercent, status, compressionCount: 0 };
    },

    getState(performerId: string): BudgetState | null {
      const usage = tracker.getUsage(performerId);
      if (!usage) return null;
      const cfg = configs.get(performerId) ?? DEFAULT_CONFIG;
      const pct = Math.round((usage.currentTokens / cfg.maxTokens) * 100);
      const status: BudgetState['status'] = pct >= cfg.criticalThreshold * 100 ? 'critical' : pct >= cfg.warningThreshold * 100 ? 'warning' : 'normal';
      return { performerId, currentTokens: usage.currentTokens, maxTokens: cfg.maxTokens, usagePercent: pct, status, compressionCount: usage.compressionsTriggered };
    },

    getAlert(performerId: string) {
      const state = this.getState(performerId);
      if (!state || state.status === 'normal') return null;
      return { level: state.status, message: `Context ${state.status}: ${state.usagePercent}% used (${state.currentTokens}/${state.maxTokens})` };
    },

    emergencyRecover(performerId: string) {
      const state = this.getState(performerId);
      if (!state) return { saved: false, suggestion: 'Performer not found' };
      tracker.recordEvent(performerId, 'emergency_recovery');
      return { saved: true, suggestion: 'Run /compact immediately. Consider splitting remaining work into new session.' };
    },
  };
}

let defaultBudget: ContextBudget | null = null;
export function getContextBudget(): ContextBudget { return defaultBudget ?? (defaultBudget = createContextBudget()); }

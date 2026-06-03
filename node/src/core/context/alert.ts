/**
 * KALLAX Context Alert — overflow detection and notification.
 */

import { logger } from '../../utils/logger.js';
import type { ContextUsage } from './tracker.js';
import { getContextTracker } from './tracker.js';

export type AlertLevel = 'info' | 'warning' | 'critical';

export interface ContextAlert {
  readonly id: string;
  readonly performerId: string;
  readonly level: AlertLevel;
  readonly message: string;
  readonly currentTokens: number;
  readonly maxTokens: number;
  readonly usagePercent: number;
  readonly timestamp: number;
  readonly acknowledged: boolean;
}

export interface AlertConfig {
  readonly warningThreshold: number; // percentage, default 70
  readonly criticalThreshold: number; // percentage, default 85
  readonly overflowThreshold: number; // percentage, default 95
  readonly cooldownMs: number; // minimum ms between alerts per performer, default 30000
}

export interface ContextAlertManager {
  check: (performerId: string) => ContextAlert | null;
  acknowledge: (alertId: string) => void;
  getAlerts: (performerId?: string) => ContextAlert[];
  getActiveAlerts: () => ContextAlert[];
  configure: (config: Partial<AlertConfig>) => void;
  getStats: () => AlertStats;
}

export interface AlertStats {
  readonly totalAlerts: number;
  readonly activeAlerts: number;
  readonly criticalAlerts: number;
  readonly byPerformer: Record<string, number>;
}

const DEFAULT_ALERT_CONFIG: AlertConfig = {
  warningThreshold: 70,
  criticalThreshold: 85,
  overflowThreshold: 95,
  cooldownMs: 30000,
};

function generateAlertId(): string {
  return `alert_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 6)}`;
}

export function createContextAlertManager(): ContextAlertManager {
  const alerts: ContextAlert[] = [];
  const lastAlertTime = new Map<string, number>();
  const MAX_ALERTS = 500;
  let config = { ...DEFAULT_ALERT_CONFIG };

  function determineLevel(usagePercent: number): AlertLevel | null {
    if (usagePercent >= config.overflowThreshold) return 'critical';
    if (usagePercent >= config.criticalThreshold) return 'critical';
    if (usagePercent >= config.warningThreshold) return 'warning';
    return null;
  }

  return {
    check(performerId: string): ContextAlert | null {
      const tracker = getContextTracker();
      const usage = tracker.getUsage(performerId);
      if (!usage) return null;

      const usagePercent = Math.round((usage.currentTokens / usage.maxTokens) * 100);
      const level = determineLevel(usagePercent);
      if (!level) return null;

      // Cooldown check
      const lastTime = lastAlertTime.get(performerId) ?? 0;
      if (Date.now() - lastTime < config.cooldownMs) return null;

      lastAlertTime.set(performerId, Date.now());

      const alert: ContextAlert = {
        id: generateAlertId(),
        performerId,
        level,
        message: `Context ${level === 'critical' ? 'CRITICAL' : 'WARNING'}: ${usagePercent}% used (${usage.currentTokens}/${usage.maxTokens} tokens)`,
        currentTokens: usage.currentTokens,
        maxTokens: usage.maxTokens,
        usagePercent,
        timestamp: Date.now(),
        acknowledged: false,
      };

      alerts.push(alert);
      if (alerts.length > MAX_ALERTS) alerts.shift();

      logger.warn({
        performerId,
        alertId: alert.id,
        level,
        usagePercent,
        currentTokens: usage.currentTokens,
        maxTokens: usage.maxTokens,
      }, 'context alert triggered');

      return alert;
    },

    acknowledge(alertId: string): void {
      const alert = alerts.find((a) => a.id === alertId);
      if (alert) {
        (alert as { acknowledged: boolean }).acknowledged = true;
      }
    },

    getAlerts(performerId?: string): ContextAlert[] {
      if (performerId) {
        return alerts.filter((a) => a.performerId === performerId);
      }
      return [...alerts];
    },

    getActiveAlerts(): ContextAlert[] {
      return alerts.filter((a) => !a.acknowledged);
    },

    configure(partial: Partial<AlertConfig>): void {
      config = { ...config, ...partial };
      logger.info({ config }, 'alert configuration updated');
    },

    getStats(): AlertStats {
      let criticalCount = 0;
      const byPerformer: Record<string, number> = {};
      for (const alert of alerts) {
        if (alert.level === 'critical') criticalCount++;
        byPerformer[alert.performerId] = (byPerformer[alert.performerId] ?? 0) + 1;
      }
      return {
        totalAlerts: alerts.length,
        activeAlerts: alerts.filter((a) => !a.acknowledged).length,
        criticalAlerts: criticalCount,
        byPerformer,
      };
    },
  };
}

let defaultAlertManager: ContextAlertManager | null = null;

export function getContextAlertManager(): ContextAlertManager {
  if (defaultAlertManager === null) {
    defaultAlertManager = createContextAlertManager();
  }
  return defaultAlertManager;
}

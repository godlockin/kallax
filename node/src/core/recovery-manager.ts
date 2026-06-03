/**
 * KALLAX RecoveryManager — implements DEGRADATION-STRATEGY.md tier probing + auto-recovery.
 *
 * Tiers: L3=Rust, L2=Node.js, L1=Shell fallback, L0=Degraded
 * Probes every 60s, auto-upgrades when higher tiers recover.
 */

import { logger } from '../utils/logger.js';
import { getMasterElection } from './master-election.js';
import { getCircuitBreaker } from './circuit-breaker.js';
import type { CircuitBreaker } from './circuit-breaker.js';

export type TierLevel = 0 | 1 | 2 | 3;

export interface TierStatus {
  readonly level: TierLevel;
  readonly name: string;
  healthy: boolean;
  lastProbeAt: number;
  consecutiveFailures: number;
  consecutiveSuccesses: number;
  degradedAt?: number;
}

export interface DegradationState {
  readonly currentTier: TierLevel;
  readonly targetTier: TierLevel;
  readonly tiers: Record<TierLevel, TierStatus>;
  readonly startedAt: number;
  crashCount: number;
  lastCrashAt?: number;
}

export interface RecoveryManager {
  start: () => void;
  stop: () => void;
  getState: () => DegradationState;
  probeAll: () => Promise<void>;
  forceUpgrade: () => Promise<boolean>;
  recordCrash: (component: string) => void;
}

// ── Config ─────────────────────────────────────────────────────────────────

const PROBE_INTERVAL_MS = 60_000;
const UPGRADE_THRESHOLD = 3; // consecutive successes needed to upgrade
const DEGRADE_THRESHOLD = 2; // consecutive failures to degrade
const CRASH_LIMIT = 5; // crashes within window → force degrade
const CRASH_WINDOW_MS = 300_000; // 5 min crash window

// ── Probe implementations ──────────────────────────────────────────────────

async function probeRust(): Promise<boolean> {
  try {
    const { getRustBridge } = await import('./rust-bridge.js');
    const bridge = getRustBridge();
    return await bridge.isAlive();
  } catch {
    return false;
  }
}

async function probeNode(): Promise<boolean> {
  try {
    const { execFile } = await import('node:child_process');
    const { promisify } = await import('node:util');
    const execFileAsync = promisify(execFile);
    await execFileAsync('node', ['-e', 'true'], { timeout: 5000 });
    return true;
  } catch {
    return false;
  }
}

async function probeSQLite(): Promise<boolean> {
  try {
    const { getSqliteManager } = await import('./sqlite-manager.js');
    const db = getSqliteManager();
    db.run('SELECT 1');
    return true;
  } catch {
    return false;
  }
}

async function probeRedis(): Promise<boolean> {
  try {
    const election = getMasterElection();
    const state = await election.getState();
    return state.isOk();
  } catch {
    return false;
  }
}

async function probeFileQueue(): Promise<boolean> {
  try {
    const { mkdir, access } = await import('node:fs/promises');
    await mkdir('.kallax/queue', { recursive: true });
    await access('.kallax/queue');
    return true;
  } catch {
    return false;
  }
}

// ── RecoveryManager ────────────────────────────────────────────────────────

export function createRecoveryManager(): RecoveryManager {
  const tiers: Record<TierLevel, TierStatus> = {
    3: { level: 3, name: 'Rust', healthy: false, lastProbeAt: 0, consecutiveFailures: 0, consecutiveSuccesses: 0 },
    2: { level: 2, name: 'Node.js', healthy: true, lastProbeAt: Date.now(), consecutiveFailures: 0, consecutiveSuccesses: 1 },
    1: { level: 1, name: 'Shell', healthy: true, lastProbeAt: Date.now(), consecutiveFailures: 0, consecutiveSuccesses: 1 },
    0: { level: 0, name: 'Degraded', healthy: true, lastProbeAt: Date.now(), consecutiveFailures: 0, consecutiveSuccesses: 1 },
  };

  let currentTier: TierLevel = 2; // Start at Node.js
  let probeTimer: ReturnType<typeof setInterval> | null = null;
  const crashLog: Array<{ component: string; timestamp: number }> = [];

  function determineTargetTier(): TierLevel {
    if (tiers[3].healthy) return 3;
    if (tiers[2].healthy) return 2;
    if (tiers[1].healthy) return 1;
    return 0;
  }

  function emitMetrics(): void {
    const state = getState();
    logger.info({
      currentTier: state.currentTier,
      targetTier: state.targetTier,
      tier3: tiers[3].healthy,
      tier2: tiers[2].healthy,
      tier1: tiers[1].healthy,
      tier0: tiers[0].healthy,
      crashCount: state.crashCount,
    }, 'degradation metrics');
  }

  function getState(): DegradationState {
    return {
      currentTier,
      targetTier: determineTargetTier(),
      tiers: { ...tiers },
      startedAt: Date.now(),
      crashCount: crashLog.length,
      lastCrashAt: crashLog.length > 0 ? crashLog[crashLog.length - 1]?.timestamp : undefined,
    };
  }

  async function probeAll(): Promise<void> {
    // Probe Rust tier
    const rustOk = await probeRust();
    updateTierStatus(3, rustOk);

    // Probe Node tier
    const nodeOk = await probeNode();
    const sqliteOk = await probeSQLite();
    updateTierStatus(2, nodeOk && sqliteOk);

    // Probe shell fallback
    const fileQOk = await probeFileQueue();
    updateTierStatus(1, fileQOk);

    emitMetrics();

    // Auto-upgrade if target > current
    const target = determineTargetTier();
    if (target > currentTier) {
      logger.info({ from: currentTier, to: target }, 'auto-upgrading tier');
      currentTier = target;
    }
  }

  function updateTierStatus(level: TierLevel, healthy: boolean): void {
    const tier = tiers[level];
    tier.lastProbeAt = Date.now();

    if (healthy) {
      tier.consecutiveSuccesses++;
      tier.consecutiveFailures = 0;
      if (tier.consecutiveSuccesses >= UPGRADE_THRESHOLD && !tier.healthy) {
        tier.healthy = true;
        tier.degradedAt = undefined;
        logger.info({ tier: tier.name, level }, 'tier recovered');
      }
    } else {
      tier.consecutiveFailures++;
      tier.consecutiveSuccesses = 0;
      if (tier.consecutiveFailures >= DEGRADE_THRESHOLD && tier.healthy) {
        tier.healthy = false;
        tier.degradedAt = Date.now();
        logger.warn({ tier: tier.name, level, failures: tier.consecutiveFailures }, 'tier degraded');

        // If this tier was the current, degrade
        if (level === currentTier) {
          const newTier = determineTargetTier();
          if (newTier < currentTier) {
            logger.warn({ from: currentTier, to: newTier }, 'degrading to lower tier');
            currentTier = newTier;
          }
        }
      }
    }
  }

  return {
    start(): void {
      if (probeTimer) return;
      // Initial probe
      probeAll().catch((err: unknown) => {
        logger.error({ error: err instanceof Error ? err.message : String(err) }, 'initial probe failed');
      });
      // Periodic probe
      probeTimer = setInterval(() => {
        probeAll().catch((err: unknown) => {
          logger.error({ error: err instanceof Error ? err.message : String(err) }, 'periodic probe failed');
        });
      }, PROBE_INTERVAL_MS);
      logger.info({ intervalMs: PROBE_INTERVAL_MS }, 'recovery manager started');
    },

    stop(): void {
      if (probeTimer) {
        clearInterval(probeTimer);
        probeTimer = null;
        logger.info('recovery manager stopped');
      }
    },

    getState,

    probeAll,

    async forceUpgrade(): Promise<boolean> {
      await probeAll();
      return currentTier === determineTargetTier();
    },

    recordCrash(component: string): void {
      const now = Date.now();
      crashLog.push({ component, timestamp: now });

      // Purge old crashes outside window
      while (crashLog.length > 0 && (crashLog[0]?.timestamp ?? 0) < now - CRASH_WINDOW_MS) {
        crashLog.shift();
      }

      if (crashLog.length >= CRASH_LIMIT) {
        logger.error({ crashCount: crashLog.length, component }, 'crash limit exceeded, forcing degradation');
        // Degrade current tier
        const tier = tiers[currentTier];
        tier.healthy = false;
        tier.degradedAt = now;
        const newTier = determineTargetTier();
        if (newTier < currentTier) {
          currentTier = newTier;
        }
      }
    },
  };
}

// Singleton
let defaultRM: RecoveryManager | null = null;

export function getRecoveryManager(): RecoveryManager {
  if (defaultRM === null) {
    defaultRM = createRecoveryManager();
  }
  return defaultRM;
}

/**
 * KALLAX RecoveryManager — implements DEGRADATION-STRATEGY.md tier probing + auto-recovery.
 *
 * Tiers: L3=Rust, L2=Node.js, L1=Shell fallback, L0=Degraded
 * Probes every 60s, auto-upgrades when higher tiers recover.
 */
import { existsSync, readFileSync, writeFileSync, mkdirSync, renameSync } from 'node:fs';
import { dirname } from 'node:path';

import { logger } from '../utils/logger.js';

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
  start: () => Promise<void>;
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

// EPIC-088 + EPIC-098 Perf-2: tier 1 探针去重 — 双层 (in-process + 跨进程)
// 跨进程: state.json 共享 timestamp (atomic via tmp+mv)
// in-process: module-level cache (EPIC-088 已有)
const TIER1_PROBE_DEBOUNCE_MS = 5_000; // 5s 内跳过 tier 1 (其他进程已 probe)
let lastTier1ProbeAt = 0;
const TIER1_PROBE_STATE_PATH = `${process.cwd()}/.kallax/state/tier1-probe.json`;

function shouldProbeTier1(now: number): boolean {
  // EPIC-098: 跨进程检查 state.json timestamp
  try {
    if (existsSync(TIER1_PROBE_STATE_PATH)) {
      const raw = readFileSync(TIER1_PROBE_STATE_PATH, 'utf-8');
      const { ts } = JSON.parse(raw) as { ts: number };
      if (now - ts < TIER1_PROBE_DEBOUNCE_MS) {
        return false; // 跨进程: 其他进程最近 probe 过
      }
    }
  } catch {
    // state.json 损坏, fallback to in-process
  }
  return now - lastTier1ProbeAt >= TIER1_PROBE_DEBOUNCE_MS;
}

function recordTier1Probe(now: number): void {
  lastTier1ProbeAt = now;
  // EPIC-098: 持久化到 state.json (跨进程)
  try {
    const dir = dirname(TIER1_PROBE_STATE_PATH);
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true, mode: 0o700 });
    const tmp = `${TIER1_PROBE_STATE_PATH}.tmp.${String(process.pid)}.${String(Date.now())}`;
    writeFileSync(tmp, JSON.stringify({ ts: now, pid: process.pid }), { mode: 0o600 });
    renameSync(tmp, TIER1_PROBE_STATE_PATH);
  } catch {
    // best-effort, 不阻塞
  }
}

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
    const { getSqliteManager } = await import('./sqlite/index.js');
    const db = getSqliteManager();
    (db as unknown as { run: (sql: string) => unknown }).run('SELECT 1');
    return true;
  } catch {
    return false;
  }
}

async function probeRedis(): Promise<boolean> {
  try {
    // v3.5.0 hotfix (跟 B 组 S-004 治根 联合): 实际探测 Redis PING (跟 probeNode 模式 1:1)
    const { execFile } = await import('node:child_process');
    const { promisify } = await import('node:util');
    const execFileAsync = promisify(execFile);
    const { stdout } = await execFileAsync('redis-cli', ['-u', 'redis://localhost:6379', 'PING'], { timeout: 3000 });
    return stdout.trim() === 'PONG';
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
    // EPIC-088 Perf-2: tier 1 (shell/redis) 探针去重 — 跨进程共享
    // 原: N performer + 1 conductor 各自 60s probe 一次 → N+1 次 probeSQLite/Redis
    // 修: 用 state.json 写 last_tier1_probe_at, 5s 内跳过
    const now = Date.now();
    if (!shouldProbeTier1(now)) {
      logger.debug({}, 'recovery: tier 1 probe skipped (recent)');
    } else {
      // Probe shell fallback
      const fileQOk = await probeFileQueue();
      updateTierStatus(1, fileQOk);
      // v3.5.0 hotfix (跟 B 组 S-004 治根 联合): Redis 加到 probeAll + Tier 1 跟 Redis 选举层 联合
      const redisOk = await probeRedis();
      updateTierStatus(1, fileQOk && redisOk);
      recordTier1Probe(now);
    }

    // Probe Rust tier
    const rustOk = await probeRust();
    updateTierStatus(3, rustOk);

    // Probe Node tier
    const nodeOk = await probeNode();
    const sqliteOk = await probeSQLite();
    updateTierStatus(2, nodeOk && sqliteOk);

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
    async start(): Promise<void> {
      if (probeTimer) return;
      // v3.5.0 hotfix (跟 B 组 S-006 治根 联合, 跟 V310-B S-006 audit chain fire-and-forget 1:1):
      // await 初始 probe, throw on fatal 而非 fire-and-forget 静默失败
      try {
        await probeAll();
      } catch (err: unknown) {
        logger.error(
          { error: err instanceof Error ? err.message : String(err) },
          'recovery: initial probe failed (caller should treat as degraded)',
        );
        throw err;
      }
      // Periodic probe 也 try/catch 而非 swallow
      probeTimer = setInterval(() => {
        probeAll().catch((err: unknown) => {
          logger.error(
            { error: err instanceof Error ? err.message : String(err) },
            'recovery: periodic probe failed',
          );
        });
      }, PROBE_INTERVAL_MS);
      logger.info({ intervalMs: PROBE_INTERVAL_MS }, 'recovery manager started');
    },

    stop(): void {
      if (probeTimer) {
        clearInterval(probeTimer);
        probeTimer = null;
        logger.info({}, 'recovery manager stopped');
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
  defaultRM ??= createRecoveryManager();
  return defaultRM;
}

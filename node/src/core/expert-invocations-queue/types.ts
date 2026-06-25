/**
 * KALLAX Expert Invocations Queue — Types + Constants + Helpers
 *
 * EPIC-021-F: expert_invocations 降级链 (Redis → SQLite → file)
 *
 * 3 backends:
 *   L1 Redis (primary, ioredis) — cross-process, low latency
 *   L2 SQLite (better-sqlite3) — local durable
 *   L3 File (JSONL append-only) — last-resort
 *
 * Fallback triggers:
 *   L1 → L2: Redis op exceeds L1_LATENCY_THRESHOLD_MS (1s) or throws
 *   L2 → L3: SQLite op exceeds L2_LATENCY_THRESHOLD_MS (500ms), throws,
 *            or returns ENOSPC-equivalent (SQLITE_FULL)
 *
 * Recovery: every RECOVERY_PROBE_INTERVAL_MS (5 min) attempt L1; on success
 *            promote back to primary.
 *
 * Hard Rule compliance:
 *   #1 Type safety: zero `any`, strict Result<T,E>
 *   #4 No magic numbers: all thresholds named (exported)
 *   #5 No console.log: structured logger
 *   #7 DI: RedisClient + SQLiteHandle injected via config for testability
 */

import { promises as fs } from 'node:fs';
import path from 'node:path';
import type { Redis } from 'ioredis';
import type { KallaxResult } from '../../types/index.js';

// ─── Types ──────────────────────────────────────────────────────────────────

export type ExpertInvocationBackend = 'redis' | 'sqlite' | 'file';

export interface ExpertInvocation {
  readonly expertId: string;
  readonly ticketId: string;
  readonly timestamp: number;
}

export interface ExpertInvocationsQueueConfig {
  readonly redis?: Redis | undefined;
  readonly redisStreamKey?: string;
  readonly sqlitePath?: string;
  readonly filePath?: string;
  readonly l1LatencyThresholdMs?: number;
  readonly l2LatencyThresholdMs?: number;
  readonly recoveryProbeIntervalMs?: number;
}

export interface ExpertInvocationsHealth {
  readonly backend: ExpertInvocationBackend;
  readonly latencyMs: number | null;
  readonly queueSize: number;
  readonly lastError: string | null;
  readonly degradedFrom: ExpertInvocationBackend | null;
}

export interface ExpertInvocationsQueue {
  emit: (invocation: ExpertInvocation) => Promise<KallaxResult<ExpertInvocationBackend>>;
  drain: () => Promise<KallaxResult<readonly ExpertInvocation[]>>;
  health: () => ExpertInvocationsHealth;
  probeRecovery: () => Promise<ExpertInvocationBackend>;
  close: () => Promise<void>;
}

// ─── Constants (Hard Rule #4: 0 magic numbers) ──────────────────────────────

export const L1_LATENCY_THRESHOLD_MS = 1000;
export const L2_LATENCY_THRESHOLD_MS = 500;
export const RECOVERY_PROBE_INTERVAL_MS = 5 * 60 * 1000;
export const DEFAULT_REDIS_STREAM_KEY = 'expert_invocations';
export const DEFAULT_SQLITE_PATH = '.kallax/queue/expert_invocations.db';
export const DEFAULT_FILE_PATH = '.kallax/queue/expert_invocations.jsonl';
export const SQLITE_TABLE_NAME = 'invocations';
export const SQLITE_FULL_ERROR_CODE = 'SQLITE_FULL';

// ─── Helpers ────────────────────────────────────────────────────────────────

export function toInvocation(row: unknown): ExpertInvocation {
  const r = row as Partial<ExpertInvocation>;
  return {
    expertId: typeof r.expertId === 'string' ? r.expertId : '',
    ticketId: typeof r.ticketId === 'string' ? r.ticketId : '',
    timestamp: typeof r.timestamp === 'number' ? r.timestamp : 0,
  };
}

export async function ensureDir(filePath: string): Promise<void> {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
}

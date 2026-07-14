/**
 * KALLAX Expert Invocations Queue — Factory + timed wrapper
 *
 * EPIC-021-F: 3-tier degradation chain (L1 Redis → L2 SQLite → L3 file)
 * with periodic recovery probe back to L1.
 *
 * Public API re-exports preserve backwards compatibility for consumers
 * (e.g. tests importing from '../core/expert-invocations-queue.js').
 */

import { err, ok, type Result } from 'neverthrow';
import { KallaxError, KallaxErrorCode, type KallaxResult } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import { createFileBackend, type FileBackend } from './file-backend.js';
import { createRedisBackend, type RedisBackend } from './redis-backend.js';
import {
  createFallbackSqliteBackend,
  createSqliteBackend,
  type SqliteBackend,
} from './sqlite-backend.js';
import {
  DEFAULT_FILE_PATH,
  DEFAULT_REDIS_STREAM_KEY,
  DEFAULT_SQLITE_PATH,
  L1_LATENCY_THRESHOLD_MS,
  L2_LATENCY_THRESHOLD_MS,
  RECOVERY_PROBE_INTERVAL_MS,
  SQLITE_FULL_ERROR_CODE,
  toInvocation,
  type ExpertInvocation,
  type ExpertInvocationBackend,
  type ExpertInvocationsHealth,
  type ExpertInvocationsQueue,
  type ExpertInvocationsQueueConfig,
} from './types.js';

// Re-export public API (back-compat for consumers).
export type {
  ExpertInvocation,
  ExpertInvocationBackend,
  ExpertInvocationsHealth,
  ExpertInvocationsQueue,
  ExpertInvocationsQueueConfig,
} from './types.js';
export {
  DEFAULT_FILE_PATH,
  DEFAULT_REDIS_STREAM_KEY,
  DEFAULT_SQLITE_PATH,
  L1_LATENCY_THRESHOLD_MS,
  L2_LATENCY_THRESHOLD_MS,
  RECOVERY_PROBE_INTERVAL_MS,
  SQLITE_FULL_ERROR_CODE,
  SQLITE_TABLE_NAME,
} from './types.js';
export { createFileBackend, type FileBackend } from './file-backend.js';
export { createRedisBackend, type RedisBackend } from './redis-backend.js';
export {
  createFallbackSqliteBackend,
  createSqliteBackend,
  type SqliteBackend,
} from './sqlite-backend.js';

// ─── Timed wrapper for latency-triggered fallback ───────────────────────────

interface TimedResult<T> {
  readonly value: T;
  readonly elapsedMs: number;
}

export async function timed<T>(op: () => Promise<T>, thresholdMs: number): Promise<Result<TimedResult<T>, Error>> {
  const start = Date.now();
  let timer: ReturnType<typeof setTimeout> | null = null;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timer = setTimeout(() => { reject(new Error(`op exceeded ${String(thresholdMs)}ms threshold`)); }, thresholdMs);
  });
  try {
    const value = await Promise.race([op(), timeoutPromise]);
    // timer may be null if op() rejects before setTimeout fires (race condition)
    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
    if (timer !== null) clearTimeout(timer);
    return ok({ value, elapsedMs: Date.now() - start });
  } catch (e: unknown) {
    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
    if (timer !== null) clearTimeout(timer);
    return err(e instanceof Error ? e : new Error(String(e)));
  }
}

// ─── Factory ─────────────────────────────────────────────────────────────────

export function createExpertInvocationsQueue(config: ExpertInvocationsQueueConfig = {}): ExpertInvocationsQueue {
  const l1Threshold = config.l1LatencyThresholdMs ?? L1_LATENCY_THRESHOLD_MS;
  const l2Threshold = config.l2LatencyThresholdMs ?? L2_LATENCY_THRESHOLD_MS;
  const recoveryInterval = config.recoveryProbeIntervalMs ?? RECOVERY_PROBE_INTERVAL_MS;

  const redisBackend: RedisBackend | null = config.redis
    ? createRedisBackend(config.redis, config.redisStreamKey ?? DEFAULT_REDIS_STREAM_KEY)
    : null;
  let sqliteBackend: SqliteBackend;
  try {
    sqliteBackend = createSqliteBackend(config.sqlitePath ?? DEFAULT_SQLITE_PATH);
  } catch (e: unknown) {
    logger.warn(
      { error: e instanceof Error ? e.message : String(e), path: config.sqlitePath },
      'expert-invocations-queue SQLite init failed, will use file fallback',
    );
    sqliteBackend = createFallbackSqliteBackend();
  }
  const fileBackend: FileBackend = createFileBackend(config.filePath ?? DEFAULT_FILE_PATH);

  let currentBackend: ExpertInvocationBackend = redisBackend !== null ? 'redis' : 'sqlite';
  let lastError: string | null = null;
  let lastProbeAt = 0;
  let degradedFrom: ExpertInvocationBackend | null = null;

  function recordError(backend: ExpertInvocationBackend, error: unknown): void {
    lastError = error instanceof Error ? error.message : String(error);
    logger.warn(
      { backend, error: lastError },
      'expert-invocations-queue backend error',
    );
  }

  function degrade(from: ExpertInvocationBackend, to: ExpertInvocationBackend): void {
    if (currentBackend === from) {
      currentBackend = to;
      degradedFrom = from;
      logger.warn({ from, to }, 'expert-invocations-queue degraded');
    }
  }

  async function tryRedisRecovery(): Promise<boolean> {
    // redisBackend is non-null here (guarded by == null check above)
    // eslint-disable-next-line @typescript-eslint/prefer-optional-chain
    if (redisBackend == null || !redisBackend.isAvailable()) {
      return false;
    }
    const pingResult = await timed(() => redisBackend.ping(), l1Threshold);
    if (pingResult.isOk()) {
      if (currentBackend !== 'redis') {
        logger.info({ from: currentBackend, to: 'redis' }, 'expert-invocations-queue recovered');
        degradedFrom = currentBackend;
        currentBackend = 'redis';
      }
      return true;
    }
    return false;
  }

  async function emit(inv: ExpertInvocation): Promise<KallaxResult<ExpertInvocationBackend>> {
    const payload = JSON.stringify(inv);

    if (currentBackend === 'redis' && redisBackend !== null) {
      const timedResult = await timed(() => redisBackend.xadd(payload), l1Threshold);
      if (timedResult.isOk()) {
        const innerResult = timedResult.value.value;
        if (innerResult.isOk()) {
          return ok('redis');
        }
        recordError('redis', innerResult.error);
      } else {
        recordError('redis', timedResult.error);
      }
      degrade('redis', 'sqlite');
    }

    if (currentBackend === 'sqlite') {
      const insertStart = Date.now();
      const insertResult = sqliteBackend.insert(inv);
      const elapsed = Date.now() - insertStart;
      if (insertResult.isOk() && elapsed <= l2Threshold) {
        return ok('sqlite');
      }
      if (insertResult.isErr()) {
        recordError('sqlite', insertResult.error);
        const errCode = (insertResult.error.cause as { code?: string } | undefined)?.code;
        if (errCode === SQLITE_FULL_ERROR_CODE) {
          logger.error({}, 'expert-invocations-queue SQLite FULL, degrading to file');
        }
      } else {
        recordError('sqlite', new Error(`sqlite insert exceeded ${String(l2Threshold)}ms (${String(elapsed)}ms)`));
      }
      degrade('sqlite', 'file');
    }

    const fileResult = await fileBackend.append(inv);
    if (fileResult.isOk()) {
      return ok('file');
    }
    recordError('file', fileResult.error);
    return err(
      new KallaxError(
        KallaxErrorCode.INTERNAL_ERROR,
        `All backends failed for expert invocation: ${fileResult.error.message}`,
        { cause: fileResult.error, metadata: { expertId: inv.expertId, ticketId: inv.ticketId } },
      ),
    );
  }

  async function drain(): Promise<KallaxResult<readonly ExpertInvocation[]>> {
    if (currentBackend === 'redis' && redisBackend !== null) {
      const timedRange = await timed(() => redisBackend.xrange(), l1Threshold);
      if (timedRange.isOk()) {
        const innerRange = timedRange.value.value;
        if (innerRange.isOk()) {
          const payloads = innerRange.value;
          const items = payloads.map((p) => toInvocation(JSON.parse(p) as unknown));
          return ok(items);
        }
        recordError('redis', innerRange.error);
      } else {
        recordError('redis', timedRange.error);
      }
      degrade('redis', 'sqlite');
    }

    if (currentBackend === 'sqlite') {
      const selectStart = Date.now();
      const selectResult = sqliteBackend.selectAll();
      const elapsed = Date.now() - selectStart;
      if (selectResult.isOk() && elapsed <= l2Threshold) {
        const items = selectResult.value;
        const clear = sqliteBackend.clear();
        if (clear.isErr()) {
          recordError('sqlite', clear.error);
        }
        return ok(items);
      }
      if (selectResult.isErr()) {
        recordError('sqlite', selectResult.error);
      } else {
        recordError('sqlite', new Error(`sqlite select exceeded ${String(l2Threshold)}ms (${String(elapsed)}ms)`));
      }
      degrade('sqlite', 'file');
    }

    const read = await fileBackend.readAll();
    if (read.isOk()) {
      const items = read.value;
      const clear = await fileBackend.clear();
      if (clear.isErr()) {
        recordError('file', clear.error);
      }
      return ok(items);
    }
    recordError('file', read.error);
    return err(
      new KallaxError(
        KallaxErrorCode.INTERNAL_ERROR,
        `All backends failed during drain: ${read.error.message}`,
        { cause: read.error },
      ),
    );
  }

  async function queueSize(): Promise<number> {
    if (currentBackend === 'redis' && redisBackend !== null) {
      const range = await redisBackend.xrange();
      return range.isOk() ? range.value.length : 0;
    }
    if (currentBackend === 'sqlite') {
      const result = sqliteBackend.selectAll();
      return result.isOk() ? result.value.length : 0;
    }
    const read = await fileBackend.readAll();
    return read.isOk() ? read.value.length : 0;
  }

  function health(): ExpertInvocationsHealth {
    return {
      backend: currentBackend,
      latencyMs: null,
      queueSize: 0,
      lastError,
      degradedFrom,
    };
  }

  async function probeRecovery(): Promise<ExpertInvocationBackend> {
    const now = Date.now();
    if (now - lastProbeAt < recoveryInterval && currentBackend === 'redis') {
      return currentBackend;
    }
    lastProbeAt = now;
    if (currentBackend === 'redis') {
      return currentBackend;
    }
    const recovered = await tryRedisRecovery();
    if (recovered) return 'redis';
    if (currentBackend === 'sqlite') return 'sqlite';
    return 'file';
  }

  async function close(): Promise<void> {
    await sqliteBackend.close();
  }

  void queueSize;

  return { emit, drain, health, probeRecovery, close };
}

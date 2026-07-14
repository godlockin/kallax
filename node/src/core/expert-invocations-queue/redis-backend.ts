/**
 * KALLAX Expert Invocations Queue — L1 Redis backend
 *
 * EPIC-021-F: primary backend, ioredis stream-based.
 * Degrades to L2 (SQLite) when op exceeds L1_LATENCY_THRESHOLD_MS or throws.
 */

import type { Redis } from 'ioredis';
import { err, ok, type Result } from 'neverthrow';

// ─── L1 Redis backend ───────────────────────────────────────────────────────

export interface RedisBackend {
  readonly isAvailable: () => boolean;
  readonly xadd: (payload: string) => Promise<Result<string, Error>>;
  readonly xrange: () => Promise<Result<readonly string[], Error>>;
  readonly xdel: (id: string) => Promise<Result<void, Error>>;
  readonly ping: () => Promise<Result<void, Error>>;
}

export function createRedisBackend(redis: Redis, streamKey: string): RedisBackend {
  return {
    isAvailable: () => redis.status === 'ready' || redis.status === 'connect',
    async xadd(payload): Promise<Result<string, Error>> {
      try {
        const id = await redis.xadd(streamKey, '*', 'payload', payload);
        return id === null ? err(new Error('xadd returned null')) : ok(id);
      } catch (e: unknown) {
        return err(e instanceof Error ? e : new Error(String(e)));
      }
    },
    async xrange(): Promise<Result<readonly string[], Error>> {
      try {
        const entries = await redis.xrange(streamKey, '-', '+');
        const payloads: string[] = entries.map((entry) => {
          const fields = entry[1];
          const payloadIdx = fields.findIndex((f, i) => i % 2 === 0 && f === 'payload');
          const payload = payloadIdx >= 0 && fields[payloadIdx + 1] !== undefined ? (fields[payloadIdx + 1] ?? '') : '';
          return payload;
        });
        return ok(payloads);
      } catch (e: unknown) {
        return err(e instanceof Error ? e : new Error(String(e)));
      }
    },
    async xdel(id): Promise<Result<void, Error>> {
      try {
        await redis.xdel(streamKey, id);
        return ok(undefined);
      } catch (e: unknown) {
        return err(e instanceof Error ? e : new Error(String(e)));
      }
    },
    async ping(): Promise<Result<void, Error>> {
      try {
        await redis.ping();
        return ok(undefined);
      } catch (e: unknown) {
        return err(e instanceof Error ? e : new Error(String(e)));
      }
    },
  };
}

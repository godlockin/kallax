/**
 * KALLAX Pub/Sub Bus — cross-process publish/subscribe abstraction
 *
 * EPIC-060-C: ioredis Pub/Sub 启用 (跟 v2.7.0 分布式 路线图 联合, 跟 eket 4 级降级 模式 联合)
 *
 * 1 interface + 2 implementations (跟 Rule 5 DRY 联合, 0 copy-paste):
 *   - RedisPubSubBus     (primary, ioredis, 跨 Node.js 进程 通信)
 *   - InMemoryPubSubBus  (fallback, 单进程, 跟 AGENTS.md 4 级降级 L2 联合)
 *
 * 跟 v2.4.1 Hard Rule #4 联合: 0 magic numbers, 全部 named constants
 * 跟 v2.4.1 Hard Rule #5 联合: 0 console.log, 用 logger
 * 跟 v2.4.1 Hard Rule #8 联合: 0 copy-paste, 1 interface + 2 implementations
 */

import { logger } from '../utils/logger.js';
import { registerCleanupHandler } from '../utils/process-cleanup.js';
import { Redis } from 'ioredis';

// ── Types ──────────────────────────────────────────────────────────────────

export type PubSubHandler = (data: unknown) => void | Promise<void>;

export interface PubSubBus {
  publish: (channel: string, data: unknown) => Promise<void>;
  subscribe: (channel: string, handler: PubSubHandler) => Promise<void>;
  unsubscribe: (channel: string) => Promise<void>;
  close: () => Promise<void>;
  readonly mode: 'redis' | 'memory';
}

export interface RedisPubSubConfig {
  readonly host: string;
  readonly port: number;
  readonly password?: string;
  readonly db?: number;
}

export type PubSubMode = 'redis' | 'memory';

export interface PubSubConfig {
  readonly mode: PubSubMode;
  readonly redis?: RedisPubSubConfig;
}

// ── Constants (跟 Hard Rule #4 0 magic numbers 联合) ────────────────────────

export const KALLAX_PUBSUB_CHANNEL_PREFIX = 'kallax:pubsub:';
export const REDIS_RETRY_BASE_MS = 100;
export const REDIS_RETRY_MAX_DELAY_MS = 3_000;

// ── Helpers ────────────────────────────────────────────────────────────────

function channelWithPrefix(channel: string): string {
  return `${KALLAX_PUBSUB_CHANNEL_PREFIX}${channel}`;
}

function redisRetryStrategy(times: number): number {
  return Math.min(times * REDIS_RETRY_BASE_MS, REDIS_RETRY_MAX_DELAY_MS);
}

// ── RedisPubSubBus (primary, ioredis) ──────────────────────────────────────
//
// ioredis is now a hard dependency (file:line `node/package.json:32`), so the
// static import above is safe. InMemoryPubSubBus remains as the L2 fallback
// for unit tests and degraded single-process environments (跟 eket 4 级降级 模式 联合).

export function createRedisPubSubBus(config: RedisPubSubConfig): PubSubBus {
  const publisher = new Redis({
    host: config.host,
    port: config.port,
    password: config.password,
    db: config.db ?? 0,
    retryStrategy: redisRetryStrategy,
  });

  const subscriber = new Redis({
    host: config.host,
    port: config.port,
    password: config.password,
    db: config.db ?? 0,
    retryStrategy: redisRetryStrategy,
  });

  // channel -> Set<handler>  (multiple handlers per channel allowed)
  const handlers = new Map<string, Set<PubSubHandler>>();

  subscriber.on('message', (channel: string, messageStr: string) => {
    const handlersForChannel = handlers.get(channel);
    if (handlersForChannel === undefined || handlersForChannel.size === 0) {
      return;
    }
    let parsed: unknown;
    try {
      parsed = JSON.parse(messageStr) as unknown;
    } catch (parseError: unknown) {
      logger.error(
        {
          channel,
          error: parseError instanceof Error ? parseError.message : String(parseError),
        },
        'redis-pubsub failed to parse message',
      );
      return;
    }
    for (const handler of handlersForChannel) {
      try {
        const result = handler(parsed);
        if (result instanceof Promise) {
          result.catch((error: unknown) => {
            logger.error(
              {
                channel,
                error: error instanceof Error ? error.message : String(error),
              },
              'redis-pubsub handler rejected',
            );
          });
        }
      } catch (error: unknown) {
        logger.error(
          {
            channel,
            error: error instanceof Error ? error.message : String(error),
          },
          'redis-pubsub handler threw synchronously',
        );
      }
    }
  });

  publisher.on('error', (error: Error) => {
    logger.error(
      { error: error.message, host: config.host, port: config.port },
      'redis-pubsub publisher error',
    );
  });
  subscriber.on('error', (error: Error) => {
    logger.error(
      { error: error.message, host: config.host, port: config.port },
      'redis-pubsub subscriber error',
    );
  });

  registerCleanupHandler('redis-pubsub-bus', async () => {
    try {
      await publisher.quit();
    } catch (error: unknown) {
      logger.warn(
        { error: error instanceof Error ? error.message : String(error) },
        'redis-pubsub publisher quit failed',
      );
    }
    try {
      await subscriber.quit();
    } catch (error: unknown) {
      logger.warn(
        { error: error instanceof Error ? error.message : String(error) },
        'redis-pubsub subscriber quit failed',
      );
    }
  });

  return {
    mode: 'redis',

    async publish(channel: string, data: unknown): Promise<void> {
      const payload = JSON.stringify(data);
      await publisher.publish(channelWithPrefix(channel), payload);
      logger.debug({ channel }, 'redis-pubsub published');
    },

    async subscribe(channel: string, handler: PubSubHandler): Promise<void> {
      const fullChannel = channelWithPrefix(channel);
      let handlersForChannel = handlers.get(fullChannel);
      if (handlersForChannel === undefined) {
        handlersForChannel = new Set();
        handlers.set(fullChannel, handlersForChannel);
        await subscriber.subscribe(fullChannel);
        logger.debug({ channel: fullChannel }, 'redis-pubsub subscribed');
      }
      handlersForChannel.add(handler);
    },

    async unsubscribe(channel: string): Promise<void> {
      const fullChannel = channelWithPrefix(channel);
      const handlersForChannel = handlers.get(fullChannel);
      if (handlersForChannel === undefined) {
        return;
      }
      handlersForChannel.clear();
      handlers.delete(fullChannel);
      await subscriber.unsubscribe(fullChannel);
      logger.debug({ channel: fullChannel }, 'redis-pubsub unsubscribed');
    },

    async close(): Promise<void> {
      handlers.clear();
      await publisher.quit();
      await subscriber.quit();
      logger.info({}, 'redis-pubsub bus closed');
    },
  };
}

// ── InMemoryPubSubBus (fallback, single-process) ───────────────────────────

export function createInMemoryPubSubBus(): PubSubBus {
  // channel -> Set<handler>  (跟 RedisPubSubBus 同 结构, 跟 Rule 5 DRY 联合)
  const handlers = new Map<string, Set<PubSubHandler>>();

  registerCleanupHandler('in-memory-pubsub-bus', () => {
    handlers.clear();
  });

  return {
    mode: 'memory',

    async publish(channel: string, data: unknown): Promise<void> {
      const handlersForChannel = handlers.get(channel);
      if (handlersForChannel === undefined || handlersForChannel.size === 0) {
        logger.debug({ channel }, 'in-memory-pubsub publish: no subscribers');
        return;
      }
      // Snapshot to allow handlers to unsubscribe during dispatch
      const snapshot = Array.from(handlersForChannel);
      for (const handler of snapshot) {
        try {
          const result = handler(data);
          if (result instanceof Promise) {
            await result;
          }
        } catch (error: unknown) {
          logger.error(
            {
              channel,
              error: error instanceof Error ? error.message : String(error),
            },
            'in-memory-pubsub handler failed',
          );
        }
      }
      logger.debug({ channel, subscriberCount: handlersForChannel.size }, 'in-memory-pubsub published');
    },

    async subscribe(channel: string, handler: PubSubHandler): Promise<void> {
      let handlersForChannel = handlers.get(channel);
      if (handlersForChannel === undefined) {
        handlersForChannel = new Set();
        handlers.set(channel, handlersForChannel);
      }
      handlersForChannel.add(handler);
      logger.debug({ channel, subscriberCount: handlersForChannel.size }, 'in-memory-pubsub subscribed');
    },

    async unsubscribe(channel: string): Promise<void> {
      handlers.delete(channel);
      logger.debug({ channel }, 'in-memory-pubsub unsubscribed');
    },

    async close(): Promise<void> {
      handlers.clear();
      logger.info({}, 'in-memory-pubsub bus closed');
    },
  };
}

// ── Factory (跟 AGENTS.md 4 级降级 模式 联合) ──────────────────────────────

/**
 * Create a Pub/Sub bus based on configuration.
 *
 * 跟 eket 4 级降级 模式 联合:
 *   - L3 (Production):     mode='redis'    → RedisPubSubBus
 *   - L2 (Degraded / dev): mode='memory'   → InMemoryPubSubBus
 */
export function createPubSubBus(config: PubSubConfig): PubSubBus {
  if (config.mode === 'redis') {
    if (config.redis === undefined) {
      throw new Error('PubSubBus mode=redis requires redis config (host, port)');
    }
    logger.info(
      { host: config.redis.host, port: config.redis.port },
      'creating redis pub/sub bus (L3)',
    );
    return createRedisPubSubBus(config.redis);
  }
  logger.info({}, 'creating in-memory pub/sub bus (L2 fallback)');
  return createInMemoryPubSubBus();
}

/**
 * KALLAX Message Queue
 * Redis/File dual-mode message queue
 */

import { err, ok } from 'neverthrow';
import { Redis } from 'ioredis';
import { KallaxError, KallaxErrorCode, type KallaxResult, type Message, MessagePriority } from '../types/index.js';
import { logger } from '../utils/logger.js';
import { registerCleanupHandler } from '../utils/process-cleanup.js';
import { createSQLiteManager, type SQLiteManager } from './sqlite/index.js';

export interface MessageQueueConfig {
  readonly mode: 'redis' | 'sqlite' | 'memory';
  readonly redis?: {
    readonly host: string;
    readonly port: number;
    readonly password?: string;
    readonly db?: number;
  };
  readonly sqlite?: {
    readonly path: string;
  };
}

export interface MessageQueue {
  publish: (type: string, payload: unknown, options?: PublishOptions) => Promise<KallaxResult<string>>;
  subscribe: (type: string, handler: MessageHandler) => KallaxResult<void>;
  unsubscribe: (type: string) => KallaxResult<void>;
  peek: (limit?: number) => Promise<KallaxResult<Message[]>>;
  ack: (messageId: string) => Promise<KallaxResult<void>>;
  close: () => Promise<void>;
  getStats: () => MessageQueueStats;
}

export interface PublishOptions {
  readonly priority?: number;
  readonly targetId?: string;
  readonly ttlMs?: number;
}

export type MessageHandler = (message: Message) => Promise<void>;

export interface MessageQueueStats {
  readonly mode: string;
  readonly pendingCount: number;
  readonly subscriberCount: number;
  readonly messagesPublished: number;
  readonly messagesProcessed: number;
}

function generateMessageId(): string {
  return `msg_${Date.now()}_${Math.random().toString(36).slice(2, 11)}`;
}

/**
 * Create in-memory message queue (for testing/development)
 */
function createMemoryQueue(): MessageQueue {
  const messages: Message[] = [];
  const handlers = new Map<string, MessageHandler>();
  let messagesPublished = 0;
  let messagesProcessed = 0;

  return {
    async publish(type, payload, options): Promise<KallaxResult<string>> {
      const id = generateMessageId();
      const message: Message = {
        id,
        type,
        payload,
        priority: options?.priority ?? MessagePriority.NORMAL,
        createdAt: Date.now(),
        expiresAt: options?.ttlMs !== undefined ? Date.now() + options.ttlMs : undefined,
        targetId: options?.targetId,
      };

      messages.push(message);
      messagesPublished++;

      // Immediately dispatch to handler if subscribed
      const handler = handlers.get(type);
      if (handler !== undefined) {
        try {
          await handler(message);
          messagesProcessed++;
        } catch (error: unknown) {
          logger.error(
            { messageId: id, type, error: error instanceof Error ? error.message : String(error) },
            'message handler failed'
          );
        }
      }

      logger.debug({ messageId: id, type }, 'message published');
      return ok(id);
    },

    subscribe(type, handler): KallaxResult<void> {
      handlers.set(type, handler);
      logger.debug({ type }, 'subscribed to message type');
      return ok(undefined);
    },

    unsubscribe(type): KallaxResult<void> {
      handlers.delete(type);
      logger.debug({ type }, 'unsubscribed from message type');
      return ok(undefined);
    },

    async peek(limit = 10): Promise<KallaxResult<Message[]>> {
      const now = Date.now();
      const pending = messages
        .filter((m) => m.processedAt === undefined && (m.expiresAt === undefined || m.expiresAt > now))
        .sort((a, b) => (b.priority - a.priority) || (a.createdAt - b.createdAt))
        .slice(0, limit);
      return ok(pending);
    },

    async ack(messageId): Promise<KallaxResult<void>> {
      const index = messages.findIndex((m) => m.id === messageId);
      if (index !== -1) {
        const message = messages[index];
        if (message !== undefined) {
          messages[index] = { ...message, processedAt: Date.now() };
        }
      }
      return ok(undefined);
    },

    async close(): Promise<void> {
      messages.length = 0;
      handlers.clear();
      logger.info({}, 'memory queue closed');
    },

    getStats(): MessageQueueStats {
      return {
        mode: 'memory',
        pendingCount: messages.filter((m) => m.processedAt === undefined).length,
        subscriberCount: handlers.size,
        messagesPublished,
        messagesProcessed,
      };
    },
  };
}

/**
 * Create SQLite-backed message queue
 */
function createSQLiteQueue(dbManager: SQLiteManager): MessageQueue {
  const handlers = new Map<string, MessageHandler>();
  let messagesPublished = 0;
  let messagesProcessed = 0;

  // Poll for messages periodically
  let pollInterval: ReturnType<typeof setInterval> | null = null;

  async function processMessages(): Promise<void> {
    for (const [type, handler] of handlers) {
      const result = dbManager.dequeueMessage();
      if (result.isOk() && result.value !== null && result.value.type === type) {
        try {
          await handler(result.value);
          messagesProcessed++;
        } catch (error: unknown) {
          logger.error(
            { messageId: result.value.id, type, error: error instanceof Error ? error.message : String(error) },
            'message handler failed'
          );
        }
      }
    }
  }

  return {
    async publish(type, payload, options): Promise<KallaxResult<string>> {
      const id = generateMessageId();
      const message: Message = {
        id,
        type,
        payload,
        priority: options?.priority ?? MessagePriority.NORMAL,
        createdAt: Date.now(),
        expiresAt: options?.ttlMs !== undefined ? Date.now() + options.ttlMs : undefined,
        targetId: options?.targetId,
      };

      const result = dbManager.enqueueMessage(message);
      if (result.isErr()) {
        return err(result.error);
      }

      messagesPublished++;
      logger.debug({ messageId: id, type }, 'message published');
      return ok(id);
    },

    subscribe(type, handler): KallaxResult<void> {
      handlers.set(type, handler);

      // Start polling if not already
      if (pollInterval === null) {
        pollInterval = setInterval(() => {
          void processMessages();
        }, 1000);
      }

      logger.debug({ type }, 'subscribed to message type');
      return ok(undefined);
    },

    unsubscribe(type): KallaxResult<void> {
      handlers.delete(type);

      if (handlers.size === 0 && pollInterval !== null) {
        clearInterval(pollInterval);
        pollInterval = null;
      }

      logger.debug({ type }, 'unsubscribed from message type');
      return ok(undefined);
    },

    async peek(limit = 10): Promise<KallaxResult<Message[]>> {
      return dbManager.peekMessages(limit);
    },

    async ack(_messageId): Promise<KallaxResult<void>> {
      // Messages are already marked as processed when dequeued
      return ok(undefined);
    },

    async close(): Promise<void> {
      if (pollInterval !== null) {
        clearInterval(pollInterval);
        pollInterval = null;
      }
      handlers.clear();
      logger.info({}, 'sqlite queue closed');
    },

    getStats(): MessageQueueStats {
      const peekResult = dbManager.peekMessages(1000);
      const pendingCount = peekResult.isOk() ? peekResult.value.length : 0;

      return {
        mode: 'sqlite',
        pendingCount,
        subscriberCount: handlers.size,
        messagesPublished,
        messagesProcessed,
      };
    },
  };
}

/**
 * Create Redis-backed message queue
 */
function createRedisQueue(config: NonNullable<MessageQueueConfig['redis']>): MessageQueue {
  const redis = new Redis({
    host: config.host,
    port: config.port,
    password: config.password,
    db: config.db ?? 0,
    retryStrategy: (times: number) => Math.min(times * 100, 3000),
  });

  const subscriber = new Redis({
    host: config.host,
    port: config.port,
    password: config.password,
    db: config.db ?? 0,
  });

  const handlers = new Map<string, MessageHandler>();
  let messagesPublished = 0;
  let messagesProcessed = 0;

  const QUEUE_KEY = 'kallax:messages';
  const CHANNEL_PREFIX = 'kallax:channel:';

  // Handle pub/sub messages
  subscriber.on('message', (channel: string, messageStr: string) => {
    const type = channel.replace(CHANNEL_PREFIX, '');
    const handler = handlers.get(type);

    if (handler !== undefined) {
      try {
        const message = JSON.parse(messageStr) as Message;
        void handler(message).then(() => {
          messagesProcessed++;
        }).catch((error: unknown) => {
          logger.error(
            { type, error: error instanceof Error ? error.message : String(error) },
            'message handler failed'
          );
        });
      } catch (parseError: unknown) {
        logger.error(
          { channel, error: parseError instanceof Error ? parseError.message : String(parseError) },
          'failed to parse message'
        );
      }
    }
  });

  registerCleanupHandler('redis-queue', async () => {
    await redis.quit();
    await subscriber.quit();
  });

  return {
    async publish(type, payload, options): Promise<KallaxResult<string>> {
      try {
        const id = generateMessageId();
        const message: Message = {
          id,
          type,
          payload,
          priority: options?.priority ?? MessagePriority.NORMAL,
          createdAt: Date.now(),
          expiresAt: options?.ttlMs !== undefined ? Date.now() + options.ttlMs : undefined,
          targetId: options?.targetId,
        };

        const messageStr = JSON.stringify(message);

        // Store in sorted set by priority
        await redis.zadd(QUEUE_KEY, message.priority, messageStr);

        // Publish to channel for real-time subscribers
        await redis.publish(`${CHANNEL_PREFIX}${type}`, messageStr);

        messagesPublished++;
        logger.debug({ messageId: id, type }, 'message published');
        return ok(id);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.REDIS_ERROR, 'Failed to publish message', { cause: error })
        );
      }
    },

    subscribe(type, handler): KallaxResult<void> {
      handlers.set(type, handler);
      void subscriber.subscribe(`${CHANNEL_PREFIX}${type}`);
      logger.debug({ type }, 'subscribed to message type');
      return ok(undefined);
    },

    unsubscribe(type): KallaxResult<void> {
      handlers.delete(type);
      void subscriber.unsubscribe(`${CHANNEL_PREFIX}${type}`);
      logger.debug({ type }, 'unsubscribed from message type');
      return ok(undefined);
    },

    async peek(limit = 10): Promise<KallaxResult<Message[]>> {
      try {
        const items = await redis.zrevrange(QUEUE_KEY, 0, limit - 1);
        const messages = items.map((item: string) => JSON.parse(item) as Message);
        return ok(messages);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.REDIS_ERROR, 'Failed to peek messages', { cause: error })
        );
      }
    },

    async ack(messageId): Promise<KallaxResult<void>> {
      try {
        // Remove from sorted set by scanning
        const items = await redis.zrange(QUEUE_KEY, 0, -1);
        for (const item of items) {
          const message = JSON.parse(item) as Message;
          if (message.id === messageId) {
            await redis.zrem(QUEUE_KEY, item);
            break;
          }
        }
        return ok(undefined);
      } catch (error: unknown) {
        return err(
          new KallaxError(KallaxErrorCode.REDIS_ERROR, 'Failed to ack message', { cause: error })
        );
      }
    },

    async close(): Promise<void> {
      handlers.clear();
      await redis.quit();
      await subscriber.quit();
      logger.info({}, 'redis queue closed');
    },

    getStats(): MessageQueueStats {
      return {
        mode: 'redis',
        pendingCount: 0, // Would need async call
        subscriberCount: handlers.size,
        messagesPublished,
        messagesProcessed,
      };
    },
  };
}

/**
 * Create message queue based on configuration
 */
export function createMessageQueue(config: MessageQueueConfig): KallaxResult<MessageQueue> {
  switch (config.mode) {
    case 'memory':
      logger.info({}, 'creating memory message queue');
      return ok(createMemoryQueue());

    case 'sqlite': {
      if (config.sqlite === undefined) {
        return err(new KallaxError(KallaxErrorCode.CONFIG_INVALID, 'SQLite config required for sqlite mode'));
      }
      logger.info({ path: config.sqlite.path }, 'creating sqlite message queue');
      const dbResult = createSQLiteManager({ path: config.sqlite.path });
      if (dbResult.isErr()) {
        return err(dbResult.error);
      }
      return ok(createSQLiteQueue(dbResult.value));
    }

    case 'redis': {
      if (config.redis === undefined) {
        return err(new KallaxError(KallaxErrorCode.CONFIG_INVALID, 'Redis config required for redis mode'));
      }
      logger.info({ host: config.redis.host, port: config.redis.port }, 'creating redis message queue');
      return ok(createRedisQueue(config.redis));
    }

    default:
      return err(new KallaxError(KallaxErrorCode.CONFIG_INVALID, `Unknown queue mode: ${config.mode as string}`));
  }
}

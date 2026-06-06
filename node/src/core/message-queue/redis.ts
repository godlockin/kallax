/**
 * KALLAX Redis-backed Message Queue
 */
import { err, ok } from 'neverthrow';
import { Redis } from 'ioredis';
import { KallaxError, KallaxErrorCode, MessagePriority, type KallaxResult, type Message } from '../../types/index.js';
import type { MessageHandler, MessageQueue, MessageQueueConfig } from './types.js';
import { logger } from '../../utils/logger.js';
import { registerCleanupHandler } from '../../utils/process-cleanup.js';

function generateMessageId(): string {
  return `msg_${Date.now()}_${Math.random().toString(36).slice(2, 11)}`;
}

/**
 * Create Redis-backed message queue
 */
export function createRedisQueue(config: NonNullable<MessageQueueConfig['redis']>): MessageQueue {
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
            'message handler failed',
          );
        });
      } catch (parseError: unknown) {
        logger.error(
          { channel, error: parseError instanceof Error ? parseError.message : String(parseError) },
          'failed to parse message',
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
          new KallaxError(KallaxErrorCode.REDIS_ERROR, 'Failed to publish message', { cause: error }),
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
          new KallaxError(KallaxErrorCode.REDIS_ERROR, 'Failed to peek messages', { cause: error }),
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
          new KallaxError(KallaxErrorCode.REDIS_ERROR, 'Failed to ack message', { cause: error }),
        );
      }
    },

    async close(): Promise<void> {
      handlers.clear();
      await redis.quit();
      await subscriber.quit();
      logger.info({}, 'redis queue closed');
    },

    getStats() {
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

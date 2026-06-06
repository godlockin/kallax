/**
 * KALLAX SQLite-backed Message Queue
 */
import { ok, err } from 'neverthrow';
import { MessagePriority, type KallaxResult, type Message } from '../../types/index.js';
import type { MessageHandler, MessageQueue, MessageQueueStats } from './types.js';
import type { SQLiteManager } from '../sqlite/index.js';
import { logger } from '../../utils/logger.js';

function generateMessageId(): string {
  return `msg_${Date.now()}_${Math.random().toString(36).slice(2, 11)}`;
}

/**
 * Create SQLite-backed message queue
 */
export function createSQLiteQueue(dbManager: SQLiteManager): MessageQueue {
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
            'message handler failed',
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

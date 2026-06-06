/**
 * KALLAX In-Memory Message Queue
 */
import { ok } from 'neverthrow';
import { MessagePriority, type KallaxResult, type Message } from '../../types/index.js';
import type { MessageHandler, MessageQueue, MessageQueueStats } from '../message-queue.js';
import { logger } from '../../utils/logger.js';

function generateMessageId(): string {
  return `msg_${Date.now()}_${Math.random().toString(36).slice(2, 11)}`;
}

/**
 * Create in-memory message queue (for testing/development)
 */
export function createMemoryQueue(): MessageQueue {
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
            'message handler failed',
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

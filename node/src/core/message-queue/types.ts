/**
 * KALLAX Message Queue Types
 * Shared interfaces — separate from implementation to avoid circular deps.
 */

import type { KallaxResult, Message } from '../../types/index.js';

export interface MessageQueueConfig {
  readonly mode: 'redis' | 'sqlite' | 'memory';
  readonly redis?: { readonly host: string; readonly port: number; readonly password?: string; readonly db?: number; };
  readonly sqlite?: { readonly path: string; };
}

export interface PublishOptions {
  readonly priority?: number;
  readonly targetId?: string;
  readonly ttlMs?: number;
}

export type MessageHandler = (message: Message) => Promise<void>;

export interface MessageQueue {
  publish: (type: string, payload: unknown, options?: PublishOptions) => Promise<KallaxResult<string>>;
  subscribe: (type: string, handler: MessageHandler) => KallaxResult<void>;
  unsubscribe: (type: string) => KallaxResult<void>;
  peek: (limit?: number) => Promise<KallaxResult<Message[]>>;
  ack: (messageId: string) => Promise<KallaxResult<void>>;
  close: () => Promise<void>;
  getStats: () => MessageQueueStats;
}

export interface MessageQueueStats {
  readonly mode: string;
  readonly pendingCount: number;
  readonly subscriberCount: number;
  readonly messagesPublished: number;
  readonly messagesProcessed: number;
}

/**
 * KALLAX Message Queue
 * Redis/File/Memory multi-mode message queue
 */

import { err, ok } from 'neverthrow';
import { KallaxError, KallaxErrorCode, type KallaxResult } from '../types/index.js';
import { logger } from '../utils/logger.js';
import { createSQLiteManager } from './sqlite/index.js';
import { createRedisQueue } from './message-queue/redis.js';
import { createMemoryQueue } from './message-queue/memory.js';
import { createSQLiteQueue } from './message-queue/sqlite.js';
import type { MessageQueueConfig, MessageQueue } from './message-queue/types.js';
export type {
  MessageQueueConfig,
  PublishOptions,
  MessageHandler,
  MessageQueue,
  MessageQueueStats,
} from './message-queue/types.js';

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

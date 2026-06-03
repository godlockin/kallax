/**
 * Message Queue tests: memory backend enqueue/dequeue + priority ordering.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createMessageQueue } from '../src/core/message-queue.js';
import { MessagePriority } from '../src/types/index.js';

describe('MessageQueue (memory mode)', () => {
  beforeEach(async () => {
    // Each test gets its own queue via createMessageQueue directly
  });

  it('publishes and dispatches to subscribed handler', async () => {
    const result = createMessageQueue({ mode: 'memory' });
    expect(result.isOk()).toBe(true);
    const mq = result._unsafeUnwrap();

    const messages: string[] = [];
    mq.subscribe('test-type', async (msg) => {
      messages.push(msg.id);
    });

    const pubResult = await mq.publish('test-type', { hello: 'world' });
    expect(pubResult.isOk()).toBe(true);
    expect(messages.length).toBe(1);
  });

  it('peek returns unprocessed messages sorted by priority desc', async () => {
    const result = createMessageQueue({ mode: 'memory' });
    expect(result.isOk()).toBe(true);
    const mq = result._unsafeUnwrap();

    await mq.publish('type-a', { x: 1 }, { priority: MessagePriority.LOW });
    await mq.publish('type-b', { x: 2 }, { priority: MessagePriority.CRITICAL });
    await mq.publish('type-c', { x: 3 }, { priority: MessagePriority.NORMAL });

    const peekResult = await mq.peek(10);
    expect(peekResult.isOk()).toBe(true);
    const pending = peekResult._unsafeUnwrap();
    expect(pending.length).toBe(3);
    // CRITICAL (3) first, then NORMAL (1), then LOW (0)
    expect(pending[0]?.priority).toBe(MessagePriority.CRITICAL);
    expect(pending[2]?.priority).toBe(MessagePriority.LOW);
  });

  it('ack marks message as processed, excluding from subsequent peek', async () => {
    const result = createMessageQueue({ mode: 'memory' });
    expect(result.isOk()).toBe(true);
    const mq = result._unsafeUnwrap();

    const pubResult = await mq.publish('type-a', { x: 1 });
    expect(pubResult.isOk()).toBe(true);
    const msgId = pubResult._unsafeUnwrap();

    await mq.ack(msgId);
    const peekResult = await mq.peek(10);
    expect(peekResult._unsafeUnwrap().length).toBe(0);
  });

  it('expired messages (ttlMs) are excluded from peek', async () => {
    const result = createMessageQueue({ mode: 'memory' });
    expect(result.isOk()).toBe(true);
    const mq = result._unsafeUnwrap();

    await mq.publish('type-a', { x: 1 }, { ttlMs: -1 }); // already expired

    const peekResult = await mq.peek(10);
    expect(peekResult._unsafeUnwrap().length).toBe(0);
  });

  it('handles missing handler gracefully (handler not required)', async () => {
    const result = createMessageQueue({ mode: 'memory' });
    expect(result.isOk()).toBe(true);
    const mq = result._unsafeUnwrap();

    const pubResult = await mq.publish('unsubscribed-type', { x: 1 });
    expect(pubResult.isOk()).toBe(true);

    // No subscriber to consume, but ack still works
    await mq.ack(pubResult._unsafeUnwrap());
  });

  it('tracks stats correctly', async () => {
    const result = createMessageQueue({ mode: 'memory' });
    expect(result.isOk()).toBe(true);
    const mq = result._unsafeUnwrap();

    mq.subscribe('t', async () => {});
    await mq.publish('t', { x: 1 });

    const stats = mq.getStats();
    expect(stats.mode).toBe('memory');
    expect(stats.messagesPublished).toBe(1);
    expect(stats.subscriberCount).toBe(1);
  });
});

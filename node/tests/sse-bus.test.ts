/**
 * SSE Bus tests: client add/remove, publish, subscribe/unsubscribe.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createSSEBus, createEvent } from '../src/core/sse-bus.js';
import type { SSEBus, SSEClient } from '../src/core/sse-bus.js';

function makeClient(id: string): SSEClient {
  return { id, send: vi.fn(), close: vi.fn() };
}

describe('SSEBus', () => {
  let bus: SSEBus;

  beforeEach(() => {
    bus = createSSEBus();
  });

  it('addClient increases client count', () => {
    expect(bus.getClientCount()).toBe(0);
    bus.addClient(makeClient('c1'));
    bus.addClient(makeClient('c2'));
    expect(bus.getClientCount()).toBe(2);
  });

  it('removeClient disconnects and decreases count', () => {
    const client = makeClient('c1');
    bus.addClient(client);
    bus.removeClient('c1');
    expect(bus.getClientCount()).toBe(0);
    expect(client.close).toHaveBeenCalledOnce();
  });

  it('publish sends event to all clients without subscriptions (broadcast)', () => {
    const c1 = makeClient('c1');
    const c2 = makeClient('c2');
    bus.addClient(c1);
    bus.addClient(c2);

    const event = createEvent('task.created', { id: 1 }, 'source-1');
    const result = bus.publish(event);
    expect(result.isOk()).toBe(true);

    expect(c1.send).toHaveBeenCalled();
    expect(c2.send).toHaveBeenCalled();
  });

  it('publish only sends to subscribed clients', () => {
    const c1 = makeClient('c1');
    const c2 = makeClient('c2');
    bus.addClient(c1);
    bus.addClient(c2);

    bus.subscribe('c1', ['task.created']);
    bus.subscribe('c2', ['task.completed']);

    const event = createEvent('task.created', { id: 1 }, 'source-1');
    bus.publish(event);

    expect(c1.send).toHaveBeenCalled();
    expect(c2.send).not.toHaveBeenCalled();
  });

  it('publishToClient returns false for unknown client', () => {
    const event = createEvent('task.created', {}, 'src');
    const result = bus.publishToClient('nonexistent', event);
    expect(result._unsafeUnwrap()).toBe(false);
  });

  it('publishToClient sends to specific client only', () => {
    const c1 = makeClient('c1');
    const c2 = makeClient('c2');
    bus.addClient(c1);
    bus.addClient(c2);

    const event = createEvent('task.created', { id: 1 }, 'src');
    const result = bus.publishToClient('c1', event);
    expect(result._unsafeUnwrap()).toBe(true);
    expect(c1.send).toHaveBeenCalled();
    expect(c2.send).not.toHaveBeenCalled();
  });

  it('unsubscribe clears all subscriptions when no eventTypes given', () => {
    const c1 = makeClient('c1');
    bus.addClient(c1);
    bus.subscribe('c1', ['task.created', 'task.completed']);

    bus.unsubscribe('c1');
    bus.publish(createEvent('task.created', {}, 'src'));
    expect(c1.send).not.toHaveBeenCalled();
  });

  it('tracks events published by type', () => {
    bus.addClient(makeClient('c1'));

    bus.publish(createEvent('task.created', {}, 's1'));
    bus.publish(createEvent('task.created', {}, 's1'));
    bus.publish(createEvent('task.completed', {}, 's1'));

    const stats = bus.getStats();
    expect(stats.eventsPublished).toBe(3);
    expect(stats.eventsByType['task.created']).toBe(2);
    expect(stats.eventsByType['task.completed']).toBe(1);
  });
});

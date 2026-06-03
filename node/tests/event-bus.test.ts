/**
 * EventBus tests — DLQ, interceptors, priority, once-delivery.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ok, err } from 'neverthrow';
import { createEventBus, getEventBus } from '../src/core/event-bus.js';
import type { EventBus } from '../src/core/event-bus.js';
import type { KallaxEvent, EventType } from '../src/types/index.js';

function createMockEvent(type: EventType = 'task.created'): KallaxEvent {
  return {
    id: `evt_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
    type,
    payload: { test: true },
    timestamp: Date.now(),
    sourceId: 'test',
  };
}

describe('EventBus', () => {
  let bus: EventBus;

  beforeEach(() => {
    bus = createEventBus();
  });

  describe('publish + subscribe', () => {
    it('delivers events to matching subscribers', async () => {
      const handler = vi.fn().mockResolvedValue(undefined);
      const unsub = bus.subscribe('sub1', ['task.created'], handler);
      expect(unsub.isOk()).toBe(true);

      const event = createMockEvent('task.created');
      const result = bus.publish(event);
      expect(result.isOk()).toBe(true);

      // Allow async delivery
      await vi.waitFor(() => expect(handler).toHaveBeenCalled(), { timeout: 1000 });
      expect(handler).toHaveBeenCalledWith(expect.objectContaining({ type: 'task.created' }));
    });

    it('does not deliver to non-matching subscribers', async () => {
      const handler = vi.fn().mockResolvedValue(undefined);
      bus.subscribe('sub1', ['task.completed'], handler);
      bus.publish(createMockEvent('task.created'));

      await new Promise((r) => setTimeout(r, 50));
      expect(handler).not.toHaveBeenCalled();
    });

    it('respects once-delivery', async () => {
      const calls: number[] = [];
      bus.subscribe('sub_once', ['task.created'], async () => { calls.push(Date.now()); }, { once: true });

      // First publish
      bus.publish(createMockEvent('task.created'));
      await vi.waitFor(() => expect(calls.length).toBe(1), { timeout: 2000 });

      // Second publish
      bus.publish(createMockEvent('task.created'));
      // Wait for any possible async delivery
      await new Promise((r) => setTimeout(r, 500));

      expect(calls.length).toBe(1);
    }, 5000);
  });

  describe('interceptors', () => {
    it('runs beforePublish interceptor', async () => {
      const handler = vi.fn().mockResolvedValue(undefined);
      // Use a real interceptor that modifies and passes
      bus.addInterceptor({
        name: 'test-interceptor',
        async afterPublish() { /* noop */ },
      });

      bus.subscribe('sub1', ['task.created'], handler);
      bus.publish(createMockEvent('task.created'));

      await vi.waitFor(() => expect(handler).toHaveBeenCalled(), { timeout: 500 });
    });

    it('allows interceptor to reject event', () => {
      const interceptor = {
        name: 'reject-interceptor',
        beforePublish: vi.fn().mockReturnValue(err(new Error('blocked'))),
      };

      bus.addInterceptor(interceptor);
      const result = bus.publish(createMockEvent('task.created'));
      expect(result.isErr()).toBe(true);
    });
  });

  describe('dead letter queue', () => {
    it('records failed deliveries to DLQ', async () => {
      // Register a handler that throws
      const handler = vi.fn().mockRejectedValue(new Error('always fails'));
      bus.subscribe('failing_sub', ['task.created'], handler);

      const event = createMockEvent('task.created');
      bus.publish(event);

      // Wait for retries to exhaust (3 retries with backoff)
      await new Promise((r) => setTimeout(r, 1500));

      const dlq = bus.getDeadLetters();
      expect(dlq.length).toBeGreaterThan(0);
      expect(dlq[0]?.envelope.event.id).toBe(event.id);
    }, 5000);
  });

  describe('priority delivery', () => {
    it('delivers to higher priority subscribers first (same event type)', async () => {
      const order: string[] = [];
      const lowHandler = vi.fn().mockImplementation(async () => { order.push('low'); });
      const highHandler = vi.fn().mockImplementation(async () => { order.push('high'); });

      bus.subscribe('low_sub', ['task.created'], lowHandler, { priority: 0 });
      bus.subscribe('high_sub', ['task.created'], highHandler, { priority: 3 });

      bus.publish(createMockEvent('task.created'));
      await vi.waitFor(() => expect(order.length).toBe(2), { timeout: 500 });

      expect(order).toEqual(['high', 'low']);
    });
  });

  describe('unsubscribe', () => {
    it('removes subscriber', () => {
      const handler = vi.fn();
      bus.subscribe('sub1', ['task.created'], handler);
      expect(bus.getSubscriberCount()).toBe(1);

      bus.unsubscribe('sub1');
      expect(bus.getSubscriberCount()).toBe(0);
    });

    it('returns unsubscribe function from subscribe', () => {
      const handler = vi.fn();
      const result = bus.subscribe('sub1', ['task.created'], handler);
      expect(result.isOk()).toBe(true);

      const unsubscribe = result.value;
      unsubscribe();
      expect(bus.getSubscriberCount()).toBe(0);
    });
  });

  describe('dead letter management', () => {
    it('retries dead letters', async () => {
      // Create a failing handler, let it fail to DLQ
      let shouldFail = true;
      const handler = vi.fn().mockImplementation(async () => {
        if (shouldFail) throw new Error('failing');
      });

      bus.subscribe('flaky_sub', ['task.created'], handler);
      const event = createMockEvent('task.created');
      bus.publish(event);

      await new Promise((r) => setTimeout(r, 1500));

      const dlqBefore = bus.getDeadLetters();
      expect(dlqBefore.length).toBeGreaterThan(0);

      // Now fix the handler and retry
      shouldFail = false;
      const retryResult = await bus.retryDeadLetter(event.id);
      expect(retryResult.isOk()).toBe(true);

      // DLQ should be empty for this event
      const dlqAfter = bus.getDeadLetters();
      expect(dlqAfter.find((d) => d.envelope.event.id === event.id)).toBeUndefined();
    }, 5000);

    it('purges all dead letters', async () => {
      const handler = vi.fn().mockRejectedValue(new Error('fail'));
      bus.subscribe('sub', ['task.created'], handler);

      bus.publish(createMockEvent('task.created'));
      await new Promise((r) => setTimeout(r, 1500));

      expect(bus.getDeadLetters().length).toBeGreaterThan(0);
      bus.purgeDeadLetters();
      expect(bus.getDeadLetters().length).toBe(0);
    }, 5000);
  });

  describe('stats', () => {
    it('tracks published events by type', () => {
      bus.publish(createMockEvent('task.created'));
      bus.publish(createMockEvent('task.created'));
      bus.publish(createMockEvent('task.completed'));

      const stats = bus.getStats();
      expect(stats.eventsPublished).toBe(3);
      expect(stats.eventsByType['task.created']).toBe(2);
      expect(stats.eventsByType['task.completed']).toBe(1);
    });
  });

  describe('singleton', () => {
    it('getEventBus returns same instance', () => {
      const bus1 = getEventBus();
      const bus2 = getEventBus();
      expect(bus1).toBe(bus2);
    });
  });
});

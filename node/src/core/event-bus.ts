/**
 * KALLAX EventBus — typed pub/sub with DLQ, interceptors, priority, once-delivery.
 */

import { ok, err } from 'neverthrow';
import type { KallaxResult, KallaxEvent, EventType } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

// ── Types ──────────────────────────────────────────────────────────────────

export type MessagePriority = 0 | 1 | 2 | 3; // LOW=0, NORMAL=1, HIGH=2, CRITICAL=3

export interface Envelope {
  readonly event: KallaxEvent;
  readonly priority: MessagePriority;
  readonly deliveredAt: number;
  retryCount: number;
  lastError?: string;
}

export interface DeadLetter {
  readonly envelope: Envelope;
  readonly failedAt: number;
  readonly reason: string;
  readonly retryExhausted: boolean;
}

export type EventHandler = (event: KallaxEvent) => Promise<void>;

export interface Interceptor {
  readonly name: string;
  beforePublish?: (event: KallaxEvent) => KallaxResult<KallaxEvent>;
  afterPublish?: (event: KallaxEvent) => Promise<void>;
  onError?: (event: KallaxEvent, error: Error) => Promise<void>;
}

export interface Subscription {
  readonly id: string;
  readonly eventTypes: Set<EventType>;
  readonly handler: EventHandler;
  readonly priority: MessagePriority;
  readonly once: boolean;
  fired: boolean;
}

export interface EventBus {
  publish: (event: KallaxEvent, priority?: MessagePriority) => KallaxResult<void>;
  subscribe: (
    id: string,
    eventTypes: EventType[],
    handler: EventHandler,
    opts?: { priority?: MessagePriority; once?: boolean },
  ) => KallaxResult<() => void>;
  unsubscribe: (id: string) => KallaxResult<void>;
  addInterceptor: (interceptor: Interceptor) => void;
  removeInterceptor: (name: string) => void;
  getDeadLetters: () => DeadLetter[];
  retryDeadLetter: (eventId: string) => Promise<KallaxResult<void>>;
  purgeDeadLetters: () => void;
  getStats: () => EventBusStats;
  getSubscriberCount: () => number;
}

export interface EventBusStats {
  readonly eventsPublished: number;
  readonly eventsDelivered: number;
  readonly eventsFailed: number;
  readonly deadLetterCount: number;
  readonly subscriberCount: number;
  readonly eventsByType: Record<string, number>;
}

// ── Constants ──────────────────────────────────────────────────────────────

const MAX_RETRY = 3;
const MAX_DLQ_SIZE = 1000;
const DLQ_RETENTION_MS = 3600_000; // 1 hour

// ── Implementation ─────────────────────────────────────────────────────────

export function createEventBus(): EventBus {
  const subscriptions = new Map<string, Subscription>();
  const interceptors: Interceptor[] = [];
  const deadLetters: DeadLetter[] = [];
  let eventsPublished = 0;
  let eventsDelivered = 0;
  let eventsFailed = 0;
  const eventsByType: Record<string, number> = {};

  // Priority-sorted queue for ordered delivery
  function sortByPriority(subs: Subscription[]): Subscription[] {
    return subs.sort((a, b) => b.priority - a.priority);
  }

  function getMatchingSubscriptions(eventType: EventType): Subscription[] {
    const matches: Subscription[] = [];
    for (const sub of subscriptions.values()) {
      if (sub.eventTypes.has(eventType) && (!sub.once || !sub.fired)) {
        matches.push(sub);
      }
    }
    return sortByPriority(matches);
  }

  async function deliverToHandler(
    sub: Subscription,
    event: KallaxEvent,
  ): Promise<{ success: boolean; error?: string }> {
    try {
      await sub.handler(event);
      sub.fired = true;
      return { success: true };
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      return { success: false, error: message };
    }
  }

  async function deliverWithRetry(
    envelope: Envelope,
    sub: Subscription,
  ): Promise<void> {
    const { success, error } = await deliverToHandler(sub, envelope.event);

    if (success) {
      eventsDelivered++;
      return;
    }

    envelope.retryCount++;
    envelope.lastError = error;

    if (envelope.retryCount < MAX_RETRY) {
      logger.warn(
        { eventId: envelope.event.id, subscriberId: sub.id, retryCount: envelope.retryCount, error },
        'event delivery failed, will retry',
      );
      // Re-queue with backoff
      setTimeout(() => {
        deliverWithRetry(envelope, sub).catch((err: unknown) => {
        logger.error({ eventId: envelope.event.id, subscriberId: sub.id, error: err instanceof Error ? err.message : String(err) }, 'unhandled delivery error');
      });
      }, Math.pow(2, envelope.retryCount) * 100);
    } else {
      eventsFailed++;
      addToDeadLetter(envelope, error ?? 'unknown error');
    }
  }

  function addToDeadLetter(envelope: Envelope, reason: string): void {
    const dl: DeadLetter = {
      envelope: { ...envelope },
      failedAt: Date.now(),
      reason,
      retryExhausted: envelope.retryCount >= MAX_RETRY,
    };

    deadLetters.push(dl);

    // Evict oldest if over limit
    while (deadLetters.length > MAX_DLQ_SIZE) {
      deadLetters.shift();
    }

    logger.error(
      { eventId: envelope.event.id, reason, retryCount: envelope.retryCount },
      'event moved to dead letter queue',
    );
  }

  // ── Public API ─────────────────────────────────────────────────────────

  return {
    publish(event: KallaxEvent, priority: MessagePriority = 1): KallaxResult<void> {
      // Run before-publish interceptors
      let processedEvent = event;
      for (const interceptor of interceptors) {
        if (interceptor.beforePublish) {
          const result = interceptor.beforePublish(processedEvent);
          if (result.isErr()) {
            logger.error({ eventId: event.id, interceptor: interceptor.name }, 'beforePublish rejected');
            return err(result.error);
          }
          processedEvent = result.value;
        }
      }

      eventsPublished++;
      eventsByType[event.type] = (eventsByType[event.type] ?? 0) + 1;

      const matchingSubs = getMatchingSubscriptions(event.type);

      if (matchingSubs.length === 0) {
        logger.debug({ eventId: event.id, type: event.type }, 'no subscribers for event');
        return ok(undefined);
      }

      const envelope: Envelope = {
        event: processedEvent,
        priority,
        deliveredAt: Date.now(),
        retryCount: 0,
      };

      // Deliver to all matching subscribers (fire-and-forget per subscriber)
      for (const sub of matchingSubs) {
        deliverWithRetry({ ...envelope }, sub).catch((err: unknown) => {
          logger.error(
            { eventId: event.id, subscriberId: sub.id, error: err instanceof Error ? err.message : String(err) },
            'unhandled delivery error',
          );
        });
      }

      // Run after-publish interceptors (fire-and-forget)
      for (const interceptor of interceptors) {
        if (interceptor.afterPublish) {
          interceptor.afterPublish(processedEvent).catch((err: unknown) => {
            logger.error(
              { interceptor: interceptor.name, error: err instanceof Error ? err.message : String(err) },
              'afterPublish interceptor failed',
            );
          });
        }
      }

      return ok(undefined);
    },

    subscribe(
      id: string,
      eventTypes: EventType[],
      handler: EventHandler,
      opts?: { priority?: MessagePriority; once?: boolean },
    ): KallaxResult<() => void> {
      if (subscriptions.has(id)) {
        return err(new KallaxError(KallaxErrorCode.INSTANCE_ALREADY_EXISTS, `Subscriber ${id} already exists`));
      }

      const sub: Subscription = {
        id,
        eventTypes: new Set(eventTypes),
        handler,
        priority: opts?.priority ?? 1,
        once: opts?.once ?? false,
        fired: false,
      };

      subscriptions.set(id, sub);
      logger.debug({ subscriberId: id, eventTypes, priority: sub.priority }, 'subscriber registered');

      // Return unsubscribe function
      const unsubscribe = (): KallaxResult<void> => {
        subscriptions.delete(id);
        logger.debug({ subscriberId: id }, 'subscriber unregistered');
        return ok(undefined);
      };

      return ok(unsubscribe);
    },

    unsubscribe(id: string): KallaxResult<void> {
      if (!subscriptions.has(id)) {
        return err(new KallaxError(KallaxErrorCode.INSTANCE_NOT_FOUND, `Subscriber ${id} not found`));
      }
      subscriptions.delete(id);
      logger.debug({ subscriberId: id }, 'subscriber unregistered');
      return ok(undefined);
    },

    addInterceptor(interceptor: Interceptor): void {
      // Replace existing with same name
      const idx = interceptors.findIndex((i) => i.name === interceptor.name);
      if (idx >= 0) {
        interceptors[idx] = interceptor;
      } else {
        interceptors.push(interceptor);
      }
      logger.debug({ interceptor: interceptor.name }, 'interceptor registered');
    },

    removeInterceptor(name: string): void {
      const idx = interceptors.findIndex((i) => i.name === name);
      if (idx >= 0) {
        interceptors.splice(idx, 1);
        logger.debug({ interceptor: name }, 'interceptor removed');
      }
    },

    getDeadLetters(): DeadLetter[] {
      // Garbage collect old dead letters
      const cutoff = Date.now() - DLQ_RETENTION_MS;
      while (deadLetters.length > 0 && (deadLetters[0]?.failedAt ?? 0) < cutoff) {
        deadLetters.shift();
      }
      return [...deadLetters];
    },

    async retryDeadLetter(eventId: string): Promise<KallaxResult<void>> {
      const idx = deadLetters.findIndex((dl) => dl.envelope.event.id === eventId);
      if (idx < 0) {
        return err(new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, `Dead letter ${eventId} not found`));
      }

      const dl = deadLetters[idx];
      if (!dl) return err(new KallaxError(KallaxErrorCode.TASK_NOT_FOUND, `Dead letter ${eventId} not found at index`));
      deadLetters.splice(idx, 1);

      // Reset retry count and re-deliver
      const envelope: Envelope = {
        ...dl.envelope,
        retryCount: 0,
        lastError: undefined,
      };

      const matchingSubs = getMatchingSubscriptions(envelope.event.type);
      for (const sub of matchingSubs) {
        await deliverWithRetry(envelope, sub);
      }

      return ok(undefined);
    },

    purgeDeadLetters(): void {
      deadLetters.length = 0;
      logger.info({}, 'dead letter queue purged');
    },

    getStats(): EventBusStats {
      return {
        eventsPublished,
        eventsDelivered,
        eventsFailed,
        deadLetterCount: deadLetters.length,
        subscriberCount: subscriptions.size,
        eventsByType: { ...eventsByType },
      };
    },

    getSubscriberCount(): number {
      return subscriptions.size;
    },
  };
}

// Default singleton
let defaultBus: EventBus | null = null;

export function getEventBus(): EventBus {
  defaultBus ??= createEventBus();
  return defaultBus;
}

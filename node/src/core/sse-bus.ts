/**
 * KALLAX SSE Bus
 * Server-Sent Events for real-time communication
 */

import { ok } from 'neverthrow';
import type { KallaxResult, KallaxEvent, EventType } from '../types/index.js';
import { logger } from '../utils/logger.js';

export interface SSEClient {
  readonly id: string;
  readonly send: (data: string) => void;
  readonly close: () => void;
}

export interface SSEBus {
  addClient: (client: SSEClient) => void;
  removeClient: (clientId: string) => void;
  publish: (event: KallaxEvent) => KallaxResult<void>;
  publishToClient: (clientId: string, event: KallaxEvent) => KallaxResult<boolean>;
  subscribe: (clientId: string, eventTypes: EventType[]) => KallaxResult<void>;
  unsubscribe: (clientId: string, eventTypes?: EventType[]) => KallaxResult<void>;
  getClientCount: () => number;
  getStats: () => SSEBusStats;
}

export interface SSEBusStats {
  readonly clientCount: number;
  readonly subscriptionCount: number;
  readonly eventsPublished: number;
  readonly eventsByType: Record<string, number>;
}

function generateEventId(): string {
  return `evt_${String(Date.now())}_${Math.random().toString(36).slice(2, 8)}`;
}

export function createSSEBus(): SSEBus {
  const clients = new Map<string, SSEClient>();
  const subscriptions = new Map<string, Set<EventType>>(); // clientId -> subscribed event types
  let eventsPublished = 0;
  const eventsByType: Record<string, number> = {};

  function formatSSEMessage(event: KallaxEvent): string {
    const lines = [
      `id: ${event.id}`,
      `event: ${event.type}`,
      `data: ${JSON.stringify(event.payload)}`,
      '', // Empty line to end the event
    ];
    return lines.join('\n');
  }

  return {
    addClient(client: SSEClient): void { if (clients.size >= 1000) { client.close(); return; }
      clients.set(client.id, client);
      subscriptions.set(client.id, new Set());
      logger.info({ clientId: client.id }, 'SSE client connected');
    },

    removeClient(clientId: string): void {
      const client = clients.get(clientId);
      if (client !== undefined) {
        client.close();
        clients.delete(clientId);
        subscriptions.delete(clientId);
        logger.info({ clientId }, 'SSE client disconnected');
      }
    },

    publish(event: KallaxEvent): KallaxResult<void> {
      const message = formatSSEMessage(event);
      let sentCount = 0;

      for (const [clientId, client] of clients) {
        const clientSubs = subscriptions.get(clientId);

        // Send if client has no specific subscriptions (broadcast) or is subscribed to this type
        if (clientSubs === undefined || clientSubs.size === 0 || clientSubs.has(event.type)) {
          try {
            client.send(message);
            sentCount++;
          } catch (error: unknown) {
            logger.warn(
              { clientId, error: error instanceof Error ? error.message : String(error) },
              'failed to send to client'
            );
            // Remove disconnected client
            this.removeClient(clientId);
          }
        }
      }

      eventsPublished++;
      eventsByType[event.type] = (eventsByType[event.type] ?? 0) + 1;

      logger.debug({ eventId: event.id, type: event.type, sentCount }, 'event published');
      return ok(undefined);
    },

    publishToClient(clientId: string, event: KallaxEvent): KallaxResult<boolean> {
      const client = clients.get(clientId);
      if (client === undefined) {
        return ok(false);
      }

      try {
        const message = formatSSEMessage(event);
        client.send(message);
        eventsPublished++;
        eventsByType[event.type] = (eventsByType[event.type] ?? 0) + 1;
        return ok(true);
      } catch (error: unknown) {
        logger.warn(
          { clientId, error: error instanceof Error ? error.message : String(error) },
          'failed to send to specific client'
        );
        this.removeClient(clientId);
        return ok(false);
      }
    },

    subscribe(clientId: string, eventTypes: EventType[]): KallaxResult<void> {
      let subs = subscriptions.get(clientId);
      if (subs === undefined) {
        subs = new Set();
        subscriptions.set(clientId, subs);
      }

      for (const eventType of eventTypes) {
        subs.add(eventType);
      }

      logger.debug({ clientId, eventTypes }, 'client subscribed to events');
      return ok(undefined);
    },

    unsubscribe(clientId: string, eventTypes?: EventType[]): KallaxResult<void> {
      const subs = subscriptions.get(clientId);
      if (subs === undefined) {
        return ok(undefined);
      }

      if (eventTypes === undefined) {
        subs.clear();
      } else {
        for (const eventType of eventTypes) {
          subs.delete(eventType);
        }
      }

      logger.debug({ clientId, eventTypes }, 'client unsubscribed from events');
      return ok(undefined);
    },

    getClientCount(): number {
      return clients.size;
    },

    getStats(): SSEBusStats {
      let subscriptionCount = 0;
      for (const subs of subscriptions.values()) {
        subscriptionCount += subs.size;
      }

      return {
        clientCount: clients.size,
        subscriptionCount,
        eventsPublished,
        eventsByType: { ...eventsByType },
      };
    },
  };
}

/**
 * Create a KallaxEvent helper
 */
export function createEvent(
  type: EventType,
  payload: unknown,
  sourceId: string
): KallaxEvent {
  return {
    id: generateEventId(),
    type,
    payload,
    timestamp: Date.now(),
    sourceId,
  };
}

// Default singleton instance
let defaultBus: SSEBus | null = null;

export function getSSEBus(): SSEBus {
  defaultBus ??= createSSEBus();
  return defaultBus;
}

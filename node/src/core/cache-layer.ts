/**
 * KALLAX Cache Layer
 * LRU Cache with mandatory TTL - Map without TTL is PROHIBITED
 */

import { LRUCache } from 'lru-cache';
import { logger } from '../utils/logger.js';

export interface CacheConfig {
  readonly max: number;
  readonly ttlMs: number;
  readonly updateAgeOnGet?: boolean;
  readonly updateAgeOnHas?: boolean;
}

export interface CacheStats {
  readonly size: number;
  readonly hits: number;
  readonly misses: number;
  readonly hitRate: number;
}

export interface Cache<K, V extends object> {
  get: (key: K) => V | undefined;
  set: (key: K, value: V, ttlMs?: number) => void;
  has: (key: K) => boolean;
  delete: (key: K) => boolean;
  clear: () => void;
  size: () => number;
  stats: () => CacheStats;
  keys: () => IterableIterator<K>;
  values: () => IterableIterator<V>;
  entries: () => IterableIterator<[K, V]>;
}

/**
 * Create a type-safe LRU cache with mandatory TTL
 */
export function createCache<K extends object | string | number, V extends object>(
  name: string,
  config: CacheConfig
): Cache<K, V> {
  let hits = 0;
  let misses = 0;

  // LRUCache constraint requires V extends {}; generic V passed through Cache<K,V> interface
  const cache = new LRUCache<K, V>({
    max: config.max,
    ttl: config.ttlMs,
    updateAgeOnGet: config.updateAgeOnGet ?? true,
    updateAgeOnHas: config.updateAgeOnHas ?? false,
    dispose: (value, key, reason) => {
      logger.debug({ cacheName: name, key, reason }, 'cache entry disposed');
    },
  });

  logger.info({ cacheName: name, max: config.max, ttlMs: config.ttlMs }, 'cache created');

  return {
    get(key: K): V | undefined {
      const value = cache.get(key);
      if (value === undefined) {
        misses++;
        logger.debug({ cacheName: name, key, result: 'miss' }, 'cache get');
      } else {
        hits++;
        logger.debug({ cacheName: name, key, result: 'hit' }, 'cache get');
      }
      return value;
    },

    set(key: K, value: V, ttlMs?: number): void {
      if (ttlMs !== undefined) {
        cache.set(key, value, { ttl: ttlMs });
      } else {
        cache.set(key, value);
      }
      logger.debug({ cacheName: name, key }, 'cache set');
    },

    has(key: K): boolean {
      return cache.has(key);
    },

    delete(key: K): boolean {
      const deleted = cache.delete(key);
      if (deleted) {
        logger.debug({ cacheName: name, key }, 'cache delete');
      }
      return deleted;
    },

    clear(): void {
      cache.clear();
      hits = 0;
      misses = 0;
      logger.info({ cacheName: name }, 'cache cleared');
    },

    size(): number {
      return cache.size;
    },

    stats(): CacheStats {
      const total = hits + misses;
      return {
        size: cache.size,
        hits,
        misses,
        hitRate: total > 0 ? hits / total : 0,
      };
    },

    keys(): IterableIterator<K> {
      return cache.keys();
    },

    values(): IterableIterator<V> {
      return cache.values();
    },

    entries(): IterableIterator<[K, V]> {
      return cache.entries();
    },
  };
}

// Default cache instances for common use cases
const DEFAULT_TTL_MS = 5 * 60 * 1000; // 5 minutes
const DEFAULT_MAX = 1000;

export const ticketCache = createCache<string, unknown>('tickets', {
  max: DEFAULT_MAX,
  ttlMs: DEFAULT_TTL_MS,
});

export const taskCache = createCache<string, unknown>('tasks', {
  max: DEFAULT_MAX,
  ttlMs: DEFAULT_TTL_MS,
});

export const instanceCache = createCache<string, unknown>('instances', {
  max: 100,
  ttlMs: 60 * 1000, // 1 minute for instances
});

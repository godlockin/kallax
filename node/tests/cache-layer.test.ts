/**
 * Cache Layer tests: TTL expiry, LRU eviction, getOrInsert.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createCache } from '../src/core/cache-layer.js';

describe('CacheLayer', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('stores and retrieves values', () => {
    const cache = createCache<string, number>('test', { max: 100, ttlMs: 60000 });
    cache.set('a', 1);
    expect(cache.get('a')).toBe(1);
    expect(cache.get('missing')).toBeUndefined();
  });

  it('respects TTL — expired entries return undefined', () => {
    const cache = createCache<string, number>('test', { max: 100, ttlMs: 5000 });
    cache.set('a', 42);

    vi.advanceTimersByTime(4999);
    expect(cache.get('a')).toBe(42);

    vi.advanceTimersByTime(2);
    expect(cache.get('a')).toBeUndefined();
  });

  it('per-item TTL overrides default', () => {
    const cache = createCache<string, number>('test', { max: 100, ttlMs: 60000 });
    cache.set('short', 1, 100);
    cache.set('long', 2, 60000);

    vi.advanceTimersByTime(200);
    expect(cache.get('short')).toBeUndefined();
    expect(cache.get('long')).toBe(2);
  });

  it('evicts LRU entries when max size is exceeded', () => {
    const cache = createCache<string, number>('test', { max: 3, ttlMs: 60000 });
    cache.set('a', 1);
    cache.set('b', 2);
    cache.set('c', 3);
    cache.set('d', 4); // Evicts 'a'

    expect(cache.get('a')).toBeUndefined();
    expect(cache.get('b')).toBe(2);
    expect(cache.get('d')).toBe(4);
    expect(cache.size()).toBe(3);
  });

  it('tracks hit/miss stats', () => {
    const cache = createCache<string, number>('test', { max: 100, ttlMs: 60000 });
    cache.set('k', 100);

    cache.get('k'); // hit
    cache.get('k'); // hit
    cache.get('missing'); // miss

    const s = cache.stats();
    expect(s.hits).toBe(2);
    expect(s.misses).toBe(1);
    expect(s.hitRate).toBeCloseTo(2 / 3);
  });

  it('clear resets all entries and stats', () => {
    const cache = createCache<string, number>('test', { max: 100, ttlMs: 60000 });
    cache.set('a', 1);
    cache.get('a'); // hit
    cache.clear();

    expect(cache.size()).toBe(0);
    expect(cache.stats().hits).toBe(0);
    expect(cache.stats().misses).toBe(0);
  });

  it('delete removes a specific key', () => {
    const cache = createCache<string, number>('test', { max: 100, ttlMs: 60000 });
    cache.set('x', 10);
    expect(cache.has('x')).toBe(true);

    cache.delete('x');
    expect(cache.has('x')).toBe(false);
    expect(cache.get('x')).toBeUndefined();
  });
});

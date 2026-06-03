/**
 * DI Container tests.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createDIContainer } from '../src/core/di-container.js';
import type { DIContainer } from '../src/core/di-container.js';

describe('DIContainer', () => {
  let container: DIContainer;

  beforeEach(() => {
    container = createDIContainer();
  });

  it('resolves registered singleton', () => {
    container.register('test', () => ({ value: 42 }));
    const result = container.resolve<{ value: number }>('test');
    expect(result.isOk()).toBe(true);
    expect(result.value.value).toBe(42);
  });

  it('returns same instance for singleton', () => {
    container.register('counter', () => ({ count: 0 }));
    const r1 = container.resolve<{ count: number }>('counter');
    const r2 = container.resolve<{ count: number }>('counter');
    r1.value.count = 99;
    expect(r2.value.count).toBe(99); // Same instance
  });

  it('returns new instance for transient', () => {
    container.register('transient', () => ({ count: 0 }), 'transient');
    const r1 = container.resolve<{ count: number }>('transient');
    const r2 = container.resolve<{ count: number }>('transient');
    r1.value.count = 99;
    expect(r2.value.count).toBe(0); // Different instance
  });

  it('errors on duplicate registration', () => {
    container.register('dup', () => ({}));
    const result = container.register('dup', () => ({}));
    expect(result.isErr()).toBe(true);
  });

  it('errors on missing service', () => {
    const result = container.resolve('missing');
    expect(result.isErr()).toBe(true);
  });

  it('tracks stats', () => {
    container.register('s1', () => ({}));
    container.register('s2', () => ({}), 'transient');

    const stats = container.getStats();
    expect(stats.totalServices).toBe(2);
    expect(stats.singletons).toBe(1);
    expect(stats.transients).toBe(1);
  });

  it('child container falls back to parent', () => {
    container.register('parent-service', () => ({ parent: true }));
    const child = container.createChild('child');

    const result = child.resolve<{ parent: boolean }>('parent-service');
    expect(result.isOk()).toBe(true);
    expect(result.value.parent).toBe(true);
  });

  it('child can override parent', () => {
    container.register('shared', () => ({ from: 'parent' }));
    const child = container.createChild('child');
    child.register('shared', () => ({ from: 'child' }));

    const result = child.resolve<{ from: string }>('shared');
    expect(result.value.from).toBe('child');
  });

  it('supports dependency injection between services', () => {
    container.register('db', () => ({ connected: true }));
    container.register('repo', (c) => {
      const db = c.resolve<{ connected: boolean }>('db');
      return { db: db.value };
    });

    const result = container.resolve<{ db: { connected: boolean } }>('repo');
    expect(result.isOk()).toBe(true);
    expect(result.value.db.connected).toBe(true);
  });

  it('reset clears all services', () => {
    container.register('s1', () => ({}));
    container.reset();
    expect(container.getStats().totalServices).toBe(0);
  });
});

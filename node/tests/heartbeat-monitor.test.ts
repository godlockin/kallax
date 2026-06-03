/**
 * Heartbeat Monitor tests: start/stop lifecycle, stats, calculateAdaptiveTimeout.
 * Avoids fake-timer interaction with async intervals — focuses on
 * synchronous API and pure function tests.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ok } from 'neverthrow';
import { createHeartbeatMonitor, calculateAdaptiveTimeout } from '../src/core/heartbeat-monitor.js';
import { createFakeSQLiteManager } from './helpers/fakes.js';
import { createInstanceRegistry } from '../src/core/instance-registry.js';

describe('HeartbeatMonitor', () => {
  let registry: ReturnType<typeof createInstanceRegistry>;

  beforeEach(async () => {
    const db = createFakeSQLiteManager();
    registry = createInstanceRegistry(db);
    await registry.register('conductor', ['orchestration']);
  });

  it('starts and stops cleanly', () => {
    const hm = createHeartbeatMonitor(registry, { heartbeatIntervalMs: 10000, staleThresholdMs: 60000, checkIntervalMs: 30000 });

    expect(hm.isRunning()).toBe(false);
    hm.start();
    expect(hm.isRunning()).toBe(true);

    hm.stop();
    expect(hm.isRunning()).toBe(false);
  });

  it('initial stats have zero counters before start', () => {
    const hm = createHeartbeatMonitor(registry, { heartbeatIntervalMs: 10000, staleThresholdMs: 60000, checkIntervalMs: 30000 });

    const stats = hm.getStats();
    expect(stats.isRunning).toBe(false);
    expect(stats.heartbeatsSent).toBe(0);
    expect(stats.lastHeartbeatSent).toBeNull();
    expect(stats.lastCheckPerformed).toBeNull();
  });

  it('getStats reflects running state after start/stop', () => {
    const hm = createHeartbeatMonitor(registry, { heartbeatIntervalMs: 10000, staleThresholdMs: 60000, checkIntervalMs: 30000 });

    hm.start();
    expect(hm.getStats().isRunning).toBe(true);

    hm.stop();
    expect(hm.getStats().isRunning).toBe(false);
  });

  it('isRunning returns false before start', () => {
    const hm = createHeartbeatMonitor(registry);
    expect(hm.isRunning()).toBe(false);
  });

  it('start again does not double-schedule', () => {
    const hm = createHeartbeatMonitor(registry);
    hm.start();
    hm.start(); // should be no-op
    expect(hm.isRunning()).toBe(true);
    hm.stop();
  });

  it('stop on non-running monitor is a no-op', () => {
    const hm = createHeartbeatMonitor(registry);
    hm.stop(); // should not throw
    expect(hm.isRunning()).toBe(false);
  });

  describe('calculateAdaptiveTimeout', () => {
    it('returns default 30min when no estimate given', () => {
      expect(calculateAdaptiveTimeout(undefined)).toBe(30 * 60 * 1000);
      expect(calculateAdaptiveTimeout(0)).toBe(30 * 60 * 1000);
    });

    it('clamps to minimum 5min for short tasks', () => {
      expect(calculateAdaptiveTimeout(10)).toBe(5 * 60 * 1000);
    });

    it('caps at 30min for very long tasks', () => {
      expect(calculateAdaptiveTimeout(480)).toBe(30 * 60 * 1000);
      expect(calculateAdaptiveTimeout(5000)).toBe(30 * 60 * 1000);
    });
  });
});

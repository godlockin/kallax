/**
 * Heartbeat Monitor tests: heartbeat send, stale detection, start/stop lifecycle.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ok } from 'neverthrow';
import { createHeartbeatMonitor, calculateAdaptiveTimeout } from '../src/core/heartbeat-monitor.js';
import { createFakeSQLiteManager } from './helpers/fakes.js';
import { createInstanceRegistry } from '../src/core/instance-registry.js';

describe('HeartbeatMonitor', () => {
  let registry: ReturnType<typeof createInstanceRegistry>;

  beforeEach(async () => {
    vi.useFakeTimers();
    const db = createFakeSQLiteManager();
    registry = createInstanceRegistry(db);
    await registry.register('conductor', ['orchestration']);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('starts and stops cleanly', () => {
    const hm = createHeartbeatMonitor(registry, { heartbeatIntervalMs: 10000, staleThresholdMs: 60000, checkIntervalMs: 30000 });

    expect(hm.isRunning()).toBe(false);
    hm.start();
    expect(hm.isRunning()).toBe(true);

    hm.stop();
    expect(hm.isRunning()).toBe(false);
  });

  it('sends heartbeat on start', () => {
    const heartbeatSpy = vi.spyOn(registry, 'heartbeat').mockResolvedValue(ok(undefined));
    const hm = createHeartbeatMonitor(registry, { heartbeatIntervalMs: 10000, staleThresholdMs: 60000, checkIntervalMs: 30000 });

    hm.start();
    // Initial heartbeat sent immediately
    expect(heartbeatSpy).toHaveBeenCalled();

    hm.stop();
  });

  it('tracks heartbeat stats', () => {
    const hm = createHeartbeatMonitor(registry, { heartbeatIntervalMs: 5000, staleThresholdMs: 60000, checkIntervalMs: 30000 });
    vi.spyOn(registry, 'heartbeat').mockResolvedValue(ok(undefined));
    vi.spyOn(registry, 'markStaleInstances').mockResolvedValue(ok([]));

    hm.start();

    // Advance time to trigger heartbeat interval
    vi.advanceTimersByTime(5000);
    vi.advanceTimersByTime(5000);

    hm.stop();

    const stats = hm.getStats();
    expect(stats.heartbeatsSent).toBeGreaterThanOrEqual(1);
    expect(stats.isRunning).toBe(false);
    expect(stats.lastHeartbeatSent).not.toBeNull();
  });

  it('onStaleInstance handler fires when stale instances detected', () => {
    const staleHandler = vi.fn().mockResolvedValue(undefined);
    const hm = createHeartbeatMonitor(registry, { heartbeatIntervalMs: 5000, staleThresholdMs: 60000, checkIntervalMs: 10000 });

    vi.spyOn(registry, 'heartbeat').mockResolvedValue(ok(undefined));
    const staleResult = [{
      id: 'stale-inst', role: 'performer' as const, status: 'active' as const,
      hostname: 'h', pid: 1, startedAt: 0, lastHeartbeat: 0, currentTaskId: null, capabilities: [],
    }];
    vi.spyOn(registry, 'markStaleInstances').mockResolvedValue(ok(staleResult));

    hm.onStaleInstance(staleHandler);
    hm.start();

    vi.advanceTimersByTime(10000); // trigger stale check
    hm.stop();

    expect(staleHandler).toHaveBeenCalledWith(staleResult);
  });

  it('calculateAdaptiveTimeout returns correct values', () => {
    // No estimate -> default 30 min
    expect(calculateAdaptiveTimeout(undefined)).toBe(30 * 60 * 1000);
    expect(calculateAdaptiveTimeout(0)).toBe(30 * 60 * 1000);

    // For a 10-minute task: min(10/10 * 60s, 30min) = 60s, but clamped to 5min min
    expect(calculateAdaptiveTimeout(10)).toBe(5 * 60 * 1000);

    // Large task (8h): min(480/10 * 60s, 30min) = 30min
    expect(calculateAdaptiveTimeout(480)).toBe(30 * 60 * 1000);
  });
});

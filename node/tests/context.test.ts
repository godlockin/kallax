/**
 * Context management tests — estimator, compressor, tracker, alert.
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { createContextEstimator } from '../src/core/context/estimator.js';
import { createContextCompressor } from '../src/core/context/compressor.js';
import { createContextTracker } from '../src/core/context/tracker.js';
import { createContextAlertManager } from '../src/core/context/alert.js';
import type { ContextEstimator } from '../src/core/context/estimator.js';
import type { ContextCompressor } from '../src/core/context/compressor.js';
import type { ContextTracker } from '../src/core/context/tracker.js';
import type { ContextAlertManager } from '../src/core/context/alert.js';

describe('ContextEstimator', () => {
  let estimator: ContextEstimator;

  beforeEach(() => { estimator = createContextEstimator(); });

  it('estimates text tokens (4 chars/token)', () => {
    const tokens = estimator.estimateText('Hello world, this is a test.');
    expect(tokens).toBeGreaterThan(0);
  });

  it('estimates code tokens (3.5 chars/token)', () => {
    const tokens = estimator.estimateCode('const x: number = 42;');
    expect(tokens).toBeGreaterThan(0);
  });

  it('estimates JSON tokens (3 chars/token)', () => {
    const tokens = estimator.estimateJson('{"key":"value","count":42}');
    expect(tokens).toBeGreaterThan(0);
  });

  it('classifies files by extension', () => {
    const tsFile = estimator.estimateFile('const x = 1;', 'test.ts');
    expect(tsFile.type).toBe('code');

    const jsonFile = estimator.estimateFile('{}', 'config.json');
    expect(jsonFile.type).toBe('json');

    const mdFile = estimator.estimateFile('# Title', 'readme.md');
    expect(mdFile.type).toBe('text');
  });

  it('computes total estimate across files', () => {
    const files = [
      { content: 'line 1\nline 2\n', path: 'a.ts' },
      { content: '{"a":1}', path: 'b.json' },
    ];
    const estimate = estimator.estimateTotal(files);
    expect(estimate.totalTokens).toBeGreaterThan(0);
    expect(estimate.codeTokens).toBeGreaterThan(0);
    expect(estimate.jsonTokens).toBeGreaterThan(0);
  });
});

describe('ContextCompressor', () => {
  let compressor: ContextCompressor;

  beforeEach(() => { compressor = createContextCompressor(); });

  it('detects when compression is needed', () => {
    expect(compressor.shouldCompress(110_000, 128_000)).toBe(true);
    expect(compressor.shouldCompress(50_000, 128_000)).toBe(false);
  });

  it('prioritize strategy keeps high-priority items', () => {
    const items = [
      { estimatedTokens: 100, priority: 0, id: 'low1' },
      { estimatedTokens: 100, priority: 3, id: 'high' },
      { estimatedTokens: 100, priority: 0, id: 'low2' },
      { estimatedTokens: 100, priority: 2, id: 'mid' },
    ];
    const result = compressor.compress(items, {
      maxTokens: 1000,
      thresholdPercent: 0,
      targetPercent: 25, // target = 250 tokens, fits ~2 items
      strategy: 'prioritize',
      keepRecent: 0,
    });
    expect(result.removedItems).toBeGreaterThan(0);
    const ids = result.items.map((i: { id: string }) => i.id);
    expect(ids).toContain('high'); // high priority preserved
  });

  it('truncate strategy keeps head items', () => {
    const items = Array.from({ length: 20 }, (_, i) => ({
      estimatedTokens: 1000,
      id: `item_${i}`,
    }));
    const result = compressor.compress(items, {
      maxTokens: 5000, // 20*1000=20000, target=2500 → keep ~2-3 items
      thresholdPercent: 0,
      targetPercent: 25,
      strategy: 'truncate',
    });
    expect(result.removedItems).toBeGreaterThan(0);
    expect(result.items.some((i: { id: string }) => i.id === 'item_0')).toBe(true);
  });
});

describe('ContextTracker', () => {
  let tracker: ContextTracker;

  beforeEach(() => { tracker = createContextTracker(); });

  it('registers and unregisters performers', () => {
    tracker.registerPerformer('perf-1');
    const usage = tracker.getUsage('perf-1');
    expect(usage).toBeDefined();
    expect(usage?.currentTokens).toBe(0);

    tracker.unregisterPerformer('perf-1');
    expect(tracker.getUsage('perf-1')).toBeUndefined();
  });

  it('tracks token updates', () => {
    tracker.registerPerformer('perf-1');
    const action = tracker.updateTokens('perf-1', 110_000); // 86% of 128k → triggers compression
    expect(action.type).toBe('required');
    expect(action.current).toBe(110_000);
  });

  it('adds tokens by content type', () => {
    tracker.registerPerformer('perf-1');
    const total = tracker.addTokens('perf-1', 'const x: number = 42;\nfunction foo(): void {}', 'code');
    expect(total).toBeGreaterThan(0);
  });

  it('tracks stats across performers', () => {
    tracker.registerPerformer('p1', 100_000);
    tracker.registerPerformer('p2', 100_000);
    tracker.updateTokens('p1', 90_000);
    tracker.updateTokens('p2', 20_000);

    const stats = tracker.getStats();
    expect(stats.trackedPerformers).toBe(2);
    expect(stats.performersNearLimit).toBeGreaterThanOrEqual(1);
  });
});

describe('ContextAlertManager', () => {
  let alertMgr: ContextAlertManager;
  let tracker: ContextTracker;

  beforeEach(() => {
    tracker = createContextTracker();
    alertMgr = createContextAlertManager(tracker); // Inject tracker
    alertMgr.configure({ cooldownMs: 0 }); // Disable cooldown for tests
  });

  it('generates alert when near limit', () => {
    tracker.registerPerformer('perf-1', 100_000);
    tracker.updateTokens('perf-1', 75_000); // 75%

    const alert = alertMgr.check('perf-1');
    expect(alert).not.toBeNull();
    expect(alert?.level).toBe('warning');
    expect(alert?.usagePercent).toBeGreaterThanOrEqual(70);
  });

  it('generates critical alert at high usage', () => {
    tracker.registerPerformer('perf-1', 100_000);
    tracker.updateTokens('perf-1', 90_000); // 90%

    const alert = alertMgr.check('perf-1');
    expect(alert).not.toBeNull();
    expect(alert!.level).toBe('critical');
  });

  it('respects cooldown when configured', () => {
    alertMgr.configure({ cooldownMs: 60_000 });
    tracker.registerPerformer('perf-1', 100_000);
    tracker.updateTokens('perf-1', 80_000);

    const first = alertMgr.check('perf-1');
    expect(first).not.toBeNull();

    // Immediate second check suppressed by 60s cooldown
    const second = alertMgr.check('perf-1');
    expect(second).toBeNull();
  });

  it('acknowledges alerts', () => {
    tracker.registerPerformer('perf-1', 100_000);
    tracker.updateTokens('perf-1', 80_000);

    const alert = alertMgr.check('perf-1');
    expect(alert).not.toBeNull();
    alertMgr.acknowledge(alert!.id);

    const active = alertMgr.getActiveAlerts();
    expect(active.find((a) => a.id === alert!.id)).toBeUndefined();
  });
});

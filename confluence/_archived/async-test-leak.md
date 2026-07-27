---
title: Async Test Resource Leak
category: pitfall
severity: high
date: 2026-06-03
status: active
---

## Context

Tests that create async resources (timers, connections, file handles) without proper cleanup cause "open handle" warnings and can affect subsequent tests.

## Problem

```typescript
// ❌ Leaking test
test('processes messages', async () => {
  const redis = new Redis();        // Never closed
  const timer = setInterval(() => {}, 1000); // Never cleared
  // ... test logic ...
}); // Redis still connected, timer still running
```

Symptoms:
- Jest warns "A worker process has failed to exit gracefully"
- Port conflicts in later tests
- Memory growth over test suite run

## Solution

```typescript
// ✅ Clean test with cleanup
test('processes messages', async () => {
  const redis = new Redis();
  const timer = setInterval(() => {}, 1000);

  try {
    // ... test logic ...
  } finally {
    clearInterval(timer);
    await redis.quit();
  }
});
```

Or use beforeEach/afterEach:
```typescript
let redis: Redis;
beforeEach(() => { redis = new Redis(); });
afterEach(async () => { await redis.quit(); });
```

## Detection

Run Jest with `--detectOpenHandles` flag.

## Related
- [[coverage-driven-development]] — Tests that inflate coverage without real value

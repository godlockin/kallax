# @kallax/node

> KALLAX Node.js Enhancement Layer — Knowledge-Augmented Leveraged Learning Agent eXecutor (跟 v2.4.1 + 跟 CLAUDE.md v2.0 联合)

## Overview

Node.js runtime for the KALLAX Conductor-Performer multi-agent system. Provides
typed event sourcing, in-process pub/sub, SQLite/Redis message queues, and the
ioredis-backed cross-process pub/sub bus (EPIC-060-C).

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│ L2: Node.js  (this package)                              │
│                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌─────────────┐  │
│  │  event-bus   │    │ message-     │    │ redis-      │  │
│  │  (in-process │    │ queue        │    │ pubsub      │  │
│  │   typed)     │    │ (sqlite/     │    │ (ioredis    │  │
│  │              │    │  redis/      │    │  cross-     │  │
│  │  DLQ +       │    │  memory)     │    │  process)   │  │
│  │  interceptors│    │              │    │             │  │
│  └──────────────┘    └──────────────┘    └─────────────┘  │
└──────────────────────────────────────────────────────────┘
         ↓                    ↓                    ↓
    single proc         single proc           multi proc
```

## Pub/Sub Bus (ioredis 启用, EPIC-060-C)

`src/core/redis-pubsub.ts` provides a 1-interface + 2-implementation cross-process
pub/sub bus (跟 Rule 5 DRY 联合, 跟 eket 4 级降级 模式 联合):

| Implementation       | When to use                       | Notes                          |
|----------------------|-----------------------------------|--------------------------------|
| `RedisPubSubBus`     | Production (multi-process)        | L3: ioredis, channel prefixed  |
| `InMemoryPubSubBus`  | Tests, single-process, degraded   | L2: pure JS, no ioredis        |

Factory: `createPubSubBus({ mode, redis? })`.

### Channels

All channel names are auto-prefixed with `kallax:pubsub:` (constant
`KALLAX_PUBSUB_CHANNEL_PREFIX`) to avoid collisions in shared Redis instances.
This is the same convention used by `src/core/message-queue/redis.ts`.

### Example

```typescript
import { createPubSubBus } from './core/redis-pubsub.js';

// L3 (production)
const bus = createPubSubBus({
  mode: 'redis',
  redis: { host: '127.0.0.1', port: 6379 },
});

await bus.subscribe('task.completed', (data) => {
  console.log('task done:', data);
});

await bus.publish('task.completed', { taskId: 'TASK-001', result: 'ok' });

// L2 (tests / single-process)
const memoryBus = createPubSubBus({ mode: 'memory' });
```

### Integration Test

```
bash tests/integration/redis-pubsub-test.sh
```

Target: **2/2 PASS** (TC1 raw ioredis + TC2 module cross-process).

## Scripts

```bash
npm run build        # tsc → dist/
npm run typecheck    # tsc --noEmit
npm test             # vitest (unit tests)
npm run lint         # eslint src/
```

## Dependencies

- `ioredis` (required, v5.4+) — cross-process pub/sub (EPIC-060-C 启用)
- `better-sqlite3` — single-process message queue + WAL mode
- `neverthrow` — `Result<T, E>` error type (no `any`, no `throw`)
- `pino` — structured JSON logging (no `console.log`)
- `zod` — runtime config validation
- `commander`, `express`, `helmet`, `cors` — CLI + HTTP API
- `lru-cache` — TTL caches (no TTL-less Maps)

## 9 Hard Rules (per AGENTS.md v1.0.0)

1. Never merge to main (Conductor only)
2. Never self-review PRs
3. Never skip tests (real exec, no mocks)
4. No magic numbers (all named constants)
5. No `console.log` (use `logger` from `utils/logger.ts`)
6. No ignored lint errors
7. No commented-out code
8. No copy-paste (extract to shared functions / interfaces)
9. No cross-cutting changes (1 PR = 1 concern)

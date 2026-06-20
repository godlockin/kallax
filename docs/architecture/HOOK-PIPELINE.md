# Hook Pipeline

> Design document for the KALLAX hook lifecycle and pipeline processing system.

---

## Overview

The Hook Pipeline manages pre/post hooks for every KALLAX operation. It supports sequential and parallel execution, conditional skipping, timeout enforcement, and result aggregation across the hook chain.

---

## Architecture

```
  Operation (e.g., task:claim)
       │
       ▼
  ┌─────────────────────────────────────────────┐
  │            Hook Pipeline                     │
  │                                              │
  │   pre_hooks ──▶ main_operation ──▶ post_hooks│
  │       │                              │       │
  │       ▼                              ▼       │
  │  ┌──────────┐                  ┌──────────┐ │
  │  │ Hook 1   │                  │ Hook A   │ │
  │  │ Hook 2   │  sequential or   │ Hook B   │ │
  │  │ Hook 3   │  parallel        │ Hook C   │ │
  │  └──────────┘                  └──────────┘ │
  │                                              │
  │  ┌──────────────────────────────────────┐    │
  │  │  ErrorHandler: skip/abort/retry      │    │
  │  └──────────────────────────────────────┘    │
  └─────────────────────────────────────────────┘
```

---

## Hook Definition

```typescript
interface Hook {
  name: string;
  type: 'pre' | 'post';
  run: (ctx: HookContext) => Promise<HookResult>;
  condition?: (ctx: HookContext) => boolean;  // skip if false
  timeout?: number;                            // ms, default 30000
  mode?: 'sequential' | 'parallel';            // default sequential
  onError?: 'abort' | 'skip' | 'retry';        // default abort
}
```

### Hook Context

```typescript
interface HookContext {
  operation: string;       // e.g. "task:claim"
  args: Record<string, unknown>;
  result: unknown;         // populated for post-hooks
  state: Record<string, unknown>;  // shared across hooks
}
```

---

## Execution Flow

```
1. Resolve hooks for operation (from config + built-in)
2. Evaluate conditions — skip hooks where condition() is false
3. Execute pre-hooks:
   - Sequential: one by one, abort on failure
   - Parallel: all at once, collect errors
4. If all pre-hooks pass → run main operation
5. Execute post-hooks (same pattern)
6. Aggregate results — hook chain result = { pre: [...], main, post: [...] }
```

### Timeout Behavior

Each hook runs with a configurable timeout. Hooks exceeding timeout are terminated and treated as failure.

### Error Strategy

| onError | pre-hook fail | post-hook fail |
|---------|---------------|----------------|
| abort   | Block operation | Log error |
| skip    | Skip hook only | Skip hook only |
| retry   | Retry up to 3x | Retry up to 3x |

---

## Built-in Hooks

| Hook | Type | Mode | Description |
|------|------|------|-------------|
| `validate-config` | pre | sequential | Validate config before critical ops |
| `check-disk` | pre | parallel | Check disk space before DB writes |
| `notify-slack` | post | parallel | Send notification on completion |
| `log-audit` | post | sequential | Write audit log entry |
| `cleanup-worktree` | post | sequential | Remove stale worktrees |

---

## Configuration

```yaml
hooks:
  pre:
    - name: validate-config
      timeout: 5000
      on_error: abort
    - name: check-disk
      mode: parallel
      timeout: 3000
      on_error: skip
  post:
    - name: log-audit
      timeout: 5000
    - name: notify-slack
      mode: parallel
      timeout: 10000
      on_error: skip
```

---

## Related Files

- `node/src/core/hooks/` — Hook pipeline implementation
- `node/src/core/hooks/pipeline.ts` — Pipeline executor
- `node/src/core/hooks/registry.ts` — Hook registration
- `node/src/defaults/hooks.yml` — Default hook configuration
- `docs/reference/config-reference.md` — Full config reference

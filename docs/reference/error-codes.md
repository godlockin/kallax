# Error Codes

> Complete reference for KallaxError codes from both the Rust core and Node.js layer.

---

## Rust Core Errors (`kallax-core`)

The Rust core defines a single `KallaxError` enum with structured variants. Each variant carries context for debugging without requiring stack traces.

### Database

| Variant | Fields | Trigger |
|---------|--------|---------|
| `Database` | `operation`, `message` | SQLite query failures, connection errors |

### State Machine

| Variant | Fields | Trigger |
|---------|--------|---------|
| `InvalidState` | `entity_type`, `entity_id`, `expected`, `actual` | Invalid status transition (e.g., completing an unstarted ticket) |
| `NotFound` | `entity_type`, `entity_id` | Entity not found in store |
| `AlreadyExists` | `entity_type`, `entity_id` | Duplicate registration (e.g., performer already registered) |

### Isolation/Scope

| Variant | Fields | Trigger |
|---------|--------|---------|
| `IsolationViolation` | `performer_id`, `path`, `scope` | Performer accessed file outside its assigned scope |
| `ScopeOverlap` | `performer_a`, `performer_b`, `path` | Two performers claim overlapping file paths |

### Parsing/Validation

| Variant | Fields | Trigger |
|---------|--------|---------|
| `Parse` | `context`, `message` | YAML/JSON/config parse failures |
| `Validation` | `field`, `message` | Input validation (e.g., invalid priority string) |

### Resource

| Variant | Fields | Trigger |
|---------|--------|---------|
| `Timeout` | `operation`, `duration_ms` | Operation exceeded deadline (e.g., tree-sitter parse timeout) |
| `ResourceExhausted` | `resource`, `limit`, `requested` | Pool capacity exceeded, disk full |

### Execution

| Variant | Fields | Trigger |
|---------|--------|---------|
| `TaskExecution` | `task_id`, `reason` | Task runtime failure |
| `TreeSitterTimeout` | `path`, `size_bytes`, `timeout_ms` | Code parsing timeout on large files |

### IO

| Variant | Fields | Trigger |
|---------|--------|---------|
| `Io` | `path`, `message` | Filesystem read/write errors |

### Configuration

| Variant | Fields | Trigger |
|---------|--------|---------|
| `Config` | `key`, `message` | Missing or invalid configuration |

### Communication

| Variant | Fields | Trigger |
|---------|--------|---------|
| `ChannelClosed` | `channel_name` | Event bus or channel closed unexpectedly |
| `MessageDelivery` | `recipient`, `reason` | Message to agent/performer failed |

### Serialization

| Variant | Fields | Trigger |
|---------|--------|---------|
| `Serialization` | `context`, `message` | JSON/msgpack serialization or deserialization failure |

### Internal

| Variant | Fields | Trigger |
|---------|--------|---------|
| `Internal` | `message` | Unexpected invariant violation (bug — please report) |

---

## Node.js Errors (`@kallax/node`)

The Node layer defines error codes as string constants on `KallaxErrorCode`.

### System Errors

| Code | Description |
|------|-------------|
| `INTERNAL_ERROR` | Unexpected internal error |
| `CONFIG_INVALID` | Configuration validation failure |
| `DB_ERROR` | Database query/connection failure |
| `REDIS_ERROR` | Redis connection or operation failure |
| `FILE_NOT_FOUND` | Referenced file does not exist |
| `PERMISSION_DENIED` | Insufficient permissions |

### Task Errors

| Code | Description |
|------|-------------|
| `TASK_NOT_FOUND` | Task ID not in database |
| `TASK_ALREADY_CLAIMED` | Task is already assigned to another performer |
| `TASK_INVALID_STATE` | Invalid status transition for task |
| `TASK_ISOLATION_CONFLICT` | Task scope conflicts with active task |

### Ticket Errors

| Code | Description |
|------|-------------|
| `TICKET_NOT_FOUND` | Ticket ID not in database |
| `TICKET_INVALID` | Ticket data failed validation |

### Instance Errors

| Code | Description |
|------|-------------|
| `INSTANCE_NOT_FOUND` | Conductor/performer instance not registered |
| `INSTANCE_ALREADY_EXISTS` | Duplicate instance registration |
| `INSTANCE_TIMEOUT` | Instance heartbeat timeout |

### Worktree Errors

| Code | Description |
|------|-------------|
| `WORKTREE_CREATE_FAILED` | Git worktree creation failure |
| `WORKTREE_NOT_FOUND` | Referenced worktree does not exist |
| `WORKTREE_CLEANUP_FAILED` | Worktree removal or cleanup failure |

### Argument Errors

| Code | Description |
|------|-------------|
| `INVALID_ARGUMENT` | Invalid CLI argument or parameter |

### Saga Errors

| Code | Description |
|------|-------------|
| `SAGA_STEP_FAILED` | A step in the Saga execution failed |
| `SAGA_COMPENSATE_FAILED` | Compensation (rollback) step failed |

### Verification Errors

| Code | Description |
|------|-------------|
| `VERIFICATION_FAILED` | Output verification did not pass |
| `OUTPUT_NOT_FOUND` | No output recorded for the task |

---

## Error Handling Pattern

### TypeScript (Node.js)

```typescript
import { KallaxError, KallaxErrorCode } from '@kallax/node';

try {
  const result = riskyOperation();
  if (result.isErr()) {
    logger.kallaxError(result.error);
    process.exit(1);
  }
} catch (error: unknown) {
  const kallaxError = error instanceof KallaxError
    ? error
    : KallaxError.fromUnknown(error);
  logger.kallaxError(kallaxError);
}
```

### Rust

```rust
use kallax_core::{KallaxError, Result};

fn process() -> Result<()> {
    let ticket = engine.get_ticket("TICKET-001")
        .map_err(|e| KallaxError::not_found("ticket", "TICKET-001"))?;
    Ok(())
}
```

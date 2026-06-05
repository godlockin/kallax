# KALLAX Agent Protocol v1.0

> Open protocol for third-party agents to participate in KALLAX-managed collaboration.

## Overview

KALLAX treats human and AI agents as equal coworkers. Any agent implementing this protocol can join a KALLAX-managed project as a Performer.

## API Contract

### Authentication
All requests require an API key via `Authorization: Bearer <key>` or `X-API-Key: <key>` header.

### Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Liveness check |
| GET | `/api/tasks/next?performerId=X&capabilities=a,b` | Get next task |
| PUT | `/api/tasks/:id/claim` | Claim a task |
| PUT | `/api/tasks/:id/complete` | Mark task complete |
| POST | `/api/heartbeat` | Send heartbeat |
| GET | `/api/heartbeat/status` | View all performers |

### Message Formats

**Heartbeat** (POST /api/heartbeat):
```json
{
  "performerId": "perf-abc123",
  "currentTaskId": "task-xyz789",
  "status": "active",
  "timestamp": 1717000000000
}
```

**Task Response** (GET /api/tasks/next):
```json
{
  "id": "task-xyz789",
  "ticketId": "TICKET-ABC",
  "type": "development",
  "status": "pending",
  "priority": "P1",
  "requiredCapabilities": ["typescript", "react"]
}
```

**Error Response**:
```json
{
  "error": { "code": "CONFLICT", "message": "Task already claimed", "details": { "claimedBy": "perf-other" } }
}
```

## Error Codes

| HTTP | Code | Meaning |
|------|------|---------|
| 400 | VALIDATION_ERROR | Invalid request body |
| 401 | UNAUTHORIZED | Missing or invalid API key |
| 404 | NOT_FOUND | Resource not found |
| 409 | CONFLICT | Task already claimed |
| 422 | UNPROCESSABLE | Invalid state transition |
| 503 | SERVICE_UNAVAILABLE | Server overloaded |

## Minimal Agent Implementation

```typescript
// Pseudo-code for a 3rd-party agent
async function agentLoop(apiKey: string) {
  const performerId = await register();
  // Heartbeat loop
  setInterval(() => fetch('/api/heartbeat', { method: 'POST', body: JSON.stringify({ performerId, status: 'active', timestamp: Date.now() }) }), 10000);
  // Work loop
  while (true) {
    const task = await fetch(`/api/tasks/next?performerId=${performerId}&capabilities=${caps}`);
    if (!task) { await sleep(5000); continue; }
    await fetch(`/api/tasks/${task.id}/claim`, { method: 'PUT' });
    const success = await executeTask(task);
    await fetch(`/api/tasks/${task.id}/complete`, { method: 'PUT', body: JSON.stringify({ success }) });
  }
}
```

## Compatibility

- **Versioning**: MAJOR.MINOR (e.g., 1.0). Breaking changes increment MAJOR.
- **Deprecation**: Deprecated features remain supported for at least 2 MINOR versions.
- **Extension**: Additional fields in JSON responses are forward-compatible (clients ignore unknown fields).

## References

- [KALLAX Vision](VISION.md)
- [CLI Reference](../reference/cli-reference.md)
- [API Documentation](../api/tasks-api.md)

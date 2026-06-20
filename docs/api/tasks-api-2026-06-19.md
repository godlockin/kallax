# Tasks API

> Task CRUD and lifecycle management endpoints.

Base path: `/api/tasks`

All endpoints produce JSON with the following envelope:

```json
{ "success": true, "data": { ... }, "timestamp": 1717000000000 }
```

On error:

```json
{ "success": false, "error": { "code": "TASK_NOT_FOUND", "message": "..." }, "timestamp": ... }
```

---

## List Tasks

```
GET /api/tasks?status=running&performerId=inst_xxx&ticketId=TICKET-xxx&page=1&limit=20
```

Returns paginated tasks. All query parameters are optional.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `status` | string | Filter by status: `pending`, `claimed`, `running`, `completed`, `cancelled`, `failed` |
| `performerId` | string | Filter by assigned performer |
| `ticketId` | string | Filter by parent ticket |
| `page` | number | Page number (1-based, default: 1) |
| `limit` | number | Items per page (max: 100, default: 20) |

**Response:**

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "task_abc123",
        "ticketId": "TICKET-XXX",
        "type": "development",
        "status": "running",
        "performerId": "inst_xxx",
        "progress": 65,
        "createdAt": 1717000000000,
        "updatedAt": 1717000500000
      }
    ],
    "total": 1,
    "page": 1,
    "limit": 20
  }
}
```

---

## Get Task

```
GET /api/tasks/:id
```

Returns a single task enriched with its parent ticket.

**Errors:** `404 TASK_NOT_FOUND` if task does not exist.

---

## Create Task

```
POST /api/tasks
```

Creates a task from an existing ticket.

**Request body:**

```json
{
  "ticketId": "TICKET-001",
  "type": "development"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ticketId` | string | Yes | Parent ticket ID |
| `type` | string | No | Task type: `development`, `review`, `testing` (default: `development`) |

**Errors:** `400 VALIDATION_ERROR` if ticketId missing. `404 TICKET_NOT_FOUND` if ticket does not exist.

---

## Claim Task

```
PUT /api/tasks/:id/claim
```

Assigns a task to a performer. Creates an isolated git worktree for the task.

**Request body:**

```json
{
  "performerId": "inst_xxx"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `performerId` | string | Yes | Registered performer instance ID |

**Behavior:**
- Validates task is in `pending` state
- Creates git worktree for isolation
- Updates task status to `claimed`
- Broadcasts `TASK_CLAIMED` event via SSE

**Errors:** `409 TASK_INVALID_STATE` if task is not pending.

---

## Complete Task

```
PUT /api/tasks/:id/complete?level=4
```

Completes a task after output verification. The task must be in `claimed` or `running` state.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `level` | number | Fact-Forcing verification level (1-4, default: 4) |

**Level 1:** File existence check.
**Level 2:** Substantive content check (no stubs).
**Level 3:** Wiring check (correct imports/exports).
**Level 4:** Data flow check (integration testing).

**Behavior:**
- Runs Fact-Forcing verification at the specified level
- If verification fails, returns `400 VERIFICATION_FAILED` with evidence
- On success, updates task status to `completed`

---

## Update Progress

```
PUT /api/tasks/:id/progress
```

Updates task progress percentage.

**Request body:**

```json
{
  "progress": 75,
  "message": "Tests passing, starting lint"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `progress` | number | Yes | 0-100 |
| `message` | string | No | Optional progress note |

**Behavior:** If progress reaches 100, status auto-updates to `completed`.

---

## Cancel Task

```
DELETE /api/tasks/:id
```

Cancels a task by ID. Releases isolation scope and cleans up worktree.

**Errors:** `409 TASK_INVALID_STATE` if task is already `completed` or `cancelled`.

---

## Error Codes

| Code | Meaning |
|------|---------|
| `TASK_NOT_FOUND` | Task ID does not exist |
| `TICKET_NOT_FOUND` | Referenced ticket does not exist |
| `TASK_INVALID_STATE` | Operation not valid for current status |
| `VERIFICATION_FAILED` | Output verification did not pass |
| `VALIDATION_ERROR` | Missing or invalid request body |
| `WORKTREE_NOT_FOUND` | No worktree associated with task |

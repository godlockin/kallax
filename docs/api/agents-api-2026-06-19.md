# Agents API

> Performer and Conductor instance management endpoints.

Base path: `/api/agents`

All endpoints use the standard envelope:

```json
{ "success": true, "data": { ... }, "timestamp": 1717000000000 }
```

---

## List Agents

```
GET /api/agents?role=performer
```

Returns all registered agent instances.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `role` | string | Filter by role: `conductor`, `performer` |

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "inst_abc123",
      "role": "performer",
      "status": "active",
      "hostname": "host-1",
      "pid": 12345,
      "startedAt": 1717000000000,
      "lastHeartbeat": 1717000500000,
      "currentTaskId": null,
      "capabilities": ["react", "typescript", "rust"]
    }
  ]
}
```

Instance status values: `initializing`, `active`, `idle`, `busy`, `error`, `shutdown`.

---

## Register Agent

```
POST /api/agents/register
```

Register a new Conductor or Performer instance.

**Request body:**

```json
{
  "name": "performer-1",
  "capabilities": ["react", "typescript"]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | No | Human-readable instance name |
| `capabilities` | string[] | No | List of agent capabilities |

**Role header:** Set `x-kallax-role: conductor` to register as Conductor (default: `performer`).

**Behavior:**
- Generates unique instance ID (`inst_<timestamp>_<random>`)
- Captures hostname, PID, startup timestamp
- Sets initial status to `initializing`
- Broadcasts `INSTANCE_REGISTERED` event via SSE
- Caches instance metadata locally (30s TTL) for fast status lookups

**Response (201):**

```json
{
  "success": true,
  "data": {
    "id": "inst_abc123",
    "role": "performer",
    "status": "initializing"
  }
}
```

---

## Get Agent

```
GET /api/agents/:id
```

Returns a single agent instance by ID.

**Errors:** `404 INSTANCE_NOT_FOUND` if instance does not exist.

---

## Agent Heartbeat

```
PUT /api/agents/:id/heartbeat
```

Periodic keep-alive from an agent instance.

**Request body:**

```json
{
  "status": "busy",
  "currentTaskId": "task_xxx"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | string | No | Updated status (`active`, `idle`, `busy`, `error`) |
| `currentTaskId` | string | No | Task currently being worked on |

**Behavior:**
- Updates `lastHeartbeat` timestamp in database and cache
- Status thresholds: 30s no heartbeat = idle, 5min = stale (marked `error`)
- Broadcasts `INSTANCE_HEARTBEAT` event via SSE

---

## Get Agent Tasks

```
GET /api/agents/:id/tasks
```

Lists all tasks assigned to a specific performer.

---

## Error Codes

| Code | Meaning |
|------|---------|
| `INSTANCE_NOT_FOUND` | Instance ID does not exist |
| `VALIDATION_ERROR` | Missing or invalid request body |

---

## CLI Equivalents

```bash
# Same operations via CLI
kallax performer register            # POST /api/agents/register
kallax performer status              # GET /api/agents/:id
kallax performer poll                # GET /api/agents/:id/tasks (loose equivalent)
kallax conductor heartbeat           # PUT /api/agents/:id/heartbeat
kallax team:status                   # GET /api/agents (team view)
kallax system:doctor                 # GET /api/system/doctor
```

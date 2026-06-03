# System API

> Diagnostics, configuration, and system management endpoints.

Base path: `/api/system`

---

## System Doctor

```
GET /api/system/doctor
```

Runs comprehensive diagnostics across all KALLAX components. Returns a snapshot of system health, resource usage, and component statuses.

**Response:**

```json
{
  "success": true,
  "data": {
    "timestamp": 1717000000000,
    "uptime": 1234.56,
    "memory": {
      "rss": 123456789,
      "heapTotal": 98765432,
      "heapUsed": 65432123,
      "external": 1234567
    },
    "node": "v22.0.0",
    "platform": "darwin",
    "arch": "arm64",
    "cpus": 12,
    "loadavg": [2.5, 1.8, 1.2],
    "hostname": "my-machine",
    "database": {
      "connected": true,
      "stats": {
        "ticketCount": 42,
        "taskCount": 87,
        "instanceCount": 3,
        "messageCount": 5
      }
    },
    "instances": {
      "active": 2,
      "list": [
        { "id": "inst_xxx", "role": "conductor", "status": "active", "uptime": 3600000 }
      ]
    },
    "sse": { "connections": 1, "eventsPublished": 150 },
    "circuitBreakers": [
      { "name": "redis", "state": "closed", "failureCount": 0 }
    ]
  }
}
```

**CLI equivalent:** `kallax system:doctor`

The command exits with code 0 if all checks pass (healthy), 1 otherwise.

---

## Get Config

```
GET /api/system/config
```

Returns the current server configuration. Sensitive fields (apiKey) are masked — only the `apiKeyConfigured` boolean is exposed.

**Response:**

```json
{
  "success": true,
  "data": {
    "port": 9877,
    "host": "127.0.0.1",
    "corsOrigins": ["http://localhost:3000"],
    "rateLimit": 100,
    "bodyLimit": "1mb",
    "apiKeyConfigured": true
  }
}
```

---

## Circuit Breakers

```
GET /api/system/circuit-breakers
```

Returns the state of all circuit breakers: `closed` (normal), `open` (tripped), or `half-open` (testing recovery).

**Response:**

```json
{
  "success": true,
  "data": [
    { "name": "redis", "state": "closed", "failureCount": 0, "lastFailure": null },
    { "name": "github-api", "state": "open", "failureCount": 5, "lastFailure": 1717000000000 }
  ]
}
```

---

## Trigger Garbage Collection

```
POST /api/system/gc
```

Forces V8 garbage collection (requires `--expose-gc` flag at Node.js startup).

**Response:**

```json
{
  "success": true,
  "data": {
    "gcTriggered": true,
    "heapUsedBefore": 98765432,
    "heapUsedAfter": 65432123,
    "freedMb": 31.8
  }
}
```

If `--expose-gc` is not configured:

```json
{ "success": true, "data": { "gcTriggered": false, "message": "GC not available. Start node with --expose-gc flag" } }
```

---

## Degradation Status (CLI only)

```bash
# View current degradation tier
kallax system:degradation

# Force a probe cycle
kallax system:degradation-probe
```

These are CLI-only commands and not exposed via REST.

**Output example:**

```
=== KALLAX Degradation Status ===

Current Tier : 2 (Node.js)
Target Tier  : 3
Crash Count  : 0

Tier Status:
  ✓ L3 Rust        healthy
  ✓ L2 Node.js     healthy
  ✓ L1 Shell       healthy
  ✓ L0 Degraded    healthy

Use "kallax system:degradation probe" to force a probe cycle.
```

---

## Error Codes

| Code | Meaning |
|------|---------|
| `INTERNAL_ERROR` | Unexpected system failure |

---

## Related

- `scripts/health_check.sh` — Bash-based health check (runs outside Node.js)
- `docker/prometheus.yml` — Prometheus scrape configuration
- `node/src/api/routes/system.ts` — System routes implementation
- `node/src/core/recovery-manager.ts` — Degradation probing logic

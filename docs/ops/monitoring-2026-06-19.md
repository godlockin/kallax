# Monitoring Guide

> Metrics, logging, alerting, and dashboards for KALLAX.

---

## Architecture

```
KALLAX Process
  ├─ stdout/stderr → structured JSON logs
  ├─ SQLite        → metrics storage (30d retention)
  ├─ SSE Bus       → real-time events to dashboard
  └─ Prometheus    → time-series metrics (via /metrics)
```

---

## Logging

KALLAX uses structured JSON logging via the `pino` library.

### Log Format

```json
{"level":30,"time":1717000000000,"pid":12345,"hostname":"my-machine","module":"task-assigner","msg":"task claimed","taskId":"task_abc123"}
```

### Log Levels

| Level | Numeric | When |
|-------|---------|------|
| `debug` | 20 | Per-step saga execution, cache hits |
| `info` | 30 | Task creation/completion, instance registration |
| `warn` | 40 | Degradation events, stale instances, circuit breaker open |
| `error` | 50 | Saga step failure, DB errors, startup validation failure |
| `fatal` | 60 | Unrecoverable: startup validation fail, process exit |

### Viewing Logs

```bash
# Tail live
tail -f logs/kallax.log | pino-pretty

# Filter by module
grep '"module":"recovery-manager"' logs/kallax.log | pino-pretty

# Filter by severity
grep '"level":50' logs/kallax.log  # errors only

# Recent errors with context
tail -1000 logs/kallax.log | grep -E '"level":50|"level":60' | tail -20
```

### Log Rotation

Configured in `config.yml`:

```yaml
logging:
  output: "./logs"
  rotation:
    max_size: "10MB"
    max_files: 10
```

When any log reaches 10MB, it is rotated. Up to 10 rotated files are kept (total ~100MB).

---

## Metrics

### Collected Metrics

| Metric | Type | Source |
|--------|------|--------|
| `task_claimed_count` | Counter | Task assigner |
| `task_completed_count` | Counter | Task assigner |
| `task_blocked_count` | Counter | Isolation checker |
| `performer_active_count` | Gauge | Instance registry |
| `pr_review_time` | Histogram | PR review hook |
| `degradation_count` | Counter | Recovery manager |

### Storage

- **Primary**: SQLite `.kallax/data/kallax.db` (metrics table, 30-day retention)
- **Prometheus**: Optional, via `/metrics` endpoint on port 9877

### Metrics via CLI

```bash
# View system health (includes key metrics)
kallax system:doctor

# View current degradation state
kallax system:degradation
```

---

## Health Checks

### Scripted Health Check

Run via `scripts/health_check.sh`:

```bash
./scripts/health_check.sh
```

Checks performed:

| Check | What It Probes | Pass/Fail Criteria |
|-------|---------------|-------------------|
| Git | Repo validity | `git rev-parse` succeeds |
| Database | SQLite file | `.kallax/data/kallax.db` exists |
| Disk | Free space | <85% = PASS, 85-95% = WARN, >95% = FAIL |
| Node.js | Runtime | `node -v` succeeds |
| Rust | Compiler (optional) | `rustc --version` succeeds |
| Worktrees | Count | <=5 = PASS, >5 = WARN |
| Config | YAML files | `.kallax/config.yml` exists |

### System Doctor (In-Process)

```bash
kallax system:doctor
```

Performs deeper checks inside the running process:

- Database connectivity (actual queries)
- Instance registry health
- SSE bus connection count
- Circuit breaker states

---

## Alerting

### Configuration

Edit `.kallax/config/monitoring.yml`:

```yaml
alerting:
  enabled: true
  channels:
    - type: file
      path: "./logs/alerts.log"
```

### Built-in Alert Rules

| Rule | Condition | Severity |
|------|-----------|----------|
| `performer_timeout` | Performer idle > 30m | warning |
| `high_memory` | Memory usage > 90% | critical |
| `degradation` | Tier degradation occurred | warning |

### Custom Alerting

To add webhook alerts, uncomment in `monitoring.yml`:

```yaml
channels:
  - type: webhook
    url: https://hooks.example.com/alert
    method: POST
```

The webhook receives JSON payloads with `rule`, `condition`, `severity`, and `timestamp`.

---

## Dashboard

Prometheus metrics are scraped at `kallax:9877/metrics` (see `docker/prometheus.yml`).

Recommended Grafana panels:

| Panel | Query | Type |
|-------|-------|------|
| Tasks by status | `kallax_task_status_count` | Bar chart |
| Active performers | `kallax_performer_active` | Gauge |
| Degradation events | `rate(kallax_degradation_count[5m])` | Time series |
| Task throughput | `rate(kallax_task_completed_count[1h])` | Time series |
| Memory usage | `process_resident_memory_bytes` | Time series |

---

## Related

- `scripts/health_check.sh` -- Health check script
- `docker/prometheus.yml` -- Prometheus scrape config
- `.kallax/config/monitoring.yml` -- Monitoring configuration
- `node/src/core/heartbeat-monitor.ts` -- Heartbeat monitoring
- `node/src/utils/memory-monitor.ts` -- Memory usage tracking

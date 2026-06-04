# Configuration Reference

> Complete reference for KALLAX configuration keys in `.kallax/config.yml`.

---

## Top-Level Structure

```yaml
version: "1.0"
mode: "development"           # development | production | demo
profile: "default"
degradation:
  enabled: true
isolation:
  enabled: true
resources:
  max_entries: 1000
error_handling:
  strategy: "fail_fast"       # fail_fast | graceful
verification:
  level: 3                    # 1=L1 only, 2=L1+L2, 3=L1+L2+L3, 4=all
logging:
  level: "info"               # debug | info | warn | error
monitoring:
  enabled: true
server:
  port: 3000
dashboard:
  enabled: true
```

---

## Server

| Key | Default | Description |
|-----|---------|-------------|
| `server.port` | `3000` | HTTP listen port |
| `server.host` | `0.0.0.0` | Bind address |
| `server.auth.mode` | `none` | `none` / `api-key` / `jwt` / `header` |
| `server.auth.api_key` | — | Static API key (mode: api-key) |
| `server.auth.jwt_secret` | — | JWT secret or RSA key path (mode: jwt) |
| `server.rate_limit.enabled` | `false` | Enable rate limiting |
| `server.rate_limit.max_requests` | `100` | Max requests per window |
| `server.rate_limit.window_ms` | `60000` | Rate limit window |

---

## Logging

| Key | Default | Description |
|-----|---------|-------------|
| `logging.level` | `info` | Log level |
| `logging.format` | `text` | `text` / `json` |
| `logging.output` | `stdout` | `stdout` / file path |
| `logging.max_size_mb` | `50` | Max log file size (file output) |
| `logging.max_files` | `5` | Max rotated log files |

---

## Resources

| Key | Default | Description |
|-----|---------|-------------|
| `resources.max_entries` | `1000` | LRU cache max entries |
| `resources.ttl_ms` | `300000` | LRU cache TTL (5 min) |
| `resources.worker_pool_size` | `4` | Max concurrent workers |

---

## Isolation

| Key | Default | Description |
|-----|---------|-------------|
| `isolation.enabled` | `true` | Enable worktree isolation |
| `isolation.max_parallel_performers` | `5` | Max concurrent performers |
| `isolation.worktree_base_dir` | `/tmp/kallax-worktrees` | Worktree location |

---

## Verification

| Key | Default | Description |
|-----|---------|-------------|
| `verification.level` | `3` | L1=exist, L2=substance, L3=wiring, L4=dataflow |
| `verification.require_test_pass` | `true` | Must pass tests before merge |
| `verification.require_lint_pass` | `true` | Must pass linting before merge |

---

## Monitoring

| Key | Default | Description |
|-----|---------|-------------|
| `monitoring.enabled` | `true` | Enable metrics collection |
| `monitoring.metrics_port` | `9090` | Prometheus metrics port |
| `monitoring.health_check_interval` | `30` | Health check interval (s) |

---

## Election

| Key | Default | Description |
|-----|---------|-------------|
| `election.lease_ttl` | `30` | Master lease TTL (s) |
| `election.lease_refresh` | `15` | Lease refresh interval (s) |
| `election.retry_interval` | `60` | Retry after all tiers fail (s) |

---

## Related Files

- `.kallax/config.yml` — Active configuration
- `.kallax/config.template.yml` — Template with defaults
- `scripts/validate-config.sh` — Config validation tool
- `docs/reference/environment-variables.md` — Env var overrides

# Environment Variables

> Complete reference of environment variables that control KALLAX behavior.

---

## Core

| Variable | Default | Description |
|----------|---------|-------------|
| `KALLAX_MODE` | `development` | Runtime mode: `development` / `production` / `demo` |
| `KALLAX_PORT` | `3000` | HTTP server port |
| `KALLAX_HOST` | `0.0.0.0` | HTTP server bind address |
| `KALLAX_HOME` | `./.kallax` | KALLAX data directory |
| `KALLAX_LOG_LEVEL` | `info` | Log level: `debug` / `info` / `warn` / `error` |
| `KALLAX_LOG_FORMAT` | `text` | Log format: `text` / `json` |

---

## Database

| Variable | Default | Description |
|----------|---------|-------------|
| `KALLAX_DB_PATH` | `{KALLAX_HOME}/data/kallax.db` | SQLite database path |
| `KALLAX_DB_WAL_ENABLED` | `true` | Enable WAL mode for SQLite |

---

## Redis

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_URL` | `redis://localhost:6379` | Redis connection string |
| `REDIS_TLS_ENABLED` | `false` | Enable TLS for Redis |
| `REDIS_PASSWORD` | — | Redis password (if required) |

---

## Authentication

| Variable | Default | Description |
|----------|---------|-------------|
| `KALLAX_API_KEY` | — | Static API key for auth mode `api-key` |
| `KALLAX_JWT_SECRET` | — | JWT secret (HMAC) or public key path (RSA) |

---

## Performance

| Variable | Default | Description |
|----------|---------|-------------|
| `KALLAX_CACHE_MAX` | `1000` | LRU cache max entries |
| `KALLAX_CACHE_TTL_MS` | `300000` | LRU cache TTL (5 min) |
| `KALLAX_WORKER_POOL` | `4` | Max concurrent workers |
| `KALLAX_MAX_PARALLEL` | `5` | Max concurrent performers |

---

## Paths

| Variable | Default | Description |
|----------|---------|-------------|
| `KALLAX_CONFIG_PATH` | `{KALLAX_HOME}/config.yml` | Config file path |
| `KALLAX_DATA_DIR` | `{KALLAX_HOME}/data` | Data storage directory |
| `KALLAX_WORKTREE_DIR` | `/tmp/kallax-worktrees` | Git worktree base directory |
| `KALLAX_LOGS_DIR` | `{KALLAX_HOME}/logs` | Log output directory |

---

## Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `KALLAX_DEGRADATION_ENABLED` | `true` | Enable degradation strategy |
| `KALLAX_ISOLATION_ENABLED` | `true` | Enable worktree isolation |
| `KALLAX_MONITORING_ENABLED` | `true` | Enable metrics collection |
| `KALLAX_DASHBOARD_ENABLED` | `true` | Enable web dashboard |

---

## Related Files

- `.env.example` — Example environment file
- `docs/reference/config-reference.md` — Config file reference
- `scripts/env-validator.sh` — Validate env configuration
- `docs/guides/deployment.md` — Deployment instructions

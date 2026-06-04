# Troubleshooting Guide

> Common issues, root causes, and resolutions for KALLAX deployments.

---

## Startup Issues

### Config validation fails

```
[FAIL] Missing required key: degradation
```

**Cause**: `config.yml` is missing a required key.
**Fix**: Run `./scripts/validate-config.sh --strict` to list all missing keys. Copy missing sections from `.kallax/config.template.yml`.

### Port already in use

```
Error: listen EADDRINUSE :::3000
```

**Cause**: Another process is on port 3000.
**Fix**: `lsof -i :3000` to find the PID, then `kill <PID>`. Or set `KALLAX_PORT` to a different value.

### Database migration fails

```
Migration V003 failed: column "role" already exists
```

**Cause**: Migration applied out of order or state corruption.
**Fix**: `kallax system doctor --repair-db` to re-run pending migrations safely.

---

## Runtime Issues

### Task stuck in "claimed" state

**Cause**: Performer crashed without releasing the task.
**Fix**: `kallax task:reset TASK-001` to force back to "open". Run `./scripts/detect-stale-worktrees.sh` to check for orphaned worktrees.

### High memory usage

**Cause**: LRU cache growing unchecked or event collector leak.
**Fix**: Check `max_entries` in config.yml (default 1000). Restart server. Run `./scripts/health_check.sh` to verify.

### Redis connection refused

```
Error: connect ECONNREFUSED 127.0.0.1:6379
```

**Cause**: Redis not running or wrong URL configured.
**Fix**: Verify `REDIS_URL` env var. Start Redis: `redis-server --daemonize yes`. The system auto-degrades to SQLite lock mode.

---

## Worktree Issues

### Worktree cleanup fails

```
fatal: '/tmp/kallax-wt-xyz' is not a valid path
```

**Cause**: Worktree already removed manually.
**Fix**: `git worktree prune` to clean stale worktrees from git metadata. Then run `./scripts/worktree-cleaner.sh`.

### Branch drift detected

```
Branch is behind main by 42 commits
```

**Fix**: `git rebase main` or `./scripts/sync-branches.sh` to catch up.

---

## Network / API Issues

### API returns 401

**Cause**: Missing or invalid API key.
**Fix**: Check `KALLAX_API_KEY` env var matches the key in `config.yml`. See `docs/guides/api-authentication.md`.

### Slack notification not sent

**Cause**: Webhook URL misconfigured or Slack unreachable.
**Fix**: Verify `hooks.post.slack.webhook_url` in config. Test with `curl -X POST -H 'Content-type: application/json' --data '{"text":"test"}' <webhook_url>`.

---

## Logs & Diagnostics

```bash
# Check application logs
tail -f logs/kallax.log

# Run health check
./scripts/health_check.sh

# Validate config
./scripts/validate-config.sh --strict

# Full system diagnostic
kallax system doctor

# Enable debug logging
export KALLAX_LOG_LEVEL=debug
```

---

## Escalation

If the issue persists after trying the steps above:

1. Collect logs: `./scripts/log-rotate.sh && tar czf debug-logs.tar.gz logs/`
2. Run diagnostic: `kallax system doctor --verbose > diagnosis.txt`
3. Open an issue with both files attached.

---

## Related Files

- `docs/ops/runbook.md` — Operations runbook
- `scripts/health_check.sh` — Health check script
- `scripts/detect-stale-worktrees.sh` — Stale worktree detection
- `docs/reference/error-codes.md` — Error code reference

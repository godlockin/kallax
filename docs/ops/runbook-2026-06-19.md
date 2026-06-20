# Operations Runbook

> Common failure scenarios and their resolution procedures.

---

## 1. Conductor Unreachable

**Symptoms:**
- Heartbeat monitor warns: `performer.poll: conductor heartbeat timeout`
- Tasks assigned but no progress updates
- `kallax system:doctor` shows conductor as stale or missing

**Diagnosis:**

```bash
# Check instance status
kallax system:doctor | grep -A 5 "instances"

# Check for stale instances (5 min threshold)
sqlite3 .kallax/data/kallax.db \
  "SELECT id, role, status, datetime(last_heartbeat/1000, 'unixepoch') as last_hb
   FROM instances WHERE last_heartbeat < $(date +%s)000 - 300000;"

# Check logs
tail -100 logs/kallax.log | grep -i conductor
```

**Resolution:**

```
1. Re-start conductor:
   kallax start --role conductor
   (new instance registered, takes over)

2. Reassign orphaned tasks:
   For each task in 'claimed' status with stale performer:
   Run `kallax task:complete TASK-NNN --skip-tests`
   Then `kallax task:create TICKET-NNN` to re-create

3. If conductor fails repeatedly (>5 crashes in 5min):
   Run `kallax system:degradation-probe`
   Check degradation state: `kallax system:degradation`
```

**Prevention:**
- Ensure conductor heartbeat interval < 30s (heartbeat monitor checks every 60s)
- At least one active conductor instance tagged in config

---

## 2. Worktree Leakage

**Symptoms:**
- `git worktree list` shows many stale entries
- Disk space warning from `scripts/health_check.sh`
- `isolation:check` reports conflicts on unused worktrees

**Diagnosis:**

```bash
# Count worktrees
git worktree list | wc -l

# Find worktrees with no matching task or stale branch
for wt in .kallax/worktrees/*/; do
  task_id=$(basename "$wt")
  task_exists=$(sqlite3 .kallax/data/kallax.db \
    "SELECT count(*) FROM tasks WHERE id='$task_id' AND status NOT IN ('completed','cancelled');")
  if [ "$task_exists" -eq 0 ]; then
    echo "Stale worktree: $task_id"
  fi
done
```

**Resolution:**

```bash
# Auto-clean (dry run first)
bash scripts/worktree-cleaner.sh --dry-run
bash scripts/worktree-cleaner.sh

# Manual removal
kallax task:resume TASK-NNN  # attempt recovery
# Or force remove:
git worktree remove .kallax/worktrees/TASK-NNN
git branch -D feature/TASK-NNN  # if branch exists
```

**Prevention:**
- `git.yml` config: `auto_cleanup: true`, `cleanup_on_merge: true`
- Max worktrees: 10 (configurable in `git.yml`)
- Worktree cleaner script runs as cron job

---

## 3. Redis Disconnection

**Symptoms:**
- Degradation warning: `tier degraded: L3 Rust`
- `kallax system:degradation` shows L3 unhealthy
- Circuit breaker status: `redis: open`

**Diagnosis:**

```bash
# Check Redis
redis-cli ping 2>/dev/null || echo "Redis unreachable"

# Check degradation state
kallax system:degradation

# Check circuit breaker stats
curl -s http://127.0.0.1:9877/api/system/circuit-breakers | jq .

# Check logs
tail -50 logs/kallax.log | grep -i -E "redis|circuit|cache"
```

**Resolution:**

KALLAX auto-degrades to L2 (Node.js + SQLite) when Redis is down:

```
1. Confirm degradation is active:
   kallax system:degradation
   Expected: Current Tier: 2 (Node.js), L3 Rust: unhealthy

2. Fix Redis (if Redis is infrastructure):
   docker compose up -d redis
   redis-cli ping

3. Verify recovery (auto, within 60s):
   kallax system:degradation-probe
   Wait for: L3 Rust: healthy
   Expected: Current Tier: 3 (Rust)

4. If Redis was the message queue:
   Unprocessed messages in SQLite will drain automatically
```

**Prevention:**
- Redis timeout: 5000ms (configurable in `config.yml > degradation.redis_timeout`)
- Circuit breaker: 3 failures before open, 30s reset timeout
- No critical data stored exclusively in Redis

---

## 4. Database Corruption

**Symptoms:**
- `kallax system:doctor` reports SQLite error
- Queries return `SQLITE_CORRUPT` errors
- Backup script fails on integrity check

**Resolution:**

```bash
# 1. Stop all KALLAX processes
kill $(pgrep -f "kallax")

# 2. Attempt recovery via .dump
sqlite3 .kallax/data/kallax.db ".dump" | sqlite3 .kallax/data/kallax_recovered.db

# 3. If recovery fails, restore from backup
gunzip -k .kallax/backups/kallax_$(ls -1t .kallax/backups/ | head -1).gz
cp .kallax/backups/kallax_*.db .kallax/data/kallax.db

# 4. Delete WAL artifacts
rm -f .kallax/data/kallax.db-wal .kallax/data/kallax.db-shm

# 5. Verify
sqlite3 .kallax/data/kallax.db "PRAGMA integrity_check;"
```

---

## 5. Performer Idle Timeout

**Symptoms:**
- Task stays in `claimed`/`running` status for >30 minutes
- No heartbeat from performer
- Conductor heartbeat Q2 reports stale performers

**Resolution:**

```bash
# 1. Mark stale performer
sqlite3 .kallax/data/kallax.db \
  "UPDATE instances SET status='error' WHERE status='active' AND last_heartbeat < $(date +%s)000 - 1800000;"

# 2. Reclaim task
kallax task:resume TASK-NNN

# 3. Re-assign to another performer
kallax task:claim TASK-NNN
```

**Prevention:**
- Performer heartbeat: 30s interval (config: `tasks.yml > timeouts.performer_heartbeat: 30m`)
- Idle threshold: 30 min (config: `tasks.yml > timeouts.task_max_idle: 30m`)
- Conductor polls every 60s for stale performers

# KALLAX to KALLAX Migration Guide

> Migrating from the legacy KALLAX framework to KALLAX.

---

## Overview

KALLAX was a single-agent automation framework. KALLAX is a multi-agent orchestration framework. The migration involves restructuring project files, renaming configuration, and adapting to the Conductor/Performer model.

---

## Data Export and Import

### Step 1: Export KALLAX Data

KALLAX stored data in JSON files under `.kallax/`:

```bash
# Create export directory
mkdir -p .kallax/migration

# Export tickets (KALLAX stored as flat JSON)
cp .kallax/tickets.json .kallax/migration/tickets_export.json 2>/dev/null || echo "No tickets found"

# Export config
cp .kallax/config.yml .kallax/migration/kallax_config.yml 2>/dev/null || echo "No KALLAX config found"
```

### Step 2: Transform to KALLAX Schema

```bash
# Transform ticket format
node -e "
const tickets = require('./.kallax/migration/tickets_export.json');
const db = require('./dist/sqlite-manager.js');
for (const t of tickets) {
  const ticket = {
    id: t.id || 'TICKET-' + Date.now().toString(36).toUpperCase(),
    title: t.title || t.name || 'Untitled',
    description: t.description || '',
    status: mapStatus(t.status),
    priority: mapPriority(t.priority),
    assigneeId: t.assignee || null,
    createdAt: t.created_at || Date.now(),
    updatedAt: t.updated_at || Date.now(),
    acceptanceCriteria: t.acceptance_criteria || [],
    labels: t.labels || [],
  };
  db.createTicket(ticket);
}
"
```

### Step 3: Verify Import

```bash
# Count imported records
kallax task:status --status pending

# Verify via SQLite
sqlite3 .kallax/data/kallax.db "SELECT count(*) FROM tickets;"
```

---

## Configuration Mapping

| KALLAX Config | KALLAX Config | Notes |
|-------------|---------------|-------|
| `.kallax/config.yml` | `.kallax/config.yml` | New version field, degradation block |
| `.kallax/tasks/` | `.kallax/config/tasks.yml` | Status flow simplified: KALLAX had 12 states, KALLAX has 9 |
| `.kallax/agents.yml` | `.kallax/config/process.yml` | Agent definitions moved to process config |
| `.kallax/rules/` | `.kallax/config/review_merge.yml` | Review rules consolidated |
| `master_email` | `conductor_emails` | Renamed per ADR-002 |
| `slave_timeout` | `timeouts.performer_heartbeat` | Same value, new path |

### Key Config Changes

```yaml
# KALLAX (old)
master_email: admin@example.com
slave_timeout: 30m
cache_ttl: 300
degradation_mode: manual

# KALLAX (new)
conductor_emails:
  - admin@example.com
timeouts:
  performer_heartbeat: 30m
resources:
  cache:
    default_ttl: 300000    # now in milliseconds
degradation:
  mode: auto               # manual -> auto (KALLAX auto-probes)
  redis_timeout: 5000
  node_crash_fallback: true
```

---

## Workflow Migration

### KALLAX: Sequential Task Queue

```
1. Create ticket in .kallax/tickets/
2. Agent picks next available
3. Works sequentially in main branch
4. Reports done via console.log
5. Human reviews manually
```

### KALLAX: Parallel Isolated Workflow

```
1. Create ticket via `kallax ticket:create TITLE`
2. Conductor decomposes into tasks with file scopes
3. Performer claims task -> auto creates worktree
4. Works in isolated worktree, commits step-by-step
5. 5-step Saga completion with Fact-Forcing verification
6. Conductor reviews via `kallax verify:output TASK-NNN`
7. PR merged (Conductor only)
```

---

## Directory Structure Changes

```
# KALLAX structure (old)
.kallax/
  tickets/
  agents/
  config.yml
  rules/

# KALLAX structure (new)
.kallax/
  config.yml                 # Main config
  config/                    # Modular configs
    tasks.yml
    git.yml
    monitoring.yml
    ...
  data/
    kallax.db                # SQLite database
    kallax.db-wal            # WAL journal
  state/
    instance_config.yml
  backups/                   # Auto-created by backup script
  templates/
    ticket-template.md
    epic-template.md
    pr-template.md
    review-template.md
```

---

## Common Migration Issues

### Issue 1: Missing WAL Mode

**Problem:** KALLAX used standard SQLite journal mode. KALLAX requires WAL mode for concurrent reads.

**Fix:** KALLAX auto-sets `PRAGMA journal_mode = WAL` on startup. No manual action needed.

### Issue 2: expect() / unwrap() in Production Code

**Problem:** KALLAX code used `expect()` (Rust) and `any` types (TypeScript). KALLAX CI rejects these.

**Fix:** Replace with `Result<T, E>` propagation and `unknown` type guards:

```typescript
// KALLAX
const result = operation().expect("should not fail");

// KALLAX
const result = operation()
  .map_err(|e| KallaxError::Operation { source: e })?;
```

### Issue 3: Shared State Between Agents

**Problem:** KALLAX agents shared the same working directory. KALLAX enforces worktree isolation.

**Fix:** Each Performer must claim a task, which auto-creates a worktree. Never work outside the worktree.

### Issue 4: Single Branch

**Problem:** KALLAX worked on main. KALLAX uses feature branches.

**Fix:** Performer pushes to `feature/TASK-NNN-short-name`. Conductor merges to `testing` -> `main` -> `miao`.

### Issue 5: Config in Seconds vs Milliseconds

**Problem:** KALLAX used seconds for TTL, KALLAX uses milliseconds.

**Fix:** Multiply all KALLAX TTL values by 1000.

```yaml
# KALLAX: cache_ttl: 300 (5 min in seconds)
# KALLAX: default_ttl: 300000 (5 min in milliseconds)
```

---

## Rollback Plan

If migration fails, revert to KALLAX:

```bash
# 1. Stop KALLAX
kill $(pgrep -f "kallax")

# 2. Remove KALLAX data
rm -rf .kallax/

# 3. Restore KALLAX (from backup)
cp -r .kallax/migration/kallax_backup/ .kallax/

# 4. Verify KALLAX works
./kallax/start.sh
```

---

## Post-Migration Checklist

- [ ] All tickets migrated (compare counts)
- [ ] Config converted (no warning on `kallax start`)
- [ ] `kallax system:doctor` passes all checks
- [ ] At least one conductor and one performer registered
- [ ] Backup script runs successfully
- [ ] All team members have conductor/performer roles assigned

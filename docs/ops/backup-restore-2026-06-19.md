# Backup and Restore Guide

> SQLite database backup and recovery procedures.

---

## Backup Strategy

KALLAX stores all persistent state in a single SQLite database at `.kallax/data/kallax.db`, backed by a WAL (Write-Ahead Log) journal for concurrent read access.

### Automated Backup

The `scripts/backup-sqlite.sh` script handles daily backups:

```bash
# Default backup (30-day retention)
./scripts/backup-sqlite.sh

# Custom retention (keep 90 days)
./scripts/backup-sqlite.sh "$PWD" 90
```

**Backup process:**
1. Checkpoints the WAL journal (ensures all writes are flushed)
2. Uses `sqlite3 .backup` for consistent snapshots (or `cp` as fallback)
3. Compresses with gzip (reduces size ~80%)
4. Stores in `.kallax/backups/` with timestamp: `kallax_20260601_143000.db.gz`
5. Rotates backups older than retention days (default: 30)

```cron
# Add to crontab for daily 2AM backup
0 2 * * * cd /path/to/project && ./scripts/backup-sqlite.sh
```

### Manual Backup Hot-Read

For ad-hoc queries without impacting writes:

```bash
# Read-only query on live DB (WAL allows concurrent reads)
sqlite3 .kallax/data/kallax.db "SELECT COUNT(*) FROM tasks;"

# Export to CSV
sqlite3 -csv .kallax/data/kallax.db "SELECT * FROM tasks;" > tasks_export.csv
```

---

## Restore Procedure

### Full Restore

```bash
# 1. Stop KALLAX (if running)
kill $(pgrep -f "kallax")

# 2. Locate backup
ls -la .kallax/backups/

# 3. Decompress
gunzip -k .kallax/backups/kallax_20260601_143000.db.gz

# 4. Restore
cp .kallax/backups/kallax_20260601_143000.db .kallax/data/kallax.db

# 5. Remove old WAL artifacts (will be recreated on next open)
rm -f .kallax/data/kallax.db-wal .kallax/data/kallax.db-shm

# 6. Verify
sqlite3 .kallax/data/kallax.db "SELECT count(*) FROM tickets;"
```

### Point-in-Time Recovery

SQLite does not support native PITR. If you need granular recovery:
- Keep multiple daily backups (default retention = 30 days)
- Use `.kallax/backups/` as a time-series archive
- Restore the most recent backup that predates the incident

### Restore Verification

After restore, run these checks:

```bash
# Check DB integrity
sqlite3 .kallax/data/kallax.db "PRAGMA integrity_check;"

# Verify data
sqlite3 .kallax/data/kallax.db "SELECT count(*), status FROM tasks GROUP BY status;"
sqlite3 .kallax/data/kallax.db "SELECT count(*), role FROM instances GROUP BY role;"

# Run health check
./scripts/health_check.sh

# Start KALLAX and check
kallax system:doctor
```

---

## Redis Backup (If Used)

When running with Redis for message queuing and master election:

```bash
# Manual save
redis-cli SAVE
# Backup dump.rdb
cp /var/lib/redis/dump.rdb .kallax/backups/redis_$(date +%Y%m%d).rdb
```

Redis is not the source of truth -- it is a transient cache/messaging layer. Loss of Redis data degrades KALLAX to L2 (SQLite-only) but does not cause data loss.

---

## Disaster Recovery

| Scenario | Recovery Action | RTO | RPO |
|----------|---------------|-----|-----|
| DB corruption | Restore from latest backup | 5 min | 24h (max) |
| Accidental data loss | Restore from pre-incident backup | 5 min | 24h |
| Full disk | Move .kallax/data to new disk, symlink | 10 min | 0 |
| Redis loss | KALLAX auto-degrades to L2, no data loss | 1 min | 0 |

---

## Related

- `scripts/backup-sqlite.sh` -- Backup script
- `scripts/health_check.sh` -- Verification script
- `.kallax/data/kallax.db` -- Database location
- `docker-compose.yml` -- Redis container (if used)

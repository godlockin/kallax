# Master Election System

> Design document for the KALLAX three-tier master election subsystem.

---

## Overview

The Election System ensures exactly one Conductor is active per deployment. It uses a three-tier degradation model: Redis-based lease → SQLite advisory lock → filesystem lock. Each tier trades reliability for simplicity when infrastructure degrades.

---

## Architecture

```
Tier 1 — Redis (preferred)
  conductor-lease:{instance_id}
  TTL=30s, refresh every 15s
  └── crash → TTL expiry → automatic failover

Tier 2 — SQLite Advisory Lock (fallback)
  pragma schema.locking_mode=EXCLUSIVE
  └── works without Redis, single-node only

Tier 3 — Filesystem Lock (last resort)
  .kallax/locks/master.lock (PID file)
  └── no external deps, no crash recovery
```

---

## Lease Protocol

### Tier 1: Redis

```
1. SET conductor-lease:{id} {timestamp} NX EX 30
   ↓ success → I am master, start refresh timer (15s)
   ↓ exists  → read owner, check staleness
2. Every 15s: EXPIRE conductor-lease:{id} 30
3. On shutdown: DEL conductor-lease:{id}
```

### Tier 2: SQLite

```sql
-- Acquire
PRAGMA locking_mode = EXCLUSIVE;
BEGIN EXCLUSIVE;
INSERT INTO conductor_lock (instance_id, acquired_at) VALUES (?, datetime('now'));

-- Release
DELETE FROM conductor_lock WHERE instance_id = ?;
COMMIT;
```

### Tier 3: Filesystem

```bash
# Acquire
echo $$ > "${LOCK_FILE}"
# Release (automatic on crash via trap)
trap 'rm -f "${LOCK_FILE}"' EXIT
```

---

## Degradation Logic

```
  ┌──────────┐   Redis available?
  │  Start   │─── yes ──▶ Tier 1 (Redis lease)
  └────┬─────┘
       │ no
       ▼
  ┌──────────┐   SQLite exclusive lock works?
  │  Degrade │─── yes ──▶ Tier 2 (SQLite lock)
  └────┬─────┘
       │ no
       ▼
  ┌──────────┐
  │  Tier 3  │───▶ Filesystem lock (last resort)
  └──────────┘
```

Each tier attempt has a 5-second timeout. After all tiers fail, the instance waits 60s before retrying.

---

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `lease_ttl` | `30` | Redis lease TTL in seconds |
| `lease_refresh` | `15` | Lease refresh interval in seconds |
| `retry_interval` | `60` | Retry interval after total failure |
| `tier_timeout` | `5000` | Per-tier attempt timeout in ms |

---

## Related Files

- `node/src/core/election-client.ts` — Election client (跟 实际 flat 目录 一致, P0-8 fix)
- `node/src/core/master-election.ts` — Master election logic
- `node/src/api/routes/election.ts` — Election HTTP API
- `rust/crates/kallax-election/src/` — Rust raft-rs 0.6 (跟 EPIC-060-A Phase 5 联合)
- `docs/architecture/DEGRADATION-STRATEGY.md` — Degradation overview

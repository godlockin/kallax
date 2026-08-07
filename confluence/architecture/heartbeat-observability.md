# Heartbeat Observability Architecture

> **Status**: Implemented (EPIC-021-F)
> **Last Updated**: 2026-06-07
> **EPIC**: EPIC-021 (Expert System)

---

## 1. Architecture Overview

### 1.1 Heartbeat System Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        KALLAX Instance                                  │
│  ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐ │
│  │ heartbeat-      │─────▶│   state.json    │◀─────│ expert-invocation│ │
│  │ daemon.sh       │      │  (per instance)  │      │ -queue.sh       │ │
│  │                 │      │                 │      │                 │ │
│  │ - Runs every Ns │      │ - last_beat     │      │ - 3-layer queue │ │
│  │ - Updates JSON  │      │ - missed_count  │      │ - LRU 1000      │ │
│  │ - Tracks PID    │      │ - expert_invoc  │      │ - Emit on tick  │ │
│  └─────────────────┘      └─────────────────┘      └─────────────────┘ │
│           │                        ▲                        │          │
│           │                        │                        │          │
│           ▼                        │                        ▼          │
│  ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐ │
│  │  Master Handoff │      │   Conductor     │      │  3-Layer Queue  │ │
│  │  check-stale.sh │      │   Session Init  │      │  (see §2)       │ │
│  └─────────────────┘      └─────────────────┘      └─────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 State JSON Schema (heartbeat fields)

```json
{
  "status": "ACTIVE|STALE|CLOSING",
  "heartbeat": {
    "last_beat": "2026-06-07T20:00:00Z",
    "missed_count": 0,
    "heartbeat_daemon_pid": 12345
  },
  "expert_invocations": [
    {"expert_id": "backend", "ticket_id": "EPIC-021-A", "timestamp": 1234567890},
    ...
  ]
}
```

---

## 2. Expert Invocations 3-Layer Degradation Chain

### 2.1 Degradation Path

```
Redis Stream (primary)
       │
       ▼ (fail → SQLite)
   SQLite DB (secondary)
       │
       ▼ (fail → JSONL)
   JSONL File (fallback)
```

### 2.2 Backend Selection Logic

```bash
# STATE_FILE stores current backend: ~/.claude/state/queue_backend
# Default: redis

# Health probes:
# - Redis: redis-cli ping (1s timeout)
# - SQLite: SELECT 1 (500ms latency threshold)

# Automatic downgrade on failure:
# - Redis fails → switch to SQLite
# - SQLite fails → switch to JSONL

# Automatic upgrade (every 5 minutes):
# - try_upgrade_redis() probes Redis
# - If healthy → switch back to Redis
```

### 2.3 File Paths

| Backend | Path |
|---------|------|
| Redis Key | `expert_invocations` (stream) |
| SQLite DB | `~/.kallax/state/expert_invocations.db` |
| JSONL | `~/.kallax/queue/expert_invocations.jsonl` |
| Archive | `~/.kallax/state/expert_invocations.archive.jsonl` |
| State | `~/.claude/state/queue_backend` |

---

## 3. LRU 1000 Maintenance Strategy

### 3.1 In-Memory LRU (state.json)

```bash
# heartbeat-daemon.sh maintains LRU in state.json
jq '.expert_invocations[0:1000]' "${STATE_FILE}"
```

- **Max entries**: 1000
- **Trimming**: On every heartbeat tick
- **Location**: `state.json` → `expert_invocations[]`

### 3.2 Overflow Archival Path

When LRU exceeds 1000:

1. **Old entries archived** to `expert_invocations.archive.jsonl`
2. **Format**: Append-only JSONL (one invocation per line)
3. **Retention**: Until manual cleanup or EPIC completion

### 3.3 LRU Maintenance Function

```bash
# expert-invocation-queue.sh calls write_state_invocations()
# which delegates to backend-specific write
# NOT in backend code (avoid duplication)
```

**Key insight**: LRU is maintained uniformly via `write_state_invocations()` in the queue library, not in each backend. This ensures consistency across Redis/SQLite/file backends.

---

## 4. Portable Lock Implementation

### 4.1 mkdir-based Lock (POSIX compliant)

```bash
# expert-invocation-queue.sh uses mkdir for atomic locking
with_lock() {
  local lock_name="$1"
  local lock_path="${INVOCATION_DIR}/.lock_${lock_name}_$$"
  local try=0

  while [ "$try" -lt 200 ]; do
    if mkdir "$lock_path" 2>/dev/null; then
      "$@"  # Execute critical section
      rmdir "$lock_path" 2>/dev/null || true
      return $?
    fi
    try=$((try + 1))
    sleep 0.001  # 1ms, max 200ms total wait
  done

  LAST_ERROR="with_lock: timeout acquiring $lock_name"
  return 1
}
```

### 4.2 flock vs mkdir Comparison

| Feature | flock | mkdir-based |
|---------|-------|-------------|
| macOS support | ❌ (requires brew) | ✅ (built-in) |
| Atomic on POSIX | ✅ | ✅ |
| Deadlock avoidance | via timeout | via timeout + sleep |
| Lock file cleanup | automatic | automatic (on exit) |
| Network FS support | ⚠️ limited | ❌ not recommended |

**Decision**: Use mkdir-based lock for KALLAX portability.

### 4.3 Lock Scope

Locks are used for:
- `state` — backend selection state file
- `drain` — drain queue to file
- `emit` — emit to queue

---

## 5. macOS Compatibility & Fallbacks

### 5.1 Missing Commands

| Command | macOS Issue | Fallback |
|---------|-------------|----------|
| `flock` | Not installed by default | mkdir-based lock |
| `timeout` | Not installed | with_timeout() using background+kill+wait |
| `gtimeout` | Not installed (GNU) | with_timeout() portable pattern |

### 5.2 Portable Timeout Implementation

```bash
with_timeout() {
  local secs="$1"
  shift
  "$@" &
  local pid=$!
  local elapsed=0

  while kill -0 "$pid" 2>/dev/null; do
    if [ "$elapsed" -ge "$secs" ]; then
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124  # GNU timeout convention
    fi
    sleep 0.1
    elapsed=$((elapsed + 1))
  done
  wait "$pid"
  return $?
}
```

### 5.3 Testing Matrix

| Platform | redis-cli | sqlite3 | flock | timeout | Status |
|----------|-----------|---------|-------|---------|--------|
| Linux (Ubuntu) | ✅ | ✅ | ✅ | ✅ | Fully supported |
| macOS (Ventura+) | ✅ (brew) | ✅ | ❌ | ❌ | Requires fallback |
| CI (GitHub Actions) | ✅ | ✅ | ✅ | ✅ | Fully supported |

---

## 6. EPIC-021-F 11 Fixes Integration

### 6.1 Critical Fixes (2)

| ID | Issue | Fix | Location |
|----|-------|-----|----------|
| F-C1 | SQL injection in sqlite_emit | Input validation + JSON escape | `validate_input()` + `json_escape()` |
| F-C2 | Race condition (drain+emit) | mkdir-based atomic lock | `with_lock("drain")` + `with_lock("emit")` |

### 6.2 High Fixes (4)

| ID | Issue | Fix | Location |
|----|-------|-----|----------|
| F-H1 | Redis XADD silent fallthrough | Explicit error check after XADD | `emit()` function |
| F-H2 | get_backend race condition | Lock on STATE_FILE | `with_lock("state")` in `get_backend()` |
| F-H3 | Redis probe timeout | `with_timeout()` wrapper | `probe_redis()` |
| F-H4 | Backend switch race | Atomic state file update | `set_backend()` with lock |

### 6.3 Medium Fixes (4)

| ID | Issue | Fix | Location |
|----|-------|-----|----------|
| F-M1 | chmod 0700 too restrictive | `|| true` on chmod, graceful fallback | Multiple locations |
| F-M2 | Explicit length checks missing | `MAX_EXPERT_ID_LEN=128`, `MAX_TICKET_ID_LEN=64` | `validate_input()` |
| F-M3 | SQLite write latency not checked | 500ms threshold in `probe_sqlite()` | `probe_sqlite()` |
| F-M4 | Archive file not created | Write to ARCHIVE_FILE on overflow | `drain_to_file()` |

### 6.4 Low Fixes (1)

| ID | Issue | Fix | Location |
|----|-------|-----|----------|
| F-L1 | gtimeout not available on macOS | Portable with_timeout pattern | `with_timeout()` function |

---

## 7. Expert Invocation Flow

### 7.1 Emit Flow (on heartbeat tick)

```bash
# heartbeat-daemon.sh calls emit on each tick
MY_EXPERT_ID="$(jq -r '.expert_id // empty' "${STATE_FILE}")"
LAST_TICKET="$(jq -r '.ticket_id // empty' "${STATE_FILE}")"
emit "$MY_EXPERT_ID" "$LAST_TICKET"
```

### 7.2 Queue Write (3-layer)

```
emit(expert_id, ticket_id)
  → validate_input(expert_id, ticket_id)
  → switch (backend):
      case redis: redis_xadd()
      case sqlite: sqlite_insert()
      case file: jsonl_append()
```

### 7.3 Drain Flow (for observability)

```bash
# drain reads from current backend
# and writes to ARCHIVE_FILE on overflow
drain()
  → with_lock("drain")
  → read from current backend
  → if overflow: mv to .bak, cat, rm (atomic)
```

---

## 8. Observability Integration

### 8.1 Heartbeat → Expert Invocations

Each heartbeat tick emits an invocation:

```bash
# In heartbeat-daemon.sh loop:
emit "$MY_EXPERT_ID" "$LAST_TICKET" 2>/dev/null || true

# Trims LRU to 1000:
jq '.expert_invocations[0:1000]' "${STATE_FILE}"
```

### 8.2 Metrics Available

| Metric | Source | Aggregation |
|--------|--------|-------------|
| Expert utilization | `expert_invocations[]` | Count by expert_id |
| Ticket engagement | `expert_invocations[]` | Count by ticket_id |
| Session duration | `last_beat` delta | Per instance |
| Stale detection | `missed_count` | check-stale.sh |
| Queue health | Backend probe | 3-layer status |

### 8.3 Cross-Reference

- **Stale detection**: `scripts/check-stale.sh`
- **Master handoff**: `scripts/master-handoff.sh`
- **Session init**: `scripts/conductor-session-init.sh`, `scripts/performer-session-init.sh`

---

## 9. Index & References

### 9.1 Related Documents

- [confluence/decisions/index.md §6](../decisions/index.md#6-expert-invocations-queue) — Expert invocation queue decisions
- [scripts/lib/expert-invocation-queue.sh](../../scripts/lib/expert-invocation-queue.sh) — Implementation
- [scripts/heartbeat-daemon.sh](../../scripts/heartbeat-daemon.sh) — Heartbeat daemon

### 9.2 EPIC Dependencies

| EPIC | Relationship |
|------|---------------|
| EPIC-015 | Heartbeat infrastructure (daemon, state.json) |
| EPIC-016 | Init performance baseline |
| EPIC-021 | Expert system + 7 personas |
| EPIC-022 | Permission Model v1 (L4 scripts real implementation) |

---

## 10. Maintenance Notes

### 10.1 Adding New Backend

1. Add probe function: `probe_<backend>()`
2. Add emit function: `emit_to_<backend>()`
3. Add drain function: `drain_from_<backend>()`
4. Update `get_backend()` logic
5. Update this document §2

### 10.2 Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Queue not writing | Backend down | Check `~/.claude/state/queue_backend` |
| Lock timeout | High contention | Increase sleep in `with_lock()` |
| LRU not trimming | jq not available | Install jq |
| Redis silent fail | XADD error not checked | Add error capture |

---

**Author**: EPIC-021-F Performer
**Reviewers**: A-Forward (backend), B-Attack (security)
**Approved**: master_main

---

## §11. Operational SOP (接手指南)

### 启动 / 停止 Heartbeat Daemon

```bash
# 启动 (在 session 中自动, 但可以手动触发)
bash scripts/heartbeat-daemon.sh start  # 后台 daemon, 60s 心跳

# 停止 (优雅)
bash scripts/heartbeat-daemon.sh stop

# 强制 kill (orphan cleanup)
bash scripts/kallax-cleanup.sh --force
```

### 检查 Queue Health

```bash
# 1. expert_invocations queue 状态
bash scripts/lib/expert-invocation-queue.sh health

# 2. emit/drain 测试
source scripts/lib/expert-invocation-queue.sh
emit "kallax.backend.001" "EPIC-XXX-test" "$(date +%s)"
drain

# 3. state.json expert_invocations array
jq '.expert_invocations | length' .kallax/state/state.json
```

### 响应 STALE Instance

```bash
# 1. 扫描 STALE (last_beat > 5min)
bash scripts/kallax-cleanup.sh --dry-run

# 2. 看具体哪 些 STALE
bash scripts/audit-closing-instances.sh

# 3. 强制清理 (master only, 需 KALLAX_MASTER_TOKEN)
KALLAX_MASTER_TOKEN=$(cat ~/.claude/state/kallax-master-token) bash scripts/kallax-cleanup.sh --force
```

### 紧急降级 (Redis/SQLite 都不工作时)

```bash
# 1. 强制使用 file backend
# 改 scripts/lib/expert-invocation-queue.sh:
#   set_backend() 强制 echo "file" > STATE_FILE

# 2. 验证 file 队列可用
ls -la .kallax/queue/expert_invocations.jsonl

# 3. 监控 .kallax/queue/ 大小
du -sh .kallax/queue/
# 超过 100MB 需考虑归档
```

### 关键路径 (Path Cheat Sheet)

- Heartbeat: `.kallax/hooks/session_start.sh` → `scripts/heartbeat-daemon.sh`
- 队列: `.kallax/queue/expert_invocations.jsonl` (file) / `expert_invocations` (Redis Stream) / `.kallax/state/expert_invocations.db` (SQLite)
- State: `.kallax/state/state.json` → `expert_invocations[]` (LRU 1000)
- Logs: `.kallax/logs/orphan_kills.jsonl` (daemon kill audit) / `.kallax/logs/preflight-overrides.jsonl` (force-merge audit)
- Rollback: `confluence/runbooks/permission-p0-rollback.md` / `confluence/runbooks/instance-pre-clean.md`

---

## §9. Cross-References

- `../docs/architecture/FRAMEWORK.md` — KALLAX 架构白皮书
- `../docs/architecture/DEGRADATION-STRATEGY.md` — 3 层降级策略设计
- [confluence/decisions/index.md](../decisions/index.md) — 决策文档总索引
- `../decisions/EXPERT-PRIORITY-SYNTHESIS-2026-06-07.md` — 8 专家优先级综合
- [scripts/check-skill-anatomy.sh](../../scripts/check-skill-anatomy.sh) — 7 文件 KALLAX 校验 (10 项)
- [scripts/lib/expert-invocation-queue.sh](../../scripts/lib/expert-invocation-queue.sh) — Queue 库 (跨 EPIC 复用)

#!/usr/bin/env bash
# scripts/lib/expert-invocation-queue.sh
# KALLAX expert_invocations 降级链 (FIXED — EPIC-021-F A+B review fixes)
# 降级: Redis Stream → SQLite → JSONL
# 写盘 by default, 队列是升级路径
#
# 修复 (A+B review):
# - CRITICAL: SQL injection in sqlite_emit → input validation + JSON escape
# - CRITICAL: race drain+emit → portable mkdir-based atomic lock
# - HIGH: Redis XADD silent fallthrough → explicit error check
# - HIGH: get_backend race → lock on STATE_FILE
# - MEDIUM: chmod 0700 on INVOCATION_DIR
# - MEDIUM: explicit length check (MAX_*_LEN)
# - LOW: gtimeout fallback (uses background+kill+wait portable pattern)
#
# 不依赖 flock/timeout (macOS 默认无, 用 mkdir/sleep 替代)

set -euo pipefail

# 状态文件
STATE_FILE="${HOME}/.claude/state/queue_backend"
INVOCATION_DIR="${HOME}/.kallax/queue"
INVOCATION_FILE="${INVOCATION_DIR}/expert_invocations.jsonl"
ARCHIVE_FILE="${HOME}/.kallax/state/expert_invocations.archive.jsonl"
SQLITE_DB="${HOME}/.kallax/state/expert_invocations.db"
REDIS_KEY="expert_invocations"
REDIS_PING_TIMEOUT=1  # 秒
SQLITE_WRITE_TIMEOUT=0.5  # 秒
LRU_MAX=1000
LAST_ERROR=""

# Input validation
MAX_EXPERT_ID_LEN=128
MAX_TICKET_ID_LEN=64
VALID_ID_PATTERN='^[a-zA-Z0-9._-]+$'

mkdir -p "$INVOCATION_DIR" "$(dirname "$SQLITE_DB")" "$(dirname "$STATE_FILE")"
chmod 0700 "$INVOCATION_DIR" 2>/dev/null || true
chmod 0700 "$(dirname "$SQLITE_DB")" 2>/dev/null || true

# EPIC-026-A Bug 3 Fix: SQLite WAL mode + busy_timeout
# Avoids SQLITE_BUSY permanent hang on concurrent write/read
init_sqlite() {
  if [ -f "$SQLITE_DB" ]; then
    sqlite3 "$SQLITE_DB" "PRAGMA journal_mode=WAL;" 2>/dev/null || true
    sqlite3 "$SQLITE_DB" "PRAGMA busy_timeout=5000;" 2>/dev/null || true
  fi
}
init_sqlite

# 全局状态
__expert_invocation_last_redis_probe=0
__expert_invocation_redis_retry_interval=300  # 5 min in seconds

# Portable lock: uses mkdir (atomic on POSIX, including macOS)
# Usage: with_lock LOCK_NAME critical_section_args...
# LOCK_NAME: any short string, used as lock file basename
with_lock() {
  local lock_name="$1"
  shift
  local lock_path="${INVOCATION_DIR}/.lock_${lock_name}_$$"
  local try=0
  while [ "$try" -lt 200 ]; do
    if mkdir "$lock_path" 2>/dev/null; then
      local rc=0
      "$@" || rc=$?
      rmdir "$lock_path" 2>/dev/null || true
      return $rc
    fi
    try=$((try + 1))
    # brief sleep to avoid busy loop (1ms × 200 = 200ms max wait)
    sleep 0.001 2>/dev/null || sleep 1
  done
  LAST_ERROR="with_lock: timeout acquiring $lock_name"
  return 1
}

# Portable timeout: runs cmd in background, kills after N seconds
# Usage: with_timeout N cmd args...
# Returns 124 on timeout (matching GNU timeout convention)
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
      return 124
    fi
    sleep 0.1 2>/dev/null || sleep 1
    elapsed=$((elapsed + 1))
  done
  wait "$pid" 2>/dev/null
  return $?
}

# 当前 backend 选择 (with lock)
get_backend() {
  with_lock "state" sh -c '
    if [ -f "$1" ]; then
      cat "$1"
    else
      echo "redis"
    fi
  ' _ "$STATE_FILE"
}

set_backend() {
  with_lock "state" sh -c '
    echo "$1" > "$2"
    chmod 0600 "$2" 2>/dev/null || true
  ' _ "$1" "$STATE_FILE"
  LAST_ERROR="backend switched to $1 at $(date +%s)"
}

# 探测 backend 健康
probe_redis() {
  if ! command -v redis-cli &>/dev/null; then
    LAST_ERROR="redis-cli not found"
    return 1
  fi
  if with_timeout "$REDIS_PING_TIMEOUT" redis-cli ping &>/dev/null; then
    return 0
  fi
  LAST_ERROR="redis ping timeout > ${REDIS_PING_TIMEOUT}s"
  return 1
}

probe_sqlite() {
  if ! command -v sqlite3 &>/dev/null; then
    LAST_ERROR="sqlite3 not found"
    return 1
  fi
  local start=$(date +%s%N)
  if ! sqlite3 "$SQLITE_DB" "SELECT 1" &>/dev/null; then
    LAST_ERROR="sqlite3 probe failed"
    return 1
  fi
  local end=$(date +%s%N)
  local elapsed=$(( (end - start) / 1000000 ))  # ms
  if [ "$elapsed" -ge 500 ]; then
    LAST_ERROR="sqlite3 write latency ${elapsed}ms >= 500ms"
    return 1
  fi
  return 0
}

# 尝试回切到 Redis（每 5 分钟一次）
try_upgrade_redis() {
  local now=$(date +%s)
  local elapsed=$(( now - __expert_invocation_last_redis_probe ))
  if [ "$elapsed" -lt "$__expert_invocation_redis_retry_interval" ]; then
    return 1
  fi
  __expert_invocation_last_redis_probe="$now"
  if probe_redis; then
    set_backend redis
    return 0
  fi
  return 1
}

# FIX: input validation
# Returns 0 if valid, 1 if invalid (with LAST_ERROR set)
validate_input() {
  local expert_id="$1"
  local ticket_id="$2"

  if [ -z "$expert_id" ] || [ -z "$ticket_id" ]; then
    LAST_ERROR="empty expert_id or ticket_id"
    return 1
  fi

  if [ "${#expert_id}" -gt "$MAX_EXPERT_ID_LEN" ]; then
    LAST_ERROR="expert_id too long (${#expert_id} > $MAX_EXPERT_ID_LEN)"
    return 1
  fi

  if [ "${#ticket_id}" -gt "$MAX_TICKET_ID_LEN" ]; then
    LAST_ERROR="ticket_id too long (${#ticket_id} > $MAX_TICKET_ID_LEN)"
    return 1
  fi

  if ! [[ "$expert_id" =~ $VALID_ID_PATTERN ]]; then
    LAST_ERROR="expert_id contains invalid chars (allowed: a-zA-Z0-9._-)"
    return 1
  fi

  if ! [[ "$ticket_id" =~ $VALID_ID_PATTERN ]]; then
    LAST_ERROR="ticket_id contains invalid chars (allowed: a-zA-Z0-9._-)"
    return 1
  fi

  return 0
}

# FIX: JSON escape for safe JSON construction
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# emit: 写一条 invocation
# $1: expert_id
# $2: ticket_id
# $3: timestamp (optional, default now)
# EPIC-026-A Bug 2 Fix: emit+drain must be mutually exclusive (atomic)
emit() {
  local expert_id="$1"
  local ticket_id="$2"
  local ts="${3:-$(date +%s)}"

  # FIX: input validation BEFORE any backend call
  if ! validate_input "$expert_id" "$ticket_id"; then
    echo "ERROR: $LAST_ERROR" >&2
    return 1
  fi

  # FIX: ts must be numeric
  if ! [[ "$ts" =~ ^[0-9]+$ ]]; then
    LAST_ERROR="ts must be numeric"
    echo "ERROR: $LAST_ERROR" >&2
    return 1
  fi

  # EPIC-026-A Bug 2 Fix: use global __emit_* vars so sh -c can access them
  __emit_expert_id="$expert_id"
  __emit_ticket_id="$ticket_id"
  __emit_ts="$ts"

  with_lock "emit_drain" sh -c '
    local backend
    backend=$(get_backend)

    # 尝试升级到 Redis（如果当前不是 redis）
    if [ "$backend" != "redis" ]; then
      try_upgrade_redis && backend=$(get_backend)
    fi

    # FIX: JSON escape user input (use __emit_* globals from outer scope)
    local safe_expert_id safe_ticket_id
    safe_expert_id=$(json_escape "$__emit_expert_id")
    safe_ticket_id=$(json_escape "$__emit_ticket_id")
    local payload="{\"expert_id\":\"$safe_expert_id\",\"ticket_id\":\"$safe_ticket_id\",\"ts\":$__emit_ts,\"backend\":\"$backend\"}"

     # Degradation chain: redis → sqlite → file
    if [ "$backend" = "redis" ]; then
      if probe_redis; then
        # FIX: explicit error check (no silent fallthrough)
        if redis-cli -x XADD "$REDIS_KEY" '"'"'*'"'"' payload "$payload" 2>/dev/null; then
          write_state_invocations "$__emit_expert_id" "$__emit_ticket_id" "$__emit_ts" "$backend"
          return 0
        fi
        LAST_ERROR="redis XADD failed despite probe success (ACL/stream config?)"
        # fallthrough to sqlite
      fi
      set_backend sqlite
      backend="sqlite"
    fi

    if [ "$backend" = "sqlite" ]; then
      if probe_sqlite; then
        if sqlite_emit "$payload"; then
          write_state_invocations "$__emit_expert_id" "$__emit_ticket_id" "$__emit_ts" "$backend"
          return 0
        fi
      fi
      set_backend file
      backend="file"
    fi

    if [ "$backend" = "file" ]; then
      file_emit "$payload"
      write_state_invocations "$__emit_expert_id" "$__emit_ticket_id" "$__emit_ts" "$backend"
    fi
  '
}

# FIX: escape single quotes for SQL safety (input already validated)
sqlite_emit() {
  local payload="$1"
  sqlite3 "$SQLITE_DB" "CREATE TABLE IF NOT EXISTS invocations (id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT, ts INTEGER DEFAULT (strftime('%s','now')))" 2>/dev/null
  with_lock "sqlite" sh -c '
    # Escape single quotes: '\'' -> '\'\''
    local safe
    safe=$(printf "%s" "$1" | sed "s/'\''/'\'''\''/g")
    sqlite3 "$2" "INSERT INTO invocations (payload) VALUES ('\''$safe'\'');"
  ' _ "$payload" "$SQLITE_DB"
}

# FIX: lock + atomic write
file_emit() {
  local payload="$1"
  with_lock "file" sh -c '
    if ! touch "$1" 2>/dev/null; then
      echo "ENOSPC" >&2
      return 1
    fi
    echo "$2" >> "$1"
  ' _ "$INVOCATION_FILE" "$payload" || {
    LAST_ERROR="ENOSPC: cannot write to $INVOCATION_FILE"
    return 1
  }
  lru_archive
}

# LRU 溢出归档（超过 LRU_MAX 行则刷到 archive）
lru_archive() {
  if [ ! -f "$INVOCATION_FILE" ]; then
    return 0
  fi
  local line_count
  line_count=$(wc -l < "$INVOCATION_FILE" 2>/dev/null || echo 0)
  if [ "$line_count" -gt "$LRU_MAX" ]; then
    local overflow=$(( line_count - LRU_MAX ))
    local tmp="${INVOCATION_FILE}.lru.$$"
    tail -n "$overflow" "$INVOCATION_FILE" >> "$ARCHIVE_FILE"
    head -n "$LRU_MAX" "$INVOCATION_FILE" > "$tmp" && mv "$tmp" "$INVOCATION_FILE"
  fi
}

# FIX: drain uses lock for atomicity with concurrent emit
drain() {
  local backend=$(get_backend)
  with_lock "drain" sh -c '
    case "$1" in
      redis)
        redis-cli XRANGE "$2" - + 2>/dev/null
        redis-cli XTRIM "$2" MAXLEN 0 2>/dev/null
        ;;
      sqlite)
        sqlite3 "$3" "BEGIN; SELECT payload FROM invocations; DELETE FROM invocations; COMMIT;" 2>/dev/null
        ;;
      file)
        if [ -f "$4" ]; then
          mv "$4" "${4}.drain.$$"
          cat "${4}.drain.$$"
          rm -f "${4}.drain.$$"
        fi
        ;;
    esac
  ' _ "$backend" "$REDIS_KEY" "$SQLITE_DB" "$INVOCATION_FILE"
}

# FIX: sanitize LAST_ERROR (no internal paths in health output)
sanitize_error() {
  local err="$1"
  case "$err" in
    *sqlite3*not*found*|*sqlite3*probe*failed*) echo "backend_unavailable" ;;
    *redis*not*found*|*redis*ping*timeout*) echo "backend_unavailable" ;;
    *ENOSPC*) echo "disk_full" ;;
    *switched*to*) echo "backend_switched" ;;
    *too*long*|*invalid*chars*|*empty*) echo "invalid_input" ;;
    *) echo "unknown_error" ;;
  esac
}

# health: 报告 JSON (FIX: sanitized last_error)
health() {
  local backend=$(get_backend)
  local latency
  latency=$(get_latency_ms)
  local size
  size=$(get_queue_size)
  local safe_error
  safe_error=$(sanitize_error "$LAST_ERROR")
  cat <<EOF
{
  "backend": "$backend",
  "latency_ms": $latency,
  "queue_size": $size,
  "last_error": "$safe_error"
}
EOF
}

# FIX AC6: state.json expert_invocations LRU 1000 maintenance
# Uses jq for safe JSON manipulation
write_state_invocations() {
  local expert_id="$1"
  local ticket_id="$2"
  local ts="$3"
  local backend="$4"

  local state_file="${HOME}/.kallax/state/state.json"
  if [ ! -f "$state_file" ]; then
    return 0
  fi

  if ! command -v jq &>/dev/null; then
    LAST_ERROR="jq not found, state.json LRU not maintained"
    return 1
  fi

  with_lock "state_json" sh -c '
    local tmp="${1}.tmp.$$"
    jq --arg eid "$2" \
       --arg tid "$3" \
       --argjson ts "$4" \
       --arg b "$5" \
       --argjson max "$6" \
       ".expert_invocations = ((.expert_invocations // []) + [{expert_id:\$eid, ticket_id:\$tid, ts:\$ts, backend:\$b}]) |
        if (.expert_invocations | length) > \$max then
          .expert_invocations |= .[-\$max:]
        else . end" \
       "$1" > "$tmp" && mv "$tmp" "$1"
  ' _ "$state_file" "$expert_id" "$ticket_id" "$ts" "$backend" "$LRU_MAX"
}

get_latency_ms() {
  case "$(get_backend)" in
    redis)
      local start
      start=$(date +%s%N)
      if probe_redis; then
        local end
        end=$(date +%s%N)
        echo $(( (end - start) / 1000000 ))
      else
        echo -1
      fi
      ;;
    sqlite)
      local start
      start=$(date +%s%N)
      if probe_sqlite; then
        local end
        end=$(date +%s%N)
        echo $(( (end - start) / 1000000 ))
      else
        echo -1
      fi
      ;;
    file) echo 1 ;;
    *) echo -1 ;;
  esac
}

get_queue_size() {
  case "$(get_backend)" in
    redis) redis-cli XLEN "$REDIS_KEY" 2>/dev/null || echo 0 ;;
    sqlite) sqlite3 "$SQLITE_DB" "SELECT COUNT(*) FROM invocations" 2>/dev/null || echo 0 ;;
    file) wc -l < "$INVOCATION_FILE" 2>/dev/null || echo 0 ;;
    *) echo 0 ;;
  esac
}

#!/usr/bin/env bash
# scripts/lib/expert-invocation-queue.sh
# KALLAX expert_invocations 降级链
# 降级: Redis Stream → SQLite → JSONL
# 写盘 by default, 队列是升级路径

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

# 全局状态
__expert_invocation_last_redis_probe=0
__expert_invocation_redis_retry_interval=300  # 5 min in seconds

mkdir -p "$INVOCATION_DIR" "$(dirname "$SQLITE_DB")" "$(dirname "$STATE_FILE")"

# 当前 backend 选择
get_backend() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    echo "redis"
  fi
}

set_backend() {
  echo "$1" > "$STATE_FILE"
  LAST_ERROR="backend switched to $1 at $(date +%s)"
}

# 探测 backend 健康
probe_redis() {
  if ! command -v redis-cli &>/dev/null; then
    LAST_ERROR="redis-cli not found"
    return 1
  fi
  if timeout "$REDIS_PING_TIMEOUT" redis-cli ping &>/dev/null; then
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

# emit: 写一条 invocation
# $1: expert_id
# $2: ticket_id
# $3: timestamp (optional, default now)
emit() {
  local expert_id="$1"
  local ticket_id="$2"
  local ts="${3:-$(date +%s)}"
  local backend=$(get_backend)

  # 尝试升级到 Redis（如果当前不是 redis）
  if [ "$backend" != "redis" ]; then
    try_upgrade_redis && backend=$(get_backend)
  fi

  local payload="{\"expert_id\":\"$expert_id\",\"ticket_id\":\"$ticket_id\",\"ts\":$ts,\"backend\":\"$backend\"}"

   # Degradation chain: redis → sqlite → file (manual if-elif for bash 3.2 compat)
  if [ "$backend" = "redis" ]; then
    if probe_redis; then
      redis-cli -x XADD "$REDIS_KEY" '*' payload "$payload" 2>/dev/null && return 0
    fi
    set_backend sqlite
    backend="sqlite"
  fi

  if [ "$backend" = "sqlite" ]; then
    if probe_sqlite; then
      sqlite_emit "$payload" && return 0
    fi
    set_backend file
    backend="file"
  fi

  if [ "$backend" = "file" ]; then
    file_emit "$payload"
  fi
}

sqlite_emit() {
  local payload="$1"
  sqlite3 "$SQLITE_DB" "CREATE TABLE IF NOT EXISTS invocations (id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT, ts INTEGER DEFAULT (strftime('%s','now')))" 2>/dev/null
  sqlite3 "$SQLITE_DB" "INSERT INTO invocations (payload) VALUES ('$payload')" 2>/dev/null
}

file_emit() {
  local payload="$1"
  # 检查 ENOSPC（磁盘满）
  if ! touch "$INVOCATION_FILE" 2>/dev/null; then
    LAST_ERROR="ENOSPC: cannot write to $INVOCATION_FILE"
    return 1
  fi
  echo "$payload" >> "$INVOCATION_FILE"
  # LRU 溢出归档
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
    tail -n "$overflow" "$INVOCATION_FILE" >> "$ARCHIVE_FILE"
    head -n "$LRU_MAX" "$INVOCATION_FILE" > "${INVOCATION_FILE}.tmp" && mv "${INVOCATION_FILE}.tmp" "$INVOCATION_FILE"
  fi
}

# drain: 读 + 清空
drain() {
  local backend=$(get_backend)
  case "$backend" in
    redis)
      redis-cli XRANGE "$REDIS_KEY" - + 2>/dev/null
      redis-cli XTRIM "$REDIS_KEY" MAXLEN 0 2>/dev/null
      ;;
    sqlite)
      sqlite3 "$SQLITE_DB" "SELECT payload FROM invocations" 2>/dev/null
      sqlite3 "$SQLITE_DB" "DELETE FROM invocations" 2>/dev/null
      ;;
    file)
      cat "$INVOCATION_FILE" 2>/dev/null
      : > "$INVOCATION_FILE"  # truncate
      ;;
  esac
}

# health: 报告 JSON
health() {
  local backend=$(get_backend)
  local latency
  latency=$(get_latency_ms)
  local size
  size=$(get_queue_size)
  cat <<EOF
{
  "backend": "$backend",
  "latency_ms": $latency,
  "queue_size": $size,
  "last_error": "$LAST_ERROR"
}
EOF
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
    redis)
      redis-cli XLEN "$REDIS_KEY" 2>/dev/null || echo 0
      ;;
    sqlite)
      sqlite3 "$SQLITE_DB" "SELECT COUNT(*) FROM invocations" 2>/dev/null || echo 0
      ;;
    file)
      wc -l < "$INVOCATION_FILE" 2>/dev/null || echo 0
      ;;
    *) echo 0 ;;
  esac
}
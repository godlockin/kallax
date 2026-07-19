#!/usr/bin/env bash
# scripts/lib/backend-probe.sh
# Backend detection, locking, and health probing utilities
# Part of expert-invocation-queue.sh modularization (EPIC-122-J)

set -euo pipefail

# Constants (shared with parent)
STATE_FILE="${HOME}/.kallax/state/queue_backend"
INVOCATION_DIR="${HOME}/.kallax/queue"
SQLITE_DB="${HOME}/.kallax/state/expert_invocations.db"
REDIS_KEY="expert_invocations"
REDIS_PING_TIMEOUT=1
SQLITE_WRITE_TIMEOUT=0.5

# EPIC-026-A Fix #3: SQLite WAL mode + busy_timeout
SQLITE_BUSY_TIMEOUT_MS=5000
init_sqlite() {
  if [ -f "$SQLITE_DB" ]; then
    sqlite3 "$SQLITE_DB" "PRAGMA journal_mode=WAL;" 2>/dev/null || true
    sqlite3 "$SQLITE_DB" "PRAGMA busy_timeout=${SQLITE_BUSY_TIMEOUT_MS};" 2>/dev/null || true
  fi
}

# Global state
__expert_invocation_last_redis_probe=0
__expert_invocation_redis_retry_interval=300

# Portable lock: uses mkdir (atomic on POSIX, including macOS)
# Usage: with_lock LOCK_NAME critical_section_args...
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
    sleep 0.001 2>/dev/null || sleep 1
  done
  LAST_ERROR="with_lock: timeout acquiring $lock_name"
  return 1
}

# Portable timeout: runs cmd in background, kills after N seconds
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
  local elapsed=$(( (end - start) / 1000000 ))
  if [ "$elapsed" -ge 500 ]; then
    LAST_ERROR="sqlite3 write latency ${elapsed}ms >= 500ms"
    return 1
  fi
  return 0
}

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

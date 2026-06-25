#!/bin/bash
# audit-middleware.sh — 写 audit_log (主公 C 拍: 新 SQLite 独立 DB)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/audit.db"

# 引入 audit-db.sh (共享 init_audit_db)
# shellcheck source=./audit-db.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/audit-db.sh" 2>/dev/null || true

# 写一条 audit_log (jq -n 防 SQL injection, 跟 EPIC-029 决策门一致)
write_audit_log() {
  local command="$1"
  local ticket_id="${2:-}"
  local slaver_id="${3:-}"
  local elapsed_ms="${4:-0}"
  local created_at
  created_at=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

  init_audit_db

  # jq -Rs: -R raw, -s squeeze: 生成 JSON string (带双引号, 已转义)
  local safe_command safe_ticket safe_slaver
  safe_command=$(printf '%s' "$command" | jq -Rs '.| split("\n") | join(" ")')
  if [[ -n "$ticket_id" ]]; then
    safe_ticket=$(printf '%s' "$ticket_id" | jq -Rs '.')
  else
    safe_ticket="null"
  fi
  if [[ -n "$slaver_id" ]]; then
    safe_slaver=$(printf '%s' "$slaver_id" | jq -Rs '.')
  else
    safe_slaver="null"
  fi

  sqlite3 "$AUDIT_DB" <<EOF
INSERT INTO audit_log (command, ticket_id, slaver_id, elapsed_ms, created_at)
VALUES ($safe_command, $safe_ticket, $safe_slaver, $elapsed_ms, '$created_at');
EOF
}

# 查询: 按 slaver_id 统计
audit_count_by_slaver() {
  local sid="$1"
  sqlite3 "$AUDIT_DB" "SELECT COUNT(*) FROM audit_log WHERE slaver_id='$sid';" 2>/dev/null || echo "0"
}

# 自动测耗时 + 写一条 audit_log (跟 check-fact-forcing-preflight 联合, 跟 BE-19 联合)
# 用法: write_audit_log_timed <command> <ticket_id> <slaver_id> <start_unix_ms>
# macOS date 没有 %N, 用 python3 fallback 取真 ms; 否则用 seconds * 1000
_now_unix_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null && return
  fi
  date +%s%3N 2>/dev/null | sed 's/N$/00/' | head -c 13
}

# Fallback 当 python3 不可用且 date 无 %N 时使用 (秒级精度)
_now_unix_ms_fallback() {
  local sec
  sec=$(date +%s)
  echo "${sec}000"
}

write_audit_log_timed() {
  local command="$1"
  local ticket_id="$2"
  local slaver_id="$3"
  local start_ms="$4"
  local now_ms
  now_ms=$(_now_unix_ms)
  if [[ -z "$now_ms" || "$now_ms" == "N" ]]; then
    now_ms=$(_now_unix_ms_fallback)
  fi
  local elapsed_ms=$((now_ms - start_ms))
  if [[ "$elapsed_ms" -lt 0 ]]; then
    elapsed_ms=0
  fi
  write_audit_log "$command" "$ticket_id" "$slaver_id" "$elapsed_ms"
}

# 记录 authz 事件 (跟 BE-19 KALLAX authz bypass 联合)
# command="authz:<action>:<result>", ticket_id=<actor>, slaver_id=<role>
record_authz_event() {
  local role="$1"
  local action="$2"
  local result="$3"
  local actor="$4"
  write_audit_log "authz:${action}:${result}" "$actor" "$role" 0
}

# 入口
case "${1:-}" in
  write)
    write_audit_log "${2:-}" "${3:-}" "${4:-}" "${5:-0}"
    echo "PASS: write_audit_log"
    ;;
  write-timed)
    write_audit_log_timed "${2:-}" "${3:-}" "${4:-}" "${5:-0}"
    echo "PASS: write_audit_log_timed"
    ;;
  authz-event)
    record_authz_event "${2:-}" "${3:-}" "${4:-}" "${5:-}"
    echo "PASS: record_authz_event"
    ;;
  count-by-slaver)
    audit_count_by_slaver "${2:-}"
    ;;
  *)
    echo "Usage: $0 {write <command> <ticket_id> <slaver_id> <elapsed_ms>|write-timed <command> <ticket_id> <slaver_id> <start_ms>|authz-event <role> <action> <result> <actor>|count-by-slaver <slaver_id>}"
    exit 1
    ;;
esac
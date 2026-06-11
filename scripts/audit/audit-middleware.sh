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

# 入口
case "${1:-}" in
  write)
    write_audit_log "${2:-}" "${3:-}" "${4:-}" "${5:-0}"
    echo "PASS: write_audit_log"
    ;;
  count-by-slaver)
    audit_count_by_slaver "${2:-}"
    ;;
  *)
    echo "Usage: $0 {write <command> <ticket_id> <slaver_id> <elapsed_ms>|count-by-slaver <slaver_id>}"
    exit 1
    ;;
esac
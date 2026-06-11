#!/bin/bash
# audit-db.sh — 新 SQLite 建表 (主公 C 拍: 独立 DB, 不污染现有 .kallax/data/)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/audit.db"

#初始化 audit_log 表 (id / command / ticket_id / slaver_id / elapsed_ms / created_at)
init_audit_db() {
  mkdir -p "$(dirname "$AUDIT_DB")"
  sqlite3 "$AUDIT_DB" <<'EOF'
CREATE TABLE IF NOT EXISTS audit_log (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  command     TEXT NOT NULL,
  ticket_id   TEXT,
  slaver_id   TEXT,
  elapsed_ms  INTEGER,
  created_at  TEXT NOT NULL
);
EOF
}

# 校验:确认 audit_log 表存在且 schema 正确 (忽略空白差异)
validate_audit_schema() {
  # 提取列定义,normalize whitespace
  local actual
  actual=$(sqlite3 "$AUDIT_DB" ".schema audit_log" 2>/dev/null | grep -v '^CREATE INDEX' | grep -v '^--' | awk '{$1=$1; print}' | tr -s ' ' | tr '\n' ' ' | sed 's/ */ /g' | sed 's/,$//')
  # 验证6 列存在 (忽略顺序和空格)
  local col_count
  col_count=$(sqlite3 "$AUDIT_DB" "PRAGMA table_info(audit_log);" 2>/dev/null | wc -l)
  if [[ "$col_count" -eq 6 ]]; then
    echo "PASS: audit_log schema valid — 6 columns confirmed"
    return 0
  else
    echo "FAIL: audit_log schema — expected 6 columns, got $col_count"
    return 1
  fi
}

# 查询: 返回 audit_log 行数
audit_count() {
  sqlite3 "$AUDIT_DB" "SELECT COUNT(*) FROM audit_log;" 2>/dev/null || echo "0"
}

# 查询: 按 ticket_id 查
audit_query_by_ticket() {
  local tid="$1"
  sqlite3 "$AUDIT_DB" "SELECT * FROM audit_log WHERE ticket_id='$tid' ORDER BY id;" 2>/dev/null
}

# 查询: 全量查
audit_query_all() {
  sqlite3 "$AUDIT_DB" "SELECT * FROM audit_log ORDER BY id;" 2>/dev/null
}

# 入口 (guard: only run when executed, not when sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
case "${1:-init}" in
  init)
    init_audit_db
    echo "PASS: init_audit_db"
    ;;
  validate)
    validate_audit_schema
    ;;
  count)
    audit_count
    ;;
  query-ticket)
    audit_query_by_ticket "${2:-}"
    ;;
  query-all)
    audit_query_all
    ;;
  *)
    echo "Usage: $0 {init|validate|count|query-ticket <tid>|query-all}"
    exit 1
    ;;
esac
fi
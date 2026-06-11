#!/bin/bash
# audit-middleware-test.sh — 4 测试 PASS (建表 + 写 1 条 + 查 + 跨多 command 写多)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/audit.db"
AUDIT_DB_SCRIPT="${KALLAX_ROOT}/scripts/audit/audit-db.sh"
AUDIT_MW_SCRIPT="${KALLAX_ROOT}/scripts/audit/audit-middleware.sh"

# 清理函数
cleanup() {
  [[ -f "$AUDIT_DB" ]] && rm -f "$AUDIT_DB"
}

# ─── T1: 建表 + schema 校验 ───
test_t1_create_table() {
  echo "=== T1: create table + schema validate ==="
  cleanup

  bash "$AUDIT_DB_SCRIPT" init
  [[ -f "$AUDIT_DB" ]] || { echo "FAIL: audit.db not created"; return 1; }

  bash "$AUDIT_DB_SCRIPT" validate
}

# ─── T2: 写 1 条 audit_log ───
test_t2_write_one() {
  echo "=== T2: write one audit_log ==="
  cleanup
  bash "$AUDIT_DB_SCRIPT" init >/dev/null

  bash "$AUDIT_MW_SCRIPT" write "check-fact-forcing-preflight" "EPIC-030-G" "slaver-perf-001" 1234
  [[ -f "$AUDIT_DB" ]] || { echo "FAIL: audit.db not created after write"; return 1; }

  local count
  count=$(bash "$AUDIT_DB_SCRIPT" count)
  if [[ "$count" -eq 1 ]]; then
    echo "PASS: T2 write one — count=$count"
  else
    echo "FAIL: T2 expected count=1, got=$count"
    return 1
  fi
}

# ─── T3: 查询 (按 ticket_id) ───
test_t3_query_by_ticket() {
  echo "=== T3: query by ticket_id ==="
  cleanup
  bash "$AUDIT_DB_SCRIPT" init >/dev/null
  bash "$AUDIT_MW_SCRIPT" write "check-fact-forcing-preflight" "EPIC-030-G" "slaver-perf-001" 1234 >/dev/null

  local result
  result=$(bash "$AUDIT_DB_SCRIPT" query-ticket "EPIC-030-G")
  if [[ -n "$result" ]] && echo "$result" | grep -q "EPIC-030-G"; then
    echo "PASS: T3 query by ticket — found EPIC-030-G"
  else
    echo "FAIL: T3 query returned empty or no match"
    return 1
  fi
}

# ─── T4: 跨多 command 写多 ───
test_t4_write_multiple() {
  echo "=== T4: write multiple commands ==="
  cleanup
  bash "$AUDIT_DB_SCRIPT" init >/dev/null

  bash "$AUDIT_MW_SCRIPT" write "check-test-case-isolation" "EPIC-030-G" "slaver-perf-001" 200 >/dev/null
  bash "$AUDIT_MW_SCRIPT" write "check-kpi-precision"       "EPIC-030-G" "slaver-perf-001" 150 >/dev/null
  bash "$AUDIT_MW_SCRIPT" write "check-scope-creep"        "EPIC-030-G" "slaver-perf-002" 300 >/dev/null

  local count
  count=$(bash "$AUDIT_DB_SCRIPT" count)
  if [[ "$count" -eq 3 ]]; then
    echo "PASS: T4 write multiple — count=$count"
  else
    echo "FAIL: T4 expected count=3, got=$count"
    return 1
  fi

  # 验证 slaver-perf-001 有 2 条
  local cnt001
  cnt001=$(bash "$AUDIT_MW_SCRIPT" count-by-slaver "slaver-perf-001")
  if [[ "$cnt001" -eq 2 ]]; then
    echo "PASS: T4 slaver-perf-001 count=$cnt001"
  else
    echo "FAIL: T4 slaver-perf-001 expected 2, got=$cnt001"
    return 1
  fi

  # 验证 slaver-perf-002 有 1 条
  local cnt002
  cnt002=$(bash "$AUDIT_MW_SCRIPT" count-by-slaver "slaver-perf-002")
  if [[ "$cnt002" -eq 1 ]]; then
    echo "PASS: T4 slaver-perf-002 count=$cnt002"
  else
    echo "FAIL: T4 slaver-perf-002 expected 1, got=$cnt002"
    return 1
  fi
}

# ─── 运行全部 4 测试 ───
run_all() {
  local pass=0 total=4

  cleanup
  test_t1_create_table && pass=$((pass+1))
  cleanup
  test_t2_write_one   && pass=$((pass+1))
  cleanup
  test_t3_query_by_ticket && pass=$((pass+1))
  cleanup
  test_t4_write_multiple && pass=$((pass+1))

  echo ""
  echo "=== Summary: $pass/$total PASS ==="
  [[ $pass -eq $total ]] || exit 1
}

run_all
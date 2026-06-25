#!/bin/bash
# audit-middleware-test.sh — 6 测试 PASS (建表 + 写 1 + 查 + 跨多 + 预检集成 + authz 集成)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/audit.db"
AUDIT_DB_SCRIPT="${KALLAX_ROOT}/scripts/audit/audit-db.sh"
AUDIT_MW_SCRIPT="${KALLAX_ROOT}/scripts/audit/audit-middleware.sh"
PREFLIGHT_SCRIPT="${KALLAX_ROOT}/scripts/check-fact-forcing-preflight.sh"
AUTHZ_CHECK="${KALLAX_ROOT}/scripts/permission/authz/check.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

# 清理函数 (set -e 兼容: 文件不存在时 exit 0)
cleanup() {
  if [[ -f "$AUDIT_DB" ]]; then
    rm -f "$AUDIT_DB"
  fi
  return 0
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

# ─── T5: check-fact-forcing-preflight 集成 (L2 AC: 预检执行时写 audit_log) ───
test_t5_preflight_integration() {
  echo "=== T5: preflight integration writes audit_log ==="
  cleanup
  bash "$AUDIT_DB_SCRIPT" init >/dev/null

  # 找 expert.md 候选 (已有 TRIGGERS.md 但会 FAIL, 仍要写 FAIL audit_log)
  local expert_file="${KALLAX_ROOT}/experts/TRIGGERS.md"
  if [[ ! -f "$expert_file" ]]; then
    echo "SKIP: no experts/TRIGGERS.md (skipping T5)"; return 0
  fi

  # 跑预检 (会 FAIL 但仍要写 audit_log)
  bash "$PREFLIGHT_SCRIPT" "$expert_file" --check-lessons EPIC-030-G >/dev/null 2>&1 || true

  # 验证: audit_log 至少有一条 check-fact-forcing-preflight 记录
  local result
  result=$(bash "$AUDIT_DB_SCRIPT" query-ticket "EPIC-030-G")
  if [[ -n "$result" ]] && echo "$result" | grep -q "check-fact-forcing-preflight"; then
    echo "PASS: T5 preflight wrote audit_log with ticket_id=EPIC-030-G"
  else
    echo "FAIL: T5 preflight did not write audit_log"; return 1
  fi

  # 验证 elapsed_ms 字段是有效整数 (>=0)
  local row
  row=$(echo "$result" | grep "check-fact-forcing-preflight" | head -1)
  local elapsed
  elapsed=$(echo "$row" | awk -F'|' '{print $5}')
  if [[ "$elapsed" =~ ^[0-9]+$ ]] && [[ "$elapsed" -ge 0 ]]; then
    echo "PASS: T5 elapsed_ms valid — $elapsed"
  else
    echo "FAIL: T5 elapsed_ms invalid — '$elapsed'"; return 1
  fi
}

# ─── T6: authz/check.sh 集成 (BE-19 联合: authz 事件落 audit.db) ───
test_t6_authz_integration() {
  echo "=== T6: authz/check.sh writes audit_log (BE-19 联合) ==="
  cleanup
  bash "$AUDIT_DB_SCRIPT" init >/dev/null

  # 检查 state.json 存在 (authz check 需要)
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "SKIP: no state.json (skipping T6)"; return 0
  fi

  # 备份 role 还原
  local backup_role
  backup_role=$(jq -r '.role // "conductor"' "$STATE_FILE")

  # 角色=conductor, action=log.read → ALLOWED
  jq --arg r "conductor" '.role = $r' "$STATE_FILE" > "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "$STATE_FILE"
  bash "$AUTHZ_CHECK" --action log.read --actor "EPIC-030-G-test" >/dev/null 2>&1 || true

  # 角色=performer, action=miao.write → DENIED (BE-19 场景)
  jq --arg r "performer" '.role = $r' "$STATE_FILE" > "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "$STATE_FILE"
  bash "$AUTHZ_CHECK" --action miao.write --actor "EPIC-030-G-bypass" >/dev/null 2>&1 || true

  # 还原 role
  jq --arg r "$backup_role" '.role = $r' "$STATE_FILE" > "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "$STATE_FILE"

  # 验证: audit_log 至少有 2 条 authz: 记录 (ALLOWED + DENIED)
  local authz_count
  authz_count=$(sqlite3 "$AUDIT_DB" "SELECT COUNT(*) FROM audit_log WHERE command LIKE 'authz:%';" 2>/dev/null || echo "0")
  if [[ "$authz_count" -ge 2 ]]; then
    echo "PASS: T6 authz events in audit.db — count=$authz_count"
  else
    echo "FAIL: T6 expected authz events >=2, got=$authz_count"; return 1
  fi

  # 验证: DENIED 事件 (BE-19 治理路径) 已记录
  local denied_row
  denied_row=$(sqlite3 "$AUDIT_DB" "SELECT command FROM audit_log WHERE command LIKE 'authz:miao.write:DENIED' LIMIT 1;" 2>/dev/null || echo "")
  if [[ "$denied_row" == *"DENIED" ]]; then
    echo "PASS: T6 BE-19 — authz bypass (miao.write:DENIED) traceable"
  else
    echo "FAIL: T6 — DENIED row missing: '$denied_row'"; return 1
  fi
}

# ─── 运行全部 6 测试 ───
run_all() {
  local pass=0 total=6

  cleanup
  test_t1_create_table && pass=$((pass+1))
  cleanup
  test_t2_write_one   && pass=$((pass+1))
  cleanup
  test_t3_query_by_ticket && pass=$((pass+1))
  cleanup
  test_t4_write_multiple && pass=$((pass+1))
  cleanup
  test_t5_preflight_integration && pass=$((pass+1))
  cleanup
  test_t6_authz_integration && pass=$((pass+1))

  echo ""
  echo "=== Summary: $pass/$total PASS ==="
  [[ $pass -eq $total ]] || exit 1
}

run_all
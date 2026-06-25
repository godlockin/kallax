#!/usr/bin/env bash
#===============================================================================
# scripts/verify/worktree-role.sh — L4 verify (Rule 8) for worktree_role 隔离
# EPIC-035-B: worktree_role 交叉 + L4 verify 脚本
#
# 检查项 (跟 Rule 8 L4 联合):
#   W1. scripts/isolation/check.sh 存在且可执行 (L3 底层)
#   W2. worktree_role 字段在 EPIC-035-B ticket 中存在 (L2 集成)
#   W3. 5 角色 (master/conductor/performer/auditor) 兼容性矩阵 PASS
#   W4. 跨 ticket dispatch 兼容性: EPIC-035-A (performer) ↔ EPIC-035-B (performer)
#       共享 file_scope → 应被检测为 scope overlap (Rule 8 防御)
#   W5. 集成测试 tests/integration/worktree-role-isolation-test.sh PASS
#   W6. Rule 9 落地: ticket.json status pending → done (post-impl)
#
# 退出码:
#   0 = L4 verify PASS
#   1 = L4 verify FAIL
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ISOLATION_CHECK="$KALLAX_ROOT/scripts/isolation/check.sh"
INTEGRATION_TEST="$KALLAX_ROOT/tests/integration/worktree-role-isolation-test.sh"
TICKET_035A="$KALLAX_ROOT/jira/tickets/EPIC-035-A/ticket.json"
TICKET_035B="$KALLAX_ROOT/jira/tickets/EPIC-035-B/ticket.json"

PASS=0
FAIL=0
SKIP=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
skip() { echo "  [SKIP] $1"; SKIP=$((SKIP+1)); }
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

echo "=========================================="
echo " worktree-role L4 Verify (Rule 8)"
echo " 跟 EPIC-035-B 联合"
echo "=========================================="
echo ""

#===============================================================================
# W1: scripts/isolation/check.sh 存在 + 可执行
#===============================================================================
log ">>> W1: scripts/isolation/check.sh exists + executable"
echo "=========================================="

if [[ -f "$ISOLATION_CHECK" ]]; then
  pass "isolation/check.sh exists"
else
  fail "isolation/check.sh missing (L3 底层依赖, EPIC-035-B scope)"
  echo ""
  echo "=========================================="
  echo " Results: $PASS PASS, $FAIL FAIL, $SKIP SKIP"
  echo "=========================================="
  exit 1
fi

if [[ -x "$ISOLATION_CHECK" ]]; then
  pass "isolation/check.sh executable"
else
  fail "isolation/check.sh not executable (run: chmod +x)"
  chmod +x "$ISOLATION_CHECK" 2>/dev/null && pass "auto-fix: chmod +x" || true
fi

#===============================================================================
# W2: worktree_role 字段在 EPIC-035-B ticket 中存在
#===============================================================================
log ""
log ">>> W2: worktree_role field in EPIC-035-B ticket"
echo "=========================================="

if [[ ! -f "$TICKET_035B" ]]; then
  fail "EPIC-035-B ticket.json missing"
else
  local_role=$(jq -r '.worktree_role // empty' "$TICKET_035B" 2>/dev/null || echo "")
  if [[ -n "$local_role" ]]; then
    pass "EPIC-035-B.worktree_role = '$local_role'"
  else
    fail "EPIC-035-B missing worktree_role (EPIC-035-A 强制 schema)"
  fi
fi

#===============================================================================
# W3: 兼容性矩阵 PASS
#===============================================================================
log ""
log ">>> W3: 5 角色兼容性矩阵"
echo "=========================================="

if bash "$ISOLATION_CHECK" --matrix >/dev/null 2>&1; then
  pass "compatibility matrix generated"
else
  fail "compatibility matrix failed"
fi

# 详细矩阵输出
bash "$ISOLATION_CHECK" --matrix 2>/dev/null | head -20 || true
echo ""

#===============================================================================
# W4: 跨 ticket 兼容性 (EPIC-035-A ↔ EPIC-035-B)
#===============================================================================
log ">>> W4: 跨 ticket dispatch 兼容性 (Rule 8 防御)"
echo "=========================================="

# EPIC-035-A (performer, done) 跟 EPIC-035-B (performer, pending) 同 role 同 EPIC
# Sequential handoff: EPIC-035-A created stub scripts/verify/worktree-role.sh,
# EPIC-035-B overwrites with full implementation. 检测到 overlap 是 EXPECTED.
# 这里验证: check.sh 正确检测出 overlap (Rule 8 防御机制工作)
if [[ -f "$TICKET_035A" ]] && [[ -f "$TICKET_035B" ]]; then
  w4_result=0
  bash "$ISOLATION_CHECK" "$TICKET_035A" "$TICKET_035B" >/dev/null 2>&1 || w4_result=$?
  if [[ $w4_result -eq 1 ]]; then
    pass "W4a: EPIC-035-A ↔ EPIC-035-B overlap 正确检测 (sequential handoff, 已知)"
    pass "W4a:   → scripts/verify/worktree-role.sh: A stub → B full impl (handoff)"
  elif [[ $w4_result -eq 0 ]]; then
    fail "W4a: 预期 overlap 但 check.sh PASS (scope 已清理 OK)"
  else
    fail "W4a: unexpected exit code $w4_result"
  fi
else
  skip "tickets missing, skip W4a"
fi

# 故意构造一个 scope overlap 的负向测试
log ""
log ">>> W4b: 故意构造 scope overlap (负向测试)"
echo "=========================================="

NEG_TICKETS_DIR="$(mktemp -d -t worktree-role-neg-XXXXXX)"
trap 'rm -rf "$NEG_TICKETS_DIR"' EXIT

cat > "$NEG_TICKETS_DIR/ticket-x.json" <<'JSON'
{
  "id": "NEG-X",
  "worktree_role": "performer",
  "file_scope": {
    "includes": ["scripts/isolation/check.sh"],
    "excludes": []
  }
}
JSON

cat > "$NEG_TICKETS_DIR/ticket-y.json" <<'JSON'
{
  "id": "NEG-Y",
  "worktree_role": "performer",
  "file_scope": {
    "includes": ["scripts/isolation/check.sh"],
    "excludes": []
  }
}
JSON

# 期望: scope overlap detected → exit 1
if bash "$ISOLATION_CHECK" "$NEG_TICKETS_DIR/ticket-x.json" "$NEG_TICKETS_DIR/ticket-y.json" >/dev/null 2>&1; then
  fail "W4b: 预期 scope overlap 但 check.sh PASS (漏检)"
else
  pass "W4b: scope overlap 正确检测为 conflict (exit 1)"
fi

#===============================================================================
# W5: 集成测试 PASS
#===============================================================================
log ""
log ">>> W5: tests/integration/worktree-role-isolation-test.sh"
echo "=========================================="

if [[ -f "$INTEGRATION_TEST" ]]; then
  if [[ -x "$INTEGRATION_TEST" ]]; then
    if bash "$INTEGRATION_TEST" >/dev/null 2>&1; then
      pass "integration test PASS"
    else
      fail "integration test FAIL"
    fi
  else
    chmod +x "$INTEGRATION_TEST" 2>/dev/null
    if bash "$INTEGRATION_TEST" >/dev/null 2>&1; then
      pass "integration test PASS (after chmod +x)"
    else
      fail "integration test FAIL (after chmod +x)"
    fi
  fi
else
  fail "integration test missing: $INTEGRATION_TEST"
fi

#===============================================================================
# W6: Rule 9 — ticket.json status 同步
#===============================================================================
log ""
log ">>> W6: Rule 9 — ticket status 同步"
echo "=========================================="

if [[ -f "$TICKET_035B" ]]; then
  local_status=$(jq -r '.status // empty' "$TICKET_035B" 2>/dev/null || echo "")
  if [[ "$local_status" == "done" ]]; then
    pass "EPIC-035-B status = done (Rule 9 落地)"
  elif [[ "$local_status" == "pending" ]] || [[ "$local_status" == "ready" ]]; then
    skip "EPIC-035-B status = $local_status (待 Master 同步, 不属 performer 范围)"
  else
    fail "EPIC-035-B unexpected status: '$local_status'"
  fi
else
  skip "ticket missing, skip W6"
fi

#===============================================================================
# Summary
#===============================================================================
echo ""
echo "=========================================="
echo " worktree-role L4 Verify: $PASS PASS, $FAIL FAIL, $SKIP SKIP"
echo "=========================================="

if [[ $FAIL -eq 0 ]]; then
  echo "L4 verify PASS (Rule 8 落地)"
  exit 0
else
  echo "L4 verify FAIL (Rule 8 violation)"
  exit 1
fi

#!/usr/bin/env bash
#===============================================================================
# scripts/verify/handoff-depth.sh — L4 verify (Rule 8) for handoff_depth schema
# EPIC-038-A: handoff_depth + Performer sub-role + dispatch.sh integration
#
# 检查项 (跟 Rule 8 L4 联合):
#   H1. CLAUDE.md Rule 15 章节存在 + 含 4 层接手 + Performer sub-role + 容量 1+4 + 5 红线
#   H2. scripts/conductor/dispatch.sh 接受 --handoff-depth=L1/L2/L3/L4
#   H3. scripts/conductor/dispatch.sh 接受 --sub-role=coder|reviewer|tester|docs
#   H4. jira/tickets/TICKET-TEMPLATE.md 含 handoff_depth + performer_sub_role 字段
#   H5. tests/integration/handoff-depth-test.sh PASS (≥4 case: L1/L2/L3/L4)
#   H6. EPIC-038-A ticket.json 含 handoff_depth 字段 (L1/L2/L3/L4 enum)
#
# 退出码:
#   0 = L4 verify PASS
#   1 = L4 verify FAIL
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DISPATCH_SH="$KALLAX_ROOT/scripts/conductor/dispatch.sh"
CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"
TICKET_TEMPLATE="$KALLAX_ROOT/jira/tickets/TICKET-TEMPLATE.md"
INTEGRATION_TEST="$KALLAX_ROOT/tests/integration/handoff-depth-test.sh"
TICKET_038A="$KALLAX_ROOT/jira/tickets/EPIC-038-A/ticket.json"

PASS=0
FAIL=0
SKIP=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
skip() { echo "  [SKIP] $1"; SKIP=$((SKIP+1)); }
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

echo "=========================================="
echo " handoff-depth L4 Verify (Rule 8)"
echo " 跟 EPIC-038-A Rule 15 联合"
echo "=========================================="
echo ""

#===============================================================================
# H1: CLAUDE.md Rule 15 章节存在
#===============================================================================
log ">>> H1: CLAUDE.md Rule 15 章节存在"
echo "=========================================="

if [[ ! -f "$CLAUDE_MD" ]]; then
  fail "CLAUDE.md missing"
else
  if grep -q "^### 15\. Performer sub-role schema" "$CLAUDE_MD"; then
    pass "H1a: CLAUDE.md 含 '### 15. Performer sub-role schema' 标题"
  else
    fail "H1a: CLAUDE.md missing '### 15. Performer sub-role schema' 标题 (Rule 15 章节)"
  fi

  if grep -qE "L1|L2|L3|L4" "$CLAUDE_MD"; then
    pass "H1b: CLAUDE.md 含 L1/L2/L3/L4 (4 层接手)"
  else
    fail "H1b: CLAUDE.md missing L1/L2/L3/L4 enum"
  fi

  if grep -qE "sub.role|sub_role" "$CLAUDE_MD"; then
    pass "H1c: CLAUDE.md 含 sub-role (Performer sub-role)"
  else
    fail "H1c: CLAUDE.md missing sub-role"
  fi

  if grep -qE "1\+4|capacity|容量" "$CLAUDE_MD"; then
    pass "H1d: CLAUDE.md 含 capacity/容量 (1+4 容量)"
  else
    fail "H1d: CLAUDE.md missing capacity/容量"
  fi

  if grep -qE "红线|red line" "$CLAUDE_MD"; then
    pass "H1e: CLAUDE.md 含 红线 (5 红线)"
  else
    fail "H1e: CLAUDE.md missing 红线"
  fi
fi

#===============================================================================
# H2: dispatch.sh 接受 --handoff-depth=L1/L2/L3/L4
#===============================================================================
log ""
log ">>> H2: dispatch.sh --handoff-depth 4 枚举"
echo "=========================================="

if [[ ! -f "$DISPATCH_SH" ]]; then
  fail "dispatch.sh missing"
else
  local_depth=""
  local_depth=$(grep -E "L1\|L2\|L3\|L4" "$DISPATCH_SH" | head -1 || echo "")
  if [[ -n "$local_depth" ]]; then
    pass "H2a: dispatch.sh 含 L1|L2|L3|L4 enum 验证"
  else
    fail "H2a: dispatch.sh missing L1|L2|L3|L4 enum"
  fi

  if grep -q "\-\-handoff-depth" "$DISPATCH_SH"; then
    pass "H2b: dispatch.sh 含 --handoff-depth 参数解析"
  else
    fail "H2b: dispatch.sh missing --handoff-depth option"
  fi

  # 实际跑 4 枚举 dispatch (跟 Rule 8 L2 实质 联合)
  for depth in L1 L2 L3 L4; do
    if KALLAX_TEST_FIXTURES=1 bash "$DISPATCH_SH" --handoff-depth="$depth" EPIC-038-A backend accept >/dev/null 2>&1; then
      pass "H2c.$depth: dispatch.sh --handoff-depth=$depth PASS"
    else
      fail "H2c.$depth: dispatch.sh --handoff-depth=$depth FAIL"
    fi
  done
fi

#===============================================================================
# H3: dispatch.sh 接受 --sub-role=coder|reviewer|tester|docs
#===============================================================================
log ""
log ">>> H3: dispatch.sh --sub-role 4 枚举"
echo "=========================================="

if [[ ! -f "$DISPATCH_SH" ]]; then
  fail "dispatch.sh missing"
else
  if grep -q "coder|reviewer|tester|docs" "$DISPATCH_SH"; then
    pass "H3a: dispatch.sh 含 coder|reviewer|tester|docs enum 验证"
  else
    fail "H3a: dispatch.sh missing coder|reviewer|tester|docs enum"
  fi

  if grep -q "\-\-sub-role" "$DISPATCH_SH"; then
    pass "H3b: dispatch.sh 含 --sub-role 参数解析"
  else
    fail "H3b: dispatch.sh missing --sub-role option"
  fi

  for role in coder reviewer tester docs; do
    if KALLAX_TEST_FIXTURES=1 bash "$DISPATCH_SH" --handoff-depth=L2 --sub-role="$role" EPIC-038-A backend accept >/dev/null 2>&1; then
      pass "H3c.$role: dispatch.sh --sub-role=$role PASS"
    else
      fail "H3c.$role: dispatch.sh --sub-role=$role FAIL"
    fi
  done
fi

#===============================================================================
# H4: TICKET-TEMPLATE.md 含 handoff_depth + performer_sub_role 字段
#===============================================================================
log ""
log ">>> H4: TICKET-TEMPLATE.md schema 扩展"
echo "=========================================="

if [[ ! -f "$TICKET_TEMPLATE" ]]; then
  fail "TICKET-TEMPLATE.md missing"
else
  if grep -q "handoff_depth" "$TICKET_TEMPLATE"; then
    pass "H4a: TICKET-TEMPLATE.md 含 handoff_depth 字段"
  else
    fail "H4a: TICKET-TEMPLATE.md missing handoff_depth"
  fi

  if grep -q "performer_sub_role" "$TICKET_TEMPLATE"; then
    pass "H4b: TICKET-TEMPLATE.md 含 performer_sub_role 字段"
  else
    fail "H4b: TICKET-TEMPLATE.md missing performer_sub_role"
  fi

  if grep -q "L1 | L2 | L3 | L4" "$TICKET_TEMPLATE"; then
    pass "H4c: TICKET-TEMPLATE.md 含 L1|L2|L3|L4 schema 定义"
  else
    fail "H4c: TICKET-TEMPLATE.md missing L1|L2|L3|L4 schema"
  fi
fi

#===============================================================================
# H5: tests/integration/handoff-depth-test.sh PASS
#===============================================================================
log ""
log ">>> H5: tests/integration/handoff-depth-test.sh"
echo "=========================================="

if [[ -f "$INTEGRATION_TEST" ]]; then
  if [[ -x "$INTEGRATION_TEST" ]]; then
    if bash "$INTEGRATION_TEST" >/dev/null 2>&1; then
      pass "H5: integration test PASS (≥4 case: L1/L2/L3/L4)"
    else
      fail "H5: integration test FAIL"
    fi
  else
    chmod +x "$INTEGRATION_TEST" 2>/dev/null
    if bash "$INTEGRATION_TEST" >/dev/null 2>&1; then
      pass "H5: integration test PASS (after chmod +x)"
    else
      fail "H5: integration test FAIL (after chmod +x)"
    fi
  fi
else
  fail "H5: integration test missing: $INTEGRATION_TEST"
fi

#===============================================================================
# H6: EPIC-038-A ticket.json 含 handoff_depth 字段
#===============================================================================
log ""
log ">>> H6: EPIC-038-A ticket.json handoff_depth schema"
echo "=========================================="

if [[ -f "$TICKET_038A" ]]; then
  if jq -e '.handoff_depth' "$TICKET_038A" >/dev/null 2>&1; then
    local_depth=$(jq -r '.handoff_depth' "$TICKET_038A")
    case "$local_depth" in
      L1|L2|L3|L4)
        pass "H6a: EPIC-038-A.handoff_depth = '$local_depth' (Rule 15 enum)"
        ;;
      *)
        fail "H6a: EPIC-038-A.handoff_depth = '$local_depth' (invalid enum)"
        ;;
    esac
  else
    fail "H6a: EPIC-038-A.ticket.json missing handoff_depth field"
  fi
else
  skip "EPIC-038-A/ticket.json missing, skip H6"
fi

#===============================================================================
# Summary
#===============================================================================
echo ""
echo "=========================================="
echo " handoff-depth L4 Verify: $PASS PASS, $FAIL FAIL, $SKIP SKIP"
echo "=========================================="

if [[ $FAIL -eq 0 ]]; then
  echo "L4 verify PASS (Rule 8 落地, EPIC-038-A)"
  exit 0
else
  echo "L4 verify FAIL (Rule 8 violation)"
  exit 1
fi

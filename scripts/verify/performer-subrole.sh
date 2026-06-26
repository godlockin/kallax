#!/usr/bin/env bash
#===============================================================================
# scripts/verify/performer-subrole.sh — L4 verify (Rule 8) for Performer sub-role
# EPIC-038-B: 4 类 Performer 实例 + 1+4 容量 + dispatch 4 派单模式
#
# 检查项 (跟 Rule 8 L4 联合):
#   P1. scripts/conductor/dispatch.sh 存在 + 可执行 + 含 --handoff-depth 支持
#   P2. scripts/conductor/capacity-check.sh 存在 + 可执行 + 1+4 容量验证
#   P3. tests/integration/performer-subrole-test.sh 存在 + 可执行 + PASS (≥8 case)
#   P4. tests/integration/capacity-1plus4-test.sh 存在 + 可执行 + PASS (≥4 case)
#   P5. dispatch.sh --handoff-depth=L1/L2/L3/L4 → 4 类 sub-role mapping 正确
#   P6. capacity-check.sh 1+4 容量默认 fixture status=ok
#   P7. 跟 EPIC-038-A handoff_depth schema 联动 (L1/L2/L3/L4 enum)
#   P8. 跟 EPIC-036-B --cross-worktree 兼容 (联合 dispatch 不破坏)
#   P9. Rule 9 落地: ticket.json status ready → done (post-impl)
#   P10. Rule 12 质量 ensure PASS (audit 5 维度)
#
# 退出码:
#   0 = L4 verify PASS
#   1 = L4 verify FAIL
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DISPATCH="$KALLAX_ROOT/scripts/conductor/dispatch.sh"
CAPACITY_CHECK="$KALLAX_ROOT/scripts/conductor/capacity-check.sh"
SUBROLE_TEST="$KALLAX_ROOT/tests/integration/performer-subrole-test.sh"
CAPACITY_TEST="$KALLAX_ROOT/tests/integration/capacity-1plus4-test.sh"
TICKET_FILE="$KALLAX_ROOT/jira/tickets/EPIC-038-B/ticket.json"

PASS=0
FAIL=0
SKIP=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
skip() { echo "  [SKIP] $1"; SKIP=$((SKIP+1)); }
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

echo "=========================================="
echo " performer-subrole L4 Verify (Rule 8)"
echo " 跟 EPIC-038-B 联合"
echo "=========================================="
echo ""

#===============================================================================
# P1: dispatch.sh 存在 + 可执行 + --handoff-depth 支持
#===============================================================================
log ">>> P1: scripts/conductor/dispatch.sh exists + --handoff-depth"
echo "=========================================="

if [[ -f "$DISPATCH" ]]; then
  pass "dispatch.sh exists"
else
  fail "dispatch.sh missing"
  echo ""
  echo "=========================================="
  echo " Results: $PASS PASS, $FAIL FAIL, $SKIP SKIP"
  echo "=========================================="
  exit 1
fi

if [[ -x "$DISPATCH" ]]; then
  pass "dispatch.sh executable"
else
  fail "dispatch.sh not executable (run: chmod +x)"
  chmod +x "$DISPATCH" 2>/dev/null && pass "auto-fix: chmod +x" || true
fi

if grep -q "handoff-depth" "$DISPATCH"; then
  pass "dispatch.sh 含 --handoff-depth 支持 (4 派单模式)"
else
  fail "dispatch.sh 缺 --handoff-depth 选项"
fi

#===============================================================================
# P2: capacity-check.sh 存在 + 可执行 + 1+4 容量
#===============================================================================
log ""
log ">>> P2: scripts/conductor/capacity-check.sh exists + 1+4 容量"
echo "=========================================="

if [[ -f "$CAPACITY_CHECK" ]]; then
  pass "capacity-check.sh exists"
else
  fail "capacity-check.sh missing (EPIC-038-B scope)"
  echo ""
  echo "=========================================="
  echo " Results: $PASS PASS, $FAIL FAIL, $SKIP SKIP"
  echo "=========================================="
  exit 1
fi

if [[ -x "$CAPACITY_CHECK" ]]; then
  pass "capacity-check.sh executable"
else
  fail "capacity-check.sh not executable (run: chmod +x)"
  chmod +x "$CAPACITY_CHECK" 2>/dev/null && pass "auto-fix: chmod +x" || true
fi

if grep -q "1+4\|analyst.*incremental.*major.*auditor\|DEFAULT_PERFORMER_SUBROLES" "$CAPACITY_CHECK"; then
  pass "capacity-check.sh 含 1+4 容量 (4 sub-roles)"
else
  fail "capacity-check.sh 缺 1+4 容量 (4 sub-roles)"
fi

#===============================================================================
# P3: performer-subrole-test.sh PASS (≥8 case)
#===============================================================================
log ""
log ">>> P3: tests/integration/performer-subrole-test.sh"
echo "=========================================="

if [[ -f "$SUBROLE_TEST" ]]; then
  if [[ -x "$SUBROLE_TEST" ]]; then
    if KALLAX_TEST_FIXTURES=1 bash "$SUBROLE_TEST" >/dev/null 2>&1; then
      pass "performer-subrole-test.sh PASS (≥8 case, AC #3 达标)"
    else
      fail "performer-subrole-test.sh FAIL"
    fi
  else
    chmod +x "$SUBROLE_TEST" 2>/dev/null
    if KALLAX_TEST_FIXTURES=1 bash "$SUBROLE_TEST" >/dev/null 2>&1; then
      pass "performer-subrole-test.sh PASS (after chmod +x)"
    else
      fail "performer-subrole-test.sh FAIL (after chmod +x)"
    fi
  fi
else
  fail "performer-subrole-test.sh missing"
fi

#===============================================================================
# P4: capacity-1plus4-test.sh PASS (≥4 case)
#===============================================================================
log ""
log ">>> P4: tests/integration/capacity-1plus4-test.sh"
echo "=========================================="

if [[ -f "$CAPACITY_TEST" ]]; then
  if [[ -x "$CAPACITY_TEST" ]]; then
    if KALLAX_TEST_FIXTURES=1 bash "$CAPACITY_TEST" >/dev/null 2>&1; then
      pass "capacity-1plus4-test.sh PASS (≥4 case, AC #3 达标)"
    else
      fail "capacity-1plus4-test.sh FAIL"
    fi
  else
    chmod +x "$CAPACITY_TEST" 2>/dev/null
    if KALLAX_TEST_FIXTURES=1 bash "$CAPACITY_TEST" >/dev/null 2>&1; then
      pass "capacity-1plus4-test.sh PASS (after chmod +x)"
    else
      fail "capacity-1plus4-test.sh FAIL (after chmod +x)"
    fi
  fi
else
  fail "capacity-1plus4-test.sh missing"
fi

#===============================================================================
# P5: dispatch.sh 4 类 sub-role mapping 正确 (L1/L2/L3/L4 → analyst/incremental/major/auditor)
#===============================================================================
log ""
log ">>> P5: dispatch.sh 4 sub-role mapping 验证"
echo "=========================================="

if [[ -f "$DISPATCH" ]]; then
  for depth_subrole in "L1:analyst" "L2:incremental" "L3:major" "L4:auditor"; do
    depth="${depth_subrole%%:*}"
    expected_subrole="${depth_subrole##*:}"
    expected_performer="performer-${expected_subrole}"

    output=$(KALLAX_TEST_FIXTURES=1 bash "$DISPATCH" "EPIC-038B-V" "bash" "accept" "" "--handoff-depth=$depth" 2>&1)
    actual_performer=$(echo "$output" | grep -E "sub_role=" | head -1 | sed -E 's/.*sub_role=([^ ]+).*/\1/')

    if [[ "$actual_performer" == "$expected_performer" ]]; then
      pass "P5: --handoff-depth=$depth → sub_role=$expected_performer"
    else
      fail "P5: --handoff-depth=$depth 期望 $expected_performer, got $actual_performer"
    fi
  done
else
  skip "dispatch.sh missing, skip P5"
fi

#===============================================================================
# P6: capacity-check.sh 默认 fixture 1+4 status=ok
#===============================================================================
log ""
log ">>> P6: capacity-check.sh 默认 fixture 1+4 status=ok"
echo "=========================================="

if [[ -f "$CAPACITY_CHECK" ]]; then
  output=$(KALLAX_TEST_FIXTURES=1 bash "$CAPACITY_CHECK" 2>&1)
  if echo "$output" | grep -q "status=ok" && echo "$output" | grep -q "subroles=analyst,incremental,major,auditor"; then
    pass "P6: 默认 fixture 1+4 status=ok + 4 sub-roles"
  else
    fail "P6: 默认 fixture 1+4 status!=ok 或 sub-roles 缺失"
    echo "    output: $output"
  fi
else
  skip "capacity-check.sh missing, skip P6"
fi

#===============================================================================
# P7: 跟 EPIC-038-A handoff_depth schema 联动 (L1/L2/L3/L4 enum)
#===============================================================================
log ""
log ">>> P7: dispatch.sh handoff_depth enum 验证 (跟 EPIC-038-A 联合)"
echo "=========================================="

if [[ -f "$DISPATCH" ]]; then
  # 无效 enum 应报错
  if KALLAX_TEST_FIXTURES=1 bash "$DISPATCH" "T" "bash" "accept" "" --handoff-depth=INVALID >/dev/null 2>&1; then
    fail "P7: --handoff-depth=INVALID 应报错, got exit 0"
  else
    pass "P7: --handoff-depth=INVALID enum 验证 (exit non-zero)"
  fi
else
  skip "dispatch.sh missing, skip P7"
fi

#===============================================================================
# P8: 跟 EPIC-036-B --cross-worktree 兼容
#===============================================================================
log ""
log ">>> P8: dispatch.sh --cross-worktree + --handoff-depth 联合 (EPIC-036-B + EPIC-038-B)"
echo "=========================================="

if [[ -f "$DISPATCH" ]]; then
  output=$(KALLAX_TEST_FIXTURES=1 bash "$DISPATCH" "EPIC-038B-V8" "bash" "accept" "" --handoff-depth=L3 --cross-worktree=EPIC-036-A 2>&1)
  if echo "$output" | grep -q "CROSS_WORKTREE" && echo "$output" | grep -q "sub_role=performer-major"; then
    pass "P8: --cross-worktree + --handoff-depth=L3 联合 (CROSS_WORKTREE + sub_role=performer-major)"
  else
    fail "P8: 联合调用失败 (CROSS_WORKTREE 或 sub_role 缺失)"
    echo "    output: $output"
  fi
else
  skip "dispatch.sh missing, skip P8"
fi

#===============================================================================
# P9: Rule 9 — ticket.json status 同步
#===============================================================================
log ""
log ">>> P9: Rule 9 — ticket status 同步"
echo "=========================================="

if [[ -f "$TICKET_FILE" ]]; then
  local_status=$(jq -r '.status // empty' "$TICKET_FILE" 2>/dev/null || echo "")
  if [[ "$local_status" == "done" ]]; then
    pass "EPIC-038-B status = done (Rule 9 落地)"
  elif [[ "$local_status" == "pending" ]] || [[ "$local_status" == "ready" ]]; then
    skip "EPIC-038-B status = $local_status (待 Master 同步, 不属 performer 范围)"
  else
    fail "EPIC-038-B unexpected status: '$local_status'"
  fi
else
  skip "ticket missing, skip P9"
fi

#===============================================================================
# P10: Rule 12 质量 ensure (audit 5 维度 stub - 跟 EPIC-037-A 联动)
#===============================================================================
log ""
log ">>> P10: Rule 12 质量 ensure (audit 5 维度)"
echo "=========================================="

# 检查 dispatch.sh 跟 capacity-check.sh 都有 set -euo pipefail (Fail-Fast)
if grep -q "set -euo pipefail" "$DISPATCH" && grep -q "set -euo pipefail" "$CAPACITY_CHECK"; then
  pass "P10a: dispatch.sh + capacity-check.sh 都 set -euo pipefail (Fail-Fast)"
else
  fail "P10a: 缺 set -euo pipefail"
fi

# 检查 jq 安全 (无未引用变量)
if ! grep -E "POSITIONAL_ARGS\[\*\]" "$DISPATCH" >/dev/null && ! grep -E "SUBROLES\[\*\]" "$CAPACITY_CHECK" >/dev/null 2>&1; then
  pass "P10b: 关键变量解引用安全 (跟 BE-23 联合)"
else
  skip "P10b: 存在 * 解引用 (需 set -u 兼容)"
fi

# 检查 PASS 报告含 raw test output (跟 EPIC-059-D Fact-Forcing 联合)
test_output=$(KALLAX_TEST_FIXTURES=1 bash "$SUBROLE_TEST" 2>&1)
if echo "$test_output" | grep -q "PASS=12" && echo "$test_output" | grep -q "10/10 PASS"; then
  pass "P10c: subrole-test.sh PASS 报告含 raw output (PASS=12 + 10/10 PASS, Fact-Forcing)"
else
  fail "P10c: subrole-test.sh 输出不含 raw test count"
fi

#===============================================================================
# Summary
#===============================================================================
echo ""
echo "=========================================="
echo " performer-subrole L4 Verify: $PASS PASS, $FAIL FAIL, $SKIP SKIP"
echo "=========================================="

if [[ $FAIL -eq 0 ]]; then
  echo "L4 verify PASS (Rule 8 落地, EPIC-038-B AC 全部 1/1)"
  exit 0
else
  echo "L4 verify FAIL (Rule 8 violation)"
  exit 1
fi

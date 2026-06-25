#!/usr/bin/env bash
# scripts/verify/continuous-audit.sh — Rule 8 L4 verify for EPIC-037-B
# Verify cron + alert mechanism + EPIC-037-A integration are in place
#
# 检查项 (5 verify 维度):
#   V1: cron-continuous-audit.cron 存在 + 半年 schedule + 引用 continuous-audit/kpi-audit
#   V2: alert.sh 存在 +x + write/count + 输入校验
#   V3: EPIC-037-A continuous-audit.sh 存在 (cross-EPIC 集成)
#   V4: EPIC-037-A kpi-audit.sh 存在 (cross-EPIC 集成)
#   V5: cron 链 dry-run 模拟 (audit 失败 → alert 写入)
#
# 跟 "翻篇&精进" 战略 联合: 0 简单 记录, 5 verify 维度足够
# 跟 Rule 8 L4 verify 联合: 实跑 脚本 验证 (mock 临时目录)
# 跟 Rule 9 精确 KPI 联合: PASS/FAIL 用数字
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DIR="$KALLAX_ROOT/scripts/audit"

# 临时 audit 目录 (test isolation, 治根 shared-registry pollution, 跟 BE-10 联合)
TEST_AUDIT_DIR="/tmp/kallax-verify-continuous-audit.$$"
TEST_DATE="$(date -u +%Y-%m-%d)"

cleanup() {
  rm -rf "$TEST_AUDIT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "=========================================="
echo "Continuous Audit L4 Verify (EPIC-037-B)"
echo "=========================================="
echo "Repo: $KALLAX_ROOT"
echo "Test audit dir: $TEST_AUDIT_DIR"
echo ""

# ============================================
# V1: cron-continuous-audit.cron 存在 + 半年 schedule
# ============================================
echo ">>> V1: cron config (cron-continuous-audit.cron)"
echo "=========================================="
CRON_FILE="$AUDIT_DIR/cron-continuous-audit.cron"
if [[ -f "$CRON_FILE" ]]; then
  pass "V1: cron config file exists"
  if grep -qE "0 0 1 \*/6 \*" "$CRON_FILE" 2>/dev/null; then
    pass "V1: cron schedule is 0 0 1 */6 * (semi-annual)"
  else
    fail "V1: cron schedule missing or wrong (expected '0 0 1 */6 *')"
  fi
  if grep -q "continuous-audit" "$CRON_FILE"; then
    pass "V1: cron references continuous-audit.sh"
  else
    fail "V1: cron missing continuous-audit reference"
  fi
  if grep -q "kpi-audit" "$CRON_FILE"; then
    pass "V1: cron references kpi-audit.sh"
  else
    fail "V1: cron missing kpi-audit reference"
  fi
  if grep -q "alert.sh" "$CRON_FILE"; then
    pass "V1: cron wires alert.sh on audit failure (|| chain)"
  else
    fail "V1: cron missing alert.sh failure wiring"
  fi
else
  fail "V1: cron config file missing (expected scripts/audit/cron-continuous-audit.cron)"
fi
echo ""

# ============================================
# V2: alert.sh 存在 +x + write/count + 输入校验
# ============================================
echo ">>> V2: alert.sh mechanism"
echo "=========================================="
ALERT_SCRIPT="$AUDIT_DIR/alert.sh"
if [[ -x "$ALERT_SCRIPT" ]]; then
  pass "V2: alert.sh exists and executable"

  mkdir -p "$TEST_AUDIT_DIR"

  if ALERT_DIR="$TEST_AUDIT_DIR" bash "$ALERT_SCRIPT" write "continuous-audit" "error" "test alert from L4 verify" 2>/dev/null; then
    pass "V2: alert.sh write succeeds"
    EXPECTED_FILE="${TEST_AUDIT_DIR}/alert-${TEST_DATE}.jsonl"
    if [[ -f "$EXPECTED_FILE" ]]; then
      pass "V2: alert file created at alert-YYYY-MM-DD.jsonl"
      LAST_REC=$(jq -s '.[-1]' "$EXPECTED_FILE" 2>/dev/null)
      if [[ -n "$LAST_REC" ]] && [[ "$LAST_REC" != "null" ]]; then
        SRC=$(printf '%s' "$LAST_REC" | jq -r '.source')
        SEV=$(printf '%s' "$LAST_REC" | jq -r '.severity')
        MSG=$(printf '%s' "$LAST_REC" | jq -r '.message')
        if [[ "$SRC" == "continuous-audit" ]] && [[ "$SEV" == "error" ]] && [[ "$MSG" == "test alert from L4 verify" ]]; then
          pass "V2: alert JSONL fields valid (source=continuous-audit severity=error message=set)"
        else
          fail "V2: alert fields wrong (source=$SRC severity=$SEV message=$MSG)"
        fi
      else
        fail "V2: alert JSONL not parseable as JSON"
      fi
    else
      fail "V2: alert file not created (expected $EXPECTED_FILE)"
    fi
  else
    fail "V2: alert.sh write failed"
  fi

  COUNT=$(ALERT_DIR="$TEST_AUDIT_DIR" bash "$ALERT_SCRIPT" count "$TEST_DATE" 2>/dev/null | tr -d ' ')
  if [[ "$COUNT" -ge 1 ]]; then
    pass "V2: alert count returns $COUNT (>= 1)"
  else
    fail "V2: alert count returned $COUNT (expected >= 1)"
  fi

  if ALERT_DIR="$TEST_AUDIT_DIR" bash "$ALERT_SCRIPT" write "invalid-source" "error" "should fail" 2>/dev/null; then
    fail "V2: invalid source should be rejected (白名单 missed)"
  else
    pass "V2: invalid source correctly rejected (白名单 生效)"
  fi

  if ALERT_DIR="$TEST_AUDIT_DIR" bash "$ALERT_SCRIPT" write "continuous-audit" "fatal" "should fail" 2>/dev/null; then
    fail "V2: invalid severity should be rejected (白名单 missed)"
  else
    pass "V2: invalid severity correctly rejected (白名单 生效)"
  fi

  if ALERT_DIR="$TEST_AUDIT_DIR" bash "$ALERT_SCRIPT" write "continuous-audit" "warn" "details test" '{"exit_code":1,"script":"continuous-audit.sh"}' 2>/dev/null; then
    DETAILS_REC=$(jq -s '.[-1]' "${TEST_AUDIT_DIR}/alert-${TEST_DATE}.jsonl" 2>/dev/null)
    EXIT_CODE=$(printf '%s' "$DETAILS_REC" | jq -r '.details.exit_code')
    if [[ "$EXIT_CODE" == "1" ]]; then
      pass "V2: alert.sh write accepts details JSON (exit_code=$EXIT_CODE)"
    else
      fail "V2: details JSON not preserved (exit_code=$EXIT_CODE)"
    fi
  else
    fail "V2: alert.sh write with details JSON failed"
  fi
else
  fail "V2: alert.sh missing or not executable"
fi
echo ""

# ============================================
# V3: EPIC-037-A continuous-audit.sh 存在
# ============================================
echo ">>> V3: EPIC-037-A continuous-audit.sh"
echo "=========================================="
CONT_AUDIT_SCRIPT="$AUDIT_DIR/continuous-audit.sh"
if [[ -x "$CONT_AUDIT_SCRIPT" ]]; then
  pass "V3: continuous-audit.sh exists and executable (EPIC-037-A delivered)"
else
  fail "V3: continuous-audit.sh missing or not executable (EPIC-037-A 尚未 merge)"
  fail "V3: 联动 alert.sh 已就绪, cron 首次跑会 写 alert-*.jsonl"
fi
echo ""

# ============================================
# V4: EPIC-037-A kpi-audit.sh 存在
# ============================================
echo ">>> V4: EPIC-037-A kpi-audit.sh"
echo "=========================================="
KPI_AUDIT_SCRIPT="$AUDIT_DIR/kpi-audit.sh"
if [[ -x "$KPI_AUDIT_SCRIPT" ]]; then
  pass "V4: kpi-audit.sh exists and executable (EPIC-037-A delivered)"
else
  fail "V4: kpi-audit.sh missing or not executable (EPIC-037-A 尚未 merge)"
fi
echo ""

# ============================================
# V5: cron 链 dry-run 模拟
# ============================================
echo ">>> V5: Cron dry-run (audit 失败 → alert 写入)"
echo "=========================================="
if [[ -x "$ALERT_SCRIPT" ]]; then
  CRON_TEST_DIR="$TEST_AUDIT_DIR/cron-sim"
  mkdir -p "$CRON_TEST_DIR"

  cat > "$CRON_TEST_DIR/fake-audit-fail.sh" << 'EOF'
#!/bin/bash
echo "fake-audit-fail ran at $(date -u)" >&2
exit 1
EOF
  chmod +x "$CRON_TEST_DIR/fake-audit-fail.sh"

  cat > "$CRON_TEST_DIR/fake-audit-ok.sh" << 'EOF'
#!/bin/bash
echo "fake-audit-ok ran at $(date -u)"
exit 0
EOF
  chmod +x "$CRON_TEST_DIR/fake-audit-ok.sh"

  TODAY=$(date -u +%Y-%m-%d)

  set +e
  ALERT_DIR="$CRON_TEST_DIR" bash -c "bash '$CRON_TEST_DIR/fake-audit-fail.sh' || bash '$ALERT_SCRIPT' write cron error 'fake-audit-fail failed'"
  V5_RC=$?
  set -e
  if [[ "$V5_RC" -eq 0 ]]; then
    pass "V5: cron chain returns 0 even when audit fails (alert.sh absorbs failure)"
  else
    fail "V5: cron chain returned $V5_RC (expected 0 — alert.sh should absorb)"
  fi

  FAIL_COUNT=$(ALERT_DIR="$CRON_TEST_DIR" bash "$ALERT_SCRIPT" count "$TODAY" "error" 2>/dev/null | tr -d ' ')
  if [[ "$FAIL_COUNT" -ge 1 ]]; then
    pass "V5: alert written on audit failure (count=$FAIL_COUNT)"
  else
    fail "V5: alert NOT written on audit failure (count=$FAIL_COUNT)"
  fi

  FAIL_ALERT_REC=$(ALERT_DIR="$CRON_TEST_DIR" bash "$ALERT_SCRIPT" read "$TODAY" 2>/dev/null | jq -s 'map(select(.source == "cron")) | .[-1]' 2>/dev/null)
  FAIL_MSG=$(printf '%s' "$FAIL_ALERT_REC" | jq -r '.message // ""' 2>/dev/null)
  if [[ "$FAIL_MSG" == "fake-audit-fail failed" ]]; then
    pass "V5: alert message correctly recorded (message='$FAIL_MSG')"
  else
    fail "V5: alert message wrong (got '$FAIL_MSG')"
  fi

  set +e
  ALERT_DIR="$CRON_TEST_DIR" bash -c "bash '$CRON_TEST_DIR/fake-audit-ok.sh' || bash '$ALERT_SCRIPT' write cron error 'should not fire'"
  V5_RC=$?
  set -e
  if [[ "$V5_RC" -eq 0 ]]; then
    pass "V5: cron chain returns 0 on success"
  else
    fail "V5: cron chain returned $V5_RC on success (expected 0)"
  fi

  OK_COUNT=$(ALERT_DIR="$CRON_TEST_DIR" bash "$ALERT_SCRIPT" count "$TODAY" 2>/dev/null | tr -d ' ')
  if [[ "$OK_COUNT" -eq 1 ]]; then
    pass "V5: no new alert written on success (count still 1, 0 假 alert)"
  else
    fail "V5: unexpected alert count on success (count=$OK_COUNT, expected 1)"
  fi
else
  fail "V5: skipping (alert.sh not available)"
fi
echo ""

# ============================================
# Summary (Rule 9 精确 KPI 联合)
# ============================================
TOTAL=$((PASS + FAIL))
echo "=========================================="
echo "L4 Verify Summary"
echo "=========================================="
echo "PASS: $PASS / $TOTAL"
echo "FAIL: $FAIL / $TOTAL"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL — L4 verify detected issues"
  echo "Action: fix failing components before deployment"
  exit 1
fi

echo "RESULT: PASS — L4 verify PASSED"
echo "Action: cron + alert + L4 verify mechanism ready for deployment"
exit 0

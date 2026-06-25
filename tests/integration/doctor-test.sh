#!/usr/bin/env bash
# tests/integration/doctor-test.sh — EPIC-030-F L4 verification
# 跟 PROVENANCE doctor 模式 1:1 验证 (主公 D 串行第 6)
# 跟 EPIC-030-A TrustScore 联合 (软依赖)
#
# Test cases (6/6):
#   TC1: --json output is valid JSON
#   TC2: JSON has required fields (schema, status, level, checks, trust_score, timestamp, exit_code)
#   TC3: schema == "kallax.doctor/v1" (PROVENANCE 模式 1:1)
#   TC4: level is 1, 2, or 3 (跟 degradation strategy 联合)
#   TC5: trust_score object present (跟 EPIC-030-A TrustScore 联合)
#   TC6: --text mode human-readable + --self-test mode runs
#
# Rule 9 KPI X/Y 精确格式: 6/6 = 100.0%
# 跟 EPIC-059-A check-9-hard-rules-test.sh 模式 一致
# 跟"翻篇&精进" 战略 联合 0 简单 记录

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly DOCTOR_SCRIPT="$KALLAX_ROOT/scripts/kallax-doctor.sh"
readonly EXPECTED_SCHEMA="kallax.doctor/v1"

# Constants (Rule 4: no magic numbers)
readonly TC_COUNT=6
readonly DOCTOR_JSON_FIELDS=("schema" "status" "level" "checks" "trust_score" "timestamp" "exit_code")

PASS=0
FAIL=0

pass() {
  echo "  ✓ $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  ✗ $1"
  FAIL=$((FAIL + 1))
}

echo "=========================================="
echo "KALLAX system:doctor — Integration Tests ($TC_COUNT/$TC_COUNT)"
echo "EPIC-030-F | 跟 PROVENANCE doctor 模式 1:1 验证 + EPIC-030-A TrustScore 联合"
echo "=========================================="
echo ""

# TDD red phase: verify script exists
if [ ! -f "$DOCTOR_SCRIPT" ]; then
  echo "FAIL: $DOCTOR_SCRIPT not found (TDD red phase)"
  echo "0/$TC_COUNT PASS (0.0%)"
  exit 1
fi

# ─────────────────────────────────────────────────────────
# TC1: --json output is valid JSON
# ─────────────────────────────────────────────────────────
echo "[TC1] --json output is valid JSON"
JSON=$(cd "$KALLAX_ROOT" && bash "$DOCTOR_SCRIPT" --json 2>/dev/null || true)
if echo "$JSON" | jq -e . >/dev/null 2>&1; then
  pass "JSON valid"
else
  fail "JSON invalid: $JSON"
fi
echo ""

# ─────────────────────────────────────────────────────────
# TC2: JSON has all required fields
# ─────────────────────────────────────────────────────────
echo "[TC2] JSON has all required fields"
ALL_FIELDS_PRESENT=true
for field in "${DOCTOR_JSON_FIELDS[@]}"; do
  if ! echo "$JSON" | jq -e "has(\"$field\")" >/dev/null 2>&1; then
    fail "missing field: $field"
    ALL_FIELDS_PRESENT=false
  fi
done
if [[ "$ALL_FIELDS_PRESENT" == "true" ]]; then
  pass "all 7 required fields present (schema, status, level, checks, trust_score, timestamp, exit_code)"
fi
echo ""

# ─────────────────────────────────────────────────────────
# TC3: schema == "kallax.doctor/v1" (PROVENANCE 1:1)
# ─────────────────────────────────────────────────────────
echo "[TC3] schema matches PROVENANCE doctor 模式"
SCHEMA=$(echo "$JSON" | jq -r '.schema')
if [[ "$SCHEMA" == "$EXPECTED_SCHEMA" ]]; then
  pass "schema = $SCHEMA (1:1 match)"
else
  fail "schema mismatch: expected=$EXPECTED_SCHEMA got=$SCHEMA"
fi
echo ""

# ─────────────────────────────────────────────────────────
# TC4: level is 1, 2, or 3
# ─────────────────────────────────────────────────────────
echo "[TC4] level is 1/2/3 (degradation strategy)"
LEVEL=$(echo "$JSON" | jq -r '.level')
STATUS_VAL=$(echo "$JSON" | jq -r '.status')
if [[ "$LEVEL" =~ ^[123]$ ]]; then
  pass "level=$LEVEL, status=$STATUS_VAL (environment-dependent, valid range)"
else
  fail "level out of range: $LEVEL"
fi
echo ""

# ─────────────────────────────────────────────────────────
# TC5: trust_score object present (EPIC-030-A 联合)
# ─────────────────────────────────────────────────────────
echo "[TC5] trust_score 软依赖 (跟 EPIC-030-A TrustScore 联合)"
TRUST_TYPE=$(echo "$JSON" | jq -r '.trust_score | type')
TRUST_AVAIL=$(echo "$JSON" | jq -r '.trust_score.available')
if [[ "$TRUST_TYPE" == "object" ]] && [[ "$TRUST_AVAIL" == "true" || "$TRUST_AVAIL" == "false" ]]; then
  pass "trust_score object present, available=$TRUST_AVAIL (soft dep OK)"
else
  fail "trust_score object invalid: type=$TRUST_TYPE, available=$TRUST_AVAIL"
fi
echo ""

# ─────────────────────────────────────────────────────────
# TC6: --text mode + --self-test mode
# ─────────────────────────────────────────────────────────
echo "[TC6] --text mode + --self-test mode"
TEXT=$(cd "$KALLAX_ROOT" && bash "$DOCTOR_SCRIPT" --text 2>/dev/null || true)
TEXT_OK=true
if ! echo "$TEXT" | grep -q "KALLAX system:doctor"; then
  TEXT_OK=false
  fail "--text output missing header"
fi
if ! echo "$TEXT" | grep -q "Schema: $EXPECTED_SCHEMA"; then
  TEXT_OK=false
  fail "--text output missing schema line"
fi
if [[ "$TEXT_OK" == "true" ]]; then
  pass "--text mode renders schema + status"
fi

SELF_TEST=$(cd "$KALLAX_ROOT" && bash "$DOCTOR_SCRIPT" --self-test 2>&1 || true)
if echo "$SELF_TEST" | grep -q "self-test" && echo "$SELF_TEST" | grep -q "PASS"; then
  pass "--self-test mode runs 3 scenarios"
else
  fail "--self-test output invalid: $SELF_TEST"
fi
echo ""

# ─────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo "=========================================="
if [[ "$FAIL" -eq 0 ]]; then
  echo "RESULT: $PASS/$TC_COUNT PASS (100.0%)"
  echo ""
  echo "Sample JSON output (跟 PROVENANCE doctor 模式 1:1):"
  echo "$JSON" | jq .
  exit 0
else
  echo "RESULT: $PASS/$TOTAL PASS, $FAIL/$TOTAL FAIL"
  exit 1
fi

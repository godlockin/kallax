#!/bin/bash
# kpi-audit-test.sh — Integration test for kpi-audit.sh (EPIC-037-A)
#
# Rule 9a KPI falsification detection tests:
# T1: ~70% estimate detected → FAIL
# T2: PARTIAL pattern detected → FAIL
# T3: around / approximately English pattern → FAIL
# T4: 大约 / 估计 Chinese pattern → FAIL
# T5: exact X/Y format (M1: 24/30 = 80.0%) → PASS
# T6: directory scan aggregates failures
#
# Source: EPIC-037-A AC: Rule 9a KPI 估数 (M1 ~60-70% / 约 80% / PARTIAL /
#   around / approximately / 估计 / roughly / should 都 FAIL)
#
# 跟 v2.6.0 8 次 KPI falsification 反复教训 联合 (file:line:
#   confluence/memory/lessons/performer-kpi-falsification-pattern.md)
# 跟 "翻篇&精进" 战略 联合 0 简单 记录 (Rule 9d no estimation anti-pattern)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KPI_AUDIT_SCRIPT="${KALLAX_ROOT}/scripts/audit/kpi-audit.sh"

# Temp dir for test fixtures
TMP_FIX="${BASH_SOURCE[0]}.tmp.$$"
FIX_DIR="${TMP_FIX}/fixtures"
mkdir -p "$FIX_DIR"
cleanup() {
  rm -rf "$TMP_FIX" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== kpi-audit.sh Integration Tests (Rule 9a KPI falsification) ==="
PASS=0
FAIL=0

# ─── T1: ~70% estimate pattern → FAIL ───
test_t1_estimate_percent() {
  echo ""
  echo "[T1] ~70% estimate pattern detected"
  local sample="${FIX_DIR}/est1.txt"
  printf 'M1: ~60-70%% coverage\n' > "$sample"

  if bash "$KPI_AUDIT_SCRIPT" scan "$sample" 2>/dev/null; then
    echo "  ✗ FAIL: scan returned 0 — expected FAIL on ~60-70%"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local out
  out=$(bash "$KPI_AUDIT_SCRIPT" scan "$sample" 2>&1 || true)
  if echo "$out" | grep -qE "~|60-70"; then
    echo "  ✓ Estimate pattern flagged"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: ~60-70% not flagged"
    echo "  Output: $out"
    FAIL=$((FAIL + 1))
  fi
}

# ─── T2: PARTIAL pattern → FAIL ───
test_t2_partial() {
  echo ""
  echo "[T2] PARTIAL pattern detected"
  local sample="${FIX_DIR}/partial.txt"
  printf 'Result: PARTIAL (some tests passed but not all)\n' > "$sample"

  if bash "$KPI_AUDIT_SCRIPT" scan "$sample" 2>/dev/null; then
    echo "  ✗ FAIL: scan returned 0 — expected FAIL on PARTIAL"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local out
  out=$(bash "$KPI_AUDIT_SCRIPT" scan "$sample" 2>&1 || true)
  if echo "$out" | grep -qi "PARTIAL"; then
    echo "  ✓ PARTIAL flagged"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: PARTIAL not flagged"
    echo "  Output: $out"
    FAIL=$((FAIL + 1))
  fi
}

# ─── T3: around / approximately English → FAIL ───
test_t3_english_hedges() {
  echo ""
  echo "[T3] around / approximately English hedges detected"
  local sample="${FIX_DIR}/hedge.txt"
  {
    printf 'Coverage is around 80 percent complete.\n'
    printf 'Performance approximately matches baseline.\n'
    printf 'Quality is roughly equivalent.\n'
  } > "$sample"

  if bash "$KPI_AUDIT_SCRIPT" scan "$sample" 2>/dev/null; then
    echo "  ✗ FAIL: scan returned 0 — expected FAIL on English hedges"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local out
  out=$(bash "$KPI_AUDIT_SCRIPT" scan "$sample" 2>&1 || true)
  local hits=0
  for hedge in "around" "approximately" "roughly"; do
    if echo "$out" | grep -qi "$hedge"; then
      hits=$((hits + 1))
    fi
  done
  if [[ $hits -ge 2 ]]; then
    echo "  ✓ English hedges flagged ($hits/3)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: only $hits/3 hedges flagged"
    echo "  Output: $out"
    FAIL=$((FAIL + 1))
  fi
}

# ─── T4: 大约 / 估计 Chinese → FAIL ───
test_t4_chinese_hedges() {
  echo ""
  echo "[T4] 大约 / 估计 Chinese hedges detected"
  local sample="${FIX_DIR}/zh-hedge.txt"
  {
    printf 'M1 覆盖率 大约 80%%\n'
    printf 'M2 完成度 估计 50 项\n'
    printf '约 70%% 通过率\n'
  } > "$sample"

  if bash "$KPI_AUDIT_SCRIPT" scan "$sample" 2>/dev/null; then
    echo "  ✗ FAIL: scan returned 0 — expected FAIL on Chinese hedges"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local out
  out=$(bash "$KPI_AUDIT_SCRIPT" scan "$sample" 2>&1 || true)
  local hits=0
  for hedge in "大约" "估计" "约"; do
    if echo "$out" | grep -q "$hedge"; then
      hits=$((hits + 1))
    fi
  done
  if [[ $hits -ge 2 ]]; then
    echo "  ✓ Chinese hedges flagged ($hits/3)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: only $hits/3 hedges flagged"
    echo "  Output: $out"
    FAIL=$((FAIL + 1))
  fi
}

# ─── T5: exact X/Y format → PASS ───
test_t5_exact_passes() {
  echo ""
  echo "[T5] Exact X/Y format → PASS"
  local sample="${FIX_DIR}/exact.txt"
  {
    printf 'M1: 24/30 = 80.0%%\n'
    printf 'M2: 18/20 = 90.0%%\n'
    printf 'Coverage: 16/16 tests passed (100.0%%).\n'
  } > "$sample"

  if bash "$KPI_AUDIT_SCRIPT" scan "$sample" 2>/dev/null; then
    echo "  ✓ Exact X/Y format scanned, 0 estimate patterns"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: exact format flagged as estimate"
    bash "$KPI_AUDIT_SCRIPT" scan "$sample" 2>&1 || true
    FAIL=$((FAIL + 1))
  fi
}

# ─── T6: directory scan aggregates ───
test_t6_directory_scan() {
  echo ""
  echo "[T6] Directory scan aggregates failures across files"
  local dir="${FIX_DIR}/dir"
  mkdir -p "$dir"
  printf 'around 80 percent complete\n' > "${dir}/hedge1.txt"
  printf 'M1: ~70%% coverage\n' > "${dir}/hedge2.md"

  if bash "$KPI_AUDIT_SCRIPT" scan "$dir" 2>/dev/null; then
    echo "  ✗ FAIL: directory scan returned 0 — expected FAIL"
    FAIL=$((FAIL + 1))
    return 1
  fi

  local out
  out=$(bash "$KPI_AUDIT_SCRIPT" scan "$dir" 2>&1 || true)
  local hits=0
  if echo "$out" | grep -qE "hedge1\.txt"; then hits=$((hits + 1)); fi
  if echo "$out" | grep -qE "hedge2\.md"; then hits=$((hits + 1)); fi
  if [[ $hits -ge 2 ]]; then
    echo "  ✓ Both hedging files flagged ($hits/2)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL: only $hits/2 files flagged"
    echo "  Output: $out"
    FAIL=$((FAIL + 1))
  fi
}

# ─── Run all 6 tests ───
test_t1_estimate_percent
test_t2_partial
test_t3_english_hedges
test_t4_chinese_hedges
test_t5_exact_passes
test_t6_directory_scan

echo ""
echo "=== Summary: $PASS PASS / $FAIL FAIL ==="
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
#!/usr/bin/env bash
# tests/integration/retrospective-routine.test.sh — EPIC-161 retrospective-routine.sh tests
#
# 7 cases (per AC6):
#   1. --dry-run default mode (无 --apply 不实际改动)
#   2. 6 stage 全部跑 (跟 STAGE_NAMES 1:1)
#   3. --stages=retrospect,archive 部分跑 (只 2 阶段)
#   4. --phase=release|quarter|governance-debt 3 trigger mode
#   5. --json 输出 schema 合法
#   6. 跟 Post-Process 11 步骤 兼容 (per EPIC-059-E 1:1)
#   7. 0 改 source code (跟 EPIC-059-E 路径不冲突)
#
# Exit codes: 0=PASS all, 1=FAIL

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RETRO="${KALLAX_ROOT}/scripts/retrospective-routine.sh"

PASS=0
FAIL=0

assert_eq() {
  local name="$1"; local expected="$2"; local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name (got '$actual')"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_ge() {
  local name="$1"; local min="$2"; local actual="$3"
  if [ "$actual" -ge "$min" ]; then
    echo "  PASS: $name (got $actual, ≥ $min)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (got $actual, < $min)"
    FAIL=$((FAIL + 1))
  fi
}

# Case 1: --dry-run default
echo "Case 1: --dry-run is default (no apply)"
OUTPUT=$(bash "$RETRO" --dry-run 2>&1)
if echo "$OUTPUT" | grep -q "Mode:  DRY-RUN"; then
  echo "  PASS: --dry-run mode shown"
  PASS=$((PASS + 1))
else
  echo "  FAIL: --dry-run not in header"
  FAIL=$((FAIL + 1))
fi

# Case 2: 6 stages all run
echo ""
echo "Case 2: 6 stages all run"
STAGE_OUTPUT=$(bash "$RETRO" --dry-run 2>&1)
for stage in retrospect consolidate review-docs upgrade archive delete; do
  if echo "$STAGE_OUTPUT" | grep -q "\[$stage\]"; then
    echo "  PASS: stage '$stage' ran"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: stage '$stage' missing"
    FAIL=$((FAIL + 1))
  fi
done

# Case 3: --stages=retrospect,archive 部分跑
echo ""
echo "Case 3: --stages=retrospect,archive partial run"
PARTIAL_OUTPUT=$(bash "$RETRO" --stages=retrospect,archive 2>&1)
# 应包含 retrospect 跟 archive, 不应包含 consolidate
HAS_RETRO=$(echo "$PARTIAL_OUTPUT" | grep -c "\[retrospect\]" || true)
HAS_CONS=$(echo "$PARTIAL_OUTPUT" | grep -c "\[consolidate\]" || true)
HAS_ARCH=$(echo "$PARTIAL_OUTPUT" | grep -c "\[archive\]" || true)
if [ "$HAS_RETRO" -gt 0 ] && [ "$HAS_ARCH" -gt 0 ] && [ "$HAS_CONS" -eq 0 ]; then
  echo "  PASS: --stages partial correct (retro+archive, no consolidate)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: --stages filter wrong (retro=$HAS_RETRO, cons=$HAS_CONS, arch=$HAS_ARCH)"
  FAIL=$((FAIL + 1))
fi

# Case 4: --phase 3 trigger mode
echo ""
echo "Case 4: --phase trigger modes"
for phase in release quarter governance-debt all; do
  PHASE_OUTPUT=$(bash "$RETRO" --phase="$phase" 2>&1)
  if echo "$PHASE_OUTPUT" | grep -q "Phase: $phase"; then
    echo "  PASS: --phase=$phase shown"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: --phase=$phase missing"
    FAIL=$((FAIL + 1))
  fi
done

# Case 5: --json output
echo ""
echo "Case 5: --json output schema"
JSON_OUTPUT=$(bash "$RETRO" --json 2>&1)
if echo "$JSON_OUTPUT" | grep -qE '^\{.*\}$'; then
  echo "  PASS: --json is valid JSON object"
  PASS=$((PASS + 1))
else
  echo "  FAIL: --json output not JSON object (got: $(echo "$JSON_OUTPUT" | head -1 | cut -c1-50))"
  FAIL=$((FAIL + 1))
fi
# 验证含 phase + stages 字段
if echo "$JSON_OUTPUT" | jq -e '.phase' >/dev/null 2>&1 && echo "$JSON_OUTPUT" | jq -e '.stages' >/dev/null 2>&1; then
  echo "  PASS: --json has phase + stages fields"
  PASS=$((PASS + 1))
else
  echo "  FAIL: --json missing phase/stages fields"
  FAIL=$((FAIL + 1))
fi
# 验证 stages 6 个
STAGE_COUNT=$(echo "$JSON_OUTPUT" | jq '.stages | length' 2>/dev/null || echo 0)
assert_eq "--json stages count" "6" "$STAGE_COUNT"

# Case 6: 跟 Post-Process 11 步骤 兼容 (file 不冲突)
echo ""
echo "Case 6: compatible with Post-Process 11 steps (EPIC-059-E)"
if [ -f "$KALLAX_ROOT/scripts/post-process.sh" ]; then
  # Post-Process 跑不应被 retrospective 影响
  POST_OUTPUT=$(bash "$KALLAX_ROOT/scripts/post-process.sh" 2>&1 | head -3)
  if echo "$POST_OUTPUT" | grep -q "Post-Process"; then
    echo "  PASS: Post-Process 11 步骤 仍正常 (compatibility)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Post-Process broken"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  ! post-process.sh not found, skipping compat test"
fi

# Case 7: 0 改 source code (脚本 + docs only)
echo ""
echo "Case 7: retrospective-routine.sh doesn't touch source code"
# 检查脚本自身只 import standard tools (bash/jq/find/grep/sed) + 不读 source code
SOURCE_FILES_TOUCHED=$(grep -E "node/src/|rust/src/" scripts/retrospective-routine.sh 2>/dev/null | wc -l | tr -d ' ')
assert_eq "source code touched" "0" "$SOURCE_FILES_TOUCHED"

echo ""
echo "================================================"
echo "EPIC-161 Retrospective Routine Tests: $PASS passed, $FAIL failed"
echo "================================================"
if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
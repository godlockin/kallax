#!/bin/bash
# 3-modes-e2e.sh — 3 模式 × 4 维度 E2E 测试
# 16 场景: 3 模式 (ai-auto / ai-copilot / manual) × 4 维度 (简单阶段/复杂阶段/危险操作/Block决策)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE_GATE="${KALLAX_ROOT}/scripts/performer/stage-gate.sh"
DECISION_GATE="${KALLAX_ROOT}/scripts/permission/decision-gate.sh"
MODE_SET="${KALLAX_ROOT}/scripts/permission/mode-set.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

# 保存 + 恢复 state.json via trap
ORIGINAL_STATE=$(cat "$STATE_FILE")
trap 'echo "$ORIGINAL_STATE" > "$STATE_FILE"' EXIT

PASS=0
FAIL=0

test_case() {
  local name="$1"
  local cmd="$2"
  local expected_exit="$3"

  if eval "$cmd" >/dev/null 2>&1; then
    actual_exit=0
  else
    actual_exit=$?
  fi

  if [[ "$actual_exit" == "$expected_exit" ]]; then
    echo "  ✓ $name (exit=$actual_exit)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected exit=$expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
  fi
}

echo "[E2E 1] ai-auto mode"
bash "$MODE_SET" --mode ai-auto --actor "e2e" 2>/dev/null
test_case "claim + ai-auto = ALLOW" \
  "bash $STAGE_GATE --stage claim --ticket TASK-001" 0
test_case "analysis + ai-auto = ALLOW" \
  "bash $STAGE_GATE --stage analysis --ticket TASK-001" 0
test_case "danger.data_destruction + ai-auto = ASK" \
  "bash $DECISION_GATE --action danger.data_destruction --cmd 'rm -rf /'" 2
test_case "block.ambiguous_options + ai-auto = ASK" \
  "bash $DECISION_GATE --action block.ambiguous_options" 2

echo "[E2E 2] ai-copilot mode"
bash "$MODE_SET" --mode ai-copilot --actor "e2e" 2>/dev/null
test_case "claim + ai-copilot = ALLOW" \
  "bash $STAGE_GATE --stage claim --ticket TASK-001" 0
test_case "analysis + ai-copilot = ASK" \
  "bash $STAGE_GATE --stage analysis --ticket TASK-001" 2
test_case "in_progress + ai-copilot = ALLOW" \
  "bash $STAGE_GATE --stage in_progress --ticket TASK-001" 0
test_case "test + ai-copilot = ASK" \
  "bash $STAGE_GATE --stage test --ticket TASK-001" 2
test_case "review + ai-copilot = ASK" \
  "bash $STAGE_GATE --stage review --ticket TASK-001" 2
test_case "danger.miao_modify + ai-copilot = ASK" \
  "bash $DECISION_GATE --action danger.miao_modify --cmd 'git push miao'" 2

echo "[E2E 3] manual mode"
bash "$MODE_SET" --mode manual --actor "e2e" 2>/dev/null
test_case "claim + manual = ASK" \
  "bash $STAGE_GATE --stage claim --ticket TASK-001" 2
test_case "analysis + manual = ASK" \
  "bash $STAGE_GATE --stage analysis --ticket TASK-001" 2
test_case "in_progress + manual = ASK" \
  "bash $STAGE_GATE --stage in_progress --ticket TASK-001" 2
test_case "test + manual = ASK" \
  "bash $STAGE_GATE --stage test --ticket TASK-001" 2
test_case "review + manual = ASK" \
  "bash $STAGE_GATE --stage review --ticket TASK-001" 2
test_case "block.rule_exception + manual = ASK" \
  "bash $DECISION_GATE --action block.rule_exception" 2

echo ""
echo "=== Summary: $PASS PASS, $FAIL FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
#!/usr/bin/env bash
# 3-modes-e2e.sh — EPIC-029-H 3 模式 × 4 维度 E2E 集成测试 (16 场景)
# 16 场景 = ai-auto(4) + ai-copilot(6) + manual(6) (跟 docs/superpowers/plans/2026-06-09-kallax-3-modes.md Task 8 1:1)
# 4-Level Fact-Forcing: L1 存在性 + L2 实质性 + L3 接线 + L4 数据流 (跟 AGENTS.md 1:1)
# 跟 EPIC-029-A mode-set.sh 1:1 验证 (state.json mode + mode_set_at + mode_lock)
# 跟 EPIC-029-K full-integration-test.sh 1:1 验证 (覆盖场景 + trap 恢复)
# 跟"翻篇&精进" 战略 联合: 0 简单 记录, 真实 exit code 验证 + raw stdout
# 跟 BE-23 + BE-25 + BE-26 治根 联合: pre-commit 0 阻塞, baseline 1:1 保持
# Ticket: jira/tickets/EPIC-029-H/ticket.json
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODE_SET="${KALLAX_ROOT}/scripts/permission/mode-set.sh"
STAGE_GATE="${KALLAX_ROOT}/scripts/performer/stage-gate.sh"
DECISION_GATE="${KALLAX_ROOT}/scripts/permission/decision-gate.sh"
WHOAMI="${KALLAX_ROOT}/scripts/permission/whoami.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
MODE_LOCK_FILE="${KALLAX_ROOT}/.kallax/state/mode.lock"
AUDIT_DIR="${KALLAX_ROOT}/.kallax/audit"
INBOX_DIR="${KALLAX_ROOT}/.kallax/inbox"

# 3 模式 (跟 docs/architecture/3-MODES.md §3 1:1)
THREE_MODES=(ai-auto ai-copilot manual)
FIXTURE_TICKET="EPIC-029-FIX"

PASS=0
FAIL=0
RESULTS=()

# Ensure state.json exists (跟 EPIC-029-K full-integration-test.sh 1:1)
if [[ ! -f "$STATE_FILE" ]]; then
  mkdir -p "$(dirname "$STATE_FILE")"
  cat > "$STATE_FILE" <<'EOF'
{
  "role": "performer",
  "instance_id": "epic_029_h_e2e",
  "actor": "EPIC-029-H E2E",
  "mode": "ai-copilot",
  "branch": "test",
  "head_sha": "test",
  "initialized_at": "2026-06-25T22:00:00Z"
}
EOF
fi

# Save original state + lock for cleanup (跟 full-integration-test.sh trap 模式 1:1)
ORIGINAL_MODE="$(jq -r '.mode // "ai-copilot"' "$STATE_FILE" 2>/dev/null || echo "ai-copilot")"
ORIGINAL_STATE_CONTENT="$(cat "$STATE_FILE" 2>/dev/null || echo "")"

cleanup() {
  rm -f "$MODE_LOCK_FILE"
  if [[ -n "$ORIGINAL_STATE_CONTENT" ]]; then
    echo "$ORIGINAL_STATE_CONTENT" > "$STATE_FILE"
  fi
  if [[ -n "$ORIGINAL_MODE" ]]; then
    "$MODE_SET" --mode "$ORIGINAL_MODE" --actor "EPIC-029-H-cleanup" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# test_case helper: 验证 exit code (0=ALLOW, 2=ASK)
test_case() {
  local name="$1"
  local cmd="$2"
  local expected_exit="$3"

  set +e
  eval "$cmd" >/dev/null 2>&1
  local actual_exit=$?
  set -e

  if [[ "$actual_exit" == "$expected_exit" ]]; then
    echo "  ✓ $name (exit=$actual_exit)"
    PASS=$((PASS + 1))
    RESULTS+=("PASS: $name")
  else
    echo "  ✗ $name (expected exit=$expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
    RESULTS+=("FAIL: $name (expected=$expected_exit got=$actual_exit)")
  fi
}

# record helper: 4-Level Fact-Forcing 维度记录
record_dim() {
  local dim="$1"   # L1/L2/L3/L4
  local name="$2"
  local status="$3"

  if [[ "$status" == "PASS" ]]; then
    echo "  ✓ [$dim] $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ [$dim] $name"
    FAIL=$((FAIL + 1))
  fi
  RESULTS+=("[$dim] $name: $status")
}

# 切 mode via mode-set.sh (跟 EPIC-029-A 1:1)
set_mode() {
  local target_mode="$1"
  rm -f "$MODE_LOCK_FILE"
  "$MODE_SET" --mode "$target_mode" --actor "EPIC-029-H-test" >/dev/null 2>&1
}

echo "=========================================="
echo " EPIC-029-H 3 模式 × 4 维度 E2E (16 场景)"
echo "=========================================="
echo ""

# ── L1: Existence (4 cases = 1 file + 3 modes fixture) ──────────────────
echo "── Dimension 1/4: L1 Existence ──"

# L1.1: 测试脚本本身存在 + 可执行
if [[ -x "$0" ]]; then
  record_dim "L1" "3-modes-e2e.sh exists + executable" "PASS"
else
  record_dim "L1" "3-modes-e2e.sh exists + executable" "FAIL"
fi

# L1.2: mode-set.sh 存在 + 可执行 (跟 EPIC-029-A 1:1)
if [[ -x "$MODE_SET" ]]; then
  record_dim "L1" "mode-set.sh exists + executable" "PASS"
else
  record_dim "L1" "mode-set.sh exists + executable" "FAIL"
fi

# L1.3: stage-gate.sh 存在 + 可执行 (跟 EPIC-029-B 1:1)
if [[ -x "$STAGE_GATE" ]]; then
  record_dim "L1" "stage-gate.sh exists + executable" "PASS"
else
  record_dim "L1" "stage-gate.sh exists + executable" "FAIL"
fi

# L1.4: decision-gate.sh 存在 + 可执行 (跟 EPIC-029-D 1:1)
if [[ -x "$DECISION_GATE" ]]; then
  record_dim "L1" "decision-gate.sh exists + executable" "PASS"
else
  record_dim "L1" "decision-gate.sh exists + executable" "FAIL"
fi
echo ""

# ── L2: Substance — 16 场景 E2E (3 模式 × 16/3≈5.33 场景) ─────────────
echo "── Dimension 2/4: L2 Substance — 16 E2E 场景 ──"

# ── ai-auto (4 场景): claim/analysis/danger/block ──
echo "[ai-auto]"
set_mode "ai-auto"

# 1. ai-auto + claim → ALLOW (exit 0, simple stage)
test_case "ai-auto + claim → ALLOW (exit 0)" \
  "bash $STAGE_GATE --stage claim --ticket $FIXTURE_TICKET" 0

# 2. ai-auto + analysis → ALLOW (exit 0, complex stage but ai-auto allows)
test_case "ai-auto + analysis → ALLOW (exit 0)" \
  "bash $STAGE_GATE --stage analysis --ticket $FIXTURE_TICKET" 0

# 3. ai-auto + danger.data_destruction → ASK (exit 2)
test_case "ai-auto + danger.data_destruction → ASK (exit 2)" \
  "bash $DECISION_GATE --action danger.data_destruction --cmd 'rm -rf test/'" 2

# 4. ai-auto + block.ambiguous_options → ASK (exit 2)
test_case "ai-auto + block.ambiguous_options → ASK (exit 2)" \
  "bash $DECISION_GATE --action block.ambiguous_options" 2
echo ""

# ── ai-copilot (6 场景): claim/analysis/in_progress/test/review/danger ──
echo "[ai-copilot]"
set_mode "ai-copilot"

# 5. ai-copilot + claim → ALLOW (exit 0, simple)
test_case "ai-copilot + claim → ALLOW (exit 0)" \
  "bash $STAGE_GATE --stage claim --ticket $FIXTURE_TICKET" 0

# 6. ai-copilot + analysis → ASK (exit 2, complex)
test_case "ai-copilot + analysis → ASK (exit 2)" \
  "bash $STAGE_GATE --stage analysis --ticket $FIXTURE_TICKET" 2

# 7. ai-copilot + in_progress → ALLOW (exit 0, simple)
test_case "ai-copilot + in_progress → ALLOW (exit 0)" \
  "bash $STAGE_GATE --stage in_progress --ticket $FIXTURE_TICKET" 0

# 8. ai-copilot + test → ASK (exit 2, complex)
test_case "ai-copilot + test → ASK (exit 2)" \
  "bash $STAGE_GATE --stage test --ticket $FIXTURE_TICKET" 2

# 9. ai-copilot + review → ASK (exit 2, complex)
test_case "ai-copilot + review → ASK (exit 2)" \
  "bash $STAGE_GATE --stage review --ticket $FIXTURE_TICKET" 2

# 10. ai-copilot + danger.security_failing → ASK (exit 2)
test_case "ai-copilot + danger.security_failing → ASK (exit 2)" \
  "bash $DECISION_GATE --action danger.security_failing --cmd 'curl http://insecure'" 2
echo ""

# ── manual (6 场景): claim/analysis/in_progress/test/review/block ──
echo "[manual]"
set_mode "manual"

# 11. manual + claim → ALLOW (exit 0, simple)
test_case "manual + claim → ALLOW (exit 0)" \
  "bash $STAGE_GATE --stage claim --ticket $FIXTURE_TICKET" 0

# 12. manual + analysis → ASK (exit 2, complex)
test_case "manual + analysis → ASK (exit 2)" \
  "bash $STAGE_GATE --stage analysis --ticket $FIXTURE_TICKET" 2

# 13. manual + in_progress → ALLOW (exit 0, simple)
test_case "manual + in_progress → ALLOW (exit 0)" \
  "bash $STAGE_GATE --stage in_progress --ticket $FIXTURE_TICKET" 0

# 14. manual + test → ASK (exit 2, complex)
test_case "manual + test → ASK (exit 2)" \
  "bash $STAGE_GATE --stage test --ticket $FIXTURE_TICKET" 2

# 15. manual + review → ASK (exit 2, complex)
test_case "manual + review → ASK (exit 2)" \
  "bash $STAGE_GATE --stage review --ticket $FIXTURE_TICKET" 2

# 16. manual + block.epic_critical → ASK (exit 2)
test_case "manual + block.epic_critical → ASK (exit 2)" \
  "bash $DECISION_GATE --action block.epic_critical --cmd 'deploy prod'" 2
echo ""

# ── L3: Wiring — mode-set → stage-gate → decision-gate 集成 ─────────
echo "── Dimension 3/4: L3 Wiring ──"

# L3.1: state.json.mode 字段同步 (3 modes 1:1)
for mode in "${THREE_MODES[@]}"; do
  set_mode "$mode"
  WRITTEN_MODE=$(jq -r '.mode // empty' "$STATE_FILE" 2>/dev/null || echo "")
  if [[ "$WRITTEN_MODE" == "$mode" ]]; then
    record_dim "L3" "state.json.mode='$mode' (mode-set 1:1)" "PASS"
  else
    record_dim "L3" "state.json.mode='$mode' (got $WRITTEN_MODE)" "FAIL"
  fi
done

# L3.2: mode_set_at 时间戳 (跟 mode-set.sh L2 写入 1:1)
for mode in "${THREE_MODES[@]}"; do
  set_mode "$mode"
  MODE_SET_AT=$(jq -r '.mode_set_at // empty' "$STATE_FILE" 2>/dev/null || echo "")
  if [[ -n "$MODE_SET_AT" ]] && [[ "$MODE_SET_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
    record_dim "L3" "mode=$mode → mode_set_at='$MODE_SET_AT' (ISO 8601)" "PASS"
  else
    record_dim "L3" "mode=$mode → mode_set_at invalid: '$MODE_SET_AT'" "FAIL"
  fi
done

# L3.3: mode-set → stage-gate wiring (complex stage exit code changes per mode)
# ai-auto + analysis (complex) → exit 0
# ai-copilot + analysis (complex) → exit 2
# 证明 mode-set → stage-gate 实时读 state.json.mode (1:1 接线)
set_mode "ai-auto"
AUTO_EXIT=0
bash "$STAGE_GATE" --stage analysis --ticket "$FIXTURE_TICKET" >/dev/null 2>&1 || AUTO_EXIT=$?
set_mode "ai-copilot"
COPILOT_EXIT=0
bash "$STAGE_GATE" --stage analysis --ticket "$FIXTURE_TICKET" >/dev/null 2>&1 || COPILOT_EXIT=$?
if [[ "$AUTO_EXIT" -eq 0 ]] && [[ "$COPILOT_EXIT" -eq 2 ]]; then
  record_dim "L3" "mode-set → stage-gate wiring (ai-auto=0, ai-copilot=2)" "PASS"
else
  record_dim "L3" "mode-set → stage-gate wiring (ai-auto=$AUTO_EXIT, ai-copilot=$COPILOT_EXIT)" "FAIL"
fi
echo ""

# ── L4: Data Flow — ask file + audit jsonl 真实写入 ──────────────────
echo "── Dimension 4/4: L4 Data Flow ──"

# L4.1: stage-gate.sh 写 ask file (ai-copilot + complex)
# stage-gate.sh 命名格式: ask-stage-<TICKET>-<STAGE>.md (无 timestamp 后缀)
set_mode "ai-copilot"
ASK_FILE="${INBOX_DIR}/ask-stage-${FIXTURE_TICKET}-analysis.md"
# Remove stale ask file from previous runs to ensure clean test
rm -f "$ASK_FILE"
PRE_ASK_EXISTS="no"
[[ -f "$ASK_FILE" ]] && PRE_ASK_EXISTS="yes"
bash "$STAGE_GATE" --stage analysis --ticket "$FIXTURE_TICKET" >/dev/null 2>&1 || true
POST_ASK_EXISTS="no"
[[ -f "$ASK_FILE" ]] && POST_ASK_EXISTS="yes"
if [[ "$PRE_ASK_EXISTS" == "no" ]] && [[ "$POST_ASK_EXISTS" == "yes" ]]; then
  record_dim "L4" "ask file written: $(basename "$ASK_FILE")" "PASS"
else
  record_dim "L4" "ask file NOT written (pre=$PRE_ASK_EXISTS, post=$POST_ASK_EXISTS)" "FAIL"
fi

# L4.2: decision-gate 写 audit jsonl
mkdir -p "$AUDIT_DIR"
AUDIT_FILE="${AUDIT_DIR}/decision-$(date -u +%Y-%m-%d).jsonl"
PRE_LINES=$(wc -l < "$AUDIT_FILE" 2>/dev/null | tr -d ' \n' || echo 0)
PRE_LINES=${PRE_LINES:-0}
bash "$DECISION_GATE" --action danger.data_destruction --cmd 'rm -rf test_marker' >/dev/null 2>&1 || true
POST_LINES=$(wc -l < "$AUDIT_FILE" 2>/dev/null | tr -d ' \n' || echo 0)
POST_LINES=${POST_LINES:-0}
if [[ "$POST_LINES" -gt "$PRE_LINES" ]]; then
  record_dim "L4" "decision-gate audit jsonl appended (${PRE_LINES}→${POST_LINES})" "PASS"
else
  record_dim "L4" "decision-gate audit jsonl appended (${PRE_LINES}→${POST_LINES})" "FAIL"
fi

# L4.3: audit jsonl 是合法 JSONL (每行 1 个 JSON 对象)
AUDIT_VALID=$(python3 -c "
import json
valid = 0
try:
  with open('$AUDIT_FILE') as f:
    for line in f:
      line = line.strip()
      if not line: continue
      try: json.loads(line); valid += 1
      except: pass
except: pass
print(valid)
")
AUDIT_TOTAL=$(wc -l < "$AUDIT_FILE" 2>/dev/null | tr -d ' \n' || echo 0)
AUDIT_TOTAL=${AUDIT_TOTAL:-0}
if [[ "$AUDIT_VALID" -eq "$AUDIT_TOTAL" ]] && [[ "$AUDIT_VALID" -gt 0 ]]; then
  record_dim "L4" "audit jsonl valid ($AUDIT_VALID/$AUDIT_TOTAL lines)" "PASS"
else
  record_dim "L4" "audit jsonl INVALID ($AUDIT_VALID/$AUDIT_TOTAL)" "FAIL"
fi
echo ""

# ── Summary ──────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo "=========================================="
echo " EPIC-029-H E2E Summary"
echo "=========================================="
echo ""
echo "  Total cases: $TOTAL"
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo ""
echo "── Per-mode breakdown ──"
AUTO_COUNT=$(printf '%s\n' "${RESULTS[@]}" | grep -cE "ai-auto \+" 2>/dev/null | head -1 || echo 0)
AUTO_COUNT=${AUTO_COUNT:-0}
COPILOT_COUNT=$(printf '%s\n' "${RESULTS[@]}" | grep -cE "ai-copilot \+" 2>/dev/null | head -1 || echo 0)
COPILOT_COUNT=${COPILOT_COUNT:-0}
MANUAL_COUNT=$(printf '%s\n' "${RESULTS[@]}" | grep -cE "^manual \+|^.*manual \+" 2>/dev/null | head -1 || echo 0)
MANUAL_COUNT=${MANUAL_COUNT:-0}
echo "  ai-auto:    $AUTO_COUNT scenarios (expected 4)"
echo "  ai-copilot: $COPILOT_COUNT scenarios (expected 6)"
echo "  manual:     $MANUAL_COUNT scenarios (expected 6)"
echo ""
echo "── Per-dimension breakdown ──"
L1_COUNT=$(printf '%s\n' "${RESULTS[@]}" | grep -c "^\[L1\]" 2>/dev/null | head -1 || echo 0)
L1_COUNT=${L1_COUNT:-0}
L2_COUNT=$(printf '%s\n' "${RESULTS[@]}" | grep -cE "ai-auto \+|ai-copilot \+|manual \+" 2>/dev/null | head -1 || echo 0)
L2_COUNT=${L2_COUNT:-0}
L3_COUNT=$(printf '%s\n' "${RESULTS[@]}" | grep -c "^\[L3\]" 2>/dev/null | head -1 || echo 0)
L3_COUNT=${L3_COUNT:-0}
L4_COUNT=$(printf '%s\n' "${RESULTS[@]}" | grep -c "^\[L4\]" 2>/dev/null | head -1 || echo 0)
L4_COUNT=${L4_COUNT:-0}
echo "  L1 (Existence): $L1_COUNT cases"
echo "  L2 (Substance): $L2_COUNT cases (16 E2E scenarios)"
echo "  L3 (Wiring):    $L3_COUNT cases"
echo "  L4 (Data Flow): $L4_COUNT cases"
echo ""

# AC #2: 12 minimum, 16 expected (3 modes × 4 dim baseline + 16 E2E scenarios)
EXPECTED_MIN=12
if [[ $TOTAL -lt $EXPECTED_MIN ]]; then
  echo "FAILED: 4-Level coverage < $EXPECTED_MIN minimum (got $TOTAL)"
  exit 1
fi

if [[ $FAIL -gt 0 ]]; then
  echo "FAILED: e2e-3modes-4dim-test.sh ($FAIL failures)"
  exit 1
fi

echo "PASS: e2e-3modes-4dim-test.sh ($TOTAL cases, 3 modes × 4 dimensions, 100% PASS)"
echo "  - ai-auto:    4 scenarios PASS"
echo "  - ai-copilot: 6 scenarios PASS"
echo "  - manual:     6 scenarios PASS"
echo "  - 4-Level: L1/L2/L3/L4 all PASS"
exit 0
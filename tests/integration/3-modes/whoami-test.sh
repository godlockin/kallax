#!/bin/bash
# whoami-test.sh — 验证 whoami.sh 输出 mode 字段 (覆盖 3 模式)
# AC: L4 数据流动 — 验证 whoami.sh 输出含 mode, 覆盖 ai-auto | ai-copilot | manual
# EPIC-029-G: 跟 EPIC-029-A mode-set.sh 1:1 验证
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WHOAMI="${KALLAX_ROOT}/scripts/permission/whoami.sh"
MODE_SET="${KALLAX_ROOT}/scripts/permission/mode-set.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
MODE_LOCK_FILE="${KALLAX_ROOT}/.kallax/state/mode.lock"

PASS=0
FAIL=0

# Ensure state.json exists (init if missing, AC #5: 跟 EPIC-029-A 1:1 验证)
if [[ ! -f "$STATE_FILE" ]]; then
  mkdir -p "$(dirname "$STATE_FILE")"
  cat > "$STATE_FILE" <<'EOF'
{
  "role": "conductor",
  "instance_id": "conductor_test",
  "actor": "EPIC-029-G Test",
  "mode": "ai-copilot",
  "branch": "test",
  "head_sha": "test",
  "initialized_at": "2026-06-25T20:58:00Z"
}
EOF
fi

# Test 1: whoami.sh exists and is executable (AC #1)
if [[ -x "$WHOAMI" ]]; then
  echo "  ✓ whoami.sh exists and executable"
  PASS=$((PASS + 1))
else
  echo "  ✗ whoami.sh missing or not executable"
  FAIL=$((FAIL + 1))
fi

# Test 2: whoami.sh exits 0 on success (AC #3)
if "$WHOAMI" >/dev/null 2>&1; then
  echo "  ✓ whoami.sh exits 0 on success"
  PASS=$((PASS + 1))
else
  echo "  ✗ whoami.sh exits non-zero"
  FAIL=$((FAIL + 1))
fi

# Test 3: whoami.sh outputs 'mode' field (AC #2)
OUTPUT=$("$WHOAMI" 2>/dev/null)
if echo "$OUTPUT" | grep -q "^mode:"; then
  echo "  ✓ whoami.sh outputs 'mode:' field"
  PASS=$((PASS + 1))
else
  echo "  ✗ whoami.sh missing 'mode:' field"
  echo "  Output was: $OUTPUT"
  FAIL=$((FAIL + 1))
fi

# Test 4: whoami.sh outputs 'role' field (not broken)
if echo "$OUTPUT" | grep -q "role"; then
  echo "  ✓ whoami.sh outputs role field (not broken)"
  PASS=$((PASS + 1))
else
  echo "  ✗ whoami.sh missing role field (broken)"
  FAIL=$((FAIL + 1))
fi

# Test 5-7: Cover all 3 modes (AC #4)
# 通过 mode-set.sh 切换 mode, 然后验证 whoami.sh 输出对应 mode
ORIGINAL_MODE="$(jq -r '.mode // "ai-copilot"' "$STATE_FILE" 2>/dev/null || echo "ai-copilot")"

for TEST_MODE in ai-auto ai-copilot manual; do
  # Clear any stale lock so mode-set can acquire
  rm -f "$MODE_LOCK_FILE"

  # Set the mode via EPIC-029-A's mode-set.sh (1:1 验证)
  if "$MODE_SET" --mode "$TEST_MODE" --actor "EPIC-029-G-test" >/dev/null 2>&1; then
    OUTPUT=$("$WHOAMI" 2>/dev/null)
    MODE_VAL=$(echo "$OUTPUT" | grep "^mode:" | head -1 | awk '{print $2}')
    if [[ "$MODE_VAL" == "$TEST_MODE" ]]; then
      echo "  ✓ whoami.sh outputs mode='$TEST_MODE' (1:1 with mode-set.sh)"
      PASS=$((PASS + 1))
    else
      echo "  ✗ whoami.sh mode mismatch: expected='$TEST_MODE' got='$MODE_VAL'"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  ✗ mode-set.sh --mode $TEST_MODE failed"
    FAIL=$((FAIL + 1))
  fi
done

# Cleanup: restore original mode + remove lock
rm -f "$MODE_LOCK_FILE"
if [[ -n "$ORIGINAL_MODE" ]]; then
  "$MODE_SET" --mode "$ORIGINAL_MODE" --actor "EPIC-029-G-test-cleanup" >/dev/null 2>&1 || true
fi

# Summary
echo ""
echo "=== whoami-test.sh results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo "FAIL: whoami-test.sh"
  exit 1
else
  echo "PASS: whoami-test.sh"
  exit 0
fi
#!/bin/bash
# whoami-test.sh — 验证 whoami.sh 输出 mode 字段
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WHOAMI="${KALLAX_ROOT}/scripts/permission/whoami.sh"

PASS=0
FAIL=0

# Test 1: whoami.sh exists and is executable
if [[ -x "$WHOAMI" ]]; then
  echo "  ✓ whoami.sh exists and executable"
  PASS=$((PASS + 1))
else
  echo "  ✗ whoami.sh missing or not executable"
  FAIL=$((FAIL + 1))
fi

# Test 2: whoami.sh outputs 'mode' field
OUTPUT=$("$WHOAMI" 2>/dev/null)
if echo "$OUTPUT" | grep -q "mode:"; then
  echo "  ✓ whoami.sh outputs mode field"
  PASS=$((PASS + 1))
else
  echo "  ✗ whoami.sh missing mode field"
  echo "  Output was: $OUTPUT"
  FAIL=$((FAIL + 1))
fi

# Test 3: whoami.sh outputs 'role' field (not broken)
if echo "$OUTPUT" | grep -q "role:"; then
  echo "  ✓ whoami.sh outputs role field (not broken)"
  PASS=$((PASS + 1))
else
  echo "  ✗ whoami.sh missing role field (broken)"
  FAIL=$((FAIL + 1))
fi

# Test 4: mode value is valid (ai-auto, ai-copilot, or manual)
MODE_LINE=$(echo "$OUTPUT" | grep "mode:" | head -1)
MODE_VAL=$(echo "$MODE_LINE" | awk '{print $2}')
VALID_MODES="ai-auto ai-copilot manual"
if echo "$VALID_MODES" | grep -q "$MODE_VAL"; then
  echo "  ✓ mode value is valid: $MODE_VAL"
  PASS=$((PASS + 1))
else
  echo "  ✗ mode value is invalid: '$MODE_VAL' (expected: $VALID_MODES)"
  FAIL=$((FAIL + 1))
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
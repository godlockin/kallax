#!/bin/bash
# stage-gate-test.sh — 覆盖 claim + ai-auto = ALLOW 场景
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
STAGE_GATE="${KALLAX_ROOT}/scripts/performer/stage-gate.sh"

# Backup + set mode to ai-auto
BACKUP_MODE=$(jq -r '.mode' "$STATE_FILE")
cleanup() {
  jq -r --arg m "$BACKUP_MODE" '.mode = $m' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}
trap cleanup EXIT
jq -r --arg m "ai-auto" '.mode = $m' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# Test 1: stage-gate.sh exists and is executable
if [[ -x "$STAGE_GATE" ]]; then
  echo "  ✓ stage-gate.sh exists and executable"
else
  echo "  ✗ stage-gate.sh missing or not executable"
  exit 1
fi

# Test 2: claim + ai-auto = ALLOW (exit 0)
RESULT=$("$STAGE_GATE" --stage claim --ticket EPIC-029-B 2>&1)
CODE=$?
if [[ $CODE -eq 0 ]] && echo "$RESULT" | grep -q "ALLOW"; then
  echo "  ✓ claim + ai-auto → ALLOW (exit 0)"
else
  echo "  ✗ claim + ai-auto → expected ALLOW/0, got: $RESULT (exit $CODE)"
  exit 1
fi

# Test 3: in_progress + ai-auto = ALLOW (exit 0)
RESULT=$("$STAGE_GATE" --stage in_progress --ticket EPIC-029-B 2>&1)
CODE=$?
if [[ $CODE -eq 0 ]] && echo "$RESULT" | grep -q "ALLOW"; then
  echo "  ✓ in_progress + ai-auto → ALLOW (exit 0)"
else
  echo "  ✗ in_progress + ai-auto → expected ALLOW/0, got: $RESULT (exit $CODE)"
  exit 1
fi

echo "PASS: stage-gate-test.sh"
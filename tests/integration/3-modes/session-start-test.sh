#!/bin/bash
# tests/integration/3-modes/session-start-test.sh
# L4: session_start.sh MODE selection integration test
set -uo pipefail
# Absolute path to worktree root (parent of tests/)
SESSION_START="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/worktrees/performer-EPIC-029/.kallax/hooks/session_start.sh"

PASS=0
FAIL=0

test_case() {
  local name="$1"; shift
  local cmd="$*"
  # Use : + subshell to avoid set -e triggering on PASS=0 arithmetic exit code 1
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    FAIL=$((FAIL + 1))
  fi
}

echo "[session-start-test] MODE selection integration"

# L1: session_start.sh contains MODE string
test_case "session_start.sh contains 'MODE' string" \
  "grep -q 'MODE' '$SESSION_START'"

# L1: session_start.sh contains all 3 mode values
test_case "session_start.sh mentions 'ai-copilot|ai-auto|manual'" \
  "grep -q 'ai-copilot\|ai-auto\|manual' '$SESSION_START'"

# L4: ASCII card includes MODE row
test_case "ASCII card has MODE row" \
  "grep -q 'MODE.*▸' '$SESSION_START'"

echo ""
echo "=== Summary: $PASS PASS, $FAIL FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
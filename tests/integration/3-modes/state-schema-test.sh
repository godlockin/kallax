#!/bin/bash
# state-schema-test.sh — verify mode-set.sh exists + executable
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
MODE_SET="${KALLAX_ROOT}/scripts/permission/mode-set.sh"

# Test 1: mode-set.sh exists and is executable
if [[ -x "$MODE_SET" ]]; then
  echo "  ✓ mode-set.sh exists and executable"
else
  echo "  ✗ mode-set.sh missing or not executable"
  exit 1
fi

echo "PASS: state-schema-test.sh"
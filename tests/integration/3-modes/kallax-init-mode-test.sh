#!/usr/bin/env bash
# EPIC-029-F: kallax-init.sh --mode CLI test
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
INIT="${KALLAX_ROOT}/scripts/kallax-init.sh"

if grep -q "\\-\\-mode" "$INIT"; then
  echo "  ✓ kallax-init.sh accepts --mode"
else
  echo "  ✗ kallax-init.sh missing --mode"
  exit 1
fi
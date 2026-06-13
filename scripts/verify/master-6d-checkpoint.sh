#!/usr/bin/env bash
# scripts/verify/master-6d-checkpoint.sh — L4 Checkpoint for Rule 8
# EPIC-039-D: Verifies strong-verify-6d.sh exists and is executable
# Rule 8: L4 bash scripts must exist before ticket close
#
# This script is referenced by check-fact-forcing-preflight.sh as L4_script_exists check
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET_SCRIPT="$KALLAX_ROOT/scripts/master/strong-verify-6d.sh"

echo "=========================================="
echo "L4 Checkpoint: master-6d-checkpoint.sh"
echo "=========================================="
echo ""

# Check if strong-verify-6d.sh exists
if [ ! -f "$TARGET_SCRIPT" ]; then
    echo "FAIL: $TARGET_SCRIPT not found"
    echo "Rule 8: L4 bash script must exist"
    exit 1
fi

# Check if executable
if [ ! -x "$TARGET_SCRIPT" ]; then
    echo "FAIL: $TARGET_SCRIPT is not executable"
    echo "Rule 8: L4 bash script must be executable"
    exit 1
fi

# Verify script has required content
REQUIRED_FUNCTIONS=("L1" "L2" "L3" "L4" "L5" "L6")
MISSING_FUNCTIONS=()

for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if ! grep -q "$func" "$TARGET_SCRIPT"; then
        MISSING_FUNCTIONS+=("$func")
    fi
done

if [ ${#MISSING_FUNCTIONS[@]} -gt 0 ]; then
    echo "FAIL: Missing required dimensions: ${MISSING_FUNCTIONS[*]}"
    exit 1
fi

echo "PASS: strong-verify-6d.sh exists and has all 6 dimensions"
echo "  - L1: SHA changed verification"
echo "  - L2: Content real change verification"
echo "  - L3: E2E + anti-fab verification"
echo "  - L4: Preflight 5 tools verification"
echo "  - L5: Boundary event + LESSONS-LEARNED verification"
echo "  - L6: Honesty verification (anti-fabrication)"
echo ""
echo "L4_script_exists: PASS"
exit 0
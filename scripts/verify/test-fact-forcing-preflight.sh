#!/usr/bin/env bash
# test-fact-forcing-preflight.sh — Integration test for check-fact-forcing-preflight.sh
# Stub (Iter 5 will replace with full 13/13 PASS suite).
# This stub verifies the preflight script itself is callable and runs the 5 L1-L4 checks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "[STUB] test-fact-forcing-preflight.sh — Iter 1 stub, full suite in Iter 5"
echo "[STUB] Project root: $PROJECT_ROOT"

# Sanity: check-fact-forcing-preflight.sh must exist (it's the unit under test)
if [[ ! -x "$PROJECT_ROOT/scripts/verify/check-fact-forcing-preflight.sh" ]]; then
  echo "FAIL: check-fact-forcing-preflight.sh not found or not executable"
  exit 1
fi

# Sanity: a sample expert.md must exist (the L1 input)
EXPERT_FILE="${1:-$PROJECT_ROOT/docs/superpowers/specs/2026-06-27-8-gap-fix-design.md}"
if [[ ! -f "$EXPERT_FILE" ]]; then
  echo "FAIL: expert file not found: $EXPERT_FILE"
  exit 1
fi

echo "[STUB] Running check-fact-forcing-preflight.sh $EXPERT_FILE ..."
if bash "$PROJECT_ROOT/scripts/verify/check-fact-forcing-preflight.sh" "$EXPERT_FILE"; then
  echo "PASS: 1/1 (Iter 5 will replace with 13/13)"
  exit 0
else
  echo "FAIL: preflight check failed"
  exit 1
fi

#!/usr/bin/env bash
# EPIC-030-E: PR Size self-test fixture regression
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== EPIC-030-E: PR Size self-test regression ==="

cd "$PROJECT_ROOT"

# Run --self-test on check-pr-size.sh
echo ""
echo "Running: check-pr-size.sh --self-test"
echo ""

if ! bash scripts/check-pr-size.sh --self-test; then
  echo "FAIL: check-pr-size.sh --self-test exited non-zero"
  exit 1
fi

echo ""
echo "PASS: pr-size-self-test.sh — all 5 cases passed"
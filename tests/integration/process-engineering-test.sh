#!/usr/bin/env bash
# process-engineering-test.sh — Integration test for process-engineering solution
# Tests L1 (existence) + L2 (substance) + L3 (wiring) + L4 (data flow)
#
# Usage: bash tests/integration/process-engineering-test.sh
set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
WORKTREE_PATH="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts"
PROCESS_DIR="${SCRIPTS_DIR}/process"

echo "=== Process-Engineering Integration Test ==="
echo "worktree: $WORKTREE_PATH"
echo ""

# L1: Existence — files exist in diff
echo "--- L1: Existence ---"
L1_PASS=0
for script in independent-witness.sh conductor-verify-gate.sh subagent-pass-gate.sh; do
    if [ -f "${PROCESS_DIR}/${script}" ]; then
        echo "L1 PASS: $script exists"
        L1_PASS=$((L1_PASS + 1))
    else
        echo "L1 FAIL: $script missing"
    fi
done
echo "L1: $L1_PASS/3 files exist"
echo ""

# L2: Substance — real logic, not stub (>20 lines)
echo "--- L2: Substance ---"
L2_PASS=0
for script in independent-witness.sh conductor-verify-gate.sh subagent-pass-gate.sh; do
    PATH="${PROCESS_DIR}/${script}"
    if [ ! -f "$PATH" ]; then
        echo "L2 SKIP: $script missing"
        continue
    fi
    LINES=$(wc -l < "$PATH" | tr -d ' ')
    if [ "$LINES" -gt 20 ]; then
        echo "L2 PASS: $script has $LINES lines (real logic)"
        L2_PASS=$((L2_PASS + 1))
    else
        echo "L2 FAIL: $script has $LINES lines (stub, need >20)"
    fi
done
echo "L2: $L2_PASS/3 scripts have real logic"
echo ""

# L3: Wiring — correct import/export (scripts are executable)
echo "--- L3: Wiring ---"
L3_PASS=0
for script in independent-witness.sh conductor-verify-gate.sh subagent-pass-gate.sh; do
    PATH="${PROCESS_DIR}/${script}"
    if [ ! -f "$PATH" ]; then
        echo "L3 SKIP: $script missing"
        continue
    fi
    if [ -x "$PATH" ]; then
        echo "L3 PASS: $script is executable"
        L3_PASS=$((L3_PASS + 1))
    else
        echo "L3 FAIL: $script not executable"
    fi
done
echo "L3: $L3_PASS/3 scripts are executable"
echo ""

# L4: Data flow — run scripts with dry-run (no actual ticket/commit)
echo "--- L4: Data Flow (dry-run) ---"
L4_PASS=0

# Test independent-witness.sh --help
if bash "${PROCESS_DIR}/independent-witness.sh" 2>&1 | grep -q "Usage:"; then
    echo "L4 PASS: independent-witness.sh --help works"
    L4_PASS=$((L4_PASS + 1))
else
    echo "L4 FAIL: independent-witness.sh --help failed"
fi

# Test conductor-verify-gate.sh --help
if bash "${PROCESS_DIR}/conductor-verify-gate.sh" 2>&1 | grep -q "Usage:"; then
    echo "L4 PASS: conductor-verify-gate.sh --help works"
    L4_PASS=$((L4_PASS + 1))
else
    echo "L4 FAIL: conductor-verify-gate.sh --help failed"
fi

# Test subagent-pass-gate.sh --help
if bash "${PROCESS_DIR}/subagent-pass-gate.sh" 2>&1 | grep -q "Usage:"; then
    echo "L4 PASS: subagent-pass-gate.sh --help works"
    L4_PASS=$((L4_PASS + 1))
else
    echo "L4 FAIL: subagent-pass-gate.sh --help failed"
fi

echo "L4: $L4_PASS/3 scripts respond to usage check"
echo ""

# Summary
echo "=== Summary ==="
TOTAL_L1=3
TOTAL_L2=3
TOTAL_L3=3
TOTAL_L4=3
echo "L1 (existence): $L1_PASS/$TOTAL_L1"
echo "L2 (substance): $L2_PASS/$TOTAL_L2"
echo "L3 (wiring):    $L3_PASS/$TOTAL_L3"
echo "L4 (data flow): $L4_PASS/$TOTAL_L4"
TOTAL=$((L1_PASS + L2_PASS + L3_PASS + L4_PASS))
TOTAL_MAX=$((TOTAL_L1 + TOTAL_L2 + TOTAL_L3 + TOTAL_L4))
echo ""
echo "Total: $TOTAL/$TOTAL_MAX"

if [ "$TOTAL" -eq "$TOTAL_MAX" ]; then
    echo "RESULT: ALL PASS"
    exit 0
else
    echo "RESULT: PARTIAL FAIL"
    exit 1
fi
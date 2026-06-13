#!/usr/bin/env bash
# scripts/verify/checkpoint-checkpoint.sh — L4 verification for checkpoint.sh
# PHASE-008-D: Rule 8 L4 script exists verification
#
# Verifies:
#   1. scripts/context/checkpoint.sh exists and executable
#   2. checkpoint.sh has save/restore/list/clean commands
#   3. checkpoint.sh follows BE-7 fix pattern (umask + install -d -m 700)
#   4. checkpoint.sh integrates with knowledge base
#
# Exit code: 0 = PASS, 1 = FAIL
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

echo "=========================================="
echo "Checkpoint L4 Verification"
echo "=========================================="
echo "Root: $KALLAX_ROOT"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ----------------------------------------
# Test 1: checkpoint.sh exists and executable
# ----------------------------------------
test_checkpoint_exists() {
    [ -f "$KALLAX_ROOT/scripts/context/checkpoint.sh" ] && \
    [ -x "$KALLAX_ROOT/scripts/context/checkpoint.sh" ]
}

if test_checkpoint_exists; then
    pass "checkpoint.sh exists and executable"
else
    fail "checkpoint.sh missing or not executable"
fi

# ----------------------------------------
# Test 2: checkpoint.sh has required commands
# ----------------------------------------
test_has_commands() {
    local script="$KALLAX_ROOT/scripts/context/checkpoint.sh"
    grep -q "cmd_save()" "$script" && \
    grep -q "cmd_restore()" "$script" && \
    grep -q "cmd_list()" "$script" && \
    grep -q "cmd_clean()" "$script"
}

if test_has_commands; then
    pass "checkpoint.sh has save/restore/list/clean commands"
else
    fail "checkpoint.sh missing required commands"
fi

# ----------------------------------------
# Test 3: checkpoint.sh follows BE-7 fix pattern
# ----------------------------------------
test_be7_fix_pattern() {
    local script="$KALLAX_ROOT/scripts/context/checkpoint.sh"
    grep -q "umask 077" "$script" && \
    grep -q '_safe_mkdir()' "$script" && \
    grep -q "install -d -m 700" "$script"
}

if test_be7_fix_pattern; then
    pass "checkpoint.sh follows BE-7 fix pattern (umask + install -d -m 700)"
else
    fail "checkpoint.sh missing BE-7 fix pattern"
fi

# ----------------------------------------
# Test 4: checkpoint.sh integrates with knowledge base
# ----------------------------------------
test_kb_integration() {
    local script="$KALLAX_ROOT/scripts/context/checkpoint.sh"
    grep -q "knowledge" "$script" && \
    grep -q "_backup_knowledge()" "$script"
}

if test_kb_integration; then
    pass "checkpoint.sh integrates with knowledge base"
else
    fail "checkpoint.sh missing knowledge base integration"
fi

# ----------------------------------------
# Test 5: checkpoint.sh help works
# ----------------------------------------
test_help() {
    bash "$KALLAX_ROOT/scripts/context/checkpoint.sh" help >/dev/null 2>&1
}

if test_help; then
    pass "checkpoint.sh help works"
else
    fail "checkpoint.sh help failed"
fi

# ----------------------------------------
# Test 6: checkpoint.sh save creates checkpoint
# ----------------------------------------
test_save() {
    local checkpoint_id
    checkpoint_id="$(bash "$KALLAX_ROOT/scripts/context/checkpoint.sh" save --label "l4-test" 2>/dev/null | tail -1)"
    [ -n "$checkpoint_id" ] && [ -d "$KALLAX_ROOT/checkpoints/$checkpoint_id" ]
}

if test_save; then
    pass "checkpoint.sh save creates checkpoint"
else
    fail "checkpoint.sh save failed"
fi

# ----------------------------------------
# Test 7: checkpoint.sh list shows checkpoints
# ----------------------------------------
test_list() {
    local output
    output="$(bash "$KALLAX_ROOT/scripts/context/checkpoint.sh" list 2>/dev/null)"
    echo "$output" | grep -q "checkpoint"
}

if test_list; then
    pass "checkpoint.sh list shows checkpoints"
else
    fail "checkpoint.sh list failed"
fi

# ----------------------------------------
# Summary
# ----------------------------------------
echo ""
echo "=========================================="
echo "L4 Verification Summary"
echo "=========================================="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT: FAIL — $FAIL_COUNT test(s) failed"
    exit 1
fi

echo "RESULT: PASS — all $PASS_COUNT tests passed"
exit 0
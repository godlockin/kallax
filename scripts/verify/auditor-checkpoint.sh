#!/usr/bin/env bash
# scripts/verify/auditor-checkpoint.sh — L4 Checkpoint for Rule 8
# PHASE-008-E: Auditor 角色落地, 验证 auditor.sh L4 存在可执行
#
# Rule 8: L4 bash scripts must exist before ticket close
# This script is referenced by check-fact-forcing-preflight.sh as L4_script_exists check
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET_SCRIPT="$KALLAX_ROOT/scripts/auditor/auditor.sh"

echo "=========================================="
echo "L4 Checkpoint: auditor-checkpoint.sh"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# Check if auditor.sh exists
if [ ! -f "$TARGET_SCRIPT" ]; then
    fail "auditor.sh not found: $TARGET_SCRIPT"
    echo ""
    echo "Rule 8: L4 bash script must exist"
    exit 1
fi
pass "auditor.sh exists"

# Check if executable
if [ ! -x "$TARGET_SCRIPT" ]; then
    fail "auditor.sh is not executable"
    exit 1
fi
pass "auditor.sh is executable"

# Verify script has required functions
REQUIRED_FUNCTIONS=(
    "auditor_read_only"
    "auditor_lessons_write"
    "auditor_block_write_original"
    "auditor联动_strong_verify_6d"
    "auditor联动_review_sh"
    "auditor联动_ticket_status_sync"
    "list_worktrees"
    "is_original_project_code"
)

MISSING_FUNCTIONS=()
for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if ! grep -q "$func" "$TARGET_SCRIPT"; then
        MISSING_FUNCTIONS+=("$func")
    fi
done

if [ ${#MISSING_FUNCTIONS[@]} -gt 0 ]; then
    fail "Missing required functions: ${MISSING_FUNCTIONS[*]}"
    exit 1
fi
pass "All ${#REQUIRED_FUNCTIONS[@]} required functions present"

# Check integration with strong-verify-6d.sh
STRONG_VERIFY="$KALLAX_ROOT/scripts/master/strong-verify-6d.sh"
if [ -f "$STRONG_VERIFY" ] && [ -x "$STRONG_VERIFY" ]; then
    pass "strong-verify-6d.sh integration available"
else
    fail "strong-verify-6d.sh not found or not executable"
    exit 1
fi

# Check integration with review.sh
REVIEW_SCRIPT="$KALLAX_ROOT/scripts/conductor/review.sh"
if [ -f "$REVIEW_SCRIPT" ] && [ -x "$REVIEW_SCRIPT" ]; then
    pass "review.sh integration available"
else
    fail "review.sh not found or not executable"
    exit 1
fi

# Check integration with ticket-status-sync.sh
SYNC_SCRIPT="$KALLAX_ROOT/scripts/conductor/ticket-status-sync.sh"
if [ -f "$SYNC_SCRIPT" ]; then
    pass "ticket-status-sync.sh integration available"
else
    pass "ticket-status-sync.sh not found (optional, Auditor only recommends)"
fi

# Check lessons directory creation capability
LESSONS_DIR="$KALLAX_ROOT/.kallax/lessons"
if grep -q "ensure_lessons_dir" "$TARGET_SCRIPT"; then
    pass "lessons directory creation logic present"
else
    fail "lessons directory creation logic missing"
    exit 1
fi

# Check worktree reading capability
if grep -q "list_worktrees" "$TARGET_SCRIPT" && grep -q "read_worktree_file" "$TARGET_SCRIPT"; then
    pass "worktree reading capability present"
else
    fail "worktree reading capability missing"
    exit 1
fi

# Check original project code blocking
if grep -q "is_original_project_code" "$TARGET_SCRIPT"; then
    pass "original project code blocking logic present"
else
    fail "original project code blocking logic missing"
    exit 1
fi

echo ""
echo "=========================================="
echo "Result: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo "=========================================="

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "L4_script_exists: FAIL"
    exit 1
fi

echo "PASS: auditor.sh exists and has all required functions"
echo "  - cross-worktree read (auditor_read_only)"
echo "  - lessons write (auditor_lessons_write)"
echo "  - block original project code (auditor_block_write_original)"
echo "  - strong-verify-6d联动"
echo "  - review.sh联动"
echo "  - ticket-status-sync联动"
echo ""
echo "L4_script_exists: PASS"
exit 0
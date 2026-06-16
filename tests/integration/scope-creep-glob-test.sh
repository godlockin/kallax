#!/usr/bin/env bash
# tests/integration/scope-creep-glob-test.sh — TDD tests for check-scope-creep.sh glob support
# EPIC-053-F AC6: 4/4 PASS
#   Case 1: exact file match
#   Case 2: directory prefix match (jira/tickets/EPIC-XXX/ → IMPLEMENTATION-PLAN.md)
#   Case 3: no match (file outside allowed scope)
#   Case 4: multiple allowed patterns, mix exact + directory
#
# Rule 9 KPI X/Y format: 4/4 = 100.0% (no estimate, exact)
# 跟 EPIC-053-A L6 lesson 联合, 治 check-scope-creep 工具局限性

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly SCRIPT="$KALLAX_ROOT/scripts/verify/check-scope-creep.sh"

# Verify script exists
if [ ! -f "$SCRIPT" ]; then
    echo "=========================================="
    echo "Scope-Creep Glob Match — Unit Tests"
    echo "=========================================="
    echo ""
    echo "FAIL: $SCRIPT not found (TDD red phase)"
    echo "0/4 PASS (0.0%)"
    exit 1
fi

# Source the script to access match_glob function (script guards main with BASH_SOURCE check)
# shellcheck disable=SC1090
source "$SCRIPT" 2>/dev/null || {
    # If source fails (e.g. set -e in script triggers exit on no-match), extract function manually
    :
}

# Extract match_glob if not available after sourcing
if ! declare -f match_glob >/dev/null 2>&1; then
    # The script may exit on sourcing due to set -e — extract function from file
    eval "$(awk '/^match_glob\(\)/,/^}/' "$SCRIPT")"
fi

if ! declare -f match_glob >/dev/null 2>&1; then
    echo "=========================================="
    echo "Scope-Creep Glob Match — Unit Tests"
    echo "=========================================="
    echo ""
    echo "FAIL: match_glob function not found in $SCRIPT (TDD red phase)"
    echo "0/4 PASS (0.0%)"
    exit 1
fi

echo "=========================================="
echo "Scope-Creep Glob Match — Unit Tests (4/4)"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=4

# Case 1: exact file match
echo "--- Case 1: exact file match ---"
if match_glob "scripts/verify/check-scope-creep.sh" "scripts/verify/check-scope-creep.sh"; then
    echo "[PASS] exact file match → MATCH"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] exact file match → expected MATCH, got NO MATCH"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Case 2: directory prefix match (the bug fix)
echo "--- Case 2: directory prefix match (jira/tickets/EPIC-XXX/) ---"
if match_glob "jira/tickets/EPIC-053-A/IMPLEMENTATION-PLAN.md" "jira/tickets/EPIC-053-A/"; then
    echo "[PASS] dir prefix match (file in directory) → MATCH"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] dir prefix match → expected MATCH, got NO MATCH"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Case 3: no match (file outside allowed scope)
echo "--- Case 3: no match (file outside allowed scope) ---"
if match_glob "docs/random.md" "scripts/verify/"; then
    echo "[FAIL] no-match case → expected NO MATCH, got MATCH"
    FAIL_COUNT=$((FAIL_COUNT+1))
else
    echo "[PASS] no match (file outside allowed) → NO MATCH (correct)"
    PASS_COUNT=$((PASS_COUNT+1))
fi
echo ""

# Case 4: multiple allowed patterns, mix exact + directory
echo "--- Case 4: multiple allowed patterns (mix exact + directory) ---"
ALLOWED_MULTI=(
    "scripts/verify/check-scope-creep.sh"
    "jira/tickets/EPIC-053-F/"
    "tests/integration/l3-l4-consistency-truth-table-test.sh"
)
R4A=$(match_glob "scripts/verify/check-scope-creep.sh" "${ALLOWED_MULTI[@]}" && echo "MATCH" || echo "NO")
R4B=$(match_glob "jira/tickets/EPIC-053-F/LESSONS-LEARNED.md" "${ALLOWED_MULTI[@]}" && echo "MATCH" || echo "NO")
R4C=$(match_glob "jira/tickets/EPIC-053-F/IMPLEMENTATION-PLAN.md" "${ALLOWED_MULTI[@]}" && echo "MATCH" || echo "NO")
R4D=$(match_glob "jira/tickets/EPIC-053-A/PLAN.md" "${ALLOWED_MULTI[@]}" && echo "MATCH" || echo "NO")

if [ "$R4A" = "MATCH" ] && [ "$R4B" = "MATCH" ] && [ "$R4C" = "MATCH" ] && [ "$R4D" = "NO" ]; then
    echo "[PASS] multi-pattern mix: exact+dir→MATCH, unrelated→NO"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] multi-pattern: A=$R4A B=$R4B C=$R4C D=$R4D (expected MATCH/MATCH/MATCH/NO)"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# Summary — exact X/Y format (Rule 9 KPI precision)
echo "=========================================="
echo "Results: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "FAIL: $FAIL_COUNT test(s) failed"
    echo "$PASS_COUNT/$TOTAL PASS"
    exit 1
fi
echo "PASS: all $TOTAL glob match tests passed"
echo "$PASS_COUNT/$TOTAL PASS (100.0%)"
exit 0

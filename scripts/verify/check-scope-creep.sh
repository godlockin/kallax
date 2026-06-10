#!/usr/bin/env bash
# scripts/verify/check-scope-creep.sh — File scope enforcement
# Verifies changed files stay within ticket.json file_scope.includes
# Previous issue: 6563362 changed 3 unrelated files (scope creep)
#
# BYPASS: set KALLAX_BYPASS_SCOPE_CHECK=1 to skip check (design stage work)

set -euo pipefail

TICKET_ID="${1:-}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
SCOPE_CHECK_MODE="${KALLAX_SCOPE_CHECK_MODE:-per-commit}"

# BYPASS: design stage work (no ticket.json required)
if [ "${KALLAX_BYPASS_SCOPE_CHECK:-0}" = "1" ]; then
    echo "=========================================="
    echo "Scope Creep Check (BYPASS)"
    echo "=========================================="
    echo "BYPASS: design stage work, no ticket.json required"
    exit 0
fi

echo "=========================================="
echo "Scope Creep Check"
echo "=========================================="
echo "Mode: $SCOPE_CHECK_MODE (KALLAX_SCOPE_CHECK_MODE)"

if [ -z "$TICKET_ID" ]; then
    echo "Usage: $0 <TICKET_ID>"
    echo "Example: $0 EPIC-028-B"
    exit 1
fi

# Find ticket.json
TICKET_FILE="$REPO_ROOT/jira/tickets/$TICKET_ID/ticket.json"

# Fallback: look in current dir
if [ ! -f "$TICKET_FILE" ]; then
    TICKET_FILE="./jira/tickets/$TICKET_ID/ticket.json"
fi

if [ ! -f "$TICKET_FILE" ]; then
    echo "FAIL: ticket.json not found for $TICKET_ID"
    echo "Searched: $REPO_ROOT/jira/tickets/$TICKET_ID/ticket.json"
    exit 1
fi

echo "Ticket: $TICKET_ID"
echo "Scope file: $TICKET_FILE"
echo ""

# Read allowed files from file_scope.includes
if ! ALLOWED=$(jq -r '.file_scope.includes[]' "$TICKET_FILE" 2>/dev/null); then
    echo "WARN: No file_scope.includes found in ticket.json"
    echo "Skipping scope check."
    exit 0
fi

# Get changed files based on mode:
# - per-commit: last commit only (HEAD~1..HEAD)
# - per-branch: entire feature branch (miao...HEAD)
case "$SCOPE_CHECK_MODE" in
    per-branch)
        CHANGED=$(git diff --name-only miao...HEAD)
        ;;
    per-commit|*)
        CHANGED=$(git diff --name-only HEAD~1..HEAD)
        ;;
esac

if [ -z "$CHANGED" ]; then
    echo "No changed files detected."
    exit 0
fi

echo "Changed files (${CHANGED_COUNT:-unknown}):"
echo "$CHANGED" | while read -r f; do
    echo "  $f"
done
echo ""

# Check each changed file against allowed scope
OUT_OF_SCOPE=()
ALLOWED_ARRAY=()
while IFS= read -r line; do
    [ -n "$line" ] && ALLOWED_ARRAY+=("$line")
done <<< "$ALLOWED"

for file in $CHANGED; do
    MATCHED=0
    for allowed in "${ALLOWED_ARRAY[@]}"; do
        if [ "$file" = "$allowed" ]; then
            MATCHED=1
            break
        fi
    done
    if [ "$MATCHED" -eq 0 ]; then
        OUT_OF_SCOPE+=("$file")
    fi
done

CHANGED_COUNT=$(echo "$CHANGED" | wc -l | tr -d ' ')

if [ ${#OUT_OF_SCOPE[@]} -gt 0 ]; then
    echo "FAIL: ${#OUT_OF_SCOPE[@]} files outside ticket scope:"
    printf '  %s\n' "${OUT_OF_SCOPE[@]}"
    echo ""
    echo "REQUIREMENT: scope-creep files must be in separate PR, not mixed."
    echo "Allowed scope:"
    printf '  %s\n' "${ALLOWED_ARRAY[@]}"
    exit 1
fi

echo "PASS: all $CHANGED_COUNT changed files within ticket scope"
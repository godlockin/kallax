#!/usr/bin/env bash
# scripts/verify/check-scope-creep.sh — File scope enforcement
# Verifies changed files stay within ticket.json file_scope.includes
# Previous issue: 6563362 changed 3 unrelated files (scope creep)
#
# SECURITY: KALLAX_BYPASS_SCOPE_CHECK removed — scope creep is a P0 anti-fab violation
# Design stage work must use KALLAX_DESIGN_MODE=1 (requires master token validation)
#
# EPIC-053-F: Added match_glob() helper supporting directory prefix patterns
#   (e.g. "jira/tickets/EPIC-XXX/" matches files inside that directory).
#   Fixes exit=1 false positive on tickets whose file_scope includes a directory.
#   Bash 5.x compatible — uses "$@" iteration, no [[:space:]] character class arrays
#   (跟 EPIC-053-C BE-10 模式联动).

set -euo pipefail

# match_glob <file> <allowed1> [allowed2] ...
# Returns 0 if <file> matches any <allowed> pattern, 1 otherwise.
#   - Exact match: "scripts/foo.sh" == "scripts/foo.sh"
#   - Directory prefix match: "jira/tickets/EPIC-XXX/" prefix-matches files inside
# Future: glob `*` support (out of EPIC-053-F scope)
match_glob() {
    local file="$1"
    shift
    local allowed
    for allowed in "$@"; do
        if [[ "$allowed" == */ ]]; then
            if [[ "$file" == "$allowed"* ]]; then
                return 0
            fi
        else
            if [[ "$file" == "$allowed" ]]; then
                return 0
            fi
        fi
    done
    return 1
}

# Main execution guarded: only run when executed, not when sourced for testing
# Pattern: BASH_SOURCE[0] check (Bash 3.2+ compatible)
if [[ "${BASH_SOURCE[0]:-$0}" != "${0}" ]] && return 0 2>/dev/null; then
    return 0
fi

TICKET_ID="${1:-}"
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Design stage bypass: requires master token (not env var toggle)
if [ "${KALLAX_DESIGN_MODE:-0}" = "1" ]; then
    if [[ -z "${KALLAX_MASTER_TOKEN:-}" ]]; then
        echo "FAIL: KALLAX_DESIGN_MODE=1 requires KALLAX_MASTER_TOKEN"
        exit 1
    fi
    TOKEN_FILE="${HOME}/.claude/state/kallax-master-token"
    EXPECTED_TOKEN=""
    if [[ -f "$TOKEN_FILE" ]]; then
        EXPECTED_TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null || echo "")
    fi
    if [[ "$KALLAX_MASTER_TOKEN" != "$EXPECTED_TOKEN" ]] || [[ -z "$EXPECTED_TOKEN" ]]; then
        echo "FAIL: KALLAX_DESIGN_MODE=1 token validation failed"
        exit 1
    fi
    echo "=========================================="
    echo "Scope Creep Check (DESIGN MODE)"
    echo "=========================================="
    echo "OK: design stage work with master token validated"
    exit 0
fi

echo "=========================================="
echo "Scope Creep Check"
echo "=========================================="

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

# Get changed files — use last commit only (not entire branch history)
# On multi-ticket branch, miao...HEAD includes all tickets' changes causing false positives
# Using HEAD~1..HEAD limits to the most recent commit's changes
CHANGED=$(git diff --name-only HEAD~1..HEAD 2>/dev/null)

if [ -z "$CHANGED" ]; then
    echo "No changed files detected."
    exit 0
fi

CHANGED_COUNT=$(echo "$CHANGED" | wc -l | tr -d ' ')

echo "Changed files ($CHANGED_COUNT):"
echo "$CHANGED" | while read -r f; do
    echo "  $f"
done
echo ""

# Check each changed file against allowed scope using match_glob (dir prefix + exact)
OUT_OF_SCOPE=()
ALLOWED_ARRAY=()
while IFS= read -r line; do
    [ -n "$line" ] && ALLOWED_ARRAY+=("$line")
done <<< "$ALLOWED"

for file in $CHANGED; do
    if ! match_glob "$file" "${ALLOWED_ARRAY[@]}"; then
        OUT_OF_SCOPE+=("$file")
    fi
done

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

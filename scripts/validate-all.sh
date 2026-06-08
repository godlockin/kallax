#!/usr/bin/env bash
# KALLAX Validate All — scan jira/ and .kallax/instances/ JSON files and validate
# against Zod schemas (PhaseSchema, EpicSchema, TicketSchema, StateSchema).
#
# Usage: ./scripts/validate-all.sh
# Exit code: 0 if all pass, 1 if any fail.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# tsx may be hoisted to root node_modules (workspace) or in node's node_modules
TSX=""
for candidate in \
  "${PROJECT_ROOT}/node_modules/.bin/tsx" \
  "${PROJECT_ROOT}/node/node_modules/.bin/tsx"; do
  if [ -f "$candidate" ]; then
    TSX="$candidate"
    break
  fi
done

RED='\033[0;31m'; NC='\033[0m'

# ── Check dependencies ──────────────────────────────────────────────
if [ -z "$TSX" ]; then
  echo -e "${RED}[FATAL]${NC} tsx not found. Run 'npm install' in project root."
  exit 1
fi

# ── Discover JSON files ─────────────────────────────────────────────
JIRA_DIR="${PROJECT_ROOT}/jira"
INSTANCES_DIR="${PROJECT_ROOT}/.kallax/instances"

PHASE_FILES=()
EPIC_FILES=()
TICKET_FILES=()
STATE_FILES=()

# Use find for reliable globbing (shopt nullglob not needed in subshell)
while IFS= read -r f; do
  [ -n "$f" ] && PHASE_FILES+=("$f")
done < <(find "${JIRA_DIR}/phases" -maxdepth 2 -name "phase.json" -type f 2>/dev/null || true)

while IFS= read -r f; do
  [ -n "$f" ] && EPIC_FILES+=("$f")
done < <(find "${JIRA_DIR}/epics" -maxdepth 2 -name "epic.json" -type f 2>/dev/null || true)

while IFS= read -r f; do
  [ -n "$f" ] && TICKET_FILES+=("$f")
done < <(find "${JIRA_DIR}/tickets" -maxdepth 3 -name "ticket.json" -type f 2>/dev/null || true)

if [ -d "$INSTANCES_DIR" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] && STATE_FILES+=("$f")
  done < <(find "$INSTANCES_DIR" -maxdepth 2 -name "state.json" -type f 2>/dev/null || true)
fi

# ── Build JSON file list ────────────────────────────────────────────
# Construct a JSON object with arrays of file paths for each type.
to_json_array() {
  local first=true
  printf '['
  for f in "$@"; do
    if [ "$first" = true ]; then first=false; else printf ','; fi
    # Escape backslashes and double-quotes in file paths
    local escaped
    escaped="$(printf '%s' "$f" | sed 's/[\\"]/\\&/g')"
    printf '"%s"' "$escaped"
  done
  printf ']'
}

FILE_LIST_JSON="{\"phases\":$(to_json_array "${PHASE_FILES[@]:+${PHASE_FILES[@]}}"),\"epics\":$(to_json_array "${EPIC_FILES[@]:+${EPIC_FILES[@]}}"),\"tickets\":$(to_json_array "${TICKET_FILES[@]:+${TICKET_FILES[@]}}"),\"states\":$(to_json_array "${STATE_FILES[@]:+${STATE_FILES[@]}}")}"

# ── Summary banner ──────────────────────────────────────────────────
PHASE_COUNT=${#PHASE_FILES[@]}
EPIC_COUNT=${#EPIC_FILES[@]}
TICKET_COUNT=${#TICKET_FILES[@]}
STATE_COUNT=${#STATE_FILES[@]}
TOTAL=$((PHASE_COUNT + EPIC_COUNT + TICKET_COUNT + STATE_COUNT))

echo "=== KALLAX Validate All ==="
echo "  Phases:  ${PHASE_COUNT} file(s)"
echo "  Epics:   ${EPIC_COUNT} file(s)"
echo "  Tickets: ${TICKET_COUNT} file(s)"
echo "  States:  ${STATE_COUNT} file(s)"
echo "  Total:   ${TOTAL} file(s)"
echo ""

if [ "${TOTAL}" -eq 0 ]; then
  echo -e "${RED}[WARN]${NC} No JSON files found to validate."
  exit 0
fi

# ── Pipe to Node.js validator ───────────────────────────────────────
echo "${FILE_LIST_JSON}" | "${TSX}" "${PROJECT_ROOT}/node/src/scripts/validate-runner.ts"

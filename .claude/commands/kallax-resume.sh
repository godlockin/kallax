#!/usr/bin/env bash
# /kallax-resume — Resume from a saved session

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "Resume Session"

require_git_repo

SAVE_DIR="${KALLAX_STATE}/sessions"

if [ ! -d "$SAVE_DIR" ] || [ -z "$(ls -A "$SAVE_DIR" 2>/dev/null)" ]; then
  log_warn "No saved sessions found"
  echo ""
  echo "  Run /kallax-save first to create a session snapshot"
  exit 0
fi

# List saved sessions
echo "  Saved sessions:"
echo ""
ls -1t "$SAVE_DIR"/*.json 2>/dev/null | head -10 | while read -r f; do
  SESSION_NAME=$(basename "$f" .json)
  SESSION_TIME=$(grep -o '"timestamp":"[^"]*"' "$f" 2>/dev/null | cut -d'"' -f4 || echo "unknown")
  SESSION_ROLE=$(grep -o '"role":"[^"]*"' "$f" 2>/dev/null | cut -d'"' -f4 || echo "unknown")
  echo "  ${SESSION_NAME}  |  ${SESSION_ROLE}  |  ${SESSION_TIME}"
done
echo ""

read -r -p "  Session to resume (name or press Enter for latest): " SESSION_NAME

if [ -z "$SESSION_NAME" ]; then
  SESSION_FILE=$(ls -1t "$SAVE_DIR"/*.json 2>/dev/null | head -1)
else
  SESSION_FILE="${SAVE_DIR}/${SESSION_NAME}.json"
fi

if [ ! -f "$SESSION_FILE" ]; then
  log_error "Session not found: ${SESSION_FILE}"
  exit 1
fi

log_info "Resuming from: $(basename "$SESSION_FILE")"

# Read saved state
SAVED_ROLE=$(grep -o '"role":"[^"]*"' "$SESSION_FILE" 2>/dev/null | cut -d'"' -f4 || echo "unset")
SAVED_BRANCH=$(grep -o '"branch":"[^"]*"' "$SESSION_FILE" 2>/dev/null | cut -d'"' -f4 || echo "")

echo ""
echo "  Role:       ${SAVED_ROLE}"
echo "  Branch:     ${SAVED_BRANCH}"
echo ""

# Switch to saved branch if different
if [ -n "$SAVED_BRANCH" ] && [ "$SAVED_BRANCH" != "$(current_branch)" ]; then
  read -r -p "  Switch to branch ${SAVED_BRANCH}? [Y/n]: " SWITCH
  if [ "$SWITCH" != "n" ] && [ "$SWITCH" != "N" ]; then
    git checkout "$SAVED_BRANCH" 2>/dev/null || log_warn "Could not switch branch"
  fi
fi

# Restore role configuration
if [ "$SAVED_ROLE" != "unset" ]; then
  mkdir -p "$KALLAX_STATE"
  cat > "${KALLAX_STATE}/instance_config.yml" <<YAML
role: ${SAVED_ROLE}
configuredAt: $(date +%s)
resumedFrom: $(basename "$SESSION_FILE")
YAML
fi

# Start KALLAX
if command -v kallax &>/dev/null; then
  kallax start --role "$SAVED_ROLE" 2>/dev/null || true
fi

echo ""
log_info "Session resumed"
echo ""
echo "  /kallax-status         — Check current status"
echo "  /kallax-claim          — Continue working"
echo ""

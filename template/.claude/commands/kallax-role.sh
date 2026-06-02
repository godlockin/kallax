#!/usr/bin/env bash
# /kallax-role — View or change agent role

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "Role Management"

require_git_repo

CURRENT=$(get_role)
NEW_ROLE="${1:-}"

echo "  Current role: ${BOLD}${CURRENT}${NC}"
echo ""

if [ -n "$NEW_ROLE" ]; then
  if [ "$NEW_ROLE" != "conductor" ] && [ "$NEW_ROLE" != "performer" ]; then
    log_error "Invalid role: ${NEW_ROLE} (must be conductor or performer)"
    exit 1
  fi

  mkdir -p "$KALLAX_STATE"
  cat > "${KALLAX_STATE}/instance_config.yml" <<YAML
role: ${NEW_ROLE}
configuredAt: $(date +%s)
YAML

  log_info "Role changed: ${CURRENT} → ${NEW_ROLE}"
else
  echo "  Available roles:"
  echo "    conductor  — Orchestrator (analyze, decompose, review, merge)"
  echo "    performer  — Executor (claim, develop, test, submit)"
  echo ""
  echo "  /kallax-role conductor    — Switch to Conductor"
  echo "  /kallax-role performer    — Switch to Performer"
fi
echo ""

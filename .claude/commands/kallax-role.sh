#!/usr/bin/env bash
# /kallax-role — View or change agent role

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-role — View or change agent role

USAGE:
  /kallax-role [conductor|performer|master]

ARGS:
  role              New role to switch to. If omitted, prints the current
                    role and lists all available roles.

DESCRIPTION:
  Reads the current role from instance_config.yml. With no argument,
  prints the current role and the list of available roles. With an
  argument, writes the new role to instance_config.yml and confirms.

EXAMPLES:
  /kallax-role
  /kallax-role conductor

RELATED:
  /kallax-mode, /kallax-start
EOF
  exit 0
fi

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

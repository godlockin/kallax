#!/usr/bin/env bash
# /kallax-start — Start KALLAX in current project
# Detects or sets role, initializes state, registers instance.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-start — Start KALLAX in current project

USAGE:
  /kallax-start [role]

ARGS:
  role              master | conductor | performer (prompts if missing)

DESCRIPTION:
  Validates the requested role, writes instance_config.yml, and registers
  the agent via /api/agents/register. Prints the instance ID and the
  next-step commands appropriate to the selected role.

EXAMPLES:
  /kallax-start
  /kallax-start conductor

RELATED:
  /kallax-init, /kallax-role, /kallax-mode, /kallax-status
EOF
  exit 0
fi

log_title "KALLAX Startup"

require_git_repo

ROLE="${1:-$(get_role)}"

if [ "$ROLE" = "unset" ] || [ -z "$ROLE" ]; then
  echo ""
  echo "  Select role:"
  echo "    1) Conductor — orchestrator (analyze, decompose, review, merge)"
  echo "    2) Performer  — executor (claim, develop, test, submit)"
  echo ""
  read -r -p "  Choice [1/2]: " choice

  case "$choice" in
    1) ROLE="conductor" ;;
    2) ROLE="performer" ;;
    *) log_error "Invalid choice"; exit 1 ;;
  esac
fi

# Validate role
if [ "$ROLE" != "conductor" ] && [ "$ROLE" != "performer" ]; then
  log_error "Invalid role: $ROLE (must be conductor or performer)"
  exit 1
fi

# Ensure directories exist
mkdir -p "$KALLAX_STATE" "$KALLAX_DATA" "$KALLAX_DIR/logs" "$KALLAX_DIR/inbox"

# Write instance config
cat > "${KALLAX_STATE}/instance_config.yml" <<YAML
# KALLAX Instance Configuration
role: ${ROLE}
configuredAt: $(date +%s)
YAML

# Initialize database if needed
if [ ! -f "${KALLAX_DATA}/kallax.db" ]; then
  log_info "Initializing SQLite database..."
  if command -v kallax &>/dev/null; then
    kallax system doctor >/dev/null 2>&1 || true
  fi
fi

# Register instance via API
INSTANCE_RESPONSE=$(api_call "POST" "/api/agents/register" "{\"role\":\"${ROLE}\"}" 2>/dev/null || echo "{}")
INSTANCE_ID=$(echo "$INSTANCE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")

log_info "KALLAX ${ROLE} started successfully"
if [ -n "$INSTANCE_ID" ]; then
  log_info "Instance ID: ${INSTANCE_ID}"
fi

# Show role-specific next steps
echo ""
if [ "$ROLE" = "conductor" ]; then
  echo "  Next steps:"
  echo "    /kallax-status          — View system status"
  echo "    /kallax-board           — Show ticket board"
  echo "    /kallax-analyze         — Analyze project structure"
  echo "    /kallax-office-hours    — Requirements analysis"
  echo "    /kallax-review-pr       — Review a pull request"
else
  echo "  Next steps:"
  echo "    /kallax-status          — View your status"
  echo "    /kallax-claim           — Claim an available task"
  echo "    /kallax-submit-pr       — Submit PR for review"
fi
echo ""

#!/usr/bin/env bash
# /kallax-mode — Switch between operation modes

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-mode — Switch between operation modes

USAGE:
  /kallax-mode [conductor|performer|standalone]

ARGS:
  mode              New mode. conductor / performer / standalone
                    (prompts if missing).

DESCRIPTION:
  Writes instance_config.yml with the chosen role and standalone flag.
  Prints a summary of the responsibilities that come with the new mode.

EXAMPLES:
  /kallax-mode
  /kallax-mode conductor

RELATED:
  /kallax-role, /kallax-start
EOF
  exit 0
fi

log_title "Mode Selection"

MODE="${1:-}"

if [ -z "$MODE" ]; then
  CURRENT=$(get_role)
  echo "  Current mode: ${BOLD}${CURRENT}${NC}"
  echo ""
  echo "  Available modes:"
  echo "    conductor   — Full orchestrator (heartbeat, decompose, review)"
  echo "    performer   — Dedicated executor (claim, develop, submit)"
  echo "    standalone  — Self-managed mode (no external coordination)"
  echo ""
  echo "  /kallax-mode conductor"
  echo "  /kallax-mode performer"
  echo "  /kallax-mode standalone"
  exit 0
fi

case "$MODE" in
  conductor)
    mkdir -p "$KALLAX_STATE"
    cat > "${KALLAX_STATE}/instance_config.yml" <<YAML
role: conductor
configuredAt: $(date +%s)
YAML
    log_info "Mode: Conductor"
    echo "  Responsibilities: analyze, decompose, assign, review, merge"
    ;;
  performer)
    mkdir -p "$KALLAX_STATE"
    cat > "${KALLAX_STATE}/instance_config.yml" <<YAML
role: performer
configuredAt: $(date +%s)
YAML
    log_info "Mode: Performer"
    echo "  Responsibilities: claim, develop, test, submit"
    ;;
  standalone)
    mkdir -p "$KALLAX_STATE"
    cat > "${KALLAX_STATE}/instance_config.yml" <<YAML
role: performer
configuredAt: $(date +%s)
standalone: true
YAML
    log_info "Mode: Standalone"
    echo "  Self-managed — no external Conductor needed"
    ;;
  *)
    log_error "Invalid mode: ${MODE}"
    exit 1
    ;;
esac

echo ""
echo "  Run /kallax-start to apply changes"
echo ""

#!/usr/bin/env bash
# /kallax-instances — List active Conductor/Performer instances

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-instances — List active Conductor/Performer instances

USAGE:
  /kallax-instances

DESCRIPTION:
  Lists registered agents via `kallax team:status` or the /api/agents
  endpoint. Prints the active instance list plus a lifecycle diagram
  and the heartbeat / stale thresholds.

EXAMPLES:
  /kallax-instances

RELATED:
  /kallax-status, /kallax-check-progress
EOF
  exit 0
fi

log_title "Active Instances"

require_git_repo

echo ""

if command -v kallax &>/dev/null; then
  kallax team:status 2>/dev/null || echo "  No instances registered"
else
  AGENTS=$(api_call "GET" "/api/agents" 2>/dev/null || echo "[]")
  if [ "$AGENTS" != "[]" ] && [ -n "$AGENTS" ]; then
    echo "$AGENTS" | head -30
  else
    log_warn "No active instances found"
    echo ""
    echo "  Run /kallax-start to register an instance"
  fi
fi

echo ""
echo "  Instance Lifecycle:"
echo "    Register → Active → Busy (working) → Idle → Shutdown"
echo ""
echo "  Stale detection: instances without heartbeat > 60s"
echo "  Heartbeat interval: 10s"
echo ""

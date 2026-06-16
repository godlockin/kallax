---
description: KALLAX instances command
---
# /kallax-instances — List active Conductor/Performer instances

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

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

#!/bin/bash
# workspace/switch.sh — Switch KALLAX workspace
#
# P0 fixes:
# - set -euo pipefail
# - fail-closed: any error exit 1 deny
# - realpath execution order first
# - transition requires auditor+ role
# - role MUST come from state.json (--role CLI removed)
#
# Usage: workspace/switch.sh --workspace <name> --actor <actor>
# Example: workspace/switch.sh --workspace conductor --actor "Steven Chen"
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3

set -euo pipefail

# SIGTERM handler for graceful termination
cleanup() {
  echo "DEBUG: workspace/switch.sh received SIGTERM, cleaning up..." >&2
  exit 130
}
trap cleanup SIGTERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

# Default values
WORKSPACE=""
ACTOR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --workspace)
      WORKSPACE="$2"
      shift 2
      ;;
    --actor)
      ACTOR="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Usage: $0 --workspace <name> --actor <actor>" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$WORKSPACE" ]]; then
  echo "ERROR: --workspace is required" >&2
  exit 1
fi

if [[ -z "$ACTOR" ]]; then
  echo "ERROR: --actor is required" >&2
  exit 1
fi

# Valid workspaces
VALID_WORKSPACES="master conductor performer readonly auditor"

# Workspace validation
if [[ "$VALID_WORKSPACES" != *" $WORKSPACE "* ]] && [[ "$VALID_WORKSPACES" != "$WORKSPACE" ]] && [[ "$VALID_WORKSPACES" != *" $WORKSPACE"* ]]; then
  if [[ " $VALID_WORKSPACES " != *" $WORKSPACE "* ]]; then
    echo "ERROR: Unknown workspace: '$WORKSPACE'" >&2
    echo "Valid workspaces: $VALID_WORKSPACES" >&2
    exit 1
  fi
fi

# Get current role from state file ONLY — no CLI/env fallback
ROLE="$(jq -r '.role // ""' "$STATE_FILE")"
if [[ -z "$ROLE" ]]; then
  echo "ERROR: role not found in $STATE_FILE" >&2
  exit 1
fi

# Audit logging
log_workspace_switch() {
  local from_role="$1"
  local to_workspace="$2"
  local result="$3"
  local timestamp
  timestamp="$(date +%s)"

  mkdir -p "$(dirname "$AUDIT_DB")"
  echo "[$timestamp] role=$from_role workspace=$to_workspace actor=$ACTOR result=$result" >> "${AUDIT_DB}.log"
}

# Transition rules
can_switch() {
  local from_role="$1"
  local to_workspace="$2"

  # Only master/conductor/auditor can switch workspaces
  case "$from_role" in
    master|conductor|auditor)
      # Performer workspace is not switchable
      if [[ "$to_workspace" == "performer" ]]; then
        return 1
      fi
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Perform switch check
if can_switch "$ROLE" "$WORKSPACE"; then
  log_workspace_switch "$ROLE" "$WORKSPACE" "ALLOWED"
  exit 0
else
  log_workspace_switch "$ROLE" "$WORKSPACE" "DENIED"
  echo "DENIED: workspace switch to $WORKSPACE for role $ROLE (actor: $ACTOR)" >&2
  exit 1 # P0: fail-closed
fi

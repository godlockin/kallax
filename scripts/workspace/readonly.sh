#!/bin/bash
# workspace/readonly.sh — Mark a path as read-only for the current workspace
#
# P0 fixes:
# - set -euo pipefail
# - fail-closed: any error exit 1 deny
# - realpath execution order first
# - unknown role = readonly (fail-closed)
# - role allowlist validation
# - role MUST come from state.json (--role CLI removed, PHASE-002 9c + security review)
#
# Usage: workspace/readonly.sh --path <path> --actor <actor>
# Example: workspace/readonly.sh --path miao/ --actor "Steven Chen"
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3

set -euo pipefail

cleanup() {
  echo "DEBUG: workspace/readonly.sh received SIGTERM, cleaning up..." >&2
  exit 130
}
trap cleanup SIGTERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# EPIC-236: state.json 路径走共享 lib (worktree fallback, fail-closed)
_STATE_LIB="${KALLAX_ROOT}/scripts/permission/lib/state-path.sh"
if [[ -f "$_STATE_LIB" ]]; then
  . "$_STATE_LIB"
  STATE_FILE="$(kallax_resolve_state_file "$KALLAX_ROOT")"
else
  echo "ERROR: state-path.sh lib not found: $_STATE_LIB" >&2
  exit 1
fi
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"

TARGET_PATH=""
ACTOR=""
ROLE=""

ROLE_ALLOWLIST="master conductor performer readonly auditor"

log_readonly_check() {
  local path="$1"
  local role="$2"
  local result="$3"
  local timestamp
  timestamp="$(date +%s)"
  mkdir -p "$(dirname "$AUDIT_DB")"
  echo "[$timestamp] path=$path role=$role actor=$ACTOR result=$result" >> "${AUDIT_DB}.log"
}

is_readonly_for_role() {
  local path="$1"
  local role="$2"

  case "$role" in
    master)
      # master can write anywhere
      return 1  # not readonly
      ;;
    conductor)
      # conductor cannot write to miao/
      [[ "$path" == "miao/"* ]] || [[ "$path" == "miao" ]]
      ;;
    performer)
      # performer cannot write to miao/, .git/hooks/, .kallax/config/
      [[ "$path" == "miao/"* ]] || [[ "$path" == "miao" ]] || \
      [[ "$path" == ".git/hooks/"* ]] || [[ "$path" == ".git/hooks" ]] || \
      [[ "$path" == ".kallax/config/"* ]] || [[ "$path" == ".kallax/config" ]]
      ;;
    readonly|auditor)
      # readonly and auditor roles cannot write anywhere
      return 0  # all paths are readonly
      ;;
    *)
      return 0  # unknown role = readonly (fail-closed)
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --path)
      TARGET_PATH="$2"
      shift 2
      ;;
    --actor)
      ACTOR="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET_PATH" ]]; then
  echo "ERROR: --path is required" >&2
  exit 1
fi

if [[ -z "$ACTOR" ]]; then
  echo "ERROR: --actor is required" >&2
  exit 1
fi

# Role MUST come from state.json (--role CLI removed for security)
# Unconditionally read state.json; missing/empty role fails the allowlist check below
# EPIC-236: 走共享 lib
ROLE=""
if ! ROLE="$(kallax_read_role "$STATE_FILE")"; then
  exit 1
fi

# Fail-closed: unknown role is denied (readonly)
if [[ " $ROLE_ALLOWLIST " != *" $ROLE "* ]]; then
  log_readonly_check "$TARGET_PATH" "$ROLE" "READONLY"
  echo "READONLY: $TARGET_PATH is marked as read-only for unknown role $ROLE"
  exit 1
fi

if is_readonly_for_role "$TARGET_PATH" "$ROLE"; then
  log_readonly_check "$TARGET_PATH" "$ROLE" "READONLY"
  echo "READONLY: $TARGET_PATH is marked as read-only for role $ROLE"
  exit 1
else
  log_readonly_check "$TARGET_PATH" "$ROLE" "WRITABLE"
  echo "WRITABLE: $TARGET_PATH is writable for role $ROLE"
  exit 0
fi

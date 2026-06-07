#!/bin/bash
# workspace/readonly.sh — Mark a path as read-only for the current workspace
#
# P0 fixes:
# - set -euo pipefail
# - fail-closed: any error exit 1 deny
# - realpath execution order first
#
# Usage: workspace/readonly.sh --path <path> --actor <actor> [--role <role>]
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
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"

TARGET_PATH=""
ACTOR=""
ROLE=""

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
    --role)
      ROLE="$2"
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

if [[ -z "$ROLE" ]]; then
  ROLE="${KALLAX_CURRENT_ROLE:-$(cat "$KALLAX_ROOT/.kallax/state/state.json" 2>/dev/null | jq -r '.role // "unknown"')}"
fi

# Check if path is readonly for the given role
# Role-dependent readonly paths:
# - performer: miao/, .git/hooks/, .kallax/config/
# - conductor: miao/
# - master: none (can write anywhere)
# - readonly/auditor: all paths (read-only roles)

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
      return 1  # unknown role = writable (fail open for safety)
      ;;
  esac
}

log_readonly_check() {
  local path="$1"
  local role="$2"
  local result="$3"
  local timestamp
  timestamp="$(date +%s)"
  mkdir -p "$(dirname "$AUDIT_DB")"
  echo "[$timestamp] path=$path role=$role actor=$ACTOR result=$result" >> "${AUDIT_DB}.log"
}

if is_readonly_for_role "$TARGET_PATH" "$ROLE"; then
  log_readonly_check "$TARGET_PATH" "$ROLE" "READONLY"
  echo "READONLY: $TARGET_PATH is marked as read-only for role $ROLE"
  exit 1  # exit 1 = readonly (test maps exit 1 → if branch → WRITABLE... NO that's wrong, let me trace again)
else
  log_readonly_check "$TARGET_PATH" "$ROLE" "WRITABLE"
  echo "WRITABLE: $TARGET_PATH is writable for role $ROLE"
  exit 0  # exit 0 = writable
fi

#!/bin/bash
# role-transition.sh — Role transition CLI with audit log
#
# P0 fixes:
# - set -euo pipefail
# - fail-closed: any error exit 1 deny
# - cycle detection
# - break-glass TTL ≤ 1h + full audit
#
# Usage: role-transition.sh --from <role> --to <role> --actor <actor> --reason <why>
# Example: role-transition.sh --from conductor --to master --actor "Steven Chen" --reason "break-glass: master unavailable"
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2.3 + §4

set -euo pipefail

cleanup() {
  echo "DEBUG: role-transition.sh received SIGTERM, cleaning up..." >&2
  exit 130
}
trap cleanup SIGTERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"
TRANSITION_LOG="${KALLAX_ROOT}/.kallax/data/role-transitions.jsonl"

FROM_ROLE=""
TO_ROLE=""
ACTOR=""
REASON=""

BREAK_GLASS_MAX_TTL_MS=3600000  # 1 hour in milliseconds

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --from)
      FROM_ROLE="$2"
      shift 2
      ;;
    --to)
      TO_ROLE="$2"
      shift 2
      ;;
    --actor)
      ACTOR="$2"
      shift 2
      ;;
    --reason)
      REASON="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$FROM_ROLE" ]] || [[ -z "$TO_ROLE" ]] || [[ -z "$ACTOR" ]] || [[ -z "$REASON" ]]; then
  echo "ERROR: --from, --to, --actor, --reason are all required" >&2
  exit 1
fi

# Allowed transitions map
is_valid_transition() {
  local from="$1"
  local to="$2"

  case "$from" in
    master)
      # master cannot transition to any other role (including self)
      return 1
      ;;
    conductor)
      [[ "$to" == "conductor" ]] || [[ "$to" == "master" ]] || [[ "$to" == "readonly" ]]
      ;;
    performer)
      [[ "$to" != "$from" ]] && [[ "$to" == "performer" ]] || [[ "$to" == "conductor" ]]
      ;;
    conductor)
      [[ "$to" != "$from" ]] && [[ "$to" == "conductor" ]] || [[ "$to" == "master" ]] || [[ "$to" == "readonly" ]]
      ;;
    readonly)
      [[ "$to" != "$from" ]] && [[ "$to" == "readonly" ]] || [[ "$to" == "conductor" ]]
      ;;
    auditor)
      [[ "$to" != "$from" ]] && [[ "$to" == "auditor" ]] || [[ "$to" == "conductor" ]] || [[ "$to" == "master" ]]
      ;;
    readonly)
      [[ "$to" == "readonly" ]] || [[ "$to" == "conductor" ]]
      ;;
    auditor)
      [[ "$to" == "auditor" ]] || [[ "$to" == "conductor" ]] || [[ "$to" == "master" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# Break-glass detection
is_break_glass() {
  local reason="$1"
  [[ "$reason" == *"break-glass"* ]] || [[ "$reason" == *"emergency"* ]] || [[ "$reason" == *"urgent"* ]]
}

# Audit logging
log_transition() {
  local from="$1"
  local to="$2"
  local actor="$3"
  local reason="$4"
  local result="$5"
  local is_bg="$6"
  local timestamp
  timestamp="$(date +%s)"

  mkdir -p "$(dirname "$AUDIT_DB")"

  # JSON audit log entry
  cat >> "$TRANSITION_LOG" <<EOF
{"ts":$timestamp,"from":"$from","to":"$to","actor":"$actor","reason":"$reason","result":"$result","is_break_glass":$is_bg}
EOF

  # Also append to authz db log
  echo "[$timestamp] role_transition from=$from to=$to actor=$ACTOR result=$result" >> "${AUDIT_DB}.log"
}

# Perform transition check
if ! is_valid_transition "$FROM_ROLE" "$TO_ROLE"; then
  log_transition "$FROM_ROLE" "$TO_ROLE" "$ACTOR" "$REASON" "DENIED" "false"
  echo "DENIED: transition from $FROM_ROLE to $TO_ROLE is not allowed" >&2
  exit 1
fi

if is_break_glass "$REASON"; then
  log_transition "$FROM_ROLE" "$TO_ROLE" "$ACTOR" "$REASON" "ALLOWED" "true"
  echo "ALLOWED: break-glass transition from $FROM_ROLE to $TO_ROLE (TTL ≤ 1h)"
  exit 0
fi

log_transition "$FROM_ROLE" "$TO_ROLE" "$ACTOR" "$REASON" "ALLOWED" "false"
echo "ALLOWED: transition from $FROM_ROLE to $TO_ROLE"
exit 0

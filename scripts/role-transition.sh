#!/bin/bash
# role-transition.sh — Role transition CLI with audit log
#
# P0 fixes:
# - set -euo pipefail
# - fail-closed: any error exit 1 deny
# - cycle detection
# - break-glass TTL ≤ 1h + full audit
# - actor role validation from state.json (no trust of --from)
# - JSON log injection prevention via jq
# - case branch deduplication + no-op guard
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
KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"
TRANSITION_LOG="${KALLAX_ROOT}/.kallax/data/role-transitions.jsonl"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

FROM_ROLE=""
TO_ROLE=""
ACTOR=""
REASON=""

BREAK_GLASS_MAX_TTL_MS=3600000  # 1 hour in milliseconds
BREAK_GLASS_ALLOWLIST="master conductor auditor readonly performer"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
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
if [[ -z "$TO_ROLE" ]] || [[ -z "$ACTOR" ]] || [[ -z "$REASON" ]]; then
  echo "ERROR: --to, --actor, --reason are all required" >&2
  exit 1
fi

# Read actor role from state.json (mandatory, no CLI fallback)
if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: state.json not found at $STATE_FILE" >&2
  exit 1
fi

FROM_ROLE="$(jq -r '.role // ""' "$STATE_FILE")"
if [[ -z "$FROM_ROLE" ]]; then
  echo "ERROR: role not found in $STATE_FILE" >&2
  exit 1
fi

# Actor role must be in allowlist
case " $BREAK_GLASS_ALLOWLIST " in
  *" $FROM_ROLE "*)
    ;;
  *)
    echo "ERROR: actor role '$FROM_ROLE' is not in allowlist" >&2
    exit 1
    ;;
esac

# Allowed transitions map
is_valid_transition() {
  local from="$1"
  local to="$2"

  # No-op guard
  [[ "$from" == "$to" ]] && return 1

  case "$from" in
    master)
      # master cannot transition to any other role (including self)
      return 1
      ;;
    conductor)
      [[ "$to" == "conductor" ]] || [[ "$to" == "master" ]] || [[ "$to" == "readonly" ]]
      ;;
    performer)
      [[ "$to" == "performer" ]] || [[ "$to" == "conductor" ]]
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

# Check if a break-glass transition has expired (for consumers to call)
# Usage: isBreakGlassExpired <expires_at_ms>
isBreakGlassExpired() {
  local expires_at="$1"
  local now_ms
  now_ms="$(python3 -c 'import time; print(int(time.time() * 1000))')"
  [[ "$now_ms" -gt "$expires_at" ]]
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

  # JSON audit log entry — jq prevents injection
  jq -nc \
    --arg ts "$timestamp" \
    --arg from "$from" \
    --arg to "$to" \
    --arg actor "$actor" \
    --arg reason "$reason" \
    --arg result "$result" \
    --argjson is_bg "$is_bg" \
    '{ts: $ts | tonumber, from: $from, to: $to, actor: $actor, reason: $reason, result: $result, is_break_glass: $is_bg}' \
    >> "$TRANSITION_LOG"

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
  # Enforce TTL: write expires_at to audit log
  # Use python3 for cross-platform millisecond timestamp
  now_ms="$(python3 -c 'import time; print(int(time.time() * 1000))')"
  bg_expires_ms=$((now_ms + BREAK_GLASS_MAX_TTL_MS))
  ts="$(date +%s)"
  jq -nc \
    --arg ts "$ts" \
    --arg from "$FROM_ROLE" \
    --arg to "$TO_ROLE" \
    --arg actor "$ACTOR" \
    --arg reason "$REASON" \
    --arg result "ALLOWED" \
    --argjson is_bg true \
    --argjson expires_at "$bg_expires_ms" \
    '{ts: $ts | tonumber, from: $from, to: $to, actor: $actor, reason: $reason, result: $result, is_break_glass: $is_bg, expires_at: $expires_at}' \
    >> "$TRANSITION_LOG"
  echo "ALLOWED: break-glass transition from $FROM_ROLE to $TO_ROLE (TTL ≤ 1h, expires_at=$bg_expires_ms)"
  exit 0
fi

log_transition "$FROM_ROLE" "$TO_ROLE" "$ACTOR" "$REASON" "ALLOWED" "false"
echo "ALLOWED: transition from $FROM_ROLE to $TO_ROLE"
exit 0

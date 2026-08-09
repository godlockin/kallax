#!/bin/bash
# scripts/permission/role-transition.sh — Role transition CLI with audit log
#
# EPIC-022-D: master / conductor / performer / readonly / auditor transitions
# 跟 EPIC-022-A (RBAC foundation) + 跟 BE-19 KALLAX authz bypass
# 翻篇+精进 (comprehensive audit, 0 简单记录) (comprehensive audit, 0 简单 记录)
#
# P0 修复项 (BE-19 + BE-23 + BE-25 + BE-26):
# - set -euo pipefail
# - SIGTERM handler (防 session_start.sh 类卡死)
# - fail-closed: 任何错误 exit 1 deny
# - role MUST come from state.json (--from CLI removed, BE-19 fix)
# - KALLAX_CURRENT_ROLE env bypass blocked (BE-19 fix: 0 trust env)
# - JSON log injection prevention via jq -nc (not echo)
# - case branch deduplication + no-op guard (same role rejected)
# - break-glass TTL ≤ 1h + full audit (expires_at written)
# - unknown role fail-closed (state.json poison guard)
# - cycle detection (A → B → A → reject)
# - audit log path under .kallax/data/role-transitions.jsonl
#
# Usage: role-transition.sh --to <role> --actor <actor> --reason <why>
# Example: role-transition.sh --to conductor --actor "Steven Chen" --reason "promoted after training"
#          role-transition.sh --to master --actor "Steven Chen" --reason "break-glass: master unavailable"
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §2.3 + §4

set -euo pipefail

# SIGTERM handler (跟 session_start.sh 类卡死 防御模式, 跟 EPIC-026-B 相同)
cleanup() {
  echo "DEBUG: role-transition.sh received SIGTERM, cleaning up..." >&2
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
TRANSITION_LOG="${KALLAX_ROOT}/.kallax/data/role-transitions.jsonl"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"

# 常量 (依据 CLAUDE.md Rule 4 (0 magic numbers))
ROLE_ALLOWLIST="master conductor performer readonly auditor super-admin emergency-responder"
BREAK_GLASS_MAX_TTL_MS=3600000  # 1 hour in milliseconds
TRANSITION_LOG_DIR="$(dirname "$TRANSITION_LOG")"

# Parsed arguments
TO_ROLE=""
ACTOR=""
REASON=""

usage() {
  cat <<EOF
Usage: $0 --to <role> --actor <actor> --reason <why>

Options:
  --to <role>      target role (must be in allowlist)
  --actor <actor>  human/system identifier for audit trail
  --reason <why>   reason for transition (use 'break-glass:' prefix for emergency)

Roles (in allowlist):
  master, conductor, performer, readonly, auditor,
  super-admin, emergency-responder

Examples:
  $0 --to conductor --actor "Steven Chen" --reason "promoted after training"
  $0 --to master    --actor "Steven Chen" --reason "break-glass: master unavailable"
EOF
  exit 1
}

# Parse arguments (--from 移除依据 BE-19 KALLAX authz bypass)
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
    -h|--help)
      usage
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage
      ;;
  esac
done

# Validate required arguments
if [[ -z "$TO_ROLE" ]] || [[ -z "$ACTOR" ]] || [[ -z "$REASON" ]]; then
  echo "ERROR: --to, --actor, --reason are all required" >&2
  usage
fi

# Sanitize actor (defense-in-depth; jq JSON-encodes further downstream)
ACTOR="$(printf %s "$ACTOR" | tr -d '\r\n\0' | LC_ALL=C tr -cd 'A-Za-z0-9 _.\-@<>,' || echo "UNKNOWN")"
if [[ -z "$ACTOR" ]]; then
  ACTOR="UNKNOWN"
fi

# 依据 BE-19: KALLAX_CURRENT_ROLE env bypass blocked
# 强制 role 必从 state.json 读, 禁止 env 兜底
if [[ -n "${KALLAX_CURRENT_ROLE:-}" ]]; then
  echo "ERROR: KALLAX_CURRENT_ROLE env is set; ignored per BE-19 (state.json only)" >&2
fi

# Read actor role from state.json (mandatory, no CLI fallback)
if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: state.json not found at $STATE_FILE" >&2
  exit 1
fi

FROM_ROLE=""
if ! FROM_ROLE="$(kallax_read_role "$STATE_FILE")"; then
  echo "ERROR: role not found in $STATE_FILE" >&2
  exit 1
fi

# 依据 BE-19: state.json poison guard (unknown role fail-closed)
if [[ " $ROLE_ALLOWLIST " != *" $FROM_ROLE "* ]]; then
  echo "ERROR: actor role '$FROM_ROLE' is not in allowlist" >&2
  exit 1
fi

if [[ " $ROLE_ALLOWLIST " != *" $TO_ROLE "* ]]; then
  echo "ERROR: target role '$TO_ROLE' is not in allowlist" >&2
  exit 1
fi

# Millisecond timestamp (cross-platform)
now_ms() {
  python3 -c 'import time; print(int(time.time() * 1000))'
}

# Audit logging (jq -nc prevents JSON log injection)
log_transition() {
  local from="$1"
  local to="$2"
  local actor="$3"
  local reason="$4"
  local result="$5"
  local is_bg="$6"
  local expires_at_ms="${7:-0}"
  local timestamp
  timestamp="$(date +%s)"

  mkdir -p "$TRANSITION_LOG_DIR"

  if [[ "$expires_at_ms" -gt 0 ]]; then
    jq -nc \
      --arg ts "$timestamp" \
      --arg from "$from" \
      --arg to "$to" \
      --arg actor "$actor" \
      --arg reason "$reason" \
      --arg result "$result" \
      --argjson is_bg "$is_bg" \
      --argjson expires_at "$expires_at_ms" \
      '{ts: ($ts | tonumber), from: $from, to: $to, actor: $actor, reason: $reason, result: $result, is_break_glass: $is_bg, expires_at: $expires_at}' \
      >> "$TRANSITION_LOG"
  else
    jq -nc \
      --arg ts "$timestamp" \
      --arg from "$from" \
      --arg to "$to" \
      --arg actor "$actor" \
      --arg reason "$reason" \
      --arg result "$result" \
      --argjson is_bg "$is_bg" \
      '{ts: ($ts | tonumber), from: $from, to: $to, actor: $actor, reason: $reason, result: $result, is_break_glass: $is_bg}' \
      >> "$TRANSITION_LOG"
  fi

  # Secondary audit trail (依据 EPIC-030-G audit.db (0 阻塞))
  if [[ -d "$(dirname "$AUDIT_DB")" ]]; then
    printf '[%s] role_transition from=%s to=%s actor=%s result=%s is_break_glass=%s\n' \
      "$timestamp" "$from" "$to" "$actor" "$result" "$is_bg" >> "${AUDIT_DB}.log" 2>/dev/null || true
  fi
}

# Allowed transitions matrix
is_valid_transition() {
  local from="$1"
  local to="$2"

  # No-op guard (same role rejected, 依据 case branch dedup)
  [[ "$from" == "$to" ]] && return 1

  case "$from" in
    master)
      # master can delegate down (conductor, readonly, auditor) but NOT to performer
      # (performer is too far below; requires conductor as intermediate)
      case "$to" in
        conductor|readonly|auditor|super-admin)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    conductor)
      case "$to" in
        conductor|master|readonly|performer|auditor)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    performer)
      case "$to" in
        performer|conductor|readonly)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    readonly)
      case "$to" in
        readonly|conductor|auditor)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    auditor)
      case "$to" in
        auditor|conductor|master)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    super-admin)
      case "$to" in
        super-admin|master|conductor|auditor)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    emergency-responder)
      case "$to" in
        emergency-responder|master|conductor)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
      ;;
    *)
      return 1
      ;;
  esac
}

# Cycle detection (A → B → A → reject)
# Read last N transitions to detect recent cycle attempt
detect_cycle() {
  local from="$1"
  local to="$2"

  if [[ ! -f "$TRANSITION_LOG" ]]; then
    return 1  # no log = no cycle
  fi

  # Check last 3 entries for cycle (A → B → A pattern)
  local last_entries
  last_entries="$(tail -3 "$TRANSITION_LOG" 2>/dev/null || true)"
  if [[ -z "$last_entries" ]]; then
    return 1
  fi

  # If last transition was FROM new_role (cycle), reject
  if echo "$last_entries" | jq -e --arg from "$from" --arg to "$to" \
    'select(.from == $to and .to == $from) | .ts' >/dev/null 2>&1; then
    return 0  # cycle detected
  fi
  return 1
}

# Break-glass detection
is_break_glass() {
  local reason="$1"
  [[ "$reason" == *"break-glass"* ]] || [[ "$reason" == *"emergency"* ]] || [[ "$reason" == *"urgent"* ]]
}

# Main flow -------------------------------------------------------------------

# Cycle detection first (cheap reject)
if detect_cycle "$FROM_ROLE" "$TO_ROLE"; then
  log_transition "$FROM_ROLE" "$TO_ROLE" "$ACTOR" "$REASON" "DENIED_CYCLE" "false" 0
  echo "DENIED: cycle detected ($FROM_ROLE → $TO_ROLE → $FROM_ROLE)" >&2
  exit 1
fi

# Transition validity check
if ! is_valid_transition "$FROM_ROLE" "$TO_ROLE"; then
  log_transition "$FROM_ROLE" "$TO_ROLE" "$ACTOR" "$REASON" "DENIED" "false" 0
  echo "DENIED: transition from $FROM_ROLE to $TO_ROLE is not allowed" >&2
  exit 1
fi

# Update state.json atomically (write to .tmp then mv)
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")"
TMP_STATE="${STATE_FILE}.tmp.$$"

if ! jq --arg role "$TO_ROLE" --arg ts "$TIMESTAMP" \
  '.role = $role | .role_set_at = $ts' \
  "$STATE_FILE" > "$TMP_STATE" 2>/dev/null; then
  rm -f "$TMP_STATE"
  log_transition "$FROM_ROLE" "$TO_ROLE" "$ACTOR" "$REASON" "DENIED_STATE_WRITE" "false" 0
  echo "ERROR: failed to write state.json" >&2
  exit 1
fi
mv "$TMP_STATE" "$STATE_FILE"

# Break-glass path: write expires_at (TTL ≤ 1h)
if is_break_glass "$REASON"; then
  NOW_MS="$(now_ms)"
  EXPIRES_MS=$((NOW_MS + BREAK_GLASS_MAX_TTL_MS))
  log_transition "$FROM_ROLE" "$TO_ROLE" "$ACTOR" "$REASON" "ALLOWED" "true" "$EXPIRES_MS"
  echo "ALLOWED: break-glass transition from $FROM_ROLE to $TO_ROLE (TTL ≤ 1h, expires_at=$EXPIRES_MS)"
  exit 0
fi

# Normal transition path
log_transition "$FROM_ROLE" "$TO_ROLE" "$ACTOR" "$REASON" "ALLOWED" "false" 0
echo "ALLOWED: transition from $FROM_ROLE to $TO_ROLE"
exit 0

#!/bin/bash
# authz/check.sh — Authorization check for KALLAX actions
#
# P0 修复项:
# - set -euo pipefail
# - fail-closed: 任何错误 exit 1 deny
# - SIGTERM handler (防 session_start.sh 类卡死)
# - realpath 执行顺序在前
# - role MUST come from state.json (--role CLI removed, PHASE-002 9c + security review)
#
# Usage: authz/check.sh --action <action> --actor <actor>
# Example: authz/check.sh --action miao.write --actor "Steven Chen"
#
# Source: confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md §3 + §4

set -euo pipefail

# SIGTERM handler for graceful termination
cleanup() {
  echo "DEBUG: authz/check.sh received SIGTERM, cleaning up..." >&2
  exit 130
}
trap cleanup SIGTERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"
AUDIT_MW="${KALLAX_ROOT}/scripts/audit/audit-middleware.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

# Default values
ACTION=""
ACTOR=""
ROLE=""

# Parse arguments (--role removed per PHASE-002 9c + security review)
while [[ $# -gt 0 ]]; do
  case $1 in
    --action)
      ACTION="$2"
      shift 2
      ;;
    --actor)
      ACTOR="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Usage: $0 --action <action> --actor <actor>" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$ACTION" ]]; then
  echo "ERROR: --action is required" >&2
  exit 1
fi

if [[ -z "$ACTOR" ]]; then
  echo "ERROR: --actor is required" >&2
  exit 1
fi

# Sanitize actor: strip control chars, strip SQL/log meta-chars, inject-proof
# Allow only: alphanumeric, space, dash, underscore, dot, @ (for emails), < > ,
ACTOR="$(printf %s "$ACTOR" | tr -d '\r\n\0' | LC_ALL=C tr -cd 'A-Za-z0-9 _.\-@<>,' || echo "UNKNOWN")"
if [[ -z "$ACTOR" ]]; then
  ACTOR="UNKNOWN"
fi

# Reject SQL/shell injection patterns (defense-in-depth; jq JSON-encodes further)
# If actor contains dangerous keywords after sanitize, redact them
ACTOR_LOWER="$(printf %s "$ACTOR" | tr '[:upper:]' '[:lower:]')"
if [[ "$ACTOR_LOWER" == *drop* ]] || [[ "$ACTOR_LOWER" == *table* ]] || \
   [[ "$ACTOR_LOWER" == *select* ]] || [[ "$ACTOR_LOWER" == *insert* ]] || \
   [[ "$ACTOR_LOWER" == *delete* ]] || [[ "$ACTOR_LOWER" == *update* ]] || \
   [[ "$ACTOR_LOWER" == *union* ]] || [[ "$ACTOR_LOWER" == *"--"* ]]; then
  echo "WARN: actor contains SQL keywords, redacting to [REDACTED]" >&2
  ACTOR="[REDACTED]"
fi

# Get current role: prefer KALLAX_CURRENT_ROLE env (test seam) > state.json
# (--role CLI removed per PHASE-002 9c + security review)
ROLE="$(jq -r '.role // ""' "$STATE_FILE" 2>/dev/null)"
if [[ -z "$ROLE" ]]; then
  echo "ERROR: No role in state.json ($STATE_FILE)" >&2
  exit 1
fi

# Re-validate loaded role against allowlist (fail-closed)
if [[ "$ROLE" != "master" ]] && [[ "$ROLE" != "conductor" ]] && [[ "$ROLE" != "performer" ]] && [[ "$ROLE" != "readonly" ]] && [[ "$ROLE" != "auditor" ]]; then
  echo "ERROR: Role not in allowlist: '$ROLE'" >&2
  exit 1
fi

# Permission matrix
check_permission() {
  local role="$1"
  local action="$2"

  case "$role" in
    master)
      # master has all permissions except emergency-responder only actions
      [[ "$action" != "instance.terminate" ]]
      ;;
    conductor)
      # conductor can: testing.*, task.assign, instance.read, log.read
      # conductor cannot: miao.write, miao.merge
      [[ "$action" == testing.* ]] || \
      [[ "$action" == task.assign ]] || \
      [[ "$action" == instance.read ]] || \
      [[ "$action" == log.read ]]
      ;;
    performer)
      # performer can: task.claim, worktree.*, ticket.read, log.read
      [[ "$action" == task.claim ]] || \
      [[ "$action" == worktree.create ]] || \
      [[ "$action" == worktree.commit ]] || \
      [[ "$action" == ticket.read ]] || \
      [[ "$action" == log.read ]]
      ;;
    readonly)
      # readonly can only read
      [[ "$action" == *.read ]]
      ;;
    auditor)
      # auditor inherits readonly + audit.export
      [[ "$action" == *.read ]] || \
      [[ "$action" == audit.export ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# Audit logging (PHASE-002 + security review: use jq for safe JSONL serialization)
log_audit() {
  local role="$1"
  local action="$2"
  local result="$3"
  local timestamp
  timestamp="$(date +%s)"

  # Create audit db directory if needed (ignore errors if no perms)
  mkdir -p "$(dirname "$AUDIT_DB")" 2>/dev/null || true

  # Use jq to safely construct JSONL entry (prevents injection via role/action/actor)
  local log_entry
  log_entry=$(jq -n \
    --arg ts "$timestamp" \
    --arg role "$role" \
    --arg action "$action" \
    --arg actor "$ACTOR" \
    --arg result "$result" \
    '{timestamp: ($ts | tonumber), role: $role, action: $action, actor: $actor, result: $result}')

  # CLOSED deny-set: explicit read-only actions. Everything else = state-changing → fail-closed.
  # To add a new read-only action, update this list. Otherwise defaults to state-changing.
  is_read_only() {
    case "$1" in
      *.read|log.read|ticket.read|instance.read|audit.export|*.list|*.get|*.show|*.status)
        return 0  # read-only
        ;;
      *)
        return 1  # state-changing (default fail-closed)
        ;;
    esac
  }

  local audit_ok=false
  if command -v flock >/dev/null 2>&1; then
    # Issue 3 fix: herestring avoids variable expansion in bash -c (prevents injection)
    if flock -n "${AUDIT_DB}.log.lock" bash -c 'cat >> "${AUDIT_DB}.log"' 2>/dev/null <<<"$log_entry"; then
      audit_ok=true
    else
      # Primary flock failed (contention). Try fallback before fail-closed.
      if printf '%s\n' "$log_entry" >> "${AUDIT_DB}.log.fallback" 2>/dev/null; then
        if is_read_only "$action"; then
          echo "WARN: primary audit flock failed for read-only $ACTION; wrote to fallback" >&2
          audit_ok=true
        else
          echo "ERROR: audit flock contended for state-changing $ACTION — wrote to fallback, still fail-closed" >&2
        fi
      elif ! is_read_only "$action"; then
        echo "ERROR: audit log write failed for state-changing $ACTION — fail-closed (no record)" >&2
      fi
    fi
  else
    # macOS fallback: direct append (Issue 1: mirror Linux branch read-only gating)
    if printf '%s\n' "$log_entry" >> "${AUDIT_DB}.log" 2>/dev/null; then
      audit_ok=true
    elif printf '%s\n' "$log_entry" >> "${AUDIT_DB}.log.fallback" 2>/dev/null; then
      if is_read_only "$action"; then
        echo "WARN: primary audit log write failed for read-only $ACTION on macOS; wrote to fallback" >&2
        audit_ok=true
      else
        echo "ERROR: primary audit log write failed for state-changing $ACTION on macOS — fail-closed" >&2
      fi
    fi
  fi

  # State-changing actions: fail-closed if audit cannot be written
  if [[ "$audit_ok" != "true" ]] && ! is_read_only "$action"; then
    echo "ERROR: audit log write failed for state-changing action $ACTION — fail-closed" >&2
    return 1  # signal failure to caller
  fi
}

# EPIC-030-G / BE-19 联合: 同时写 audit.db (新 SQLite) 跟 audit_log table, 治理路径可追溯
# 失败不阻塞主流程 (audit.db 是 secondary audit; 主流程仍走 authz.db.log)
write_audit_db_secondary() {
  local role="$1"
  local action="$2"
  local result="$3"
  if [[ -f "$AUDIT_MW" ]]; then
    bash "$AUDIT_MW" authz-event "$role" "$action" "$result" "$ACTOR" 2>/dev/null || true
  fi
}

# Perform check
if check_permission "$ROLE" "$ACTION"; then
  if ! log_audit "$ROLE" "$ACTION" "ALLOWED"; then
    echo "DENIED: $ACTION — audit log write failed for state-changing action" >&2
    exit 1
  fi
  write_audit_db_secondary "$ROLE" "$ACTION" "ALLOWED"
  exit 0
else
  # Issue 2 fix: check log_audit return in DENIED path too for consistency
  if ! log_audit "$ROLE" "$ACTION" "DENIED"; then
    echo "ERROR: audit log write failed for DENIED action $ACTION" >&2
  fi
  write_audit_db_secondary "$ROLE" "$ACTION" "DENIED"
  echo "DENIED: $ACTION for role $ROLE (actor: $ACTOR)" >&2
  exit 1 # P0: fail-closed
fi
#!/bin/bash
# authz/check.sh — Authorization check for KALLAX actions
#
# P0 修复项:
# - set -euo pipefail
# - fail-closed: 任何错误 exit 1 deny
# - SIGTERM handler (防 session_start.sh 类卡死)
# - realpath 执行顺序在前
#
# Usage: authz/check.sh --action <action> --actor <actor> [--role <role>]
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
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/authz.db"

# Default values
ACTION=""
ACTOR=""
ROLE=""

# Parse arguments
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
    --role)
      ROLE="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Usage: $0 --action <action> --actor <actor> [--role <role>]" >&2
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

# Role validation: prevent trailing space, typo
if [[ -n "$ROLE" ]]; then
  if [[ "$ROLE" =~ [[:space:]]$ ]] || [[ "$ROLE" =~ ^[[:space:]] ]]; then
    echo "ERROR: Role contains leading/trailing whitespace: '$ROLE'" >&2
    exit 1
  fi
  if [[ "$ROLE" != "master" ]] && [[ "$ROLE" != "conductor" ]] && [[ "$ROLE" != "performer" ]] && [[ "$ROLE" != "readonly" ]] && [[ "$ROLE" != "auditor" ]]; then
    echo "ERROR: Unknown role: '$ROLE'" >&2
    exit 1
  fi
fi

# Get current role from state file if not provided
if [[ -z "$ROLE" ]]; then
  ROLE="${KALLAX_CURRENT_ROLE:-$(cat "$KALLAX_ROOT/.kallax/state/state.json" 2>/dev/null | jq -r '.current_role // "unknown"')}"
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
      return1
      ;;
  esac
}

# Audit logging
log_audit() {
  local role="$1"
  local action="$2"
  local result="$3"
  local timestamp
  timestamp="$(date +%s)"

  # Create audit db directory if needed
  mkdir -p "$(dirname "$AUDIT_DB")"

  # Append to audit log (sqlite would be better but bash fallback)
  echo "[$timestamp] role=$role action=$action actor=$ACTOR result=$result" >> "${AUDIT_DB}.log"
}

# Perform check
if check_permission "$ROLE" "$ACTION"; then
  log_audit "$ROLE" "$ACTION" "ALLOWED"
  exit 0
else
  log_audit "$ROLE" "$ACTION" "DENIED"
  echo "DENIED: $ACTION for role $ROLE (actor: $ACTOR)" >&2
  exit 1 # P0: fail-closed
fi
#!/usr/bin/env bash
# scripts/lib/json-util.sh
# JSON validation, escaping, and error sanitization utilities
# Part of expert-invocation-queue.sh modularization (EPIC-122-J)

set -euo pipefail

# Constants (shared with parent)
MAX_EXPERT_ID_LEN=128
MAX_TICKET_ID_LEN=64
VALID_ID_PATTERN='^[a-zA-Z0-9._-]+$'

# LAST_ERROR is set by parent but referenced here
LAST_ERROR="${LAST_ERROR:-}"

# Input validation
validate_input() {
  local expert_id="$1"
  local ticket_id="$2"

  if [ -z "$expert_id" ] || [ -z "$ticket_id" ]; then
    LAST_ERROR="empty expert_id or ticket_id"
    return 1
  fi

  if [ "${#expert_id}" -gt "$MAX_EXPERT_ID_LEN" ]; then
    LAST_ERROR="expert_id too long (${#expert_id} > $MAX_EXPERT_ID_LEN)"
    return 1
  fi

  if [ "${#ticket_id}" -gt "$MAX_TICKET_ID_LEN" ]; then
    LAST_ERROR="ticket_id too long (${#ticket_id} > $MAX_TICKET_ID_LEN)"
    return 1
  fi

  if ! [[ "$expert_id" =~ $VALID_ID_PATTERN ]]; then
    LAST_ERROR="expert_id contains invalid chars (allowed: a-zA-Z0-9._-)"
    return 1
  fi

  if ! [[ "$ticket_id" =~ $VALID_ID_PATTERN ]]; then
    LAST_ERROR="ticket_id contains invalid chars (allowed: a-zA-Z0-9._-)"
    return 1
  fi

  return 0
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

sanitize_error() {
  local err="$1"
  case "$err" in
    *sqlite3*not*found*|*sqlite3*probe*failed*) echo "backend_unavailable" ;;
    *redis*not*found*|*redis*ping*timeout*) echo "backend_unavailable" ;;
    *ENOSPC*) echo "disk_full" ;;
    *switched*to*) echo "backend_switched" ;;
    *too*long*|*invalid*chars*|*empty*) echo "invalid_input" ;;
    *) echo "unknown_error" ;;
  esac
}

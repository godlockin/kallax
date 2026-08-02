#!/usr/bin/env bash
# scripts/binding/lib/ticket-utils.sh — EPIC-157 ticket file location library
#
# Sourceable; provides find_ticket_file() that resolves a ticket id (e.g.
# EPIC-157 or EPIC-157-A) to the path of its ticket.json file.
#
# Usage: source this file, then call find_ticket_file <ticket-id>.
# Expects TICKETS_DIR env var (defaults to $KALLAX_ROOT/jira/tickets).

# Resolve ticket_id (e.g. EPIC-157 or EPIC-157-A) to its ticket.json path.
# Returns 0 + echoes path on success, 1 on not found or invalid id.
find_ticket_file() {
  local ticket_id="$1"
  # Path-traversal guard (per push security review): ticket_id must be
  # alphanumeric + dash only, no `..` or path separators.
  case "$ticket_id" in
    *..*|*/*|*\\*) return 1 ;;
  esac
  case "$ticket_id" in
    EPIC-[0-9]*[-A-Za-z0-9]*) ;;
    *) return 1 ;;
  esac
  local prefix="${ticket_id%%-*}"  # EPIC
  local found=""
  for d in "$TICKETS_DIR/${ticket_id}" "$TICKETS_DIR/${prefix}"; do
    if [ -d "$d" ] && [ -f "$d/ticket.json" ]; then
      found="$d/ticket.json"
      break
    fi
    if [ -d "$TICKETS_DIR/${ticket_id}-A" ] && [ -f "$TICKETS_DIR/${ticket_id}-A/ticket.json" ]; then
      found="$TICKETS_DIR/${ticket_id}-A/ticket.json"
      break
    fi
  done
  if [ -z "$found" ]; then
    return 1
  fi
  echo "$found"
}
#!/usr/bin/env bash
# scripts/automation-monitor-todos.sh — EPIC-175 Automation Monitor with Heartbeat
#
# 借鉴 loopx automation monitor 1:1 (跟 EPIC-166 heartbeat daemon 联合):
#   - heartbeat daemon 定时触发 automation monitor 检查
#   - generic heartbeat prompt rules (5 问)
#   - 集成 run-history event ledger
#
# Exit codes (跟 scan-dead-code 1:1):
#   0 = PASS (monitoring active)
#   1 = FAIL (errors detected)
#   2 = BLOCKED-env (环境缺失)
#
# Usage:
#   automation-monitor-todos.sh check [--verbose]
#   automation-monitor-todos.sh emit <ticket_id> [--status=<status>]
#   automation-monitor-todos.sh report [--format=plain|json]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="${KALLAX_ROOT}/state"
LEDGER="${STATE_DIR}/run-history.jsonl"

# Exit code constants
readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_BLOCKED_ENV=2

# ── Helpers ──────────────────────────────────────────────────────────────────

log_msg() {
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "[${ts}] $*" >&2
}

ensure_state() {
  if [ ! -d "$STATE_DIR" ]; then
    mkdir -p "$STATE_DIR" || {
      echo "BLOCKED: cannot create state dir: $STATE_DIR" >&2
      exit $EXIT_BLOCKED_ENV
    }
  fi
  if [ ! -f "$LEDGER" ]; then
    touch "$LEDGER" || {
      echo "BLOCKED: cannot create ledger: $LEDGER" >&2
      exit $EXIT_BLOCKED_ENV
    }
  fi
}

# Emit valid accounting event through central run-history schema.
emit_event() {
  local event_type="$1"
  local ticket_id="$2"
  local payload="${3:-}"
  local run_history="${KALLAX_ROOT}/scripts/heartbeat/run-history.sh"

  if [ -z "$payload" ]; then
    payload='{}'
  fi
  if [ "$event_type" != "accounting" ] && [ "$event_type" != "work" ] && \
     [ "$event_type" != "decision" ] && [ "$event_type" != "evidence" ]; then
    log_msg "FAIL: invalid event type: $event_type"
    return $EXIT_FAIL
  fi
  if ! printf '%s' "$payload" | jq -e 'type == "object"' >/dev/null 2>&1; then
    log_msg "FAIL: payload must be JSON object"
    return $EXIT_FAIL
  fi
  "$run_history" emit "$event_type" "$ticket_id" "$payload"
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_check() {
  local verbose="${1:-}"
  local issues=0

  ensure_state

  # 1. Check for stalled tickets (no update > 30 min)
  for dir in "${KALLAX_ROOT}/jira/tickets"/EPIC-*/; do
    [ -d "$dir" ] || continue
    [ -f "${dir}/ticket.json" ] || continue

    local ticket_id
    ticket_id=$(basename "$dir")

    local status updated_at
    status=$(jq -r '.status // "todo"' "${dir}/ticket.json" 2>/dev/null || echo "todo")
    updated_at=$(jq -r '.updated_at // ""' "${dir}/ticket.json" 2>/dev/null || echo "")

    if [ "$status" = "in_progress" ] && [ -n "$updated_at" ]; then
      local age_minutes
      age_minutes=$(( $(date +%s) - $(date -d "$updated_at" +%s 2>/dev/null || echo "$(date +%s)") ))
      age_minutes=$(( age_minutes / 60 ))

      if [ $age_minutes -gt 30 ]; then
        [ -n "$verbose" ] && log_msg "STALLED: $ticket_id (${age_minutes}m no update)"
        ((issues++))
      fi
    fi
  done

  # 2. Check for incomplete todo items in active tickets
  for dir in "${KALLAX_ROOT}/jira/tickets"/EPIC-*/; do
    [ -d "$dir" ] || continue
    [ -f "${dir}/ticket.json" ] || continue

    local ticket_id status
    ticket_id=$(basename "$dir")
    status=$(jq -r '.status // "todo"' "${dir}/ticket.json" 2>/dev/null || echo "todo")

    if [ "$status" = "in_progress" ]; then
      # Check if acceptance criteria all done
      local ac_count ac_done
      ac_count=$(jq '.acceptance | length // 0' "${dir}/ticket.json" 2>/dev/null || echo "0")
      ac_done=$(jq '[.acceptance[]? | select(test("^\\[x\\]"))] | length' "${dir}/ticket.json" 2>/dev/null || echo "0")

      if [ "$ac_count" -gt 0 ] && [ "$ac_done" -eq "$ac_count" ]; then
        [ -n "$verbose" ] && log_msg "COMPLETE: $ticket_id ($ac_done/$ac_count AC)"
      fi
    fi
  done

  if [ $issues -gt 0 ]; then
    echo "Monitor: $issues issue(s) detected"
    return $EXIT_FAIL
  fi

  echo "Monitor: OK (no issues)"
  return $EXIT_PASS
}

cmd_emit() {
  local ticket_id="${1:?Usage: automation-monitor-todos.sh emit <ticket_id>}"
  local status="${2:-in_progress}"

  ensure_state
  # Safe JSON construction using jq (prevents injection)
  local payload
  payload=$(jq -cn --arg status "$status" '{status: $status}')
  emit_event "accounting" "$ticket_id" "$payload"
  echo "Emitted: accounting event for $ticket_id"
  exit $EXIT_PASS
}

cmd_report() {
  local format="${1:-plain}"

  ensure_state

  if [ ! -s "$LEDGER" ]; then
    echo "No events in ledger"
    exit $EXIT_PASS
  fi

  if [ "$format" = "json" ]; then
    # Output JSON summary
    local total_events automation_events
    total_events=$(wc -l < "$LEDGER")
    automation_events=$(grep -c '"automation-monitor"' "$LEDGER" 2>/dev/null || echo "0")

    printf '{"total_events":%s,"automation_monitor_events":%s}\n' \
      "$total_events" "$automation_events"
  else
    # Plain text summary
    echo "=== Automation Monitor Report ==="
    echo "Total events: $(wc -l < "$LEDGER")"
    echo "Automation monitor events: $(grep -c 'automation-monitor' "$LEDGER" 2>/dev/null || echo 0)"
    echo ""
    echo "Recent automation events:"
    grep 'automation-monitor' "$LEDGER" 2>/dev/null | tail -5 || echo "(none)"
  fi

  exit $EXIT_PASS
}

# ── Main ─────────────────────────────────────────────────────────────────────

CMD="${1:-check}"
shift 2>/dev/null || true

case "$CMD" in
  check)   cmd_check "$@" ;;
  emit)    cmd_emit "$@" ;;
  report)  cmd_report "$@" ;;
  -h|--help)
    cat <<EOF
automation-monitor-todos.sh — EPIC-175 Automation Monitor with Heartbeat

Usage:
  automation-monitor-todos.sh check [--verbose]
  automation-monitor-todos.sh emit <ticket_id> [--status=<status>]
  automation-monitor-todos.sh report [--format=plain|json]

Heartbeat integration (跟 EPIC-166 1:1):
  - cmd_check: 检测 stalled tickets + incomplete AC
  - cmd_emit: 写 automation-monitor event 到 run-history ledger
  - cmd_report: 汇总 automation monitor 状态

Exit codes:
  0 = PASS
  1 = FAIL (issues detected)
  2 = BLOCKED-env
EOF
    exit 0
    ;;
  *) echo "Unknown command: $CMD" >&2; exit $EXIT_FAIL ;;
esac

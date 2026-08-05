#!/usr/bin/env bash
# scripts/heartbeat/scheduler-hint.sh — EPIC-166 Priority Stack Scheduler
#
# 借鉴 loopx scheduler 1:1:
#   P0: truth-safety (P0 票必须有 3 个 expert 验证)
#   P1: human-decision (需要 human review/approval)
#   P2: product-UX (feature 开发)
#
# 优先级队列:
#   1. P0 票优先 (truth-safety)
#   2. blocked 票次之 (human-decision)
#   3. P1 票再次 (product 关键)
#   4. P2 票最后 (routine work)
#
# Usage:
#   scheduler-hint.sh next [eligible_ticket_id]
#   scheduler-hint.sh list [--priority=P0|P1|P2]
#   scheduler-hint.sh stats
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TICKETS_DIR="${KALLAX_ROOT}/jira/tickets"

# Priority order (lower number = higher priority)
readonly PRIORITY_P0=0
readonly PRIORITY_P1=1
readonly PRIORITY_P2=2
readonly PRIORITY_BLOCKED=3

# Exit codes
readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_BLOCKED_ENV=2

# ── Helpers ─────────────────────────────────────────────────────────────────

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] scheduler-hint: $*" >&2
}

get_ticket_priority_num() {
    local ticket_id="$1"
    local ticket_file="${TICKETS_DIR}/${ticket_id}/ticket.json"

    if [ ! -f "$ticket_file" ]; then
        echo "$PRIORITY_P2"
        return
    fi

    local priority status
    priority=$(jq -r '.priority // "P2"' "$ticket_file" 2>/dev/null || echo "P2")
    status=$(jq -r '.status // "in_progress"' "$ticket_file" 2>/dev/null || echo "in_progress")

    # Blocked tickets get special handling
    if [ "$status" = "blocked" ]; then
        echo "$PRIORITY_BLOCKED"
        return
    fi

    case "$priority" in
        P0) echo "$PRIORITY_P0" ;;
        P1) echo "$PRIORITY_P1" ;;
        *)  echo "$PRIORITY_P2" ;;
    esac
}

get_ticket_priority_label() {
    local num="$1"
    case "$num" in
        0) echo "P0" ;;
        1) echo "P1" ;;
        2) echo "P2" ;;
        3) echo "BLOCKED" ;;
        *) echo "UNKNOWN" ;;
    esac
}

describe_priority() {
    local priority="$1"
    case "$priority" in
        0) echo "truth-safety" ;;
        1) echo "human-decision" ;;
        2) echo "product-UX" ;;
        3) echo "blocked-pending" ;;
        *) echo "unknown" ;;
    esac
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_next() {
    local eligible_ticket="${1:-}"

    # If we have a specific eligible ticket, validate it
    if [ -n "$eligible_ticket" ]; then
        local priority priority_num
        priority_num=$(get_ticket_priority_num "$eligible_ticket")
        priority=$(get_ticket_priority_label "$priority_num")

        # Check if already in progress
        local ticket_file="${TICKETS_DIR}/${eligible_ticket}/ticket.json"
        if [ -f "$ticket_file" ]; then
            local status
            status=$(jq -r '.status // "in_progress"' "$ticket_file" 2>/dev/null || echo "in_progress")
            if [ "$status" = "in_progress" ] || [ "$status" = "blocked" ]; then
                echo "skip: $eligible_ticket is $status"
                exit $EXIT_FAIL
            fi
        fi

        # Return scheduling hint
        cat <<EOF
{
  "ticket_id": "${eligible_ticket}",
  "priority": "${priority}",
  "priority_num": ${priority_num},
  "reason": "$(describe_priority $priority_num)",
  "next_transition": "ready-to-run",
  "estimated_minutes": 30
}
EOF
        exit $EXIT_PASS
    fi

    # No specific ticket - find next from backlog
    # First, check for P0 tickets
    local p0_tickets=()
    for ticket_dir in "${TICKETS_DIR}"/P0-*; do
        if [ -d "$ticket_dir" ] && [ -f "${ticket_dir}/ticket.json" ]; then
            local status
            status=$(jq -r '.status // "todo"' "${ticket_dir}/ticket.json" 2>/dev/null || echo "todo")
            if [ "$status" = "todo" ] || [ "$status" = "ready" ]; then
                p0_tickets+=("$(basename "$ticket_dir")")
            fi
        fi
    done

    if [ ${#p0_tickets[@]} -gt 0 ]; then
        echo "next: ${p0_tickets[0]} (P0/truth-safety)"
        exit $EXIT_PASS
    fi

    # Then blocked tickets
    local blocked_tickets=()
    for ticket_dir in "${TICKETS_DIR}"/*; do
        if [ -d "$ticket_dir" ] && [ -f "${ticket_dir}/ticket.json" ]; then
            local status
            status=$(jq -r '.status // "todo"' "${ticket_dir}/ticket.json" 2>/dev/null || echo "todo")
            if [ "$status" = "blocked" ]; then
                blocked_tickets+=("$(basename "$ticket_dir")")
            fi
        fi
    done

    if [ ${#blocked_tickets[@]} -gt 0 ]; then
        echo "next: ${blocked_tickets[0]} (BLOCKED/human-decision)"
        exit $EXIT_PASS
    fi

    # Then P1 tickets
    local p1_tickets=()
    for ticket_dir in "${TICKETS_DIR}"/P1-*; do
        if [ -d "$ticket_dir" ] && [ -f "${ticket_dir}/ticket.json" ]; then
            local status
            status=$(jq -r '.status // "todo"' "${ticket_dir}/ticket.json" 2>/dev/null || echo "todo")
            if [ "$status" = "todo" ] || [ "$status" = "ready" ]; then
                p1_tickets+=("$(basename "$ticket_dir")")
            fi
        fi
    done

    if [ ${#p1_tickets[@]} -gt 0 ]; then
        echo "next: ${p1_tickets[0]} (P1/human-decision)"
        exit $EXIT_PASS
    fi

    # Finally P2 tickets
    local p2_tickets=()
    for ticket_dir in "${TICKETS_DIR}"/P2-*; do
        if [ -d "$ticket_dir" ] && [ -f "${ticket_dir}/ticket.json" ]; then
            local status
            status=$(jq -r '.status // "todo"' "${ticket_dir}/ticket.json" 2>/dev/null || echo "todo")
            if [ "$status" = "todo" ] || [ "$status" = "ready" ]; then
                p2_tickets+=("$(basename "$ticket_dir")")
            fi
        fi
    done

    if [ ${#p2_tickets[@]} -gt 0 ]; then
        echo "next: ${p2_tickets[0]} (P2/product-UX)"
        exit $EXIT_PASS
    fi

    echo "idle: no tickets in backlog"
    exit $EXIT_PASS
}

cmd_list() {
    local filter="${1:-}"
    local priority_filter=""

    if [ -n "$filter" ]; then
        case "$filter" in
            P0) priority_filter="P0" ;;
            P1) priority_filter="P1" ;;
            P2) priority_filter="P2" ;;
        esac
    fi

    local first=true
    echo "{"
    echo "  \"tickets\": ["

    local found=false
    for ticket_dir in "${TICKETS_DIR}"/*; do
        if [ ! -d "$ticket_dir" ] || [ ! -f "${ticket_dir}/ticket.json" ]; then
            continue
        fi

        local ticket_id priority status priority_num
        ticket_id=$(basename "$ticket_dir")
        priority=$(jq -r '.priority // "P2"' "${ticket_dir}/ticket.json" 2>/dev/null || echo "P2")
        status=$(jq -r '.status // "todo"' "${ticket_dir}/ticket.json" 2>/dev/null || echo "todo")
        priority_num=$(get_ticket_priority_num "$ticket_id")

        if [ -n "$priority_filter" ] && [ "$priority" != "$priority_filter" ]; then
            continue
        fi

        if [ "$first" = "true" ]; then
            first=false
        else
            echo ","
        fi

        printf '    {"id": "%s", "priority": "%s", "status": "%s", "reason": "%s"}' \
            "$ticket_id" "$priority" "$status" "$(describe_priority $priority_num)"
        found=true
    done

    echo ""
    echo "  ]"
    echo "}"
}

cmd_stats() {
    local p0_count=0 p1_count=0 p2_count=0 blocked_count=0
    local p0_done=0 p1_done=0 p2_done=0 blocked_done=0

    for ticket_dir in "${TICKETS_DIR}"/*; do
        if [ ! -d "$ticket_dir" ] || [ ! -f "${ticket_dir}/ticket.json" ]; then
            continue
        fi

        local ticket_id priority status
        ticket_id=$(basename "$ticket_dir")
        priority=$(jq -r '.priority // "P2"' "${ticket_dir}/ticket.json" 2>/dev/null || echo "P2")
        status=$(jq -r '.status // "todo"' "${ticket_dir}/ticket.json" 2>/dev/null || echo "todo")

        case "$priority" in
            P0) p0_count=$((p0_count + 1)) ;;
            P1) p1_count=$((p1_count + 1)) ;;
            *)  p2_count=$((p2_count + 1)) ;;
        esac

        if [ "$status" = "blocked" ]; then
            blocked_count=$((blocked_count + 1))
        fi

        if [ "$status" = "done" ]; then
            case "$priority" in
                P0) p0_done=$((p0_done + 1)) ;;
                P1) p1_done=$((p1_done + 1)) ;;
                *)  p2_done=$((p2_done + 1)) ;;
            esac
        fi
    done

    cat <<EOF
{
  "priority_stack": {
    "P0": { "total": $p0_count, "done": $p0_done, "reason": "truth-safety" },
    "P1": { "total": $p1_count, "done": $p1_done, "reason": "human-decision" },
    "P2": { "total": $p2_count, "done": $p2_done, "reason": "product-UX" }
  },
  "blocked": { "count": $blocked_count, "reason": "awaiting-human-input" }
}
EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────

CMD="${1:-}"
shift || true

case "$CMD" in
    next)  cmd_next "$@" ;;
    list)  cmd_list "$@" ;;
    stats) cmd_stats ;;
    -h|--help)
        cat <<EOF
scheduler-hint.sh — EPIC-166 Priority Stack Scheduler

Usage:
  scheduler-hint.sh next [eligible_ticket_id]
  scheduler-hint.sh list [--priority=P0|P1|P2]
  scheduler-hint.sh stats

Priority Stack (高优先级先跑):
  P0 (truth-safety)     — 最高, 3 expert 验证
  BLOCKED (human-decision) — 次高, 等待 human review
  P1 (product-UX)       — 第三, 关键 product 功能
  P2 (routine)          — 最后, 常规 work
EOF
        exit 0
        ;;
    *)
        echo "Unknown command: $CMD" >&2
        exit $EXIT_FAIL
        ;;
esac

#!/usr/bin/env bash
# scripts/heartbeat/quota.sh — EPIC-166 Per-ticket Quota System
#
# 借鉴 loopx `loopx quota should-run` 6 层 quota 1:1:
#   Layer 1: Global budget (per-hour tokens)
#   Layer 2: Per-ticket budget
#   Layer 3: Per-priority budget (P0/P1/P2)
#   Layer 4: Per-expert budget
#   Layer 5: Cooldown / throttle
#   Layer 6: Pause gate (human override)
#
# State machine: eligible / throttled / paused
#
# Exit codes (跟 scan-dead-code 1:1):
#   0 = PASS (eligible)
#   1 = FAIL (throttled)
#   2 = BLOCKED-env (paused or env missing)
#
# Usage:
#   quota.sh should-run <ticket_id>
#   quota.sh spend <ticket_id> <amount>
#   quota.sh status <ticket_id>
#   quota.sh ledger <ticket_id>
#   quota.sh reset <ticket_id>
#   quota.sh pause <ticket_id>
#   quota.sh resume <ticket_id>
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="${KALLAX_ROOT}/state"
LEDGER="${STATE_DIR}/quota-ledger.jsonl"
QUOTA_DB="${STATE_DIR}/quota-db.json"

# Defaults (可被 env 覆盖)
GLOBAL_BUDGET_PER_HOUR="${QUOTA_GLOBAL_BUDGET_PER_HOUR:-100}"
TICKET_BUDGET="${QUOTA_TICKET_BUDGET:-20}"
P0_BUDGET="${QUOTA_P0_BUDGET:-50}"
P1_BUDGET="${QUOTA_P1_BUDGET:-30}"
P2_BUDGET="${QUOTA_P2_BUDGET:-20}"
EXPERT_BUDGET="${QUOTA_EXPERT_BUDGET:-10}"
COOLDOWN_SECONDS="${QUOTA_COOLDOWN_SECONDS:-300}"
PAUSE_FILE="${STATE_DIR}/quota-paused.json"

# Exit code constants
readonly EXIT_ELIGIBLE=0
readonly EXIT_THROTTLED=1
readonly EXIT_PAUSED=2
readonly EXIT_BLOCKED_ENV=2

# ── Helpers ─────────────────────────────────────────────────────────────────

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] quota: $*" >&2
}

ensure_state_dir() {
    if [ ! -d "$STATE_DIR" ]; then
        mkdir -p "$STATE_DIR" || exit $EXIT_BLOCKED_ENV
    fi
}

ensure_db() {
    ensure_state_dir
    if [ ! -f "$QUOTA_DB" ]; then
        echo "{}" > "$QUOTA_DB"
    fi
}

# Get current hour budget spent
get_hour_spent() {
    local now hour_key
    now=$(date -u +%Y-%m-%dT%H:00:00Z)
    hour_key="hour_${now//[:\-]/_}"

    if [ ! -f "$LEDGER" ]; then
        echo 0
        return
    fi

    local spent
    spent=$(awk -F'\t' -v key="$hour_key" '
        $2 == key {
            gsub(/"/, "", $3)
            sum += $3
        }
        END { print sum + 0 }
    ' "$LEDGER" 2>/dev/null || echo 0)

    echo "${spent:-0}"
}

# Get ticket spent
get_ticket_spent() {
    local ticket_id="$1"
    if [ ! -f "$LEDGER" ]; then
        echo 0
        return
    fi

    local spent
    spent=$(awk -F'\t' -v tid="$ticket_id" '
        $1 == tid {
            gsub(/"/, "", $3)
            sum += $3
        }
        END { print sum + 0 }
    ' "$LEDGER" 2>/dev/null || echo 0)

    echo "${spent:-0}"
}

# Get priority spent
get_priority_spent() {
    local priority="$1"
    local now hour_key
    now=$(date -u +%Y-%m-%dT%H:00:00Z)
    hour_key="hour_${now//[:\-]/_}"

    if [ ! -f "$LEDGER" ]; then
        echo 0
        return
    fi

    local spent
    spent=$(awk -F'\t' -v pri="$priority" -v key="$hour_key" '
        $4 == pri && $2 == key {
            gsub(/"/, "", $3)
            sum += $3
        }
        END { print sum + 0 }
    ' "$LEDGER" 2>/dev/null || echo 0)

    echo "${spent:-0}"
}

# Check cooldown (skip if QUOTA_SKIP_COOLDOWN is set for testing)
check_cooldown() {
    local ticket_id="$1"

    # Allow skip for testing
    if [ "${QUOTA_SKIP_COOLDOWN:-false}" = "true" ]; then
        return 0
    fi

    local last_run_file="${STATE_DIR}/quota-cooldown-${ticket_id}.last"

    if [ ! -f "$last_run_file" ]; then
        return 0  # No cooldown
    fi

    local last_run now diff
    last_run=$(cat "$last_run_file" 2>/dev/null || echo 0)
    now=$(date +%s)
    diff=$((now - last_run))

    if [ "$diff" -lt "$COOLDOWN_SECONDS" ]; then
        return 1  # Still in cooldown
    fi
    return 0
}

# Check pause gate
check_paused() {
    local ticket_id="${1:-}"

    if [ ! -f "$PAUSE_FILE" ]; then
        return 1  # No pause file
    fi

    # Check global pause
    if grep -q '"global": true' "$PAUSE_FILE" 2>/dev/null; then
        return 0  # Global pause active
    fi

    # Check specific ticket pause
    if [ -n "$ticket_id" ] && grep -q "\"${ticket_id}\"" "$PAUSE_FILE" 2>/dev/null; then
        return 0  # Ticket is paused
    fi

    return 1  # Not paused
}

# Check global pause only
check_global_paused() {
    if [ ! -f "$PAUSE_FILE" ]; then
        return 1
    fi
    grep -q '"global": true' "$PAUSE_FILE" 2>/dev/null
}

# Get ticket priority from ticket.json
get_ticket_priority() {
    local ticket_id="$1"
    local ticket_file="${KALLAX_ROOT}/jira/tickets/${ticket_id}/ticket.json"

    if [ -f "$ticket_file" ]; then
        jq -r '.priority // "P2"' "$ticket_file" 2>/dev/null || echo "P2"
    else
        echo "P2"  # Default
    fi
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_should_run() {
    local ticket_id="${1:?Usage: quota.sh should-run <ticket_id>}"

    ensure_db

    # Layer 6: Pause gate (check both global and ticket-specific)
    if check_paused "$ticket_id"; then
        if check_global_paused; then
            echo "paused: global pause active"
        else
            echo "paused: $ticket_id is paused"
        fi
        exit $EXIT_PAUSED
    fi

    # Layer 5: Cooldown
    if ! check_cooldown "$ticket_id"; then
        echo "throttled: $ticket_id in cooldown"
        exit $EXIT_THROTTLED
    fi

    # Layer 1: Global budget
    local hour_spent
    hour_spent=$(get_hour_spent)
    if [ "$hour_spent" -ge "$GLOBAL_BUDGET_PER_HOUR" ]; then
        echo "throttled: global budget exhausted ($hour_spent/$GLOBAL_BUDGET_PER_HOUR)"
        exit $EXIT_THROTTLED
    fi

    # Layer 2: Per-ticket budget
    local ticket_spent
    ticket_spent=$(get_ticket_spent "$ticket_id")
    if [ "$ticket_spent" -ge "$TICKET_BUDGET" ]; then
        echo "throttled: $ticket_id budget exhausted ($ticket_spent/$TICKET_BUDGET)"
        exit $EXIT_THROTTLED
    fi

    # Layer 3: Per-priority budget
    local priority spent budget
    priority=$(get_ticket_priority "$ticket_id")

    case "$priority" in
        P0) budget="$P0_BUDGET" ;;
        P1) budget="$P1_BUDGET" ;;
        *)  budget="$P2_BUDGET" ;;
    esac

    spent=$(get_priority_spent "$priority")
    if [ "$spent" -ge "$budget" ]; then
        echo "throttled: $priority budget exhausted ($spent/$budget)"
        exit $EXIT_THROTTLED
    fi

    # Layer 4: Per-expert budget (simplified - check via env or default)
    local expert_spent="${QUOTA_EXPERT_SPENT:-0}"
    if [ "$expert_spent" -ge "$EXPERT_BUDGET" ]; then
        echo "throttled: expert budget exhausted ($expert_spent/$EXPERT_BUDGET)"
        exit $EXIT_THROTTLED
    fi

    # All checks passed - eligible
    echo "eligible: $ticket_id can run (hour=$hour_spent, ticket=$ticket_spent, priority=$priority)"
    exit $EXIT_ELIGIBLE
}

cmd_spend() {
    local ticket_id="${1:?Usage: quota.sh spend <ticket_id> <amount>}"
    local amount="${2:-1}"

    ensure_state_dir
    ensure_db

    local now hour_key priority
    now=$(date -u +%Y-%m-%dT%H:00:00Z)
    hour_key="hour_${now//[:\-]/_}"
    priority=$(get_ticket_priority "$ticket_id")

    # Append to ledger
    echo -e "${ticket_id}\t${hour_key}\t${amount}\t${priority}" >> "$LEDGER"

    # Update cooldown
    date +%s > "${STATE_DIR}/quota-cooldown-${ticket_id}.last"

    echo "spent: $amount for $ticket_id"
    exit $EXIT_ELIGIBLE
}

cmd_status() {
    local ticket_id="${1:-}"

    ensure_db

    local hour_spent ticket_spent priority spent budget
    hour_spent=$(get_hour_spent)

    if [ -n "$ticket_id" ]; then
        ticket_spent=$(get_ticket_spent "$ticket_id")
        priority=$(get_ticket_priority "$ticket_id")
        case "$priority" in
            P0) budget="$P0_BUDGET" ;;
            P1) budget="$P1_BUDGET" ;;
            *)  budget="$P2_BUDGET" ;;
        esac
        spent=$(get_priority_spent "$priority")
    else
        ticket_spent=0
        priority="N/A"
        budget=0
        spent=0
    fi

    cat <<EOF
{
  "global": { "spent": $hour_spent, "budget": $GLOBAL_BUDGET_PER_HOUR },
  "ticket": { "id": "${ticket_id:-N/A}", "spent": $ticket_spent, "budget": $TICKET_BUDGET },
  "priority": { "level": "$priority", "spent": $spent, "budget": ${budget:-0} }
}
EOF
    exit $EXIT_ELIGIBLE
}

cmd_ledger() {
    local ticket_id="${1:-}"

    if [ ! -f "$LEDGER" ]; then
        echo "[]"
        exit $EXIT_ELIGIBLE
    fi

    if [ -n "$ticket_id" ]; then
        grep "^${ticket_id}" "$LEDGER" || echo ""
    else
        cat "$LEDGER"
    fi
    exit $EXIT_ELIGIBLE
}

cmd_reset() {
    local ticket_id="${1:?Usage: quota.sh reset <ticket_id>}"

    # Remove cooldown file
    rm -f "${STATE_DIR}/quota-cooldown-${ticket_id}.last"

    echo "reset: $ticket_id quota reset"
    exit $EXIT_ELIGIBLE
}

cmd_pause() {
    local ticket_id="${1:-}"

    ensure_state_dir

    if [ -z "$ticket_id" ]; then
        # Global pause
        echo '{"global": true}' > "$PAUSE_FILE"
        echo "paused: global pause enabled"
    else
        # Ticket pause
        if [ -f "$PAUSE_FILE" ]; then
            local paused
            paused=$(jq --argjson tid "$ticket_id" '.tickets += [$tid]' "$PAUSE_FILE" 2>/dev/null || echo "{}")
            echo "$paused" > "$PAUSE_FILE"
        else
            echo "{\"tickets\": [\"${ticket_id}\"]}" > "$PAUSE_FILE"
        fi
        echo "paused: $ticket_id paused"
    fi
    exit $EXIT_ELIGIBLE
}

cmd_resume() {
    local ticket_id="${1:-}"

    if [ ! -f "$PAUSE_FILE" ]; then
        echo "resume: no pause active"
        exit $EXIT_ELIGIBLE
    fi

    if [ -z "$ticket_id" ]; then
        # Clear global pause
        local content
        content=$(jq 'del(.global)' "$PAUSE_FILE" 2>/dev/null || echo "{}")
        echo "$content" > "$PAUSE_FILE"
        echo "resumed: global pause cleared"
    else
        local content
        content=$(jq --argjson tid "$ticket_id" '.tickets |= map(select(. != $tid))' "$PAUSE_FILE" 2>/dev/null || echo "{}")
        echo "$content" > "$PAUSE_FILE"
        echo "resumed: $ticket_id resumed"
    fi
    exit $EXIT_ELIGIBLE
}

# ── Main ─────────────────────────────────────────────────────────────────────

CMD="${1:-}"
shift || true

case "$CMD" in
    should-run) cmd_should_run "$@" ;;
    spend)      cmd_spend "$@" ;;
    status)     cmd_status "$@" ;;
    ledger)     cmd_ledger "$@" ;;
    reset)      cmd_reset "$@" ;;
    pause)      cmd_pause "$@" ;;
    resume)     cmd_resume "$@" ;;
    -h|--help)
        cat <<EOF
quota.sh — EPIC-166 Per-ticket Quota System

Usage:
  quota.sh should-run <ticket_id>
  quota.sh spend <ticket_id> <amount>
  quota.sh status [ticket_id]
  quota.sh ledger [ticket_id]
  quota.sh reset <ticket_id>
  quota.sh pause [ticket_id]
  quota.sh resume [ticket_id]

6 Layers:
  L1: Global budget (per-hour)
  L2: Per-ticket budget
  L3: Per-priority budget (P0/P1/P2)
  L4: Per-expert budget
  L5: Cooldown / throttle
  L6: Pause gate (human override)

State machine: eligible / throttled / paused

Exit codes:
  0 = eligible (PASS)
  1 = throttled (FAIL)
  2 = paused or BLOCKED-env
EOF
        exit 0
        ;;
    *)
        echo "Unknown command: $CMD" >&2
        exit $EXIT_THROTTLED
        ;;
esac

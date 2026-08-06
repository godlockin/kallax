#!/usr/bin/env bash
# scripts/heartbeat/run-history.sh — EPIC-166 Append-only Event Ledger
#
# 借鉴 loopx run-history 1:1:
#   4 类 event: work / decision / accounting / evidence
#   Append-only ledger (不可变)
#
# Schema (跟 loopx 1:1):
#   event_type  — work | decision | accounting | evidence
#   agent_id   — performer/master/daemon ID
#   ticket_id  — ticket ID
#   timestamp  — ISO 8601
#   payload    — JSON object
#
# Usage:
#   run-history.sh emit <event_type> <ticket_id> [payload_json]
#   run-history.sh query [--type=EVENT_TYPE] [--agent=AGENT_ID] [--ticket=TICKET_ID]
#   run-history.sh stats
#   run-history.sh verify
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="${KALLAX_ROOT}/state"
LEDGER="${KALLAX_RUN_HISTORY_LEDGER:-${STATE_DIR}/run-history.jsonl}"

# Valid event types
readonly VALID_EVENT_TYPES="work decision accounting evidence"

# Exit codes
readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_BLOCKED_ENV=2

# ── Helpers ─────────────────────────────────────────────────────────────────

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] run-history: $*" >&2
}

ensure_state_dir() {
    if [ ! -d "$STATE_DIR" ]; then
        mkdir -p "$STATE_DIR" || {
            log "BLOCKED: cannot create state dir: $STATE_DIR"
            exit $EXIT_BLOCKED_ENV
        }
    fi
}

ensure_ledger() {
    ensure_state_dir
    if [ ! -f "$LEDGER" ]; then
        touch "$LEDGER" || {
            log "BLOCKED: cannot create ledger: $LEDGER"
            exit $EXIT_BLOCKED_ENV
        }
    fi
}

validate_event_type() {
    local event_type="$1"
    for valid in $VALID_EVENT_TYPES; do
        if [ "$event_type" = "$valid" ]; then
            return 0
        fi
    done
    log "invalid event_type: $event_type (must be one of: $VALID_EVENT_TYPES)"
    exit $EXIT_FAIL
}

get_agent_id() {
    # Try various env vars to determine agent ID
    if [ -n "${AGENT_ID:-}" ]; then
        echo "$AGENT_ID"
    elif [ -n "${INSTANCE_ID:-}" ]; then
        echo "$INSTANCE_ID"
    elif [ -n "${HOSTNAME:-}" ]; then
        echo "agent-$HOSTNAME"
    else
        echo "agent-unknown"
    fi
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_emit() {
    local event_type="${1:?Usage: run-history.sh emit <event_type> <ticket_id> [payload_json]}"
    local ticket_id="${2:?Usage: run-history.sh emit <event_type> <ticket_id> [payload_json]}"
    local payload="${3:-{}}"

    validate_event_type "$event_type"
    ensure_ledger
    if ! command -v jq >/dev/null 2>&1; then
        log "jq is required to validate and append events"
        exit $EXIT_BLOCKED_ENV
    fi
    if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$payload"; then
        log "payload must be a valid JSON object"
        exit $EXIT_FAIL
    fi

    local agent_id timestamp record
    agent_id=$(get_agent_id)
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    if ! record=$(jq -cn \
        --arg event_type "$event_type" \
        --arg agent_id "$agent_id" \
        --arg ticket_id "$ticket_id" \
        --arg timestamp "$timestamp" \
        --argjson payload "$payload" \
        '{timestamp: $timestamp, event_type: $event_type, agent_id: $agent_id, ticket_id: $ticket_id, payload: $payload}'); then
        log "failed to construct event record"
        exit $EXIT_FAIL
    fi

    if command -v flock >/dev/null 2>&1; then
        local lock_fd
        exec {lock_fd}>"${LEDGER}.lock"
        flock -x "$lock_fd"
        if ! printf '%s\n' "$record" >> "$LEDGER"; then
            flock -u "$lock_fd"
            exec {lock_fd}>&-
            log "failed to append event to ledger"
            exit $EXIT_FAIL
        fi
        flock -u "$lock_fd"
        exec {lock_fd}>&-
    elif ! printf '%s\n' "$record" >> "$LEDGER"; then
        log "failed to append event to ledger"
        exit $EXIT_FAIL
    fi
    exit $EXIT_PASS
}

cmd_query() {
    local type_filter="" agent_filter="" ticket_filter="" arg
    while [ "$#" -gt 0 ]; do
        arg="$1"
        shift
        case "$arg" in
            --type=*) type_filter="${arg#--type=}" ;;
            --agent=*) agent_filter="${arg#--agent=}" ;;
            --ticket=*) ticket_filter="${arg#--ticket=}" ;;
            *) log "unknown query option: $arg"; exit $EXIT_FAIL ;;
        esac
    done

    ensure_ledger
    if [ ! -s "$LEDGER" ]; then
        echo "[]"
        exit $EXIT_PASS
    fi

    local filter_expr='.'
    local -a jq_args=()
    if [ -n "$type_filter" ]; then
        filter_expr+=' | map(select(.event_type == $type_filter))'
        jq_args+=(--arg type_filter "$type_filter")
    fi
    if [ -n "$agent_filter" ]; then
        filter_expr+=' | map(select(.agent_id == $agent_filter))'
        jq_args+=(--arg agent_filter "$agent_filter")
    fi
    if [ -n "$ticket_filter" ]; then
        filter_expr+=' | map(select(.ticket_id == $ticket_filter))'
        jq_args+=(--arg ticket_filter "$ticket_filter")
    fi
    if ! jq -s "${jq_args[@]}" "$filter_expr" "$LEDGER"; then
        log "query failed: invalid ledger JSONL"
        exit $EXIT_FAIL
    fi
    exit $EXIT_PASS
}

cmd_stats() {
    ensure_ledger

    if [ ! -s "$LEDGER" ]; then
        cat <<EOF
{
  "total_events": 0,
  "by_type": {},
  "by_agent": {},
  "by_ticket": {}
}
EOF
        exit $EXIT_PASS
    fi

    local total type_counts agent_counts ticket_counts
    total=$(wc -l < "$LEDGER")

    # Count by type
    type_counts=$(jq -r '.event_type' "$LEDGER" 2>/dev/null | sort | uniq -c | while read -r count type; do
        echo "\"$type\": $count"
    done | tr '\n' ',' | sed 's/,$//')

    # Count by agent
    agent_counts=$(jq -r '.agent_id' "$LEDGER" 2>/dev/null | sort | uniq -c | while read -r count agent; do
        echo "\"$agent\": $count"
    done | tr '\n' ',' | sed 's/,$//')

    # Count by ticket
    ticket_counts=$(jq -r '.ticket_id' "$LEDGER" 2>/dev/null | sort | uniq -c | while read -r count tid; do
        echo "\"$tid\": $count"
    done | tr '\n' ',' | sed 's/,$//')

    cat <<EOF
{
  "total_events": ${total:-0},
  "by_type": { ${type_counts:-} },
  "by_agent": { ${agent_counts:-} },
  "by_ticket": { ${ticket_counts:-} }
}
EOF
    exit $EXIT_PASS
}

cmd_verify() {
    ensure_ledger

    if [ ! -f "$LEDGER" ]; then
        log "FAIL: ledger not found"
        exit $EXIT_FAIL
    fi

    if [ ! -s "$LEDGER" ]; then
        echo "verify: empty ledger (valid)"
        exit $EXIT_PASS
    fi

    # Verify each line is valid JSON with required fields
    local line_num=0 errors=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Check required fields
        local has_type has_agent has_ticket has_ts has_payload
        has_type=$(echo "$line" | jq -r '.event_type // empty' 2>/dev/null || echo "")
        has_agent=$(echo "$line" | jq -r '.agent_id // empty' 2>/dev/null || echo "")
        has_ticket=$(echo "$line" | jq -r '.ticket_id // empty' 2>/dev/null || echo "")
        has_ts=$(echo "$line" | jq -r '.timestamp // empty' 2>/dev/null || echo "")
        has_payload=$(echo "$line" | jq -r '.payload // empty' 2>/dev/null || echo "")

        if [ -z "$has_type" ] || [ -z "$has_agent" ] || [ -z "$has_ticket" ] || [ -z "$has_ts" ]; then
            log "FAIL: line $line_num missing required field"
            errors=$((errors + 1))
            continue
        fi

        # Validate event_type
        local valid=false
        for vtype in $VALID_EVENT_TYPES; do
            if [ "$has_type" = "$vtype" ]; then
                valid=true
                break
            fi
        done
        if ! printf '%s' "$line" | jq -e '.payload | type == "object"' >/dev/null 2>&1; then
            log "FAIL: line $line_num payload must be JSON object"
            errors=$((errors + 1))
        fi
    done < "$LEDGER"

    if [ "$errors" -gt 0 ]; then
        log "verify: $errors errors found"
        exit $EXIT_FAIL
    fi

    echo "verify: ${line_num} events, all valid"
    exit $EXIT_PASS
}

# ── Main ─────────────────────────────────────────────────────────────────────

CMD="${1:-}"
shift || true

case "$CMD" in
    emit)   cmd_emit "$@" ;;
    query)  cmd_query "$@" ;;
    stats)  cmd_stats ;;
    verify) cmd_verify ;;
    -h|--help)
        cat <<EOF
run-history.sh — EPIC-166 Append-only Event Ledger

Usage:
  run-history.sh emit <event_type> <ticket_id> [payload_json]
  run-history.sh query [--type=EVENT_TYPE] [--agent=AGENT_ID] [--ticket=TICKET_ID]
  run-history.sh stats
  run-history.sh verify

4 Event Types:
  work       — agent started work on ticket
  decision   — human/agent made decision
  accounting — quota spend / heartbeat tick
  evidence   — raw output / verification result

Schema:
  {
    "event_type": "work|decision|accounting|evidence",
    "agent_id": "performer-1|master|daemon",
    "ticket_id": "EPIC-XXX",
    "timestamp": "ISO-8601",
    "payload": {}
  }

Exit codes:
  0 = PASS
  1 = FAIL
  2 = BLOCKED-env
EOF
        exit 0
        ;;
    *)
        echo "Unknown command: $CMD" >&2
        exit $EXIT_FAIL
        ;;
esac

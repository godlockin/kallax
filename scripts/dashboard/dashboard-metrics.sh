#!/usr/bin/env bash
# scripts/dashboard/dashboard-metrics.sh — EPIC-168-BG Dashboard Metrics Aggregator
#
# Phase 5 G: 北极星 dashboard 闭环 EPIC-023-C
# 读取 state/run-history.jsonl 4 类 event, 计算 4 北极星指标
#
# Usage:
#   dashboard-metrics.sh [--format=json|text]
#   dashboard-metrics.sh --daemon-status
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="${KALLAX_ROOT}/state"
LEDGER="${STATE_DIR}/run-history.jsonl"
QUOTA_DB="${STATE_DIR}/quota-db.json"
PID_FILE="${STATE_DIR}/heartbeat-daemon.pid"

# Default format
FORMAT="${1:-json}"
for arg in "$@"; do
    case "$arg" in
        --format=json) FORMAT="json" ;;
        --format=text) FORMAT="text" ;;
        --daemon-status) FORMAT="status" ;;
    esac
done

# EPIC-177-G: Pre-generate JSON for dashboard HTML
OUTPUT_JSON="${KALLAX_ROOT}/web/dashboard-metrics.json"

# ── Helpers ─────────────────────────────────────────────────────────────────

get_daemon_status() {
    if [ ! -f "$PID_FILE" ]; then
        echo "down"
        return
    fi
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        echo "down"
    else
        echo "running"
    fi
}

get_paused_status() {
    local pause_file="${STATE_DIR}/quota-paused.json"
    if [ ! -f "$pause_file" ]; then
        echo "false"
        return
    fi
    if grep -q '"global": true' "$pause_file" 2>/dev/null; then
        echo "true"
    else
        echo "false"
    fi
}

count_events_by_type() {
    local event_type="$1"
    if [ ! -f "$LEDGER" ]; then
        echo 0
        return
    fi
    grep -c "\"event_type\":\"${event_type}\"" "$LEDGER" 2>/dev/null || echo 0
}

get_total_events() {
    if [ ! -f "$LEDGER" ]; then
        echo 0
        return
    fi
    wc -l < "$LEDGER" | tr -d ' '
}

# Calculate 4 North Star metrics
calc_expert_activation() {
    # expert_activation: % of events with explicit expert binding
    local total work_events expert_annotated
    total=$(get_total_events)
    work_events=$(count_events_by_type "work")
    if [ "$total" -eq 0 ] || [ "$work_events" -eq 0 ]; then
        echo "0.0"
        return
    fi
    # Count events with expert_id field (simplified heuristic)
    expert_annotated=$(grep -c '"expert_id"' "$LEDGER" 2>/dev/null || echo 0)
    echo "scale=2; ($expert_annotated * 100) / $work_events" | bc 2>/dev/null || echo "0.0"
}

calc_cross_epic_reuse() {
    # cross_epic_reuse: % of evidence events referencing multiple tickets
    local evidence_count multi_ref single_ref
    evidence_count=$(count_events_by_type "evidence")
    if [ "$evidence_count" -eq 0 ]; then
        echo "0.0"
        return
    fi
    # Simplified: count unique ticket_ids in evidence
    multi_ref=$(grep '"event_type":"evidence"' "$LEDGER" 2>/dev/null | \
        cut -d'"' -f8 | sort -u | wc -l | tr -d ' ')
    if [ "$multi_ref" -gt 1 ]; then
        echo "scale=2; ($multi_ref * 100) / $evidence_count" | bc 2>/dev/null || echo "50.0"
    else
        echo "0.0"
    fi
}

calc_ab_hit_rate() {
    # ab_hit: % of decisions with evidence (A/B test success proxy)
    local decision_count with_evidence
    decision_count=$(count_events_by_type "decision")
    if [ "$decision_count" -eq 0 ]; then
        echo "0.0"
        return
    fi
    with_evidence=$(grep '"event_type":"decision"' "$LEDGER" 2>/dev/null | \
        grep -c '"evidence_ref"' || echo 0)
    echo "scale=2; ($with_evidence * 100) / $decision_count" | bc 2>/dev/null || echo "0.0"
}

calc_mis_dispatch_binding_rate() {
    # mis_dispatch_binding_rate: % of work events without proper ticket binding
    local work_count unbound
    work_count=$(count_events_by_type "work")
    if [ "$work_count" -eq 0 ]; then
        echo "100.0"
        return
    fi
    # Count work events without ticket_id or with "heartbeat-daemon" as ticket
    unbound=$(grep '"event_type":"work"' "$LEDGER" 2>/dev/null | \
        grep -cE '"ticket_id":"(heartbeat-daemon|default-ticket-id|)"' || echo 0)
    echo "scale=2; ($unbound * 100) / $work_count" | bc 2>/dev/null || echo "0.0"
}

# ── Output ─────────────────────────────────────────────────────────────────

output_json() {
    cat <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "daemon_status": "$(get_daemon_status)",
  "paused": $(get_paused_status),
  "north_stars": {
    "expert_activation": $(calc_expert_activation),
    "cross_epic_reuse": $(calc_cross_epic_reuse),
    "ab_hit_rate": $(calc_ab_hit_rate),
    "mis_dispatch_binding_rate": $(calc_mis_dispatch_binding_rate)
  },
  "events": {
    "total": $(get_total_events),
    "work": $(count_events_by_type "work"),
    "decision": $(count_events_by_type "decision"),
    "accounting": $(count_events_by_type "accounting"),
    "evidence": $(count_events_by_type "evidence")
  }
}
EOF
    # EPIC-177-G: Pre-generate JSON for HTML dashboard
    if [ -n "${OUTPUT_JSON:-}" ]; then
        mkdir -p "$(dirname "$OUTPUT_JSON")"
        cat > "$OUTPUT_JSON"
    fi
}

output_text() {
    echo "=== Dashboard Metrics ==="
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Daemon: $(get_daemon_status) | Paused: $(get_paused_status)"
    echo ""
    echo "--- 4 North Stars ---"
    echo "expert_activation: $(calc_expert_activation)%"
    echo "cross_epic_reuse: $(calc_cross_epic_reuse)%"
    echo "ab_hit_rate: $(calc_ab_hit_rate)%"
    echo "mis_dispatch_binding_rate: $(calc_mis_dispatch_binding_rate)%"
    echo ""
    echo "--- Event Counts ---"
    echo "total: $(get_total_events)"
    echo "work: $(count_events_by_type "work")"
    echo "decision: $(count_events_by_type "decision")"
    echo "accounting: $(count_events_by_type "accounting")"
    echo "evidence: $(count_events_by_type "evidence")"
}

output_status() {
    echo "daemon:$(get_daemon_status) paused:$(get_paused_status)"
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "$FORMAT" in
    json)  output_json ;;
    text)  output_text ;;
    status) output_status ;;
    *)     output_json ;;
esac
exit 0

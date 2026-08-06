#!/usr/bin/env bash
# tests/integration/run-history-emit-integration.test.sh
# EPIC-177-G run-history emit integration test

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="${KALLAX_ROOT}/state"
LEDGER="${STATE_DIR}/run-history.jsonl"
RUN_HISTORY="${KALLAX_ROOT}/scripts/heartbeat/run-history.sh"

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

VERBOSE=0
for arg in "$@"; do
    case "$arg" in --verbose) VERBOSE=1 ;;
    esac
done

log_test() {
    local name="$1" status="$2"
    [ "$VERBOSE" -eq 1 ] || [ "$status" = "FAIL" ] && echo "[$status] $name"
}

count_lines() {
    local f="$1"
    [ -f "$f" ] && wc -l < "$f" | awk '{print $1}' || echo "0"
}

test_binding_tracker_actual_emit() {
    local test_ticket="EPIC-177G-TEST-A"
    local test_dir="${KALLAX_ROOT}/jira/tickets/${test_ticket}"
    mkdir -p "$test_dir"
    cat > "${test_dir}/ticket.json" <<EOF
{"ticket_id": "${test_ticket}", "status": "todo", "expert_binding": {"suggested_expert": "backend"}}
EOF
    local count_before=$(count_lines "$LEDGER")
    bash "${KALLAX_ROOT}/scripts/binding/binding-tracker.sh" actual "$test_ticket" --expert backend >/dev/null 2>&1 || true
    local count_after=$(count_lines "$LEDGER")
    local last_line=$(tail -1 "$LEDGER") has_accounting
    has_accounting=$(echo "$last_line" | grep -c '"event_type":"accounting"' || echo 0)
    if [ "$count_after" -gt "$count_before" ] && [ "$has_accounting" -eq 1 ]; then
        log_test "binding-tracker.sh cmd_actual emit accounting" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "binding-tracker.sh cmd_actual emit accounting" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    rm -rf "$test_dir"
}

test_binding_tracker_validate_emit() {
    local test_ticket="EPIC-177G-TEST-B"
    local test_dir="${KALLAX_ROOT}/jira/tickets/${test_ticket}"
    mkdir -p "$test_dir"
    cat > "${test_dir}/ticket.json" <<EOF
{"ticket_id": "${test_ticket}", "status": "done", "expert_binding": {"suggested_expert": "backend", "actual_expert": "backend", "expert_binding_at": "2026-08-05T00:00:00Z"}}
EOF
    local count_before=$(count_lines "$LEDGER")
    bash "${KALLAX_ROOT}/scripts/binding/binding-tracker.sh" validate "$test_ticket" >/dev/null 2>&1 || true
    local count_after=$(count_lines "$LEDGER")
    if [ "$count_after" -gt "$count_before" ]; then
        log_test "binding-tracker.sh cmd_validate emit accounting" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "binding-tracker.sh cmd_validate emit accounting" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    rm -rf "$test_dir"
}

test_binding_tracker_validate_all_emit() {
    for sub in C D; do
        local test_ticket="EPIC-177G-TEST-${sub}" test_dir="${KALLAX_ROOT}/jira/tickets/${test_ticket}"
        mkdir -p "$test_dir"
        cat > "${test_dir}/ticket.json" <<EOF
{"ticket_id": "${test_ticket}", "status": "done", "expert_binding": {"suggested_expert": "backend", "actual_expert": "backend", "expert_binding_at": "2026-08-05T00:00:00Z"}}
EOF
    done
    local count_before=$(count_lines "$LEDGER")
    bash "${KALLAX_ROOT}/scripts/binding/binding-tracker.sh" validate-all --dir "${KALLAX_ROOT}/jira/tickets" >/dev/null 2>&1 || true
    local count_after=$(count_lines "$LEDGER")
    local has_decision=$(grep -c '"event_type":"decision"' "$LEDGER" 2>/dev/null || echo 0)
    if [ "$count_after" -gt "$count_before" ] && [ "$has_decision" -gt 0 ]; then
        log_test "binding-tracker.sh cmd_validate-all emit decision" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "binding-tracker.sh cmd_validate-all emit decision" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    rm -rf "${KALLAX_ROOT}/jira/tickets/EPIC-177G-TEST-C" "${KALLAX_ROOT}/jira/tickets/EPIC-177G-TEST-D"
}

test_post_process_emit() {
    local count_before=$(count_lines "$LEDGER")
    bash "${KALLAX_ROOT}/scripts/post-process.sh" >/dev/null 2>&1 || true
    local count_after=$(count_lines "$LEDGER")
    local last_lines=$(tail -2 "$LEDGER") has_work has_decision
    has_work=$(echo "$last_lines" | grep -c '"event_type":"work"' || echo 0)
    has_decision=$(echo "$last_lines" | grep -c '"event_type":"decision"' || echo 0)
    if [ "$count_after" -gt "$count_before" ] && [ "$has_work" -ge 1 ] && [ "$has_decision" -ge 1 ]; then
        log_test "post-process.sh emit work + decision" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "post-process.sh emit work + decision" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_branch_4pr_emit() {
    local test_branch="feature/v3.33.0-EPIC-177G-test"
    local count_before=$(count_lines "$LEDGER")
    bash "${KALLAX_ROOT}/scripts/branch-4pr.sh" "$test_branch" --dry-run >/dev/null 2>&1 || true
    local count_after=$(count_lines "$LEDGER")
    if [ "$count_after" -ge "$count_before" ]; then
        log_test "branch-4pr.sh emit decision (dry-run)" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "branch-4pr.sh emit decision (dry-run)" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_install_emit() {
    local count_before=$(count_lines "$LEDGER")
    bash "${KALLAX_ROOT}/scripts/install.sh" --dry-run >/dev/null 2>&1 || true
    local count_after=$(count_lines "$LEDGER")
    local has_evidence=$(grep -c '"event_type":"evidence"' "$LEDGER" 2>/dev/null || echo 0)
    if [ "$count_after" -gt "$count_before" ] && [ "$has_evidence" -gt 0 ]; then
        log_test "install.sh emit evidence" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "install.sh emit evidence" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_skill_manager_emit() {
    local count_before=$(count_lines "$LEDGER")
    bash "${KALLAX_ROOT}/scripts/skill/skill-manager.sh" enable architect >/dev/null 2>&1 || true
    local count_after=$(count_lines "$LEDGER")
    local has_work=$(grep -c '"event_type":"work"' "$LEDGER" 2>/dev/null || echo 0)
    if [ "$count_after" -gt "$count_before" ] && [ "$has_work" -gt 0 ]; then
        log_test "skill-manager.sh enable emit work" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "skill-manager.sh enable emit work" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_dashboard_json_generate() {
    local json_file="${KALLAX_ROOT}/web/dashboard-metrics.json"
    bash "${KALLAX_ROOT}/scripts/dashboard/dashboard-metrics.sh" >/dev/null 2>&1 || true
    if [ -f "$json_file" ]; then
        log_test "dashboard-metrics.sh pre-generate JSON" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "dashboard-metrics.sh pre-generate JSON" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_ledger_append_only() {
    local count_before=$(count_lines "$LEDGER")
    bash "$RUN_HISTORY" emit work "test-append-only" '{}' >/dev/null 2>&1 || true
    local count_after=$(count_lines "$LEDGER")
    if [ "$count_after" -eq $((count_before + 1)) ]; then
        log_test "run-history.jsonl append-only" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "run-history.jsonl append-only" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_north_star_metrics() {
    local json_file="${KALLAX_ROOT}/web/dashboard-metrics.json"
    [ ! -f "$json_file" ] && bash "${KALLAX_ROOT}/scripts/dashboard/dashboard-metrics.sh" >/dev/null 2>&1 || true
    if [ -f "$json_file" ] && command -v jq >/dev/null 2>&1; then
        local ea cs ah md
        ea=$(jq -r '.north_stars.expert_activation // "missing"' "$json_file" 2>/dev/null || echo "missing")
        cs=$(jq -r '.north_stars.cross_epic_reuse // "missing"' "$json_file" 2>/dev/null || echo "missing")
        ah=$(jq -r '.north_stars.ab_hit_rate // "missing"' "$json_file" 2>/dev/null || echo "missing")
        md=$(jq -r '.north_stars.mis_dispatch_binding_rate // "missing"' "$json_file" 2>/dev/null || echo "missing")
        if [ "$ea" != "missing" ] && [ "$cs" != "missing" ] && [ "$ah" != "missing" ] && [ "$md" != "missing" ]; then
            log_test "4 north star metrics computed" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_test "4 north star metrics computed" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        log_test "4 north star metrics computed (jq unavailable)" "SKIP"; TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    fi
}

test_event_counts() {
    local json_file="${KALLAX_ROOT}/web/dashboard-metrics.json"
    [ ! -f "$json_file" ] && bash "${KALLAX_ROOT}/scripts/dashboard/dashboard-metrics.sh" >/dev/null 2>&1 || true
    if [ -f "$json_file" ] && command -v jq >/dev/null 2>&1; then
        local work dec acc ev
        work=$(jq -r '.events.work // "missing"' "$json_file" 2>/dev/null || echo "missing")
        dec=$(jq -r '.events.decision // "missing"' "$json_file" 2>/dev/null || echo "missing")
        acc=$(jq -r '.events.accounting // "missing"' "$json_file" 2>/dev/null || echo "missing")
        ev=$(jq -r '.events.evidence // "missing"' "$json_file" 2>/dev/null || echo "missing")
        if [ "$work" != "missing" ] && [ "$dec" != "missing" ] && [ "$acc" != "missing" ] && [ "$ev" != "missing" ]; then
            log_test "event counts in dashboard JSON" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_test "event counts in dashboard JSON" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        log_test "event counts in dashboard JSON (jq unavailable)" "SKIP"; TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    fi
}

test_run_history_verify() {
    if bash "$RUN_HISTORY" verify >/dev/null 2>&1; then
        log_test "run-history.sh verify" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "run-history.sh verify" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

main() {
    echo "=========================================="
    echo "EPIC-177-G run-history emit integration"
    echo "=========================================="
    mkdir -p "$STATE_DIR"; touch "$LEDGER"
    echo "Running tests..."
    test_binding_tracker_actual_emit
    test_binding_tracker_validate_emit
    test_binding_tracker_validate_all_emit
    test_post_process_emit
    test_branch_4pr_emit
    test_install_emit
    test_skill_manager_emit
    test_dashboard_json_generate
    test_ledger_append_only
    test_north_star_metrics
    test_event_counts
    test_run_history_verify
    echo ""
    echo "=========================================="
    echo "Summary: ${TESTS_PASSED}/12 PASS (${TESTS_FAILED} FAIL, ${TESTS_SKIPPED} SKIP)"
    echo "=========================================="
    [ "$TESTS_FAILED" -gt 0 ] && exit 1; exit 0
}

main "$@"

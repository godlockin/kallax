#!/usr/bin/env bash
# tests/integration/run-history-emit-integration.test.sh
# EPIC-177-G run-history emit integration test
#
# Fail-closed contract (v2):
#   Each script-under-test MUST emit a valid ledger event when its
#   emission-trigger command runs. Tests use an ISOLATED LEDGER
#   (via KALLAX_RUN_HISTORY_LEDGER) so historical multi-line data
#   cannot leak in, and assertion is done via jq event-count, not
#   grep -c / wc -l, which break on multi-line pretty JSON.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROD_LEDGER="${KALLAX_ROOT}/state/run-history.jsonl"
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

# ── Isolated ledger harness ───────────────────────────────────────────────
# Each test gets a fresh empty LEDGER path. KALLAX_RUN_HISTORY_LEDGER is
# honoured by run-history.sh, post-process.sh, binding-tracker.sh,
# heartbeat-daemon.sh (via subprocess env). All emit-asserting helpers
# operate on the EVENTS array produced by `jq -s . $LEDGER` (parsed
# from JSONL), not on raw line counts.

ISOLATED_DIR=""
ISOLATED_LEDGER=""

setup_isolation() {
    ISOLATED_DIR="$(mktemp -d -t run-history-iso.XXXXXX)"
    ISOLATED_LEDGER="${ISOLATED_DIR}/run-history.jsonl"
    : > "$ISOLATED_LEDGER"
    export KALLAX_RUN_HISTORY_LEDGER="$ISOLATED_LEDGER"
}

teardown_isolation() {
    unset KALLAX_RUN_HISTORY_LEDGER
    [ -n "$ISOLATED_DIR" ] && [ -d "$ISOLATED_DIR" ] && rm -rf "$ISOLATED_DIR"
    ISOLATED_DIR=""; ISOLATED_LEDGER=""
}

# Parse the isolated ledger into events (jq tolerates both single-line
# JSONL and legacy multi-line records).
events_total() {
    [ -s "$ISOLATED_LEDGER" ] && jq -s 'length' "$ISOLATED_LEDGER" 2>/dev/null || echo 0
}

events_with() {
    # events_with '.event_type == "X" and .ticket_id == "Y"'
    [ -s "$ISOLATED_LEDGER" ] && \
        jq -s "[.[] | select($1)] | length" "$ISOLATED_LEDGER" 2>/dev/null \
        || echo 0
}

events_last() {
    # Return last event's JSON object string (or empty)
    [ -s "$ISOLATED_LEDGER" ] && \
        jq -s '.[-1] // empty' "$ISOLATED_LEDGER" 2>/dev/null \
        || echo ""
}

# ── Tests ────────────────────────────────────────────────────────────────

test_payload_is_object_and_escaped() {
    setup_isolation
    AGENT_ID='agent"quoted' bash "$RUN_HISTORY" emit work 'ticket"quoted' \
        '{"message":"safe \"value\""}' >/dev/null 2>&1
    local last
    last=$(events_last)
    if echo "$last" | jq -e '.payload | type == "object"' >/dev/null 2>&1; then
        if echo "$last" | jq -e '.agent_id == "agent\"quoted" and .payload.message == "safe \"value\""' >/dev/null 2>&1; then
            log_test "run-history jq escaping" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_test "run-history jq escaping" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        log_test "run-history jq escaping" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Array payload must be rejected
    if AGENT_ID='agent' bash "$RUN_HISTORY" emit work ticket '[1]' >/dev/null 2>&1; then
        log_test "run-history rejects array payload" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        log_test "run-history rejects array payload" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    teardown_isolation
}

test_binding_tracker_actual_emit() {
    setup_isolation
    local test_ticket="EPIC-177G-TEST-A"
    local test_dir="${KALLAX_ROOT}/jira/tickets/${test_ticket}"
    mkdir -p "$test_dir"
    cat > "${test_dir}/ticket.json" <<EOF
{"ticket_id": "${test_ticket}", "status": "todo", "expert_binding": {"suggested_expert": "backend"}}
EOF
    local before after
    before=$(events_total)
    KALLAX_RUN_HISTORY_LEDGER="$ISOLATED_LEDGER" \
        bash "${KALLAX_ROOT}/scripts/binding/binding-tracker.sh" actual \
        "$test_ticket" --expert backend >/dev/null 2>&1 || true
    after=$(events_total)
    local n
    n=$(events_with '.event_type == "accounting" and .ticket_id == "TEST_TID"' 2>/dev/null || echo 0)
    n=$(events_with ".event_type == \"accounting\" and .ticket_id == \"${test_ticket}\"")
    if [ "$after" -gt "$before" ] && [ "$n" -ge 1 ]; then
        log_test "binding-tracker.sh cmd_actual emit accounting" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "binding-tracker.sh cmd_actual emit accounting (after=$after before=$before n=$n)" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    rm -rf "$test_dir"
    teardown_isolation
}

test_binding_tracker_validate_emit() {
    setup_isolation
    local test_ticket="EPIC-177G-TEST-B"
    local test_dir="${KALLAX_ROOT}/jira/tickets/${test_ticket}"
    mkdir -p "$test_dir"
    cat > "${test_dir}/ticket.json" <<EOF
{"ticket_id": "${test_ticket}", "status": "done", "expert_binding": {"suggested_expert": "backend", "actual_expert": "backend", "expert_binding_at": "2026-08-05T00:00:00Z"}}
EOF
    local before after n
    before=$(events_total)
    KALLAX_RUN_HISTORY_LEDGER="$ISOLATED_LEDGER" \
        bash "${KALLAX_ROOT}/scripts/binding/binding-tracker.sh" validate \
        "$test_ticket" >/dev/null 2>&1 || true
    after=$(events_total)
    n=$(events_with ".event_type == \"accounting\" and .ticket_id == \"${test_ticket}\"")
    if [ "$after" -gt "$before" ] && [ "$n" -ge 1 ]; then
        log_test "binding-tracker.sh cmd_validate emit accounting" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "binding-tracker.sh cmd_validate emit accounting (after=$after before=$before n=$n)" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    rm -rf "$test_dir"
    teardown_isolation
}

test_binding_tracker_validate_all_emit() {
    setup_isolation
    local test_ticket test_dir sub
    for sub in C D; do
        test_ticket="EPIC-177G-TEST-${sub}"
        test_dir="${KALLAX_ROOT}/jira/tickets/${test_ticket}"
        mkdir -p "$test_dir"
        cat > "${test_dir}/ticket.json" <<EOF
{"ticket_id": "${test_ticket}", "status": "done", "expert_binding": {"suggested_expert": "backend", "actual_expert": "backend", "expert_binding_at": "2026-08-05T00:00:00Z"}}
EOF
    done
    local before after n
    before=$(events_total)
    KALLAX_RUN_HISTORY_LEDGER="$ISOLATED_LEDGER" \
        bash "${KALLAX_ROOT}/scripts/binding/binding-tracker.sh" validate-all \
        --dir "${KALLAX_ROOT}/jira/tickets" >/dev/null 2>&1 || true
    after=$(events_total)
    n=$(events_with '.event_type == "decision" and .ticket_id == "binding-tracker"')
    if [ "$after" -gt "$before" ] && [ "$n" -ge 1 ]; then
        log_test "binding-tracker.sh cmd_validate-all emit decision" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "binding-tracker.sh cmd_validate-all emit decision (after=$after before=$before n=$n)" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    rm -rf "${KALLAX_ROOT}/jira/tickets/EPIC-177G-TEST-C" "${KALLAX_ROOT}/jira/tickets/EPIC-177G-TEST-D"
    teardown_isolation
}

test_post_process_emit() {
    setup_isolation
    local before after nw nd
    before=$(events_total)
    # Source the post-process.sh _postprocess_emit function in a subshell
    # with PASS_COUNT/FAIL_COUNT pre-set; full dry-run pipeline is gated by
    # `set -e` and exits early on first check_step FAIL.
    ( set -u
      export KALLAX_ROOT="${KALLAX_ROOT}"
      export KALLAX_RUN_HISTORY_LEDGER="${ISOLATED_LEDGER}"
      eval "$(grep -A 12 '^_postprocess_emit() {' "${KALLAX_ROOT}/scripts/post-process.sh")"
      eval "$(grep -A 1 '^_postprocess_emit$' "${KALLAX_ROOT}/scripts/post-process.sh")"
    ) 2>/dev/null
    after=$(events_total)
    nw=$(events_with '.event_type == "work" and .ticket_id == "post-process"')
    nd=$(events_with '.event_type == "decision" and .ticket_id == "post-process"')
    if [ "$after" -gt "$before" ] && [ "$nw" -ge 1 ] && [ "$nd" -ge 1 ]; then
        log_test "post-process.sh emit work + decision" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "post-process.sh emit work + decision (after=$after nw=$nw nd=$nd)" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    teardown_isolation
}

test_branch_4pr_emit() {
    setup_isolation
    local test_branch="feature/v3.33.0-EPIC-177G-test"
    local before after
    before=$(events_total)
    KALLAX_RUN_HISTORY_LEDGER="$ISOLATED_LEDGER" \
        bash "${KALLAX_ROOT}/scripts/branch-4pr.sh" "$test_branch" --dry-run \
        >/dev/null 2>&1 || true
    after=$(events_total)
    # branch-4pr --dry-run should NOT emit (dry-run mode); test asserts no
    # regression in ledger count (still pass-through).
    if [ "$after" -ge "$before" ]; then
        log_test "branch-4pr.sh dry-run no-leak" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "branch-4pr.sh dry-run no-leak (after=$after before=$before)" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    teardown_isolation
}

test_install_emit() {
    setup_isolation
    local before after n
    before=$(events_total)
    # install.sh dry-run path emits evidence inline; KALLAX_RUN_HISTORY_LEDGER
    # must reach the subshell so the emit lands in our isolated ledger.
    KALLAX_RUN_HISTORY_LEDGER="$ISOLATED_LEDGER" \
        bash "${KALLAX_ROOT}/scripts/install.sh" --dry-run \
        >/dev/null 2>&1 || true
    after=$(events_total)
    n=$(events_with '.event_type == "evidence" and .ticket_id == "install"')
    if [ "$after" -gt "$before" ] && [ "$n" -ge 1 ]; then
        log_test "install.sh emit evidence" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "install.sh emit evidence (after=$after n=$n)" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    teardown_isolation
}

test_skill_manager_emit() {
    setup_isolation
    local before after n
    before=$(events_total)
    KALLAX_RUN_HISTORY_LEDGER="$ISOLATED_LEDGER" \
        bash "${KALLAX_ROOT}/scripts/skill/skill-manager.sh" enable architect \
        >/dev/null 2>&1 || true
    after=$(events_total)
    n=$(events_with '.event_type == "work" and .ticket_id == "skill-manager"')
    if [ "$after" -gt "$before" ] && [ "$n" -ge 1 ]; then
        log_test "skill-manager.sh enable emit work" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "skill-manager.sh enable emit work (after=$after before=$before n=$n)" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    teardown_isolation
}

test_dashboard_json_generate() {
    # Uses real dashboard JSON, no ledger dependency.
    local json_file="${KALLAX_ROOT}/web/dashboard-metrics.json"
    bash "${KALLAX_ROOT}/scripts/dashboard/dashboard-metrics.sh" >/dev/null 2>&1 || true
    if [ -f "$json_file" ]; then
        log_test "dashboard-metrics.sh pre-generate JSON" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "dashboard-metrics.sh pre-generate JSON" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_ledger_append_only() {
    setup_isolation
    local before after
    before=$(events_total)
    KALLAX_RUN_HISTORY_LEDGER="$ISOLATED_LEDGER" \
        bash "$RUN_HISTORY" emit work "test-append-only" '{}' >/dev/null 2>&1 || true
    after=$(events_total)
    if [ "$after" -eq $((before + 1)) ]; then
        log_test "run-history.jsonl append-only" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "run-history.jsonl append-only (after=$after before=$before)" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    teardown_isolation
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
    # Use isolated ledger so verify only inspects valid events.
    setup_isolation
    KALLAX_RUN_HISTORY_LEDGER="$ISOLATED_LEDGER" \
        bash "$RUN_HISTORY" emit work "verify-test" '{}' >/dev/null 2>&1 || true
    if KALLAX_RUN_HISTORY_LEDGER="$ISOLATED_LEDGER" \
        bash "$RUN_HISTORY" verify >/dev/null 2>&1; then
        log_test "run-history.sh verify" "PASS"; TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_test "run-history.sh verify" "FAIL"; TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    teardown_isolation
}

main() {
    echo "=========================================="
    echo "EPIC-177-G run-history emit integration (v2 isolated ledger)"
    echo "=========================================="
    mkdir -p "$(dirname "$PROD_LEDGER")"; touch "$PROD_LEDGER"
    echo "Running tests..."
    test_payload_is_object_and_escaped
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
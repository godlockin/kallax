#!/usr/bin/env bash
# tests/integration/smoke-retention.test.sh
# EPIC-174: Smoke Retention Policy Tests
# Exit: 0=PASS, 1=FAIL, 2=BLOCKED-env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SMOKE_DIR="$PROJECT_ROOT/tests/integration"
THRESHOLD=500

PASS=0
FAIL=0
BLOCKED=0

test_pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
test_fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }
test_blocked() { echo "[BLOCKED] $1"; BLOCKED=$((BLOCKED + 1)); }

# Test 1: check-smoke-retention.sh exists and is executable
test_1_scanner_exists() {
    local scanner="$PROJECT_ROOT/scripts/check-smoke-retention.sh"
    if [ ! -f "$scanner" ]; then
        test_fail "scanner not found"
        return 1
    fi
    if [ ! -x "$scanner" ]; then
        test_fail "scanner not executable"
        return 1
    fi
    test_pass "scanner exists and is executable"
}

# Test 2: smoke-size-report.sh exists and is executable
test_2_report_exists() {
    local report="$PROJECT_ROOT/scripts/audit/smoke-size-report.sh"
    if [ ! -f "$report" ]; then
        test_fail "report not found"
        return 1
    fi
    if [ ! -x "$report" ]; then
        test_fail "report not executable"
        return 1
    fi
    test_pass "report exists and is executable"
}

# Test 3: docs/process/smoke-retention-policy.md exists and >=80 lines
test_3_policy_doc() {
    local policy="$PROJECT_ROOT/docs/process/smoke-retention-policy.md"
    if [ ! -f "$policy" ]; then
        test_fail "policy doc not found"
        return 1
    fi
    local lines
    lines=$(wc -l < "$policy")
    if [ "$lines" -lt 80 ]; then
        test_fail "policy doc too short: $lines lines (need >=80)"
        return 1
    fi
    local i
    for i in 1 2 3 4 5; do
        if ! grep -q "Rule $i:" "$policy" 2>/dev/null; then
            test_fail "policy doc missing Rule $i"
            return 1
        fi
    done
    test_pass "policy doc valid: $lines lines, 5 rules present"
}

# Test 4: smoke retention policy scanner detects violations
test_4_scanner_violation_detection() {
    local tmp_smoke="$SMOKE_DIR/test-oversize-temp-smoke.test.sh"
    mkdir -p "$SMOKE_DIR"

    # Create a 501-line file
    {
        echo "#!/usr/bin/env bash"
        echo "# Temp test file for violation detection"
        i=1
        while [ $i -le 499 ]; do
            echo "# Line $i"
            i=$((i + 1))
        done
    } > "$tmp_smoke"
    chmod +x "$tmp_smoke"

    # Run scanner
    local output
    output=$(bash "$PROJECT_ROOT/scripts/check-smoke-retention.sh" --strict 2>&1 || true)

    # Cleanup
    rm -f "$tmp_smoke"

    if echo "$output" | grep -qi "VIOLATION\|FAIL\|fail"; then
        test_pass "scanner detects violations"
    else
        test_fail "scanner did not detect violations"
    fi
}

# Test 5: smoke retention policy scanner exit code contract
test_5_exit_code_contract() {
    local tmp_smoke="$SMOKE_DIR/test-small-temp-smoke.test.sh"
    {
        echo "#!/usr/bin/env bash"
        echo "echo small test"
    } > "$tmp_smoke"
    chmod +x "$tmp_smoke"

    bash "$PROJECT_ROOT/scripts/check-smoke-retention.sh" > /dev/null 2>&1
    local exit_0=$?

    rm -f "$tmp_smoke"

    if [ "$exit_0" -eq 0 ] || [ "$exit_0" -eq 1 ]; then
        test_pass "exit code contract valid: $exit_0"
    else
        test_fail "invalid exit code: $exit_0 (expected 0 or 1)"
    fi
}

# Test 6: report output format
test_6_report_format() {
    local output
    output=$(bash "$PROJECT_ROOT/scripts/audit/smoke-size-report.sh" 2>&1)

    if echo "$output" | grep -q "Smoke Size Report"; then
        test_pass "report has valid format"
    else
        test_fail "report format invalid"
    fi
}

# Test 7: report JSON output
test_7_report_json() {
    local output
    output=$(bash "$PROJECT_ROOT/scripts/audit/smoke-size-report.sh" --json 2>&1)

    if echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
        test_pass "report JSON output valid"
    else
        test_fail "report JSON output invalid"
    fi
}

# Test 8: scanner --help works
test_8_scanner_help() {
    local output
    output=$(bash "$PROJECT_ROOT/scripts/check-smoke-retention.sh" --help 2>&1)

    if echo "$output" | grep -q "Usage:"; then
        test_pass "scanner --help works"
    else
        test_fail "scanner --help failed"
    fi
}

# Test 9: scanner --warn-only mode
test_9_warn_only() {
    local tmp_smoke="$SMOKE_DIR/test-oversize-warn-smoke.test.sh"
    {
        echo "#!/usr/bin/env bash"
        i=1
        while [ $i -le 501 ]; do
            echo "# Line $i"
            i=$((i + 1))
        done
    } > "$tmp_smoke"
    chmod +x "$tmp_smoke"

    bash "$PROJECT_ROOT/scripts/check-smoke-retention.sh" --warn-only > /dev/null 2>&1
    local exit_code=$?

    rm -f "$tmp_smoke"

    if [ "$exit_code" -eq 0 ]; then
        test_pass "scanner --warn-only mode works"
    else
        test_fail "scanner --warn-only failed: exit $exit_code"
    fi
}

# Run all tests
main() {
    echo "=============================================="
    echo "EPIC-174 Smoke Retention Policy Tests"
    echo "=============================================="
    echo ""
    echo "Running tests..."
    echo ""

    test_1_scanner_exists
    test_2_report_exists
    test_3_policy_doc
    test_4_scanner_violation_detection
    test_5_exit_code_contract
    test_6_report_format
    test_7_report_json
    test_8_scanner_help
    test_9_warn_only

    echo ""
    echo "=============================================="
    echo "Results: PASS=$PASS FAIL=$FAIL BLOCKED=$BLOCKED"
    echo "=============================================="

    if [ "$FAIL" -gt 0 ]; then
        echo "FAILED: $FAIL test(s) failed"
        exit 1
    fi

    if [ "$BLOCKED" -gt 0 ]; then
        echo "BLOCKED: $BLOCKED test(s) blocked"
        exit 2
    fi

    echo "ALL TESTS PASSED"
    exit 0
}

main "$@"

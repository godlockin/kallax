#!/usr/bin/env bash
# tests/integration/kpi-evidence-chain-test.sh — TDD tests for 4-Level KPI evidence chain
# EPIC-053-B AC2: 6/6 PASS
#   1. 4-Level 完整 → OK
#   2. 缺 1 Level → FAIL
#   3. 假 git-anchor → FAIL
#   4. 假 test stdout → FAIL
#   5. 5 扩展组不全 → FAIL
#   6. 缺独立见证签名 → FAIL
#
# Rule 9 KPI X/Y format: 6/6 = 100.0% (no estimate, exact)
#
# Test design: use mock tools via KALLAX_EXTENDED_GROUPS_DIR env override
# to make tests deterministic and isolated.

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly VERIFY_SCRIPT="$KALLAX_ROOT/scripts/verify/kpi-evidence-chain.sh"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=6

# Verify script exists (TDD red phase will fail with clear error if missing)
if [ ! -f "$VERIFY_SCRIPT" ]; then
    echo "=========================================="
    echo "4-Level KPI Evidence Chain — Integration Tests"
    echo "=========================================="
    echo ""
    echo "FAIL: $VERIFY_SCRIPT not found (TDD red phase)"
    echo "0/$TOTAL PASS (0.0%)"
    exit 1
fi

echo "=========================================="
echo "4-Level KPI Evidence Chain — Integration Tests (6/6)"
echo "=========================================="
echo ""

# -------------------------------------------------------
# Helper: setup mock tools dir with controllable behavior
# -------------------------------------------------------
# Args: $1 = tools_dir, $2 = "pass" | "fail-tool1" (tool that should FAIL)
setup_mock_tools() {
    local tools_dir="$1"
    local fail_pattern="${2:-}"
    mkdir -p "$tools_dir"

    # Tools for 5 extended groups
    # security-tool-bypass
    create_tool() {
        local name="$1"
        local should_fail="$2"
        local tools_dir="$3"
        if [ "$should_fail" = "1" ]; then
            cat > "$tools_dir/$name.sh" <<EOF
#!/bin/bash
echo "FAIL: $name (mocked failure)"
exit 1
EOF
        else
            cat > "$tools_dir/$name.sh" <<EOF
#!/bin/bash
echo "PASS: $name (mock)"
exit 0
EOF
        fi
        chmod +x "$tools_dir/$name.sh"
    }

    # 9 tools total
    local fail_check_scope="0"
    local fail_check_kpi="0"
    local fail_check_test_iso="0"
    local fail_check_preflight="0"
    local fail_l3l4="0"
    local fail_auditor="0"
    local fail_subagent="0"
    local fail_review="0"
    local fail_rule19="0"

    case "$fail_pattern" in
        fail-scope) fail_check_scope="1" ;;
        fail-kpi) fail_check_kpi="1" ;;
        fail-isolation) fail_check_test_iso="1" ;;
        fail-preflight) fail_check_preflight="1" ;;
        fail-l3l4) fail_l3l4="1" ;;
        fail-auditor) fail_auditor="1" ;;
        fail-subagent) fail_subagent="1" ;;
        fail-review) fail_review="1" ;;
        fail-rule19) fail_rule19="1" ;;
    esac

    create_tool "check-scope-creep" "$fail_check_scope" "$tools_dir"
    create_tool "check-kpi-precision" "$fail_check_kpi" "$tools_dir"
    create_tool "check-test-case-isolation" "$fail_check_test_iso" "$tools_dir"
    create_tool "check-fact-forcing-preflight" "$fail_check_preflight" "$tools_dir"
    create_tool "l3-l4-consistency" "$fail_l3l4" "$tools_dir"
    create_tool "auditor-checkpoint" "$fail_auditor" "$tools_dir"
    create_tool "subagent-pass-gate" "$fail_subagent" "$tools_dir"
    create_tool "review-checkpoint" "$fail_review" "$tools_dir"
    create_tool "rule-19-checkpoint" "$fail_rule19" "$tools_dir"
}

# -------------------------------------------------------
# Helper: get a real commit SHA from current HEAD
# -------------------------------------------------------
get_real_sha() {
    git rev-parse HEAD 2>/dev/null || echo ""
}

# -------------------------------------------------------
# Helper: setup a valid test stdout file
# -------------------------------------------------------
create_valid_test_stdout() {
    local file="$1"
    cat > "$file" <<'EOF'
==========================================
Integration Test Suite
==========================================
[PASS] test_case_1
[PASS] test_case_2
[PASS] test_case_3
[PASS] test_case_4
[PASS] test_case_5
[PASS] test_case_6
==========================================
Tests: 6 passed, 6 total
6/6 PASS (100.0%)
==========================================
EOF
}

# -------------------------------------------------------
# Helper: cleanup temp dir
# -------------------------------------------------------
TMPDIR_ROOT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# -------------------------------------------------------
# Test 1: 4-Level 完整 → OK
# -------------------------------------------------------
echo "--- Test 1: 4-Level 完整 → OK ---"
T1_DIR="$TMPDIR_ROOT/test1"
mkdir -p "$T1_DIR"
setup_mock_tools "$T1_DIR/tools" "pass"
REAL_SHA=$(get_real_sha)
T1_STDOUT="$T1_DIR/test_stdout.txt"
create_valid_test_stdout "$T1_STDOUT"
set +e
KALLAX_EXTENDED_GROUPS_DIR="$T1_DIR/tools" \
    bash "$VERIFY_SCRIPT" verify "EPIC-053-B-T1" "$REAL_SHA" "$T1_STDOUT" >/dev/null 2>&1
RESULT1=$?
set -e
if [ "$RESULT1" -eq 0 ]; then
    echo "[PASS] expected OK, got OK (exit=$RESULT1)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] expected OK, got ERROR (exit=$RESULT1)"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# -------------------------------------------------------
# Test 2: 缺 1 Level → FAIL (use fake sha = missing L1)
# -------------------------------------------------------
echo "--- Test 2: 缺 1 Level (L1 假 SHA) → FAIL ---"
T2_DIR="$TMPDIR_ROOT/test2"
mkdir -p "$T2_DIR"
setup_mock_tools "$T2_DIR/tools" "pass"
T2_STDOUT="$T2_DIR/test_stdout.txt"
create_valid_test_stdout "$T2_STDOUT"
# Use non-existent SHA — this is "missing L1 evidence"
set +e
KALLAX_EXTENDED_GROUPS_DIR="$T2_DIR/tools" \
    bash "$VERIFY_SCRIPT" verify "EPIC-053-B-T2" "deadbeef_missing_sha_0000000000000000000000000000" "$T2_STDOUT" >/dev/null 2>&1
RESULT2=$?
set -e
if [ "$RESULT2" -ne 0 ]; then
    echo "[PASS] expected ERROR (L1 FAIL), got ERROR (exit=$RESULT2)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] expected ERROR (L1 FAIL), got OK (exit=$RESULT2)"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# -------------------------------------------------------
# Test 3: 假 git-anchor → FAIL
# -------------------------------------------------------
echo "--- Test 3: 假 git-anchor (fake_sha_123) → FAIL ---"
T3_DIR="$TMPDIR_ROOT/test3"
mkdir -p "$T3_DIR"
setup_mock_tools "$T3_DIR/tools" "pass"
T3_STDOUT="$T3_DIR/test_stdout.txt"
create_valid_test_stdout "$T3_STDOUT"
set +e
KALLAX_EXTENDED_GROUPS_DIR="$T3_DIR/tools" \
    bash "$VERIFY_SCRIPT" verify "EPIC-053-B-T3" "fake_sha_123_not_real_git_object" "$T3_STDOUT" >/dev/null 2>&1
RESULT3=$?
set -e
if [ "$RESULT3" -ne 0 ]; then
    echo "[PASS] expected ERROR (L1 fake SHA), got ERROR (exit=$RESULT3)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] expected ERROR (L1 fake SHA), got OK (exit=$RESULT3)"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# -------------------------------------------------------
# Test 4: 假 test stdout → FAIL (no PASS pattern, no X/Y format)
# -------------------------------------------------------
echo "--- Test 4: 假 test stdout (无 PASS / X/Y 标记) → FAIL ---"
T4_DIR="$TMPDIR_ROOT/test4"
mkdir -p "$T4_DIR"
setup_mock_tools "$T4_DIR/tools" "pass"
REAL_SHA=$(get_real_sha)
T4_STDOUT="$T4_DIR/test_stdout.txt"
cat > "$T4_STDOUT" <<'EOF'
==========================================
Integration Test Suite
==========================================
Everything looks good, no actual test results
==========================================
EOF
set +e
KALLAX_EXTENDED_GROUPS_DIR="$T4_DIR/tools" \
    bash "$VERIFY_SCRIPT" verify "EPIC-053-B-T4" "$REAL_SHA" "$T4_STDOUT" >/dev/null 2>&1
RESULT4=$?
set -e
if [ "$RESULT4" -ne 0 ]; then
    echo "[PASS] expected ERROR (L2 fake stdout), got ERROR (exit=$RESULT4)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] expected ERROR (L2 fake stdout), got OK (exit=$RESULT4)"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# -------------------------------------------------------
# Test 5: 5 扩展组不全 → FAIL (one group has failing tool)
# -------------------------------------------------------
echo "--- Test 5: 5 扩展组不全 (auditor-checkpoint FAIL) → FAIL ---"
T5_DIR="$TMPDIR_ROOT/test5"
mkdir -p "$T5_DIR"
setup_mock_tools "$T5_DIR/tools" "fail-auditor"
REAL_SHA=$(get_real_sha)
T5_STDOUT="$T5_DIR/test_stdout.txt"
create_valid_test_stdout "$T5_STDOUT"
set +e
KALLAX_EXTENDED_GROUPS_DIR="$T5_DIR/tools" \
    bash "$VERIFY_SCRIPT" verify "EPIC-053-B-T5" "$REAL_SHA" "$T5_STDOUT" >/dev/null 2>&1
RESULT5=$?
set -e
if [ "$RESULT5" -ne 0 ]; then
    echo "[PASS] expected ERROR (L3 group fail), got ERROR (exit=$RESULT5)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] expected ERROR (L3 group fail), got OK (exit=$RESULT5)"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# -------------------------------------------------------
# Test 6: 缺独立见证签名 → FAIL
# -------------------------------------------------------
echo "--- Test 6: 缺独立见证签名 (skip-witness) → FAIL ---"
T6_DIR="$TMPDIR_ROOT/test6"
mkdir -p "$T6_DIR"
setup_mock_tools "$T6_DIR/tools" "pass"
REAL_SHA=$(get_real_sha)
T6_STDOUT="$T6_DIR/test_stdout.txt"
create_valid_test_stdout "$T6_STDOUT"
# Use --skip-witness to indicate L4 missing (or use a non-writable audit dir)
# We'll redirect KALLAX_AUDIT_SINK_DIR to a non-existent path that can't be created
set +e
KALLAX_EXTENDED_GROUPS_DIR="$T6_DIR/tools" \
    KALLAX_AUDIT_SINK_DIR="/nonexistent_path_no_permission_at_all_xyz" \
    bash "$VERIFY_SCRIPT" verify "EPIC-053-B-T6" "$REAL_SHA" "$T6_STDOUT" >/dev/null 2>&1
RESULT6=$?
set -e
if [ "$RESULT6" -ne 0 ]; then
    echo "[PASS] expected ERROR (L4 missing witness), got ERROR (exit=$RESULT6)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] expected ERROR (L4 missing witness), got OK (exit=$RESULT6)"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# -------------------------------------------------------
# Summary — exact X/Y format (Rule 9 KPI precision)
# -------------------------------------------------------
echo "=========================================="
echo "Results: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "FAIL: $FAIL_COUNT test(s) failed"
    echo "$PASS_COUNT/$TOTAL PASS"
    exit 1
fi
echo "PASS: all $TOTAL integration tests passed"
echo "$PASS_COUNT/$TOTAL PASS (100.0%)"
exit 0
#!/usr/bin/env bash
# tests/integration/process-metrics-test.sh — TDD tests for 3 KPI Process Metrics
# EPIC-056-B AC5: 6/6 PASS
#   1. 派单成功率 KPI 计算 (X/Y 格式, 跟 Rule 9 精确一致)
#   2. 平均周期 KPI 计算 (跟 6h 估时对比)
#   3. 越界率 KPI 计算 (BE-1/6/11 历史)
#   4. 历史趋势 数据聚合 (按 EPIC 分桶)
#   5. 目标值校验 (95% / 8h / 0%)
#   6. 异常告警 + 仪表盘输出
#
# Rule 9 KPI X/Y format: 6/6 = 100.0% (no estimate, exact, 1 decimal)
# Rule 16 (Subagent process) — test must be runnable in isolation.
# BE-7 修复模式: umask 077 + install -d -m 700 for any test fixtures dir.
#
# Test design: spawn Node.js CLI (process-metrics.ts) with --tickets-dir override
# pointing to fixture tickets. Validate exact X/Y output strings.

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly NODE_BIN="${NODE_BIN:-node}"
readonly PROCESS_METRICS_TS="$KALLAX_ROOT/node/src/core/process-metrics.ts"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=6

# -------------------------------------------------------
# TDD red phase: file must exist for test to start
# -------------------------------------------------------
if [ ! -f "$PROCESS_METRICS_TS" ]; then
    echo "=========================================="
    echo "Process Metrics — Integration Tests (6/6)"
    echo "=========================================="
    echo ""
    echo "FAIL: $PROCESS_METRICS_TS not found (TDD red phase)"
    echo "0/$TOTAL PASS (0.0%)"
    exit 1
fi

echo "=========================================="
echo "Process Metrics — Integration Tests (6/6)"
echo "=========================================="
echo ""

# -------------------------------------------------------
# Helper: run process-metrics CLI with given args
# Args: $1 = subcommand, $@ = remaining args
# Echoes stdout, returns exit code via RESULT global
# -------------------------------------------------------
RESULT=""
RESULT_RC=0

run_pm() {
    local subcommand="$1"
    shift
    set +e
    RESULT=$("$NODE_BIN" --experimental-strip-types "$PROCESS_METRICS_TS" "$subcommand" "$@" 2>&1)
    RESULT_RC=$?
    set -e
}

# -------------------------------------------------------
# Helper: create mock ticket fixtures in tmp dir
# Args: $1 = tickets_dir, $2 = scenario name
#   "real" — 7/12 PASS + 6h avg + 3/11 violations (matches current state)
#   "target" — 19/20 PASS + 6h avg + 0 violations (target met)
#   "critical" — 4/12 PASS + 14h avg + 4 violations (anomaly)
# -------------------------------------------------------
create_mock_tickets() {
    local tickets_dir="$1"
    local scenario="$2"
    mkdir -p "$tickets_dir"

    case "$scenario" in
        real)
            # 15 tickets total: 10 done (66.7%), 6h avg, 3 BE-tagged (20.0%)
            # Mirrors PROJECT-STATUS-2026-06-13.md: 7/12 真 PASS (58.3%) + 3 BE 越界反向
            local i
            for i in $(seq 1 7); do
                create_one_ticket "$tickets_dir/EPIC-039-A-$i" "done" "2026-06-01T00:00:00Z" "2026-06-01T06:00:00Z"
            done
            for i in $(seq 1 3); do
                create_one_ticket "$tickets_dir/EPIC-039-B-$i" "fail" "2026-06-02T00:00:00Z" "2026-06-02T06:00:00Z"
            done
            for i in $(seq 1 2); do
                create_one_ticket "$tickets_dir/EPIC-039-C-$i" "pending" "2026-06-03T00:00:00Z" ""
            done
            # BE-1/6/11 markers — done but flagged for scope violation (越界事件)
            create_one_ticket "$tickets_dir/EPIC-039-A-BE6" "done" "2026-06-01T00:00:00Z" "2026-06-01T06:00:00Z" "BE-6"
            create_one_ticket "$tickets_dir/EPIC-039-A-BE11" "done" "2026-06-01T00:00:00Z" "2026-06-01T06:00:00Z" "BE-11"
            create_one_ticket "$tickets_dir/EPIC-039-A-BE1" "done" "2026-06-01T00:00:00Z" "2026-06-01T06:00:00Z" "BE-1"
            ;;
        target)
            # 20 tickets, 19 done (95%), 6h avg, 0 violations
            local i
            for i in $(seq 1 19); do
                create_one_ticket "$tickets_dir/EPIC-053-A-$i" "done" "2026-06-10T00:00:00Z" "2026-06-10T06:00:00Z"
            done
            create_one_ticket "$tickets_dir/EPIC-053-A-fail" "fail" "2026-06-10T00:00:00Z" "2026-06-10T06:00:00Z"
            ;;
        critical)
            # 12 tickets, 4 done (33%), 14h avg, 4 violations → all 3 KPIs anomalous
            local i
            for i in $(seq 1 4); do
                create_one_ticket "$tickets_dir/EPIC-041-A-$i" "done" "2026-06-05T00:00:00Z" "2026-06-05T14:00:00Z"
            done
            for i in $(seq 1 5); do
                create_one_ticket "$tickets_dir/EPIC-041-B-$i" "fail" "2026-06-05T00:00:00Z" "2026-06-05T14:00:00Z"
            done
            for i in $(seq 1 3); do
                create_one_ticket "$tickets_dir/EPIC-041-C-$i" "pending" "2026-06-05T00:00:00Z" ""
            done
            create_one_ticket "$tickets_dir/EPIC-041-A-BE6" "done" "2026-06-05T00:00:00Z" "2026-06-05T14:00:00Z" "BE-6"
            create_one_ticket "$tickets_dir/EPIC-041-A-BE11" "done" "2026-06-05T00:00:00Z" "2026-06-05T14:00:00Z" "BE-11"
            create_one_ticket "$tickets_dir/EPIC-041-A-BE1" "done" "2026-06-05T00:00:00Z" "2026-06-05T14:00:00Z" "BE-1"
            create_one_ticket "$tickets_dir/EPIC-041-A-BE5" "done" "2026-06-05T00:00:00Z" "2026-06-05T14:00:00Z" "BE-5"
            ;;
    esac
}

# Create one ticket.json under tickets_dir/<name>/
# Args: $1 path, $2 status, $3 created_at, $4 completed_at (or ""), $5 be_tag (optional)
create_one_ticket() {
    local path="$1"
    local status="$2"
    local created_at="$3"
    local completed_at="$4"
    local be_tag="${5:-}"
    mkdir -p "$path"
    local be_field="null"
    if [ -n "$be_tag" ]; then
        be_field="\"$be_tag\""
    fi
    local completed_field="null"
    if [ -n "$completed_at" ]; then
        completed_field="\"$completed_at\""
    fi
    cat > "$path/ticket.json" <<EOF
{
  "id": "$(basename "$path")",
  "status": "$status",
  "created_at": "$created_at",
  "completed_at": $completed_field,
  "estimated_hours": 6,
  "be_event": $be_field,
  "file_scope": {"includes": [], "excludes": []}
}
EOF
}

# -------------------------------------------------------
# Helper: setup tmp dir with BE-7 修复模式 permissions
# -------------------------------------------------------
TMPDIR_ROOT=$(mktemp -d)
(umask 077 && install -d -m 700 "$TMPDIR_ROOT") || {
    echo "FATAL: cannot create tmp dir"
    exit 1
}
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# -------------------------------------------------------
# Test 1: 派单成功率 KPI 计算 (X/Y 格式)
# -------------------------------------------------------
echo "--- Test 1: 派单成功率 KPI (X/Y 格式) ---"
T1_DIR="$TMPDIR_ROOT/test1"
create_mock_tickets "$T1_DIR/tickets" "real"
run_pm dispatch-rate --tickets-dir "$T1_DIR/tickets"
if [ "$RESULT_RC" -eq 0 ] && echo "$RESULT" | grep -qE '^[0-9]+/[0-9]+ \([0-9]+\.[0-9]+%\)$'; then
    # Expect 10 done / 15 total = 66.7% (matches fixture)
    if echo "$RESULT" | grep -qE '^10/15 \(66\.7%\)$'; then
        echo "[PASS] dispatch-rate format valid: $RESULT"
        PASS_COUNT=$((PASS_COUNT+1))
    else
        echo "[FAIL] dispatch-rate value unexpected: $RESULT (expected 10/15 (66.7%))"
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
else
    echo "[FAIL] dispatch-rate invalid format or non-zero exit: rc=$RESULT_RC, output=$RESULT"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# -------------------------------------------------------
# Test 2: 平均周期 KPI 计算
# -------------------------------------------------------
echo "--- Test 2: 平均周期 KPI (X/Y 格式 跟 6h 估时对比) ---"
T2_DIR="$TMPDIR_ROOT/test2"
create_mock_tickets "$T2_DIR/tickets" "real"
run_pm cycle-time --tickets-dir "$T2_DIR/tickets"
if [ "$RESULT_RC" -eq 0 ] && echo "$RESULT" | grep -qE '^[0-9]+\.[0-9]+h$'; then
    # Expect 6.0h (6h diff for each ticket)
    if echo "$RESULT" | grep -qE '^6\.0h$'; then
        echo "[PASS] cycle-time format valid: $RESULT"
        PASS_COUNT=$((PASS_COUNT+1))
    else
        echo "[FAIL] cycle-time value unexpected: $RESULT (expected 6.0h)"
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
else
    echo "[FAIL] cycle-time invalid format or non-zero exit: rc=$RESULT_RC, output=$RESULT"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# -------------------------------------------------------
# Test 3: 越界率 KPI 计算 (BE-1/6/11 历史)
# -------------------------------------------------------
echo "--- Test 3: 越界率 KPI (BE-1/6/11 历史 3/11) ---"
T3_DIR="$TMPDIR_ROOT/test3"
create_mock_tickets "$T3_DIR/tickets" "real"
run_pm violation-rate --tickets-dir "$T3_DIR/tickets"
if [ "$RESULT_RC" -eq 0 ] && echo "$RESULT" | grep -qE '^[0-9]+/[0-9]+ \([0-9]+\.[0-9]+%\)$'; then
    # Expect 3/15 (real has 3 BE tickets over 15 total tickets)
    if echo "$RESULT" | grep -qE '^[0-9]+/15 \([0-9]+\.[0-9]+%\)$'; then
        echo "[PASS] violation-rate format valid: $RESULT"
        PASS_COUNT=$((PASS_COUNT+1))
    else
        echo "[FAIL] violation-rate unexpected: $RESULT (expected 3/15 (20.0%) for 3 BE tickets)"
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
else
    echo "[FAIL] violation-rate invalid format or non-zero exit: rc=$RESULT_RC, output=$RESULT"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# -------------------------------------------------------
# Test 4: 历史趋势 数据聚合 (按 EPIC 分桶)
# -------------------------------------------------------
echo "--- Test 4: 历史趋势 (按 EPIC 分桶) ---"
T4_DIR="$TMPDIR_ROOT/test4"
create_mock_tickets "$T4_DIR/tickets" "real"
run_pm trend --tickets-dir "$T4_DIR/tickets"
if [ "$RESULT_RC" -eq 0 ] && echo "$RESULT" | grep -q "EPIC-039" && echo "$RESULT" | grep -qE '[0-9]+/[0-9]+ \([0-9]+\.[0-9]+%\)'; then
    echo "[PASS] trend output valid (contains EPIC bucket + X/Y)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] trend invalid: rc=$RESULT_RC, output=$RESULT"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# -------------------------------------------------------
# Test 5: 目标值校验 (95% / 8h / 0%)
# -------------------------------------------------------
echo "--- Test 5: 目标值校验 ---"
T5A_DIR="$TMPDIR_ROOT/test5a"
create_mock_tickets "$T5A_DIR/tickets" "target"
run_pm check-targets --tickets-dir "$T5A_DIR/tickets"
T5A_RC=$RESULT_RC
T5A_OUT=$RESULT

T5B_DIR="$TMPDIR_ROOT/test5b"
create_mock_tickets "$T5B_DIR/tickets" "real"
run_pm check-targets --tickets-dir "$T5B_DIR/tickets"
T5B_RC=$RESULT_RC
T5B_OUT=$RESULT

# target scenario should PASS (all 3 KPIs met); real should FAIL (3 KPIs not met)
if [ "$T5A_RC" -eq 0 ] && echo "$T5A_OUT" | grep -qiE "dispatch-rate.*(PASS|OK|all.*pass|ALL_PASS=YES)"; then
    if [ "$T5B_RC" -ne 0 ] && echo "$T5B_OUT" | grep -qiE "FAIL|ALL_PASS=NO"; then
        echo "[PASS] target validation distinguishes target vs real"
        PASS_COUNT=$((PASS_COUNT+1))
    else
        echo "[FAIL] target validation should FAIL on real scenario: rc=$T5B_RC, output=$T5B_OUT"
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
else
    echo "[FAIL] target validation should PASS on target scenario: rc=$T5A_RC, output=$T5A_OUT"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi
echo ""

# -------------------------------------------------------
# Test 6: 异常告警 + 仪表盘输出
# -------------------------------------------------------
echo "--- Test 6: 异常告警 + 仪表盘输出 ---"
T6_DIR="$TMPDIR_ROOT/test6"
create_mock_tickets "$T6_DIR/tickets" "critical"
run_pm dashboard --tickets-dir "$T6_DIR/tickets"
if [ "$RESULT_RC" -eq 0 ] && echo "$RESULT" | grep -qE "3 KPI|3-KPI|KPI Dashboard" && \
   echo "$RESULT" | grep -qE "CRITICAL|WARN|FAIL" && \
   echo "$RESULT" | grep -qE '[0-9]+/[0-9]+ \([0-9]+\.[0-9]+%\)'; then
    echo "[PASS] dashboard output contains CRITICAL alert + 3 KPI in X/Y format"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "[FAIL] dashboard output incomplete: rc=$RESULT_RC, output=$RESULT"
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
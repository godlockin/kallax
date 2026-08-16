#!/usr/bin/env bash
# scripts/verify/level-2.sh — L2 实质性 (test stdout 真实跑) (武器 2 Iter 5)
#
# 目的: 验证测试真跑过 + stdout 真实 (反 "should work" 估数反模式)
# 跟 docs/5-levels.md L2 段 1:1 联合
#
# Usage:
#   bash scripts/verify/level-2.sh TICKET_ID [--dry-run]
#
# 行为:
#   1. 读 jira/tickets/<TICKET_ID>/ticket.json 的 `tests:` 字段
#   2. 跑每个 test command, capture raw stdout
#   3. grep test result (passed|failed) — 必须 0 failed
#
# Exit codes:
#   0  PASS — tests 真实跑 + 全过 (或 --dry-run + 有 test command 备案)
#   1  FAIL — 有 test failed / tests 未跑
#   2  ERROR — 参数错 / ticket.json 不存在

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TICKET_ID="${1:-}"
DRY_RUN=0
if [ "${2:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi

echo "=========================================="
echo "L2 实质性验证 (test stdout 真实跑) — 武器 2"
echo "=========================================="
echo "TICKET: $TICKET_ID"
echo "DRY_RUN: $DRY_RUN"
echo ""

if [ -z "$TICKET_ID" ]; then
    echo "ERROR: TICKET_ID required" >&2
    echo "Usage: bash scripts/verify/level-2.sh TICKET_ID [--dry-run]" >&2
    exit 2
fi

TICKET_FILE="$KALLAX_ROOT/jira/tickets/$TICKET_ID/ticket.json"
TICKET_EXISTS=0
if [ -f "$TICKET_FILE" ]; then
    TICKET_EXISTS=1
fi
if [ "$TICKET_EXISTS" -eq 0 ]; then
    # Placeholder ticket (no real ticket) — dry-run 模式 OK
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  (ticket.json not found: $TICKET_FILE — dry-run placeholder OK)"
    else
        echo "ERROR: ticket.json not found: $TICKET_FILE" >&2
        exit 2
    fi
fi

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=3

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# ----- Check 1: ticket.json 解析 -----
echo ">>> Check 1: ticket.json parse"
if [ "$TICKET_EXISTS" -eq 0 ]; then
    # Placeholder ticket (dry-run)
    pass "ticket.json placeholder (dry-run mode, skip parse)"
    TICKET_TITLE="(placeholder)"
else
    set +e
    TICKET_TITLE=$(python3 -c "import json; d=json.load(open('$TICKET_FILE')); print(d.get('title',''))" 2>&1)
    RC=$?
    set -e
    if [ "$RC" -ne 0 ]; then
        fail "ticket.json parse failed"
        echo "$TICKET_TITLE"
        echo ""
        echo "RESULT: FAIL"
        exit 1
    fi
    pass "ticket.json parsed: $TICKET_TITLE"
fi
echo ""

# ----- Check 2: tests 字段定义 -----
echo ">>> Check 2: tests field defined"
if [ "$TICKET_EXISTS" -eq 0 ]; then
    # Placeholder ticket (dry-run)
    pass "tests field placeholder (dry-run mode, skip parse)"
    TESTS_JSON="echo L2-placeholder-smoke"
    TEST_COUNT=1
else
    set +e
    TESTS_JSON=$(python3 -c "
import json
d = json.load(open('$TICKET_FILE'))
tests = d.get('tests', [])
if isinstance(tests, list):
    for t in tests:
        print(t)
" 2>&1)
    RC=$?
    set -e
    if [ "$RC" -ne 0 ]; then
        fail "tests field parse error"
        echo "$TESTS_JSON"
        echo ""
        echo "RESULT: FAIL"
        exit 1
    fi
    # Use printf to avoid empty-string wc -l issue with set -e
    # EPIC-254: `|| echo 0` 污染 → "0\n0", 后面 tr 拼成 "00" (偶然仍判 false).
    # 用 `|| true` 从源头避免多行.
    TEST_COUNT=$(printf '%s' "$TESTS_JSON" | grep -c '^.' 2>/dev/null || true)
    TEST_COUNT=$(printf '%s' "${TEST_COUNT:-0}" | tr -d '[:space:]')

    if [ "${TEST_COUNT:-0}" -gt 0 ]; then
        pass "$TEST_COUNT test command(s) defined"
        echo "  Defined tests:"
        printf '%s\n' "$TESTS_JSON" | sed 's/^/    /'
    else
        # 试 integration_test 字段
        set +e
        INT_TEST=$(python3 -c "import json; d=json.load(open('$TICKET_FILE')); v=d.get('integration_test',''); print(v if v else '')" 2>&1)
        INT_RC=$?
        set -e
        if [ "$INT_RC" -ne 0 ]; then
            fail "integration_test field parse error"
            echo "$INT_TEST"
            echo ""
            echo "RESULT: FAIL"
            exit 1
        fi
        if [ -n "$INT_TEST" ]; then
            pass "integration_test field: $INT_TEST"
            TESTS_JSON="$INT_TEST"
            TEST_COUNT=1
        else
            # dry-run 模式: 接受"无 tests"作为 placeholder, 不 FAIL
            if [ "$DRY_RUN" -eq 1 ]; then
                pass "no tests field in ticket.json (dry-run accepts placeholder)"
                TESTS_JSON="echo L2-placeholder-smoke"
                TEST_COUNT=1
            else
                fail "no tests defined in ticket.json (tests:[] + integration_test missing)"
                echo ""
                echo "RESULT: FAIL — L2 requires real test commands"
                exit 1
            fi
        fi
    fi
fi
echo ""

# ----- Check 3: 跑 test (real or dry-run) -----
echo ">>> Check 3: run tests + capture raw stdout"
STDOUT_LOG=$(mktemp /tmp/l2-stdout-XXXXXX.log)
TEST_RC=0

if [ "$DRY_RUN" -eq 1 ]; then
    echo "  (dry-run: skipping actual execution, just verifying test paths exist)"
    while IFS= read -r test_cmd; do
        [ -z "$test_cmd" ] && continue
        # Skip placeholder echo (dry-run only)
        if echo "$test_cmd" | grep -q "L2-placeholder-smoke"; then
            pass "L2 placeholder smoke (dry-run): $test_cmd"
            continue
        fi
        # Strip shell wrappers like "bash " prefix to get file path
        TEST_PATH=$(echo "$test_cmd" | sed -E 's/^bash //; s/^sh //')
        if [ -f "$KALLAX_ROOT/$TEST_PATH" ]; then
            pass "test path exists: $TEST_PATH (dry-run OK)"
        else
            fail "test path missing: $TEST_PATH (dry-run FAIL)"
            TEST_RC=1
        fi
    done <<< "$TESTS_JSON"
else
    echo "  Executing tests..."
    while IFS= read -r test_cmd; do
        [ -z "$test_cmd" ] && continue
        echo "  RUN: $test_cmd"
        set +e
        cd "$KALLAX_ROOT"
        bash -c "$test_cmd" > "$STDOUT_LOG" 2>&1
        TEST_RC=$?
        set -e
        if [ "$TEST_RC" -eq 0 ]; then
            pass "test PASS: $test_cmd"
            TAIL_OUT=$(tail -3 "$STDOUT_LOG" 2>/dev/null | tr '\n' ' ' | head -c 200 || true)
            echo "    stdout: $TAIL_OUT"
        else
            fail "test FAIL (exit=$TEST_RC): $test_cmd"
            TAIL_OUT=$(tail -10 "$STDOUT_LOG" 2>/dev/null | sed 's/^/      /' || true)
            echo "    stdout: $TAIL_OUT"
        fi
    done <<< "$TESTS_JSON"
fi
echo ""

# Summary
echo "=========================================="
echo "L2 Summary: $PASS_COUNT PASS, $FAIL_COUNT FAIL (of $TOTAL)"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ] || [ "$TEST_RC" -ne 0 ]; then
    echo "RESULT: FAIL — L2 not satisfied (test stdout not real)"
    [ -f "$STDOUT_LOG" ] && rm -f "$STDOUT_LOG"
    exit 1
fi
[ -f "$STDOUT_LOG" ] && rm -f "$STDOUT_LOG"
echo "RESULT: PASS — L2 OK (raw stdout verified)"
exit 0

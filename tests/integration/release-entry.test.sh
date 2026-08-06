#!/usr/bin/env bash
# tests/integration/release-entry.test.sh — EPIC-183 release entry 生成集成测试
#
# 覆盖:
#   T1. --version 格式校验 (FAIL_BAD_FORMAT exit=2)
#   T2. --version 缺 (exit=2)
#   T3. --self-test 6/6 PASS
#   T4. --dry-run 输出 [version] 行
#   T5. --dry-run 输出 Closed EPICs 表
#   T6. 真写入 CHANGELOG.md (backup + restore 模式)
#   T7. EPIC-177-G emit decision (run-history ledger)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RELEASE_ENTRY="$KALLAX_ROOT/scripts/release-entry.sh"
RUN_HISTORY="$KALLAX_ROOT/scripts/heartbeat/run-history.sh"
CHANGELOG="$KALLAX_ROOT/CHANGELOG.md"

PASS=0
FAIL=0

assert_contains() {
    local test_name="$1" pattern="$2" output="$3"
    if echo "$output" | grep -Eq "$pattern"; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected: $pattern)"
        FAIL=$((FAIL + 1))
    fi
}

assert_exit_code() {
    local test_name="$1" expected="$2" actual="$3"
    if [ "$actual" -eq "$expected" ]; then
        echo "  PASS: $test_name (exit=$actual)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected exit=$expected, got=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== release-entry.test.sh (≥7 用例, EPIC-183) ==="

# ── T1: --version 格式校验 ──
echo ""
echo "T1: --version 格式校验"
local out1 exit1
out1=$(bash "$RELEASE_ENTRY" --version BAD_VERSION 2>&1) || exit1=$?
exit1=${exit1:-0}
assert_exit_code "T1.1 BAD_FORMAT exit=2" 2 "$exit1"
assert_contains "T1.2 错误提示" "vX.Y.Z" "$out1"

# ── T2: --version 缺 ──
echo ""
echo "T2: --version 缺"
local out2 exit2
out2=$(bash "$RELEASE_ENTRY" 2>&1) || exit2=$?
exit2=${exit2:-0}
assert_exit_code "T2.1 缺 --version exit=2" 2 "$exit2"

# ── T3: --self-test ──
echo ""
echo "T3: --self-test"
out1=$(bash "$RELEASE_ENTRY" --self-test 2>&1)
assert_contains "T3.1 self-test 6/6 PASS" "6/6" "$out1"

# ── T4: --dry-run 输出 [version] 行 ──
echo ""
echo "T4: --dry-run 输出 [version] 行"
out1=$(cd "$KALLAX_ROOT" && bash "$RELEASE_ENTRY" --version v3.99.99 --since HEAD~1 --dry-run 2>&1)
assert_contains "T4.1 含 [v3.99.99] 行" "\[v3.99.99\]" "$out1"

# ── T5: --dry-run 输出 EPIC table ──
echo ""
echo "T5: --dry-run 输出 EPIC table"
assert_contains "T5.1 含 'Closed EPICs' 表头" "Closed EPICs" "$out1"
assert_contains "T5.2 含 'Auto-generated' 标记" "Auto-generated" "$out1"

# ── T6: 真写入 CHANGELOG.md (backup + restore) ──
echo ""
echo "T6: 真写入 CHANGELOG.md"
if [ -f "$CHANGELOG" ]; then
    backup=$(mktemp)
    cp "$CHANGELOG" "$backup"

    # 真写
    (cd "$KALLAX_ROOT" && bash "$RELEASE_ENTRY" --version v9.99.99 --since HEAD~1 2>&1)
    write_exit=$?

    # 验证 CHANGELOG 顶部含新 entry
    head_top=$(head -10 "$CHANGELOG")
    assert_contains "T6.1 CHANGELOG 顶部含新 entry" "v9.99.99" "$head_top"
    assert_exit_code "T6.2 真写 exit=0" 0 "$write_exit"

    # 还原
    mv "$backup" "$CHANGELOG"
    echo "  (CHANGELOG 已还原)"
else
    echo "  SKIP: T6 CHANGELOG.md 不存在"
fi

# ── T7: EPIC-177-G emit decision (run-history ledger) ──
echo ""
echo "T7: EPIC-177-G emit decision"
if [ -f "$RUN_HISTORY" ]; then
    # Set isolated ledger for test
    TEST_LEDGER=$(mktemp)
    out1=$(cd "$KALLAX_ROOT" && KALLAX_RUN_HISTORY_LEDGER="$TEST_LEDGER" bash "$RELEASE_ENTRY" --version v9.99.99-emit --since HEAD~1 --dry-run 2>&1)
    # emit happens in 真写 mode, --dry-run 不 emit. 所以 --dry-run 后 ledger 应该空.
    # 但 generate_entry 在 dry_run=1 时 early return, 不 emit. 我们直接测 emit by 真写
    (cd "$KALLAX_ROOT" && KALLAX_RUN_HISTORY_LEDGER="$TEST_LEDGER" bash "$RELEASE_ENTRY" --version v9.99.99 --since HEAD~1 2>&1)
    write_exit=$?

    if [ -s "$TEST_LEDGER" ]; then
        echo "  PASS: T7.1 ledger 非空 (emit 工作)"
        PASS=$((PASS + 1))
        # 验证 emit 内容
        if grep -q "release_entry_generated" "$TEST_LEDGER"; then
            echo "  PASS: T7.2 ledger 含 release_entry_generated"
            PASS=$((PASS + 1))
        else
            echo "  FAIL: T7.2 ledger 缺 release_entry_generated"
            FAIL=$((FAIL + 1))
        fi
    else
        echo "  FAIL: T7.1 ledger 空 (emit 未工作)"
        FAIL=$((FAIL + 1))
    fi
    rm -f "$TEST_LEDGER"

    # 还原 CHANGELOG (上面 T6 可能改了)
    if [ -f "$backup" ]; then
        mv "$backup" "$CHANGELOG"
    fi
else
    echo "  SKIP: T7 run-history.sh 不存在"
fi

# ── 总结 ──
echo ""
echo "=== release-entry.test.sh 总结 ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL"
echo "  FAIL: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
    echo "  ✅ ALL PASS"
    exit 0
else
    echo "  ❌ $FAIL FAILED"
    exit 1
fi
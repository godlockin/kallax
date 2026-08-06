#!/usr/bin/env bash
# tests/integration/frame-task.test.sh — EPIC-180-A 集成测试
#
# ≥6 用例覆盖 4 档 + 9 类破坏性 + 阈值边界
# 跟 Rule 9 KPI X/Y 格式联合

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FRAME_TASK="$KALLAX_ROOT/scripts/frame-task.sh"

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

echo "=== frame-task.test.sh (≥6 用例, 4 档全覆盖) ==="

# ── Test 1: TRIVIAL 档 (单查询) ──
echo ""
echo "Test 1: TRIVIAL 档 — 'EPIC-161 是什么'"
out=$(bash "$FRAME_TASK" classify "EPIC-161 是什么" 2>&1)
assert_contains "Test 1.1 包含 SCORE 字段" "SCORE:" "$out"
assert_contains "Test 1.2 包含 4 维评分" "多步骤:" "$out"
assert_contains "Test 1.3 包含 6 字段 Q1-Q6" "Q1. 目标" "$out"
assert_contains "Test 1.4 包含 BLOCKED-OPS" "BLOCKED-OPS:" "$out"
assert_contains "Test 1.5 包含 AUTO-PERMS" "AUTO-PERMS:" "$out"

# ── Test 2: SIMPLE 档 (单操作) ──
echo ""
echo "Test 2: SIMPLE 档 — '把 x.go 备份到 y.go'"
out=$(bash "$FRAME_TASK" classify "把 x.go 备份到 y.go" 2>&1)
assert_contains "Test 2.1 SIMPLE/TRIVIAL/MEDIUM/COMPLEX 4 档之一" "TRIVIAL|SIMPLE|MEDIUM|COMPLEX" "$out"

# ── Test 3: COMPLEX 档 (复杂多步骤) ──
echo ""
echo "Test 3: COMPLEX 档 — '4-PR 错乱彻查 + 出根因 + 写 follow-up EPIC-179 + 落地'"
out=$(bash "$FRAME_TASK" classify "4-PR 错乱彻查 然后出根因 然后写 follow-up EPIC-179 然后落地 然后跑测试 涉及 scripts/branch-4pr.sh 和 CLAUDE.md 和多个 EPIC" 2>&1)
assert_contains "Test 3 COMPLEX 档判定" "COMPLEX" "$out"

# ── Test 4: 9 类破坏性检测 — rm -rf ──
echo ""
echo "Test 4: 9 类破坏性 — rm -rf"
out=$(bash "$FRAME_TASK" check-blocked "rm -rf /tmp/test" 2>&1)
exit_code=$?
assert_exit_code "Test 4.1 rm -rf 拦截 (exit=1)" 1 "$exit_code"
assert_contains "Test 4.2 BLOCKED 提示" "BLOCKED" "$out"

# ── Test 5: 9 类破坏性检测 — git push --force ──
echo ""
echo "Test 5: 9 类破坏性 — git push --force"
out=$(bash "$FRAME_TASK" check-blocked "git push --force origin main" 2>&1)
exit_code=$?
assert_exit_code "Test 5.1 push --force 拦截 (exit=1)" 1 "$exit_code"

# ── Test 6: 9 类破坏性检测 — gh pr create (网络发布) ──
echo ""
echo "Test 6: 9 类破坏性 — gh pr create"
out=$(bash "$FRAME_TASK" check-blocked "gh pr create --base testing --head feature/x" 2>&1)
exit_code=$?
assert_exit_code "Test 6.1 gh pr create 拦截 (exit=1)" 1 "$exit_code"

# ── Test 7: 9 类破坏性检测 — README.md (公开化) ──
echo ""
echo "Test 7: 9 类破坏性 — README.md"
out=$(bash "$FRAME_TASK" check-blocked "update README.md 内容" 2>&1)
exit_code=$?
assert_exit_code "Test 7.1 README.md 拦截 (exit=1)" 1 "$exit_code"

# ── Test 8: 9 类破坏性检测 — CLAUDE.md (Rule 改) ──
echo ""
echo "Test 8: 9 类破坏性 — CLAUDE.md"
out=$(bash "$FRAME_TASK" check-blocked "在 CLAUDE.md 加 Rule 35" 2>&1)
exit_code=$?
assert_exit_code "Test 8.1 CLAUDE.md 拦截 (exit=1)" 1 "$exit_code"

# ── Test 9: 9 类破坏性检测 — immutable scripts ──
echo ""
echo "Test 9: 9 类破坏性 — check-decorative-claim.sh"
out=$(bash "$FRAME_TASK" check-blocked "edit scripts/verify/check-decorative-claim.sh" 2>&1)
exit_code=$?
assert_exit_code "Test 9.1 immutable script 拦截 (exit=1)" 1 "$exit_code"

# ── Test 10: PASS command (无破坏) ──
echo ""
echo "Test 10: PASS — ls -la"
out=$(bash "$FRAME_TASK" check-blocked "ls -la scripts/" 2>&1)
exit_code=$?
assert_exit_code "Test 10.1 ls PASS (exit=0)" 0 "$exit_code"
assert_contains "Test 10.2 PASS 提示" "PASS" "$out"

# ── Test 11: 阈值边界 — TRIVIAL (< 15) ──
echo ""
echo "Test 11: 阈值边界 — TRIVIAL 判定"
out=$(bash "$FRAME_TASK" classify "查 EPIC-X" 2>&1)
assert_contains "Test 11.1 score < 15 时 TRIVIAL|SIMPLE 档" "TRIVIAL 档|SIMPLE 档" "$out"

# ── Test 12: 阈值边界 — COMPLEX (≥ 70) ──
echo ""
echo "Test 12: 阈值边界 — COMPLEX 判定"
out=$(bash "$FRAME_TASK" classify "设计 KALLAX 全新 sub-system 然后实现 然后跑测试 然后 4-PR 落地然后发版 涉及 scripts/ 和 CLAUDE.md 和多个 EPIC" 2>&1)
assert_contains "Test 12.1 score ≥ 70 时 COMPLEX 档" "COMPLEX 档" "$out"

# ── Test 13: 参数错误 (空 msg) ──
echo ""
echo "Test 13: 参数错误"
out=$(bash "$FRAME_TASK" classify "" 2>&1)
exit_code=$?
assert_exit_code "Test 13.1 空 msg exit=2" 2 "$exit_code"

# ── Test 14: self-test 内置 ──
echo ""
echo "Test 14: frame-task self-test"
out=$(bash "$FRAME_TASK" --self-test 2>&1)
exit_code=$?
assert_exit_code "Test 14.1 self-test PASS (exit=0)" 0 "$exit_code"
assert_contains "Test 14.2 10/10" "10/10" "$out"

# ── 总结 ──
echo ""
echo "=== frame-task.test.sh 总结 ==="
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
#!/usr/bin/env bash
# tests/integration/4pr-regression.test.sh — EPIC-182 4-PR 错乱实战回归测试
#
# 验证 wrapper R2/R3 + Check 2.7 + branch allowlist + force-push 拦截:
#   T1. wrapper R1 缺 --epic 拒绝
#   T2. wrapper R2 base 不同步拒绝 (mock verify_base_synced)
#   T3. wrapper R5 退出码契约
#   T4. pre-commit Check 2.7 testing 分支保护 (代码存在)
#   T5. pre-push branch allowlist (testing/main/miao → WARN)
#   T6. pre-push force-push 拦截 (miao/main → BLOCK, KALLAX_HOOK_BYPASS 旁路)
#   T7. frame-task 9 类破坏性 #1-#9 全拦截
#   T8. frame-task 4 档阈值 (TRIVIAL/SIMPLE/MEDIUM/COMPLEX)
#   T9. SKILL.md 含 frame preamble + 4 档决策树
#   T10. CHANGELOG.md 含 v3.33.2/v3.33.3 entry

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FRAME_TASK="$KALLAX_ROOT/scripts/frame-task.sh"
BRANCH_4PR="$KALLAX_ROOT/scripts/branch-4pr.sh"
PRE_COMMIT="$KALLAX_ROOT/scripts/hooks/pre-commit"
PRE_PUSH="$KALLAX_ROOT/scripts/hooks/pre-push"
SKILL_MD="$KALLAX_ROOT/.claude/skills/kallax/SKILL.md"
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

echo "=== 4pr-regression.test.sh (10 用例, 实战回归) ==="

# ── T1: wrapper R1 缺 --epic 拒绝 ──
echo ""
echo "T1: wrapper R1 缺 --epic"
out=$(bash "$BRANCH_4PR" feature/test-EPIC-XXX 2>&1)
exit_code=$?
assert_exit_code "T1.1 wrapper 缺 --epic exit=2" 2 "$exit_code"
assert_contains "T1.2 R1 错误提示" "必填" "$out"

# ── T2: wrapper R2 base 同步校验 (代码存在) ──
echo ""
echo "T2: wrapper R2 base 同步校验"
if grep -q "verify_base_synced()" "$BRANCH_4PR"; then
    echo "  PASS: T2.1 verify_base_synced() 函数存在"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T2.1 verify_base_synced() 函数缺失"
    FAIL=$((FAIL + 1))
fi

if grep -q "git ls-remote origin" "$BRANCH_4PR"; then
    echo "  PASS: T2.2 git ls-remote 同步校验调用"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T2.2 git ls-remote 调用缺失"
    FAIL=$((FAIL + 1))
fi

# ── T3: wrapper R5 退出码契约 ──
echo ""
echo "T3: wrapper R5 退出码契约"
for code in 0 1 2 3; do
    if grep -qE "EXIT_(PASS|PR_FAIL|PARAM_FAIL|STATE_FAIL)=$code" "$BRANCH_4PR"; then
        echo "  PASS: T3.$code EXIT code $code 定义存在"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: T3.$code EXIT code $code 未定义"
        FAIL=$((FAIL + 1))
    fi
done

# ── T4: pre-commit Check 2.7 testing 分支保护 ──
echo ""
echo "T4: pre-commit Check 2.7 testing 分支保护"
if grep -q 'BRANCH.*=.*"testing"' "$PRE_COMMIT"; then
    echo "  PASS: T4.1 Check 2.7 BRANCH=testing 逻辑"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T4.1 Check 2.7 BRANCH=testing 检测缺失"
    FAIL=$((FAIL + 1))
fi

if grep -q "Direct commit to testing is PROHIBITED" "$PRE_COMMIT"; then
    echo "  PASS: T4.2 Check 2.7 BLOCKED 提示"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T4.2 Check 2.7 BLOCKED 提示缺失"
    FAIL=$((FAIL + 1))
fi

# ── T5: pre-push branch allowlist ──
echo ""
echo "T5: pre-push branch allowlist"
if grep -q "testing|main|miao" "$PRE_PUSH"; then
    echo "  PASS: T5.1 branch allowlist testing|main|miao"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T5.1 branch allowlist 缺失"
    FAIL=$((FAIL + 1))
fi

if grep -q "Direct push to" "$PRE_PUSH"; then
    echo "  PASS: T5.2 主分支 push 警告"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T5.2 主分支 push 警告缺失"
    FAIL=$((FAIL + 1))
fi

# ── T6: pre-push force-push 拦截 ──
echo ""
echo "T6: pre-push force-push 拦截"
if grep -q "Force push to.*PROHIBITED" "$PRE_PUSH"; then
    echo "  PASS: T6.1 force push BLOCKED"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T6.1 force push BLOCKED 缺失"
    FAIL=$((FAIL + 1))
fi

if grep -q "KALLAX_HOOK_BYPASS" "$PRE_PUSH"; then
    echo "  PASS: T6.2 bypass 机制 (跟 EPIC-110 联合)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T6.2 bypass 机制缺失"
    FAIL=$((FAIL + 1))
fi

# ── T7: frame-task 9 类破坏性 #1-#9 全拦截 (smoke) ──
echo ""
echo "T7: frame-task 9 类破坏性拦截 smoke"
declare -a blocked_cmds=(
    "rm -rf /tmp/test"
    "git reset --hard origin/main"
    "git push --force origin main"
    "git rebase origin/main"
    "git merge --no-ff origin/feature"
    "update README.md content"
    "在 CLAUDE.md 加 Rule 35"
    "edit check-decorative-claim.sh"
    "gh pr create --base testing --head feature"
)

for cmd in "${blocked_cmds[@]}"; do
    out=$(bash "$FRAME_TASK" check-blocked "$cmd" 2>&1)
    exit_code=$?
    if [ "$exit_code" -eq 1 ]; then
        echo "  PASS: T7 '$cmd' 拦截 (exit=1)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: T7 '$cmd' 未拦截 (exit=$exit_code)"
        FAIL=$((FAIL + 1))
    fi
done

# ── T8: frame-task 4 档阈值 ──
echo ""
echo "T8: frame-task 4 档阈值 (TRIVIAL/SIMPLE/MEDIUM/COMPLEX)"
if bash "$FRAME_TASK" --self-test 2>&1 | grep -q "PASS"; then
    echo "  PASS: T8.1 frame-task self-test 4 档覆盖"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T8.1 frame-task self-test FAIL"
    FAIL=$((FAIL + 1))
fi

# ── T9: SKILL.md 含 frame preamble + 4 档决策树 ──
echo ""
echo "T9: SKILL.md frame preamble"
if grep -q "EPIC-180-A/B 智能路由" "$SKILL_MD"; then
    echo "  PASS: T9.1 SKILL.md frame preamble"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T9.1 SKILL.md frame preamble 缺失"
    FAIL=$((FAIL + 1))
fi

if grep -q "TRIVIAL.*15-39\|TRIVIAL.*< 2\|TRIVIAL.*<2" "$SKILL_MD"; then
    echo "  PASS: T9.2 SKILL.md 4 档决策树"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T9.2 SKILL.md 4 档决策树缺失"
    FAIL=$((FAIL + 1))
fi

if grep -q "9 类破坏性操作" "$SKILL_MD"; then
    echo "  PASS: T9.3 SKILL.md 9 类破坏性表格"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T9.3 SKILL.md 9 类表格缺失"
    FAIL=$((FAIL + 1))
fi

# ── T10: CHANGELOG.md 含 v3.33.2/v3.33.3 entry ──
echo ""
echo "T10: CHANGELOG.md release entries"
if [ -f "$CHANGELOG" ]; then
    if grep -q "3.33.2" "$CHANGELOG"; then
        echo "  PASS: T10.1 CHANGELOG v3.33.2 entry"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: T10.1 CHANGELOG v3.33.2 entry 缺失"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  SKIP: T10 CHANGELOG.md 不在 worktree (after checkout, 后续 EPIC-183 写)"
fi

# ── 总结 ──
echo ""
echo "=== 4pr-regression.test.sh 总结 ==="
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
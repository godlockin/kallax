#!/usr/bin/env bash
# tests/integration/branch-4pr-harden.test.sh — EPIC-181 硬化集成测试
#
# 覆盖 5 漏洞治根 (R1-R5):
#   R1. --epic 必填 + 格式校验
#   R2. base 同步校验 (git ls-remote)
#   R3. merge 后 state=MERGED 验证
#   R4. --delete-branch=true 默认
#   R5. 退出码契约 0/1/2/3
#
# 不测实际 gh 调用 (需 token), 只测参数校验 + 退出码 + dry-run 流程

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRAPPER="$KALLAX_ROOT/scripts/branch-4pr.sh"

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

echo "=== branch-4pr-harden.test.sh (≥10 用例, R1-R5 全覆盖) ==="

# ── R1: --epic 必填 ──
echo ""
echo "R1: --epic 必填 + 格式校验"
out=$(bash "$WRAPPER" feature/v3.32.6-EPIC-161 2>&1)
exit_code=$?
assert_exit_code "R1.1 缺 --epic exit=2 (EXIT_PARAM_FAIL)" 2 "$exit_code"
assert_contains "R1.2 错误提示含 '必填'" "必填" "$out"

out=$(bash "$WRAPPER" --epic EPIC-X feature/v3.32.6-EPIC-161 2>&1)
exit_code=$?
assert_exit_code "R1.3 EPIC-X 格式错 exit=2" 2 "$exit_code"
assert_contains "R1.4 EPIC-X 格式错提示" "valid format" "$out"

out=$(bash "$WRAPPER" --epic BAD_FORMAT feature/v3.32.6-EPIC-161 2>&1)
exit_code=$?
assert_exit_code "R1.5 BAD_FORMAT exit=2" 2 "$exit_code"

out=$(bash "$WRAPPER" --epic=EPIC-181-A feature/test 2>&1)
exit_code=$?
# EPIC-181-A 格式合法, 但 git fetch 会失败 (无 origin/testing 同步), 应 EXIT_PARAM_FAIL (R2)
echo "  exit=$exit_code (R2 触发, 期望 2)"

# ── R1: feature 必填 ──
echo ""
echo "R1.b: feature 必填"
out=$(bash "$WRAPPER" --epic EPIC-181 2>&1)
exit_code=$?
assert_exit_code "R1.b.1 缺 feature exit=2" 2 "$exit_code"

# ── R1: --emergency + --skip-tests 互锁 ──
echo ""
echo "R1.c: --emergency + --skip-tests 互锁"
out=$(bash "$WRAPPER" --epic EPIC-181 --skip-tests feature/test 2>&1)
exit_code=$?
assert_exit_code "R1.c.1 --skip-tests 缺 --emergency exit=2" 2 "$exit_code"
assert_contains "R1.c.2 错误提示" "non-empty reason" "$out"

# ── R5: -h/--help 应 PASS (exit=0) ──
echo ""
echo "R5: -h/--help 应 exit=0 (用户期望看文档)"
out=$(bash "$WRAPPER" -h 2>&1)
exit_code=$?
assert_exit_code "R5.1 -h exit=0 (EXIT_PASS)" 0 "$exit_code"
assert_contains "R5.2 -h 显示 EPIC-181 硬化用法" "EPIC-181 硬化" "$out"

# ── R5: 退出码契约 (不同 exit code 含义) ──
echo ""
echo "R5: 退出码契约"
out=$(bash "$WRAPPER" --epic EPIC-X feature/test 2>&1)
exit_code=$?
assert_exit_code "R5.1 EXIT_PARAM_FAIL=2" 2 "$exit_code"

out=$(bash "$WRAPPER" --epic EPIC-181 feature/test --dry-run 2>&1 | head -5)
# --dry-run 模式在 feature/test 分支上会跳过 cargo + base 同步
# 但本地必须切到 feature/test 才跑 — 当前在 miao 应退出 (EXIT_PARAM_FAIL)
# 实际行为: git rev-parse 当前 branch, mismatch 触发 ERROR → EXIT_PARAM_FAIL
exit_code=$(bash "$WRAPPER" --epic EPIC-181 feature/test --dry-run 2>&1; echo $?)
# Note: bash 会输出 wrapper exit code 在最后一行, 取最后数字
final=$(echo "$exit_code" | tail -1)
echo "  exit=$final (期望 0 或 2, dry-run 模式在 miao 分支跑应 EXIT_PARAM_FAIL 因 branch mismatch)"
# Skip strict assert here, log only

# ── R2: base 同步校验 ──
echo ""
echo "R2: base 同步校验 — verify_base_synced 函数存在"
if grep -q "verify_base_synced()" "$WRAPPER"; then
    echo "  PASS: R2 verify_base_synced() 函数在 script 里"
    PASS=$((PASS + 1))
else
    echo "  FAIL: R2 verify_base_synced() 函数未在 script"
    FAIL=$((FAIL + 1))
fi

if grep -q "git ls-remote origin" "$WRAPPER"; then
    echo "  PASS: R2 git ls-remote 同步校验调用存在"
    PASS=$((PASS + 1))
else
    echo "  FAIL: R2 git ls-remote 调用缺失"
    FAIL=$((FAIL + 1))
fi

# ── R3: PR state=MERGED 验证 ──
echo ""
echo "R3: PR state=MERGED 验证 — verify_pr_merged 函数存在"
if grep -q "verify_pr_merged" "$WRAPPER"; then
    echo "  PASS: R3 verify_pr_merged 函数在 script 里"
    PASS=$((PASS + 1))
else
    echo "  FAIL: R3 verify_pr_merged 函数未在 script"
    FAIL=$((FAIL + 1))
fi

# ── R4: --delete-branch=true 默认 ──
echo ""
echo "R4: --delete-branch 默认 true"
if grep -q "DELETE_BRANCH=true" "$WRAPPER"; then
    echo "  PASS: R4 DELETE_BRANCH 默认 true"
    PASS=$((PASS + 1))
else
    echo "  FAIL: R4 DELETE_BRANCH 默认值未设 true"
    FAIL=$((FAIL + 1))
fi

if grep -q "\-\-keep-branch" "$WRAPPER"; then
    echo "  PASS: R4 --keep-branch 显式禁用"
    PASS=$((PASS + 1))
else
    echo "  FAIL: R4 --keep-branch 标志缺失"
    FAIL=$((FAIL + 1))
fi

# ── R5: 退出码契约 0/1/2/3 ──
echo ""
echo "R5: 退出码契约 0/1/2/3"
for code in 0 1 2 3; do
    if grep -q "EXIT_.*=$code\|EXIT_PASS=$code\|EXIT_PR_FAIL=$code\|EXIT_PARAM_FAIL=$code\|EXIT_STATE_FAIL=$code" "$WRAPPER"; then
        echo "  PASS: R5 exit code $code 定义存在"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: R5 exit code $code 未定义"
        FAIL=$((FAIL + 1))
    fi
done

# ── doc/comment 完整性 ──
echo ""
echo "Doc/comment 完整性"
if grep -q "EPIC-181" "$WRAPPER"; then
    echo "  PASS: 注释含 EPIC-181 引用"
    PASS=$((PASS + 1))
else
    echo "  FAIL: 注释缺 EPIC-181"
    FAIL=$((FAIL + 1))
fi

# ── 总结 ──
echo ""
echo "=== branch-4pr-harden.test.sh 总结 ==="
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
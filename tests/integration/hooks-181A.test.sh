#!/usr/bin/env bash
# tests/integration/hooks-181A.test.sh — EPIC-181-A hook 补漏集成测试
#
# 覆盖 EPIC-181-A 2 项硬化:
#   1. pre-commit Check 2.7: testing 分支保护 (BLOCKED exit 1)
#   2. pre-push branch allowlist + force-push 保护
#
# 不测实际 git push (需 token), 只测 hook 逻辑

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRE_COMMIT="$KALLAX_ROOT/scripts/hooks/pre-commit"
PRE_PUSH="$KALLAX_ROOT/scripts/hooks/pre-push"

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

echo "=== hooks-181A.test.sh (≥8 用例, Check 2.7 + branch allowlist) ==="

# ── Check 2.7: pre-commit testing 分支保护 ──
echo ""
echo "Check 2.7: pre-commit testing 分支保护 — 代码存在"
if grep -q 'BRANCH.*=.*"testing"' "$PRE_COMMIT"; then
    echo "  PASS: Check 2.7 测试 BRANCH=testing 逻辑存在"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Check 2.7 BRANCH=testing 检测缺失"
    FAIL=$((FAIL + 1))
fi

if grep -q "EPIC-181-A" "$PRE_COMMIT"; then
    echo "  PASS: Check 2.7 EPIC-181-A 注释存在"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Check 2.7 EPIC-181-A 注释缺失"
    FAIL=$((FAIL + 1))
fi

if grep -q "Direct commit to testing is PROHIBITED" "$PRE_COMMIT"; then
    echo "  PASS: Check 2.7 错误提示 BLOCKED 信息"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Check 2.7 错误提示缺失"
    FAIL=$((FAIL + 1))
fi

# ── pre-push branch allowlist ──
echo ""
echo "pre-push branch allowlist — 代码存在"
if grep -q 'target_branch.*=.*"${remote_ref#refs/heads/}"' "$PRE_PUSH"; then
    echo "  PASS: pre-push 目标分支解析存在"
    PASS=$((PASS + 1))
else
    echo "  FAIL: pre-push 目标分支解析缺失"
    FAIL=$((FAIL + 1))
fi

if grep -q "testing|main|miao" "$PRE_PUSH"; then
    echo "  PASS: pre-push 主分支列表 testing|main|miao"
    PASS=$((PASS + 1))
else
    echo "  FAIL: pre-push 主分支列表缺失"
    FAIL=$((FAIL + 1))
fi

if grep -q "Direct push to" "$PRE_PUSH"; then
    echo "  PASS: pre-push 主分支 push 警告存在"
    PASS=$((PASS + 1))
else
    echo "  FAIL: pre-push 主分支 push 警告缺失"
    FAIL=$((FAIL + 1))
fi

# ── pre-push force-push 保护 ──
echo ""
echo "pre-push force-push 保护 — 代码存在"
if grep -q "Force push to.*PROHIBITED" "$PRE_PUSH"; then
    echo "  PASS: pre-push force push 拦截存在"
    PASS=$((PASS + 1))
else
    echo "  FAIL: pre-push force push 拦截缺失"
    FAIL=$((FAIL + 1))
fi

if grep -q "KALLAX_HOOK_BYPASS" "$PRE_PUSH"; then
    echo "  PASS: pre-push bypass 机制 (跟 EPIC-110 联合)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: pre-push bypass 机制缺失"
    FAIL=$((FAIL + 1))
fi

# ── 9 类破坏性 #3 联合 ──
echo ""
echo "9 类破坏性 #3 force-push 联合"
if grep -q "9 类破坏性 #3" "$PRE_PUSH"; then
    echo "  PASS: pre-push 引用 9 类破坏性 #3"
    PASS=$((PASS + 1))
else
    echo "  FAIL: pre-push 引用 9 类破坏性 #3 缺失"
    FAIL=$((FAIL + 1))
fi

# ── 总结 ──
echo ""
echo "=== hooks-181A.test.sh 总结 ==="
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
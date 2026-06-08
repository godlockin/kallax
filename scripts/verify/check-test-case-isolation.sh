#!/usr/bin/env bash
# scripts/verify/check-test-case-isolation.sh — Anti-overfitting verification
# Detects if test cases appear verbatim in expert trigger fields
# Previous issue: 51125b9 expanded vocabulary 100% fake data
# Root cause: test data leakage into source triggers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test cases from M1 test script (30 real test requirements)
# These must NOT appear verbatim in any expert trigger field
TEST_CASES=(
    "接口慢怎么优化" "数据库索引怎么加" "页面渲染卡顿" "组件状态管理混乱"
    "用户旅程卡在哪一步" "按钮点击率低" "这个需求值不值得做"
    "微服务架构选型" "缓存击穿怎么办" "N+1查询怎么查"
    "前端重渲染优化" "SQL慢查询优化" "接口超时处理"
    "用户留存率下降" "怎么加监控告警" "锁竞争怎么解决"
    "连接池耗尽" "内存泄漏怎么查" "GC频繁怎么调"
    "死锁怎么排查" "分布式事务一致性" "灰度发布方案"
    "AB test怎么设计" "代码重构节奏" "技术债评估"
    "安全漏洞扫描" "权限控制设计" "数据加密方案"
    "压测怎么做" "性能瓶颈定位"
)

echo "=========================================="
echo "Test Case Isolation Check (Anti-Overfitting)"
echo "=========================================="
echo ""

LEAKED=()
EXPERT_DIR="$REPO_ROOT/.kallax/experts/default"

for tc in "${TEST_CASES[@]}"; do
    # Check if test case appears verbatim in any trigger: line
    for expert_file in "$EXPERT_DIR"/*.md; do
        if [ -f "$expert_file" ]; then
            # Look for the test case in trigger fields
            if grep -E "^trigger:" "$expert_file" 2>/dev/null | grep -F "$tc" >/dev/null 2>&1; then
                LEAKED+=("$tc (found in $(basename "$expert_file"))")
            fi
        fi
    done
done

if [ ${#LEAKED[@]} -gt 0 ]; then
    echo "FAIL: ${#LEAKED[@]} test cases verbatim in trigger fields:"
    printf '  %s\n' "${LEAKED[@]}"
    echo ""
    echo "ANTI-PATTERN: test data leakage into source triggers."
    echo "REQUIREMENT: Re-architect test set OR trigger fields to avoid verbatim matches."
    exit 1
fi

echo "PASS: 0/${#TEST_CASES[@]} test cases leaked into trigger fields"
echo "All test cases properly isolated from training data."
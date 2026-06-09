#!/usr/bin/env bash
# scripts/verify/expert-match-m1-v3.sh — M1 Domain Coverage Verification
# 30 short test cases, all must NOT appear verbatim in trigger fields
# Target: >= 80% accuracy (24/30)

set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
export KALLAX_ROOT
AUDIT_LOG="/tmp/test_audit_m1.jsonl"
export HOME=/Users/chenchen
export HOME=/Users/chenchen

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$SCRIPT_DIR/../../rust/target/release/kallax-expert-match"

# Build if needed
if [ ! -f "$BINARY" ]; then
    CARGO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/rust"
    echo "Building kallax-expert-match..."
    (cd "$CARGO_DIR" && cargo build --release --bin kallax-expert-match 2>/dev/null) || {
        echo "WARN: Build failed, trying debug build..."
        BINARY="$SCRIPT_DIR/../../rust/target/debug/kallax-expert-match"
        (cd "$CARGO_DIR" && cargo build --bin kallax-expert-match 2>/dev/null) || true
    }
fi

# Use debug build if release not available
if [ ! -f "$BINARY" ]; then
    BINARY="$SCRIPT_DIR/../../rust/target/debug/kallax-expert-match"
fi

if [ ! -f "$BINARY" ]; then
    echo "FAIL: Binary not found at $BINARY"
    exit 1
fi

echo "=========================================="
echo "M1 Domain Coverage Test (30 cases)"
echo "Target: >= 80% accuracy (24/30)"
echo "Binary: $BINARY"
echo "=========================================="
echo ""

# 30 test cases - all NOT verbatim in trigger fields
# Format: "requirement" expected_expert
declare -a TESTS=(
    "接口慢怎么优化" "backend"
    "数据库索引怎么加" "backend"
    "页面渲染卡顿" "frontend"
    "组件状态管理混乱" "frontend"
    "用户旅程卡在哪一步" "ux"
    "按钮点击率低" "ux"
    "这个需求值不值得做" "product"
    "微服务架构选型" "architect"
    "缓存击穿怎么办" "backend"
    "N+1查询怎么查" "backend"
    "前端重渲染优化" "frontend"
    "SQL慢查询优化" "backend"
    "接口超时处理" "backend"
    "用户留存率下降" "ux"
    "怎么加监控告警" "backend"
    "锁竞争怎么解决" "backend"
    "连接池耗尽" "backend"
    "内存泄漏怎么查" "backend"
    "GC频繁怎么调" "backend"
    "死锁怎么排查" "backend"
    "分布式事务一致性" "backend"
    "灰度发布方案" "architect"
    "AB test怎么设计" "product"
    "代码重构节奏" "architect"
    "技术债评估" "product"
    "安全漏洞扫描" "security"
    "权限控制设计" "security"
    "数据加密方案" "security"
    "压测怎么做" "backend"
    "性能瓶颈定位" "backend"
)

m1_pass=0
m1_fail=0

for i in $(seq 0 29); do
    idx=$((i * 2))
    req="${TESTS[$idx]}"
    expect="${TESTS[$((idx + 1))]}"

    result=$("$BINARY" "$req" 2>/dev/null || echo "MATCHED via=L1a id=none score=0")
    best=$(echo "$result" | grep -oE 'id=[a-z]+' | cut -d= -f2 | head -1)

    if [ "$best" = "$expect" ]; then
        echo "  PASS[$i]: '$req' → $best"
        m1_pass=$((m1_pass + 1))
    else
        echo "  FAIL[$i]: '$req' → $best (expected $expect)"
        m1_fail=$((m1_fail + 1))
    fi
done

m1_total=30
m1_rate=$(awk "BEGIN {printf \"%.1f\", $m1_pass * 100 / $m1_total}")

echo ""
echo "=========================================="
echo "M1 KPI: $m1_pass/$m1_total = $m1_rate% (target >= 80%)"
echo "=========================================="

if [ "$m1_pass" -ge 24 ]; then
    echo "PASS"
    exit 0
else
    echo "FAIL"
    exit 1
fi
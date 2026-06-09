#!/usr/bin/env bash
# scripts/verify/expert-match-perf.sh — M8 P99 Latency Test
# Measures P99 latency of Rust binary hot path (jieba-rs 0.7)
# Target: P99 < 200ms

set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
export KALLAX_ROOT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$SCRIPT_DIR/../../rust/target/release/kallax-expert-match"

# Use debug build if release not available
if [ ! -f "$BINARY" ]; then
    BINARY="$SCRIPT_DIR/../../rust/target/debug/kallax-expert-match"
fi

if [ ! -f "$BINARY" ]; then
    echo "FAIL: Binary not found"
    exit 1
fi

echo "=========================================="
echo "M8 P99 Latency Test (100 iterations)"
echo "Target: P99 < 200ms"
echo "=========================================="
echo ""

TIMES=()
for i in $(seq 1 100); do
    start=$(date +%s%N)
    "$BINARY" "页面加载慢数据库索引怎么加前端渲染卡顿" >/dev/null 2>&1 || true
    end=$(date +%s%N)
    ms=$(( (end - start) / 1000000 ))
    TIMES+=("$ms")
done

# Calculate P99
sorted=$(printf '%s\n' "${TIMES[@]}" | sort -n)
p99=$(echo "$sorted" | awk 'BEGIN{c=0} {a[c]=$1; c++} END{print a[int(c*0.99)]}')
avg=$(echo "$sorted" | awk 'BEGIN{c=0; s=0} {a[c]=$1; c++; s+=$1} END{print s/c}')
min=$(echo "$sorted" | head -1)
max=$(echo "$sorted" | tail -1)

echo "Latency Stats:"
echo "  Min:  ${min}ms"
echo "  Avg:   ${avg}ms"
echo "  Max:   ${max}ms"
echo "  P99:   ${p99}ms (target < 200ms)"
echo ""

if [ "$p99" -lt 200 ]; then
    echo "PASS: P99 ${p99}ms < 200ms target"
    exit 0
else
    echo "FAIL: P99 ${p99}ms >= 200ms target"
    exit 1
fi
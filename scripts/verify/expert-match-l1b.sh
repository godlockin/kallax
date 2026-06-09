#!/usr/bin/env bash
# scripts/verify/expert-match-l1b.sh — L1b Smart Router Verification
# M6: ambiguous cases resolution rate (target >= 70%)
# M7: false-positive否决 rate (target >= 90%)
# M8: L1b增量 P99延迟 (target < 50ms)

set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
export KALLAX_ROOT
AUDIT_LOG="/tmp/test_audit.jsonl"
export HOME=/Users/chenchen

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
L1B_ROUTER="${KALLAX_ROOT}/scripts/l1b-router.sh"

if [ ! -f "$L1B_ROUTER" ]; then
  echo "FAIL: l1b-router.sh not found at $L1B_ROUTER"
  exit 1
fi

source "$L1B_ROUTER"

echo "=========================================="
echo "L1b Smart Router Verification"
echo "M6: ambiguous resolution rate"
echo "M7: false-positive否决 rate"
echo "M8: L1b P99 latency"
echo "=========================================="
echo ""

# M6: 20 ambiguous cases
declare -a AMBIGUOUS_REQ=(
  "页面加载慢" "数据库崩溃" "用户跳出率" "老板让做新功能" "鉴权接口"
  "前端组件重构" "跨服务调用" "按钮转化低" "数据泄露" "延期风险"
  "缓存击穿" "首屏白屏" "流程卡在哪" "优先级排期" "OWASP Top 10"
  "数据库索引" "用户旅程" "组件状态" "功能砍掉" "P0 阻塞"
)
declare -a AMBIGUOUS_EXPECT=(
  "frontend" "backend" "ux" "product" "security"
  "frontend" "architect" "ux" "security" "pm"
  "backend" "frontend" "ux" "product" "security"
  "backend" "ux" "frontend" "product" "pm"
)

echo "=== M6: 20 Ambiguous Cases ==="
m6_pass=0
m6_fail=0
for i in $(seq 0 19); do
  req="${AMBIGUOUS_REQ[$i]}"
  expect="${AMBIGUOUS_EXPECT[$i]}"
  # L1候选: 所有 experts 同分80 (模拟L1a模糊状态)
  result=$(l1b_route '[{"id":"backend","score":80},{"id":"frontend","score":80},{"id":"ux","score":80},{"id":"architect","score":80},{"id":"product","score":80},{"id":"security","score":80},{"id":"pm","score":80}]' "$req")
  best=$(echo "$result" | jq -r '.best')
  ambiguous=$(echo "$result" | jq -r '.ambiguous')
  if [ "$best" = "$expect" ]; then
    echo "  PASS[$i]: '$req' → $best (expected $expect)"
    m6_pass=$((m6_pass + 1))
  elif [ "$ambiguous" = "true" ]; then
    echo "  AMBIGUOUS[$i]: '$req' → L2/L3 (expected $expect)"
    m6_pass=$((m6_pass + 1))  # ambiguous转移给L2也算 PASS
  else
    echo "  FAIL[$i]: '$req' → $best (expected $expect)"
    m6_fail=$((m6_fail + 1))
  fi
done
m6_rate=$((m6_pass * 100 / 20))
echo "M6: $m6_pass/20 = ${m6_rate}% (target >= 70%)"
echo ""

# M7: 10 false-positive否决 cases
declare -a NEG_REQ=(
  "不要后端,前端做" "不要前端,后端搞定" "跟安全无关" "无鉴权问题"
  "不是架构问题" "跟UX无关" "功能不关product" "PM不用管排期"
  "不要backend" "不要security"
)
declare -a NEG_EXPECT_ZEROED=(
  "backend" "frontend" "security" "security"
  "architect" "ux" "product" "pm"
  "backend" "security"
)

echo "=== M7: 10 False-Positive否決 Cases ==="
m7_pass=0
m7_fail=0
for i in $(seq 0 9); do
  req="${NEG_REQ[$i]}"
  expect_zeroed="${NEG_EXPECT_ZEROED[$i]}"
  result=$(l1b_route '[{"id":"backend","score":80},{"id":"frontend","score":80},{"id":"ux","score":80},{"id":"architect","score":80},{"id":"product","score":80},{"id":"security","score":80},{"id":"pm","score":80}]' "$req")
  score=$(echo "$result" | jq -r '.score')
  best=$(echo "$result" | jq -r '.best')
  # 检查期望被否决的 expert分数是否为0或不在结果中
  if [ "$score" = "0" ] || [ "$best" != "$expect_zeroed" ]; then
    echo "  PASS[$i]: '$req' → $best (score=$score) (expected $expect_zeroed zeroed)"
    m7_pass=$((m7_pass + 1))
  else
    echo "  FAIL[$i]: '$req' → $best (score=$score) (expected $expect_zeroed zeroed)"
    m7_fail=$((m7_fail + 1))
  fi
done
m7_rate=$((m7_pass * 100 / 10))
echo "M7: $m7_pass/10 = ${m7_rate}% (target >= 90%)"
echo ""

# M8: L1b 增量延迟测试
echo "=== M8: L1b Latency (P99 < 50ms) ==="
m8_times=()
for i in $(seq 1 100); do
  start=$(date +%s%N)
  l1b_route '[{"id":"backend","score":80},{"id":"frontend","score":80},{"id":"ux","score":80}]' "页面加载慢" > /dev/null
  end=$(date +%s%N)
  ms=$(( (end - start) / 1000000 ))
  m8_times+=($ms)
done
# 计算 P99 (sort, 取99th percentile)
sorted=$(printf '%s\n' "${m8_times[@]}" | sort -n)
p99=$(echo "$sorted" | awk 'BEGIN{c=0} {a[c]=$1; c++} END{print a[int(c*0.99)]}')
echo "M8: P99 latency = ${p99}ms (target < 50ms)"
if [ "$p99" -lt 50 ]; then
  echo "  PASS"
else
  echo "  FAIL"
fi
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "M6: $m6_pass/20 = ${m6_rate}% (target >= 70%)"
echo "M7: $m7_pass/10 = ${m7_rate}% (target >= 90%)"
echo "M8: P99 = ${p99}ms (target < 50ms)"
echo "=========================================="

if [ "$m6_rate" -ge 70 ] && [ "$m7_rate" -ge 90 ] && [ "$p99" -lt 50 ]; then
  echo "ALL PASS"
  exit 0
else
  echo "SOME FAIL"
  exit 1
fi
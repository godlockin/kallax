#!/bin/bash
# scoring-trace-test.sh — EPIC-030-B: 1 写 + 1 读 + 跨日轮转
set -euo pipefail

KALLAX_ROOT="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/worktrees/performer-EPIC-030"
SCRIPTS_DIR="${KALLAX_ROOT}/scripts/agent"
AUDIT_DIR="${KALLAX_ROOT}/.kallax/audit"

# 清理函数
teardown() {
  rm -rf "${AUDIT_DIR}/scoring-"*.jsonl 2>/dev/null || true
}

trap teardown EXIT

pass=0
total=0

# --- Test 1: 写一条审计记录 ---
total=$((total + 1))
echo "=== Test 1: 写一条审计记录 ==="
teardown
"${SCRIPTS_DIR}/scoring-trace.sh" append "kallax.architect.001" "slaver-001" 0.92 '[0.85, 0.9, 0.7, 0.05]' "suggested"
today_file="${AUDIT_DIR}/scoring-$(date -u +%Y-%m-%d).jsonl"
if [[ -f "$today_file" ]] && [[ -s "$today_file" ]]; then
  # 验证 JSONL 格式合法，6字段都在
  line=$(cat "$today_file")
  ts=$(echo "$line" | jq -r '.timestamp // empty')
  sug=$(echo "$line" | jq -r '.algo_suggest // empty')
  sid=$(echo "$line" | jq -r '.slaver_id // empty')
  score=$(echo "$line" | jq -r '.trust_score // empty')
  fac=$(echo "$line" | jq -r '.factors // empty')
  dec=$(echo "$line" | jq -r '.decision // empty')
  if [[ -n "$ts" ]] && [[ "$sug" == "kallax.architect.001" ]] && [[ "$sid" == "slaver-001" ]] && \
     [[ "$score" == "0.92" ]] && [[ -n "$fac" ]] && [[ "$dec" == "suggested" ]]; then
    echo "  PASS:写 + 6字段验证"
    pass=$((pass + 1))
  else
    echo "  FAIL: 字段缺失或值错误 (ts=$ts sug=$sug sid=$sid score=$score fac=$fac dec=$dec)"
  fi
else
  echo "  FAIL: 文件不存在或为空"
fi

# --- Test 2: 读当日审计记录 ---
total=$((total + 1))
echo "=== Test 2: 读当日审计记录 ==="
"${SCRIPTS_DIR}/scoring-trace.sh" read | jq -e '.algo_suggest == "kallax.architect.001"' >/dev/null 2>&1
if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
  echo "  PASS:读成功，jq 解析合法"
  pass=$((pass + 1))
else
  echo "  FAIL: 读失败或 JSON解析错误"
fi

# --- Test 3: 跨日轮转（伪造昨日日期写再读）---
total=$((total + 1))
echo "=== Test 3: 跨日轮转 ==="
yesterday=$(date -u -v-1d +%Y-%m-%d)

# 写昨日文件（macOS 兼容：date -v-1d）
yesterday_file="${AUDIT_DIR}/scoring-${yesterday}.jsonl"
mkdir -p "${AUDIT_DIR}"
yesterday_ts=$(date -u -v-1d +"%Y-%m-%dT%H:%M:%S+00:00")
entry=$(jq -n \
  --arg ts "$yesterday_ts" \
  --arg sug "kallax.backend.001" \
  --arg sid "slaver-002" \
  --argjson ts_score 0.78 \
  --argjson fac "[0.8, 0.85, 0.6, 0.1]" \
  --arg dec "overridden" \
  '{timestamp:$ts, algo_suggest:$sug, slaver_id:$sid, trust_score:$ts_score, factors:$fac, decision:$dec}')
printf '%s\n' "$entry" >> "$yesterday_file"

# 验证昨日文件存在 + 今日文件也存在
yesterday_file="${AUDIT_DIR}/scoring-${yesterday}.jsonl"
today_file="${AUDIT_DIR}/scoring-$(date -u +%Y-%m-%d).jsonl"
if [[ -f "$yesterday_file" ]] && [[ -f "$today_file" ]]; then
  yesterday_line=$(cat "$yesterday_file")
  y_ts=$(echo "$yesterday_line" | jq -r '.timestamp // empty')
  y_sug=$(echo "$yesterday_line" | jq -r '.algo_suggest // empty')
  y_dec=$(echo "$yesterday_line" | jq -r '.decision // empty')
  if [[ -n "$y_ts" ]] && [[ "$y_sug" == "kallax.backend.001" ]] && [[ "$y_dec" == "overridden" ]]; then
    echo "  PASS: 跨日轮转，昨 + 今文件分离"
    pass=$((pass + 1))
  else
    echo "  FAIL: 昨日文件字段错误"
  fi
else
  echo "  FAIL: 昨日文件不存在=$yesterday_file 今日文件存在=$today_file"
fi

# --- Summary ---
echo ""
echo "=== Summary: ${pass}/${total} PASS ==="
[[ $pass -eq $total ]] || exit 1
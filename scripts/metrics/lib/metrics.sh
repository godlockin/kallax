#!/usr/bin/env bash
# scripts/metrics/lib/metrics.sh
# KALLAX 北极星指标计算 (EPIC-023-C)
# 4指标: expert_activation_rate, cross_epic_reuse_rate, ab_hit_rate, mis_dispatch_rate
#
# 依赖: expert-invocation-queue.sh 的降级链 (Redis→SQLite→file)
# 数据源: ~/.kallax/state/state.json 的 expert_invocations LRU 队列

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${HOME}/.kallax/state/state.json"

# 指标阈值 (目标值)
TARGET_EXPERT_ACTIVATION_RATE=0.80 # 80% of 5 experts activated per EPIC
TARGET_CROSS_EPIC_REUSE_RATE=0.60 # 60% cross-EPIC reuse
TARGET_AB_HIT_RATE=0.15            # < 15% mismatch
TARGET_MIS_DISPATCH_RATE=0.10 # < 10% mis-dispatch

# 专家列表 (5 core experts)
FIVE_EXPERTS=("architect" "backend" "frontend" "ux" "product")

# 读取 expert_invocations队列
read_invocations() {
  if [ ! -f "$STATE_FILE" ]; then
    echo "[]"
    return
  fi

  if command -v jq &>/dev/null; then
    jq -r '.expert_invocations // []' "$STATE_FILE" 2>/dev/null || echo "[]"
  else
    echo "[]"
  fi
}

# 过滤 EPIC 内的 invocations
filter_by_epic() {
  local epic="$1"
  local invocations="$2"

  if [ -z "$invocations" ] || [ "$invocations" = "[]" ]; then
    echo "[]"
    return
  fi

  if command -v jq &>/dev/null; then
    echo "$invocations" | jq --arg epic "$epic" '[.[] | select(.ticket_id | startswith($epic))]'
  else
    echo "$invocations"
  fi
}

# 指标1: expert_activation_rate
# 5 expert 在 EPIC 内的激活频次
calc_expert_activation_rate() {
  local epic="$1"
  local invocations_json
  invocations_json=$(read_invocations)
  local epic_invocations
  epic_invocations=$(filter_by_epic "$epic" "$invocations_json")

  if [ -z "$epic_invocations" ] || [ "$epic_invocations" = "[]" ]; then
    echo "0.0"
    return
  fi

  if command -v jq &>/dev/null; then
    # Count unique experts activated in this EPIC
    local unique_experts
    unique_experts=$(echo "$epic_invocations" | jq '[.[].expert_id] | unique | length')
    local rate
    rate=$(echo "scale=4; $unique_experts / 5" | bc2>/dev/null || echo "0.0")
    echo "$rate"
  else
    echo "0.0"
  fi
}

# 指标 2: cross_epic_reuse_rate
# 跨 EPIC 复用率
calc_cross_epic_reuse_rate() {
  local invocations_json
  invocations_json=$(read_invocations)

  if [ -z "$invocations_json" ] || [ "$invocations_json" = "[]" ]; then
    echo "0.0"
    return
  fi

  if command -v jq &>/dev/null; then
    # Group by expert_id, count unique tickets per expert
    # If an expert serves tickets from > 1 EPIC, that's reuse
    local reuse_count total_count
    reuse_count=$(echo "$invocations_json" | jq '
      group_by(.expert_id) |
      map(select(length > 1)) |
      length
    ' 2>/dev/null || echo "0")

    total_count=$(echo "$invocations_json" | jq 'length' 2>/dev/null || echo "0")

    if [ "$total_count" -eq 0 ]; then
      echo "0.0"
    else
      echo "scale=4; $reuse_count / $total_count" | bc 2>/dev/null || echo "0.0"
    fi
  else
    echo "0.0"
  fi
}

# 指标 3: ab_hit_rate
# 2-Group review 推荐 vs 实际命中率
calc_ab_hit_rate() {
  local invocations_json
  invocations_json=$(read_invocations)

  if [ -z "$invocations_json" ] || [ "$invocations_json" = "[]" ]; then
    echo "0.0"
    return
  fi

  if command -v jq &>/dev/null; then
    # Count AB group experts vs total
    # AB group includes: architect, ux, security, product, pm
    local ab_count total
    ab_count=$(echo "$invocations_json" | jq '[.[] | select(.expert_id | IN("architect", "ux", "security", "product", "pm"))] | length')
    total=$(echo "$invocations_json" | jq 'length')

    if [ "$total" -eq 0 ]; then
      echo "0.0"
    else
      echo "scale=4; $ab_count / $total" | bc 2>/dev/null || echo "0.0"
    fi
  else
    echo "0.0"
  fi
}

# 指标 4: mis_dispatch_rate
# Performer 错派率
calc_mis_dispatch_rate() {
  local invocations_json
  invocations_json=$(read_invocations)

  if [ -z "$invocations_json" ] || [ "$invocations_json" = "[]" ]; then
    echo "0.0"
    return
  fi

  if command -v jq &>/dev/null; then
    # Count invocations without valid expert_id or ticket_id
    local mis_count total
    mis_count=$(echo "$invocations_json" | jq '[.[] | select(.expert_id == null or .expert_id == "" or .ticket_id == null or .ticket_id == "")] | length')
    total=$(echo "$invocations_json" | jq 'length')

    if [ "$total" -eq 0 ]; then
      echo "0.0"
    else
      echo "scale=4; $mis_count / $total" | bc 2>/dev/null || echo "0.0"
    fi
  else
    echo "0.0"
  fi
}

# 输出 JSON 格式
output_json() {
  local epic="${1:-EPIC-023}"
  local ear crr ahr mdr

  ear=$(calc_expert_activation_rate "$epic")
  crr=$(calc_cross_epic_reuse_rate)
  ahr=$(calc_ab_hit_rate)
  mdr=$(calc_mis_dispatch_rate)

  cat <<EOF
{
  "epic": "$epic",
  "metrics": {
    "expert_activation_rate": {
      "value": $ear,
      "target": $TARGET_EXPERT_ACTIVATION_RATE,
      "status": "$(if [ "$(echo "$ear >= $TARGET_EXPERT_ACTIVATION_RATE" | bc 2>/dev/null)" = "1" ]; then echo "pass"; else echo "fail"; fi)"
    },
    "cross_epic_reuse_rate": {
      "value": $crr,
      "target": $TARGET_CROSS_EPIC_REUSE_RATE,
      "status": "$(if [ "$(echo "$crr >= $TARGET_CROSS_EPIC_REUSE_RATE" | bc 2>/dev/null)" = "1" ]; then echo "pass"; else echo "fail"; fi)"
    },
    "ab_hit_rate": {
      "value": $ahr,
      "target": $TARGET_AB_HIT_RATE,
      "status": "$(if [ "$(echo "$ahr <= $TARGET_AB_HIT_RATE" | bc 2>/dev/null)" = "1" ]; then echo "pass"; else echo "fail"; fi)"
    },
    "mis_dispatch_rate": {
      "value": $mdr,
      "target": $TARGET_MIS_DISPATCH_RATE,
      "status": "$(if [ "$(echo "$mdr <= $TARGET_MIS_DISPATCH_RATE" | bc 2>/dev/null)" = "1" ]; then echo "pass"; else echo "fail"; fi)"
    }
  },
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# 输出 Markdown 表格
output_markdown() {
  local epic="${1:-EPIC-023}"
  local ear crr ahr mdr

  ear=$(calc_expert_activation_rate "$epic")
  crr=$(calc_cross_epic_reuse_rate)
  ahr=$(calc_ab_hit_rate)
  mdr=$(calc_mis_dispatch_rate)

  local ear_status crr_status ahr_status mdr_status
  ear_status=$(if [ "$(echo "$ear >= $TARGET_EXPERT_ACTIVATION_RATE" | bc 2>/dev/null)" = "1" ]; then echo "PASS"; else echo "FAIL"; fi)
  crr_status=$(if [ "$(echo "$crr >= $TARGET_CROSS_EPIC_REUSE_RATE" | bc 2>/dev/null)" = "1" ]; then echo "PASS"; else echo "FAIL"; fi)
  ahr_status=$(if [ "$(echo "$ahr <= $TARGET_AB_HIT_RATE" | bc 2>/dev/null)" = "1" ]; then echo "PASS"; else echo "FAIL"; fi)
  mdr_status=$(if [ "$(echo "$mdr <= $TARGET_MIS_DISPATCH_RATE" | bc 2>/dev/null)" = "1" ]; then echo "PASS"; else echo "FAIL"; fi)

  cat <<EOF
# Sprint Metrics — $epic

| 指标 | 值 | 目标 | 状态 |
|------|-----|------|------|
| expert_activation_rate | $ear | >= $TARGET_EXPERT_ACTIVATION_RATE | $ear_status |
| cross_epic_reuse_rate | $crr | >= $TARGET_CROSS_EPIC_REUSE_RATE | $crr_status |
| ab_hit_rate | $ahr | <= $TARGET_AB_HIT_RATE | $ahr_status |
| mis_dispatch_rate | $mdr | <= $TARGET_MIS_DISPATCH_RATE | $mdr_status |

Generated: $(date)
EOF
}
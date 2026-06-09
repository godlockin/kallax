#!/usr/bin/env bash
# scripts/l1b-router.sh — L1b Smart Router for KALLAX
# Rule-based precision layer after L1a keyword match
# 4 rules: noun_veto, negative_signal, history_stickiness, tiebreaker
# Compatible with bash 3.2 (macOS default)

set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
AUDIT_LOG="${HOME}/.kallax/logs/expert_resolution_audit.jsonl"
mkdir -p "$(dirname "$AUDIT_LOG")"

# l1b_route <candidates_json> <requirement>
# candidates_json: L1 候选 [{"id":"backend","score":60}, ...]
# requirement: 原始需求文本
# 输出 JSON: {"best":"backend","score":65,"ambiguous":false,"reason":"noun_veto:页面;history:+5"}
l1b_route() {
  local candidates_json="$1"
  local requirement="$2"

  # 解析 ids
  local ids
  ids=$(echo "$candidates_json" | jq -r '.[].id')

  # Rule 1: 主名词 veto
  local noun_winner=""
  local noun_mapped=0
  local reasons=""

  local primary_nouns_file="${KALLAX_ROOT}/experts/PRIMARY_NOUNS.md"
  if [ -f "$primary_nouns_file" ]; then
    # 需求分词 (中英文通用)
    local req_tokens
    if echo "$requirement" | grep -q " "; then
      # 英文/带空格文本
      req_tokens=$(echo "$requirement" | tr ' ,;。、\n' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' | sort -u)
    else
      # 中文: 提取2-char substrings
      req_tokens=$(echo "$requirement" | grep -o '..' | tr '\n' ' ' | sed 's/ $//')
    fi

    local best_expert=""
    local best_hits=0

    for expert in $ids; do
      local hit_count=0
      # 提取该 expert 的主名词 section (lines between ## expert and next ##)
      local section_start section_end
      section_start=$(grep -n "^## $expert " "$primary_nouns_file" 2>/dev/null | cut -d: -f1)
      if [ -z "$section_start" ]; then
        continue
      fi
      section_end=$(awk "NR>$section_start && /^## / {print NR; exit}" "$primary_nouns_file" 2>/dev/null)
      if [ -z "$section_end" ]; then
        section_end=$(wc -l < "$primary_nouns_file")
      fi
      section_end=$((section_end - 1))
      local section
      section=$(sed -n "${section_start},${section_end}p" "$primary_nouns_file" 2>/dev/null)
      # 检查每个 token 是否在 section 中
      for tok in $req_tokens; do
        if echo "$section" | grep -qF "$tok" 2>/dev/null; then
          hit_count=$((hit_count + 1))
        fi
      done
      if [ "$hit_count" -gt "$best_hits" ]; then
        best_hits=$hit_count
        best_expert=$expert
      fi
    done

    if [ "$best_hits" -gt 0 ]; then
      noun_mapped=1
      noun_winner=$best_expert
      reasons="${reasons}noun_veto:${requirement}->${noun_winner};"
    fi
  fi

  # Rule 2: 负向信号
  # 格式: 触发: <patterns>; 排除: <experts> (patterns和excludes都是逗号分隔)
  local neg_file="${KALLAX_ROOT}/experts/NEGATIVE_SIGNALS.md"
  local zeroed_experts=""
  if [ -f "$neg_file" ]; then
    while IFS= read -r line; do
      # 跳过注释和空行
      echo "$line" | grep -qE '^(#|^$)' && continue
      # 检查是否包含 "触发:" 和 "排除:"
      if ! echo "$line" | grep -q "触发:" || ! echo "$line" | grep -q "排除:"; then
        continue
      fi
      # 提取触发词列表 (逗号分隔,去掉 "触发:" 前缀和 ";" 后缀)
      local trigger_part
      trigger_part=$(echo "$line" | sed -n 's/.*触发: *//p' | tr -d '\r' | sed 's/;.*//')
      # 提取排除 expert 列表
      local exclude_part
      exclude_part=$(echo "$line" | sed -n 's/.*排除: *//p' | tr -d '\r')
      if [ -z "$trigger_part" ] || [ -z "$exclude_part" ]; then
        continue
      fi

      # 检查任一触发词是否在需求中 (支持正则)
      local matched=0
      for pattern in $(echo "$trigger_part" | tr ', ' '\n'); do
        [ -z "$pattern" ] && continue
        if echo "$requirement" | grep -qE "$pattern" 2>/dev/null; then
          matched=1
          break
        fi
      done

      if [ "$matched" -eq 1 ]; then
        for exp in $(echo "$exclude_part" | tr ', ' '\n'); do
          [ -n "$exp" ] && zeroed_experts="${zeroed_experts}${exp},"
        done
        reasons="${reasons}neg:$(echo "$exclude_part" | tr ',' '&');"
      fi
    done < "$neg_file"
  fi

  # 计算调整后分数并找 best/second
  local best_id second_best
  local best_score second_score
  best_id=""
  best_score=0
  second_best=""
  second_score=0

  for expert in $ids; do
    local orig_score
    orig_score=$(echo "$candidates_json" | jq -r ".[] | select(.id==\"$expert\") | .score")
    local adjusted=$orig_score

    # Rule 1: 主名词命中 → winner × 1.5, others × 0.5
    if [ "$noun_mapped" -eq 1 ] && [ "$expert" = "$noun_winner" ]; then
      adjusted=$((orig_score * 3 / 2))
      reasons="${reasons}noun_bonus:${expert}*1.5;"
    elif [ "$noun_mapped" -eq 1 ]; then
      adjusted=$((orig_score / 2))
      reasons="${reasons}noun_penalty:${expert}*0.5;"
    fi

    # Rule 2: 负向信号 → score = 0
    if echo "$zeroed_experts" | grep -q "${expert}," 2>/dev/null; then
      adjusted=0
    fi

    # 跟踪 top 2
    if [ "$adjusted" -gt "$best_score" ]; then
      second_best=$best_id
      second_score=$best_score
      best_id=$expert
      best_score=$adjusted
    elif [ "$adjusted" -gt "$second_score" ]; then
      second_best=$expert
      second_score=$adjusted
    fi
  done

  # Rule 3: 会话历史 stickiness (最后 10 条 audit log)
  if [ -f "$AUDIT_LOG" ] && [ -s "$AUDIT_LOG" ]; then
    local last_expert
    last_expert=$(tail -10 "$AUDIT_LOG" 2>/dev/null | tail -1 | jq -r '.id // empty')
    if [ -n "$last_expert" ] && [ "$last_expert" != "null" ]; then
      if [ "$last_expert" = "$best_id" ]; then
        best_score=$((best_score + 5))
        reasons="${reasons}history:+5:($last_expert);"
      fi
    fi
  fi

  # Rule 4: tiebreaker
  # tiebreaker threshold = 10: 当 best - 2nd < 10, 标记 ambiguous (L2/L3 接)
  # 阈值 10经验值: 30% 主名词 bonus 放大 +5 history补偿后, 差值仍小说明真正歧义
  local ambiguous="false"
  if [ -n "$best_id" ] && [ -n "$second_best" ]; then
    local diff=$((best_score - second_score))
    if [ "$diff" -lt 10 ]; then
      ambiguous="true"
      reasons="${reasons}tiebreaker:diff=${diff}<10;"
    fi
  fi

  # 输出 JSON
  echo "{}" | jq -r \
    --arg best "$best_id" \
    --argjson score "$best_score" \
    --arg ambiguous "$ambiguous" \
    --arg reason "${reasons}" \
    '{best: $best, score: $score, ambiguous: ($ambiguous == "true"), reason: $reason}'
}

# 如果直接运行, 做快速测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "L1b Router self-test (no LLM, pure bash)"
  echo "PASS: l1b-router.sh loads correctly"
fi
#!/usr/bin/env bash
# Stage 2 + 3: 路由器 (引导 + 确认/调整/自选)
# 跟"决策疲劳" 反讽 联合, 跟 Rule 33 联合, 跟"独立" 拍 explicit 约束 联合

set -euo pipefail

RECOMMEND_JSON="${1:-}"

recommendation=$(echo "${RECOMMEND_JSON}" | jq -r '.recommendation')
expert_count=$(echo "${RECOMMEND_JSON}" | jq -r '.expert_count')
experts=$(echo "${RECOMMEND_JSON}" | jq -r '.experts | join(",")')
rationale=$(echo "${RECOMMEND_JSON}" | jq -r '.rationale')

# Stage 2: 展示 (stderr)
cat <<EOF >&2

📊 推荐方案:
A. 简单分析 (1 单专家 — Architect)
B. 深入研究 (${expert_count} 专家组合)
   专家组: ${experts}
   理由: ${rationale}
C. 自定义: 你来选 (single / combination / 全组 5+5)

确认召唤? (A/B/C/n):
EOF

# Stage 3: 处理
read -r choice
choice=$(echo "${choice}" | tr '[:lower:]' '[:upper:]')

case "${choice}" in
  A)
    final_choice="A"
    final_experts='["architect"]'
    ;;
  B|Y)
    final_choice="${recommendation}"
    final_experts=$(echo "${RECOMMEND_JSON}" | jq -c '.experts')
    ;;
  C)
    # 自选模式
    echo "请输入专家组 (逗号分隔, e.g. architect,security):" >&2
    read -r custom
    final_choice="CUSTOM"
    custom_array=$(echo "${custom}" | tr ',' '\n' | jq -R . | jq -s .)
    final_experts="${custom_array}"
    ;;
  N|"")
    final_choice="CANCEL"
    final_experts='[]'
    ;;
  *)
    # 默认走推荐方案
    final_choice="${recommendation}"
    final_experts=$(echo "${RECOMMEND_JSON}" | jq -c '.experts')
    ;;
esac

# JSON only to stdout
cat <<EOF
{
  "choice": "${final_choice}",
  "experts": ${final_experts}
}
EOF
#!/usr/bin/env bash
# Step 1b: LLM 预审 (1 调用, 30s-1min)
# 跟"ROI 评估" 拍 explicit 约束 联合, 跟 Rule 4 Fail Fast 联合

set -euo pipefail

SCAN_JSON="${1:-}"
USER_NEED="${2:-接手分析}"

if [[ -z "${SCAN_JSON}" ]]; then
  echo "ERROR: missing scan.json" >&2
  exit 2
fi

# 构造 prompt (4 维度: 规模/领域/研究价值/ROI)
PROMPT="基于以下项目扫描数据 + 主公需求, 输出 JSON:
{
  \"scale\": \"small/medium/large/huge\",
  \"domain\": \"backend/frontend/fullstack/ml/data/infra/mixed\",
  \"research_value\": \"low/medium/high/critical\",
  \"roi\": 1-5,
  \"rationale\": \"<100 字理由>\"
}

扫描数据: ${SCAN_JSON}
主公需求: ${USER_NEED}"

# 调用 claude CLI (跟"反讽" 联合, 失败降级)
RESPONSE=$(claude --print "${PROMPT}" 2>/dev/null) || RESPONSE=""

if [[ -z "${RESPONSE}" ]]; then
  # Fallback: 基于 scan.json heuristic
  loc=$(echo "${SCAN_JSON}" | jq -r '.loc // 0')
  if [[ ${loc} -lt 5000 ]]; then
    SCALE="small"
  elif [[ ${loc} -lt 50000 ]]; then
    SCALE="medium"
  elif [[ ${loc} -lt 500000 ]]; then
    SCALE="large"
  else
    SCALE="huge"
  fi

  cat <<EOF
{
  "scale": "${SCALE}",
  "domain": "unknown",
  "research_value": "medium",
  "roi": 3,
  "rationale": "FALLBACK: LLM unavailable, using scan.json heuristic"
}
EOF
else
  echo "${RESPONSE}"
fi
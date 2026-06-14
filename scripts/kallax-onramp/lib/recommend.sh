#!/usr/bin/env bash
# Stage 1: heuristic 推荐 (0 LLM)
# 跟"ROI 评估" 拍 explicit 约束 联合, 跟 Rule 33 联合

set -euo pipefail

SCAN_JSON="${1:-}"
PRE_ASSESS_JSON="${2:-}"

# 处理空输入
if [[ -z "${PRE_ASSESS_JSON}" ]]; then
  roi=3
  research_value="medium"
else
  roi=$(echo "${PRE_ASSESS_JSON}" | jq -r '.roi // 3' 2>/dev/null) || roi=3
  research_value=$(echo "${PRE_ASSESS_JSON}" | jq -r '.research_value // "medium"' 2>/dev/null) || research_value="medium"
fi

# Heuristic
if [[ ${roi} -ge 4 ]] && [[ "${research_value}" == "high" || "${research_value}" == "critical" ]]; then
  RECOMMENDATION="C"
  EXPERT_COUNT=10
  RATIONALE="高 ROI + 高研究价值 → 5+5 完整审计 + 3 件套"
elif [[ ${roi} -ge 3 ]]; then
  RECOMMENDATION="B"
  EXPERT_COUNT=4
  RATIONALE="中 ROI → 3-5 专家深入研究"
else
  RECOMMENDATION="A"
  EXPERT_COUNT=1
  RATIONALE="低 ROI → 1 Architect 简单分析"
fi

# 选 L2/L3 专家 (按 smell + domain + recommendation)
# L1 (recommendation=A): 1 Architect
# L2 (recommendation=B): 3-5 专家 (default, 按 smell 加)
# L3 (recommendation=C): 5 default + 5 extended = 10 视角
experts_json='["architect","backend","security"]'
if [[ "${RECOMMENDATION}" == "B" ]]; then
  smell_count=$(echo "${SCAN_JSON}" | jq -r '.smell_indicators | length' 2>/dev/null || echo 0)
  if [[ ${smell_count} -ge 2 ]]; then
    experts_json='["architect","backend","security","process-engineering","auditor"]'
    EXPERT_COUNT=5
  fi
elif [[ "${RECOMMENDATION}" == "C" ]]; then
  # L3 完整审计: 5 default + 5 extended = 10 视角 (跟"反讽" 闭环, 跟 v1.3.2 修)
  experts_json='["architect","backend","security","compliance-rule-merge","auditor-independent-witness","process-engineering-self-verify","security-tool-bypass","decision-gate-complex-only","frontend","ux","product"]'
  EXPERT_COUNT=10
fi

cat <<EOF
{
  "recommendation": "${RECOMMENDATION}",
  "expert_count": ${EXPERT_COUNT},
  "experts": ${experts_json},
  "rationale": "${RATIONALE}",
  "llm_roi": ${roi},
  "llm_research_value": "${research_value}"
}
EOF
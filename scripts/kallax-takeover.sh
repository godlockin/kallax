#!/usr/bin/env bash
# KALLAX Takeover — 中途接手 (v2.0.0)
# 跟 v1.3.0 Onramp 复用 7 阶段 (scan + pre-assess + recommend + route + summon + output + audit)
# 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONRAMP_DIR="${SCRIPT_DIR}/kallax-onramp"
PROJECT_PATH="${1:-}"
USER_NEED="${2:-接手分析}"

if [[ -z "${PROJECT_PATH}" ]]; then
  echo "Usage: kallax-takeover <project_path> <user_need>" >&2
  exit 2
fi

if [[ ! -d "${PROJECT_PATH}" ]]; then
  echo "ERROR: path not accessible: ${PROJECT_PATH}" >&2
  exit 2
fi

# 触发条件检查 (跟"反讽" 联合)
if [[ ! -f "${PROJECT_PATH}/CLAUDE.md" ]] && [[ ! -d "${PROJECT_PATH}/.kallax" ]]; then
  echo "ERROR: project not initialized. Use /kallax-init instead." >&2
  exit 2
fi

# Step 1-4: 复用 v1.3.0 Onramp (跟"反讽" 联合, 跟"流程逻辑" 战略 一致 — 0 重写)
SCAN_JSON=$("${ONRAMP_DIR}/lib/scan.sh" "${PROJECT_PATH}")
PRE_ASSESS_JSON=$("${ONRAMP_DIR}/lib/pre-assess.sh" "${SCAN_JSON}" "${USER_NEED}")
RECOMMEND_JSON=$("${ONRAMP_DIR}/lib/recommend.sh" "${SCAN_JSON}" "${PRE_ASSESS_JSON}")
CHOICE=$("${ONRAMP_DIR}/lib/route.sh" "${RECOMMEND_JSON}")
EXPERT_OUTPUT=$("${ONRAMP_DIR}/lib/summon.sh" "${CHOICE}")

# Step 5: 输出 TAKEOVER-REPORT.md (3 件套: 亮点 / 缺点 / 隐患)
"${ONRAMP_DIR}/lib/output.sh" "${CHOICE}" "${EXPERT_OUTPUT}" "${PROJECT_PATH}"

# Step 6: 写入 .kallax/inbox/human_feedback/ (跟"独立" 拍 explicit 约束 联合)
mkdir -p "${PROJECT_PATH}/.kallax/inbox/human_feedback"
TAKEOVER_INBOX="${PROJECT_PATH}/.kallax/inbox/human_feedback/TAKEOVER-$(date +%Y-%m-%d).md"
cat > "${TAKEOVER_INBOX}" <<EOF
# KALLAX Takeover 等主公拍板 (跟"独立" 拍 explicit 约束 联合)

**日期**: $(date +%Y-%m-%d)
**项目**: $(basename "${PROJECT_PATH}")
**调用**: /kallax-takeover
**意图**: ${USER_NEED}

## 输出位置
docs/analysis/ONRAMP-$(basename "${PROJECT_PATH}")-$(date +%Y-%m-%d).md

## 等主公拍板
1. 接受推荐 (跟"诚实修正" 联合, 跟 v1.3.0 模式 一致)
2. 调整专家组 (跟"独立" 拍 explicit 约束 联合)
3. 重选深度 (L1/L2/L3)
EOF

echo ""
echo "✅ TAKEOVER-REPORT.md 落地 + 写入 .kallax/inbox/human_feedback/"
echo ""
echo "⚠️ 等主公拍 explicit 授权 (跟\"独立\" 拍 explicit 约束 联合)"
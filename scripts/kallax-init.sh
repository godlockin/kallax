#!/usr/bin/env bash
# KALLAX Init — 项目初始化 (v2.0.0)
# 跟 v1.3.0 Onramp 复用 7 阶段
# 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONRAMP_DIR="${SCRIPT_DIR}/kallax-onramp"
TEMPLATE_DIR="${SCRIPT_DIR}/../template"
PROJECT_PATH="${1:-}"

if [[ -z "${PROJECT_PATH}" ]]; then
  echo "Usage: kallax-init <project_path>" >&2
  exit 2
fi

if [[ ! -d "${PROJECT_PATH}" ]]; then
  echo "ERROR: path not accessible: ${PROJECT_PATH}" >&2
  exit 2
fi

# 触发条件检查 (跟"反讽" 联合)
if [[ -f "${PROJECT_PATH}/CLAUDE.md" ]] || [[ -d "${PROJECT_PATH}/.kallax" ]]; then
  echo "ERROR: project already initialized (CLAUDE.md or .kallax/ exists). Use /kallax-takeover instead." >&2
  exit 2
fi

cd "${PROJECT_PATH}"

# Step 2: 创建 3 库骨架 (跟"流程逻辑" 战略 一致)
mkdir -p docs jira scripts .kallax/{queue/{inbox,outbox,results,dispatch},audit,logs,state}

# Step 3: 复制 CLAUDE.md 模板 (跟"反讽" 联合, 跟 v1.3.0 模式 一致)
if [[ -f "${TEMPLATE_DIR}/CLAUDE-TEMPLATE.md" ]]; then
  cp "${TEMPLATE_DIR}/CLAUDE-TEMPLATE.md" ./CLAUDE.md
else
  echo "WARN: template/CLAUDE-TEMPLATE.md not found, skipping CLAUDE.md creation"
fi

# Step 4: 复制 5 default + 5 extended skill 文档
mkdir -p .claude/skills/kallax/{default,extended}
for skill in architect backend frontend ux product; do
  if [[ -f "${TEMPLATE_DIR}/.claude/skills/kallax/default/${skill}.md" ]]; then
    cp "${TEMPLATE_DIR}/.claude/skills/kallax/default/${skill}.md" \
       ".claude/skills/kallax/default/${skill}.md"
  fi
done
for skill in security-tool-bypass process-engineering-self-verify auditor-independent-witness compliance-rule-merge decision-gate-complex-only; do
  if [[ -f "${TEMPLATE_DIR}/.claude/skills/kallax/extended/${skill}.md" ]]; then
    cp "${TEMPLATE_DIR}/.claude/skills/kallax/extended/${skill}.md" \
       ".claude/skills/kallax/extended/${skill}.md"
  fi
done

# Step 5: LLM 预审 (跟"反讽" 联合, 跟 v1.3.0 pre-assess 复用)
if [[ -x "${ONRAMP_DIR}/lib/pre-assess.sh" ]]; then
  SCAN_JSON=$("${ONRAMP_DIR}/lib/scan.sh" "${PROJECT_PATH}")
  PRE_ASSESS_JSON=$("${ONRAMP_DIR}/lib/pre-assess.sh" "${SCAN_JSON}" "项目初始化")
  echo "${PRE_ASSESS_JSON}" > .kallax/state/pre-assess.json
fi

# Step 6: 输出 INIT-REPORT.md
cat > docs/INIT-REPORT.md <<EOF
# KALLAX Init Report

**日期**: $(date +%Y-%m-%d)
**项目**: $(basename "${PROJECT_PATH}")
**调用**: /kallax-init

## 3 库 边界
- **docs/**: 设计文档 / 决策记录 / 经验教训 / 索引
- **jira/**: EPIC / Ticket / Sub-task
- **scripts/**: 实现代码 + 工具脚本

## 消息队列 (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)
- **.kallax/queue/inbox/<role>_<id>/**: 收报 PASS
- **.kallax/queue/outbox/<role>_<id>/**: 报 Conductor 派单
- **.kallax/queue/results/**: 报结果 (JSON)
- **.kallax/queue/dispatch/**: Conductor 派单
- **.kallax/queue/rotate.sh**: 每日轮转 (跟 Rule 17 联合)

## Subagent 团队 (5 default + 5 extended = 10)
- A 正向: architect + backend + security + frontend + ux + product
- B 逆袭: security-tool-bypass + process-engineering + auditor + compliance + decision-gate

## 下一步
等主公拍 explicit 授权 (跟"独立" 拍 explicit 约束 联合), 进入 Phase 1.
EOF

# Step 7: 等主公拍 explicit 授权 (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)
echo ""
echo "✅ 3 库骨架 + CLAUDE.md + 5 default + 5 extended skill 文档 + INIT-REPORT.md 落地"
echo ""
echo "⚠️ 等主公拍 explicit 授权 进入 Phase 1 (跟\"独立\" 拍 explicit 约束 联合, 跟 Rule 11 联合)"
#!/usr/bin/env bash
# KALLAX Init — 项目初始化 (v2.1.0)
# 跟 v1.3.0 Onramp 复用 7 阶段
# 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合
# EPIC-029-F: --mode CLI flag (3 modes: ai-auto|ai-copilot|manual)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONRAMP_DIR="${SCRIPT_DIR}/kallax-onramp"
TEMPLATE_DIR="${SCRIPT_DIR}/../template"
# EPIC-029-A: scripts/permission/mode-set.sh 提供 schema/format 参考
# init 操作目标 = 新项目, mode-set.sh 设计为操作自身 KALLAX_ROOT, 不能直接复用 (避免 cross-KALLAX_ROOT 副作用)
MODE_SET_SH="${SCRIPT_DIR}/permission/mode-set.sh"

# 3 modes — 跟 docs/architecture/3-MODES.md §3 1:1 验证
VALID_MODES=(ai-auto ai-copilot manual)

usage() {
  cat <<EOF
Usage: kallax-init <project_path> [--mode <ai-auto|ai-copilot|manual>] [--actor <name>]
  --mode    optional, one of ai-auto, ai-copilot, manual (writes state.json + mode_lock)
  --actor   optional, audit field passed to mode-set.sh (defaults to current user)
  -h|--help show this help

Without --mode, init leaves state.json.mode unset (downstream session_start.sh will prompt).
EOF
  exit 1
}

PROJECT_PATH=""
INIT_MODE=""
INIT_ACTOR="${USER:-unknown}"

# EPIC-029-F: while [[ $# -gt 0 ]] pattern (跟 mode-set.sh + decision-gate.sh 一致)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) INIT_MODE="$2"; shift 2 ;;
    --actor) INIT_ACTOR="$2"; shift 2 ;;
    -h|--help) usage ;;
    --mode=*) INIT_MODE="${1#*=}"; shift ;;
    --actor=*) INIT_ACTOR="${1#*=}"; shift ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      usage
      ;;
    *)
      if [[ -z "${PROJECT_PATH}" ]]; then
        PROJECT_PATH="$1"
        shift
      else
        echo "ERROR: unexpected positional arg: $1" >&2
        usage
      fi
      ;;
  esac
done

if [[ -z "${PROJECT_PATH}" ]]; then
  echo "Usage: kallax-init <project_path> [--mode <mode>]" >&2
  exit 2
fi

if [[ ! -d "${PROJECT_PATH}" ]]; then
  echo "ERROR: path not accessible: ${PROJECT_PATH}" >&2
  exit 2
fi

# L2: --mode 早验证 (fail fast, 跟 EPIC-029-A mode-set.sh validation 1:1)
if [[ -n "${INIT_MODE}" ]]; then
  MODE_OK=0
  for m in "${VALID_MODES[@]}"; do
    if [[ "${m}" == "${INIT_MODE}" ]]; then
      MODE_OK=1
      break
    fi
  done
  if [[ "${MODE_OK}" -ne 1 ]]; then
    echo "ERROR: --mode must be one of: ai-auto|ai-copilot|manual, got: ${INIT_MODE}" >&2
    exit 1
  fi
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
# || true 防 scan/pre-assess 子流水线在空项目下 pipefail 阻断 init (跟 Fail Fast 区分: 预审 optional)
if [[ -x "${ONRAMP_DIR}/lib/pre-assess.sh" ]]; then
  SCAN_JSON=$("${ONRAMP_DIR}/lib/scan.sh" "${PROJECT_PATH}" 2>/dev/null || true)
  PRE_ASSESS_JSON=$("${ONRAMP_DIR}/lib/pre-assess.sh" "${SCAN_JSON}" "项目初始化" 2>/dev/null || true)
  if [[ -n "${PRE_ASSESS_JSON}" ]]; then
    echo "${PRE_ASSESS_JSON}" > .kallax/state/pre-assess.json
  fi
fi

# Step 6: 输出 INIT-REPORT.md
cat > docs/INIT-REPORT.md <<EOF
# KALLAX Init Report

**日期**: $(date +%Y-%m-%d)
**项目**: $(basename "${PROJECT_PATH}")
**调用**: /kallax-init
**模式**: ${INIT_MODE:-未指定 (session_start.sh 提示选)}

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

## 3 模式 (跟 docs/architecture/3-MODES.md §3 1:1)
- **ai-auto**: AI 决策所有事, 仅 block/danger 停下问
- **ai-copilot**: 简单 AI 自主, 复杂停下协商 (默认)
- **manual**: 每阶段主公确认

## 下一步
等主公拍 explicit 授权 (跟"独立" 拍 explicit 约束 联合), 进入 Phase 1.
EOF

# Step 7: 写 state.json seed (mode-set.sh 需要 state.json 存在, EPIC-029-A L2)
if [[ ! -f .kallax/state/state.json ]]; then
  INIT_TS=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
  cat > .kallax/state/state.json <<EOF
{
  "role": "performer",
  "instance_id": "init_$$",
  "actor": "${INIT_ACTOR}",
  "branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)",
  "initialized_at": "${INIT_TS}"
}
EOF
fi

# Step 8: --mode 写入 state.json + mode_lock (跟 EPIC-029-A mode-set.sh 联合, schema 1:1)
# 走 inline jq (init 操作目标 = 新项目, 跟 mode-set.sh 的 KALLAX_ROOT=自身 不同, 不能直接调)
if [[ -n "${INIT_MODE}" ]]; then
  if command -v jq >/dev/null 2>&1; then
    MODE_TS=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
    TMP_STATE=".kallax/state/state.json.tmp.$$"
    jq --arg m "${INIT_MODE}" --arg t "${MODE_TS}" \
       '. + {mode: $m, mode_set_at: $t}' \
       .kallax/state/state.json > "${TMP_STATE}" \
       && mv "${TMP_STATE}" .kallax/state/state.json
    # mode_lock 写新项目自己的 state dir (不是 mode-set.sh 的 KALLAX_ROOT)
    echo "$$" > .kallax/state/mode.lock
    echo "OK: mode=${INIT_MODE} set at ${MODE_TS} by ${INIT_ACTOR}"
  else
    echo "ERROR: jq not found, cannot write state.json mode" >&2
    exit 1
  fi
fi

# Step 9: 等主公拍 explicit 授权 (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)
echo ""
echo "✅ 3 库骨架 + CLAUDE.md + 5 default + 5 extended skill 文档 + INIT-REPORT.md 落地"
if [[ -n "${INIT_MODE}" ]]; then
  echo "✅ mode=${INIT_MODE} 已写入 state.json + mode_lock"
fi
echo ""
echo "⚠️ 等主公拍 explicit 授权 进入 Phase 1 (跟\"独立\" 拍 explicit 约束 联合, 跟 Rule 11 联合)"
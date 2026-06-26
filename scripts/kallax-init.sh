#!/usr/bin/env bash
# KALLAX Init — 项目目录初始化脚本 (v2.2.0)
# 跟 EPIC-015-E 联合: 项目目录初始化 + 增量初始化 + multi-target 支持
# 跟 EPIC-029-F 联合: --mode CLI (3 modes: ai-auto|ai-copilot|manual)
# 跟 EPIC-057-A 联合: --target CLI (multi-target comma-separated, 跟 install.sh 模式一致)
# 跟"翻篇&精进" 战略 联合: 0 增 Rule 0 增命令, 复用现有 init 流程

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONRAMP_DIR="${SCRIPT_DIR}/kallax-onramp"
TEMPLATE_DIR="${SCRIPT_DIR}/../template"
MODE_SET_SH="${SCRIPT_DIR}/permission/mode-set.sh"

# 3 modes — 跟 docs/architecture/3-MODES.md §3 1:1 验证
VALID_MODES=(ai-auto ai-copilot manual)

# EPIC-015-E: 标准目录结构 — 4 组分类 (3 库 + .kallax + jira + confluence)
DIRS_3_LIB=(
  docs
  jira
  scripts
)
DIRS_KALLAX=(
  .kallax/queue/inbox
  .kallax/queue/outbox
  .kallax/queue/results
  .kallax/queue/dispatch
  .kallax/audit
  .kallax/logs
  .kallax/state
  .kallax/instances
)
DIRS_JIRA=(
  jira/phases
  jira/epics
  jira/tickets
)
DIRS_CONFLUENCE=(
  confluence/decisions
  confluence/memory
  confluence/runbooks
  confluence/templates
  confluence/architecture
  confluence/pitfalls
  confluence/research
)
DIRS_CLAUDE_SKILLS=(
  .claude/skills/kallax/default
  .claude/skills/kallax/extended
)
# 5 default + 5 extended = 10 skill 文档 (跟 docs/PROCESS.md 一致)
SKILLS_DEFAULT=(architect backend frontend ux product)
SKILLS_EXTENDED=(security-tool-bypass process-engineering-self-verify auditor-independent-witness compliance-rule-merge decision-gate-complex-only)

usage() {
  cat <<EOF
Usage: kallax-init <project_path> [--mode <ai-auto|ai-copilot|manual>] [--actor <name>] [--target <path[,path2,...]>]
  --mode    optional, one of ai-auto, ai-copilot, manual (writes state.json + mode_lock)
  --actor   optional, audit field passed to mode-set.sh (defaults to current user)
  --target  optional, comma-separated list of project paths (multi-project init, 跟 EPIC-057-A install.sh 模式一致)
  -h|--help show this help

Without --mode, init leaves state.json.mode unset (downstream session_start.sh will prompt).

Behavior:
  - Fresh project (no CLAUDE.md + no .kallax/): full init
  - Existing project (CLAUDE.md or .kallax/ present): incremental — only missing dirs/files created, no overwrite
  - INIT-REPORT.md always regenerated to capture latest run
EOF
  exit 1
}

PROJECT_PATH=""
INIT_MODE=""
INIT_ACTOR="${USER:-unknown}"
TARGETS_RAW=""

# EPIC-029-F + EPIC-015-E: while [[ $# -gt 0 ]] pattern (跟 mode-set.sh + decision-gate.sh 一致)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) INIT_MODE="$2"; shift 2 ;;
    --actor) INIT_ACTOR="$2"; shift 2 ;;
    --target) TARGETS_RAW="$2"; shift 2 ;;
    -h|--help) usage ;;
    --mode=*) INIT_MODE="${1#*=}"; shift ;;
    --actor=*) INIT_ACTOR="${1#*=}"; shift ;;
    --target=*) TARGETS_RAW="${1#*=}"; shift ;;
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

# EPIC-015-E: 收集 init target 列表 — 显式 <project> 或 --target=p1,p2 或 二者联合
TARGETS=()
if [[ -n "${TARGETS_RAW}" ]]; then
  IFS=',' read -ra SPLIT_TARGETS <<< "${TARGETS_RAW}"
  for t in "${SPLIT_TARGETS[@]}"; do
    # trim whitespace (跟 EPIC-057-A install.sh 模式一致)
    TRIMMED="$(echo "${t}" | xargs)"
    if [[ -n "${TRIMMED}" ]]; then
      TARGETS+=("${TRIMMED}")
    fi
  done
fi
if [[ -n "${PROJECT_PATH}" ]]; then
  TARGETS+=("${PROJECT_PATH}")
fi

if [[ "${#TARGETS[@]}" -eq 0 ]]; then
  echo "Usage: kallax-init <project_path> [--mode <mode>] [--target <path[,path2,...]>]" >&2
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

# EPIC-015-E: init_one_project — 单项目初始化 (增量模式, 不覆盖现有)
# Returns: 0 = 成功 (含 incremental), non-zero = 失败
# 输出: stdout 一行 "[fresh|incremental] <path>: created=N skipped=M"
init_one_project() {
  local proj="$1"
  local proj_name
  proj_name="$(basename "${proj}")"
  local created=0
  local skipped=0
  local init_type="fresh"
  local line

  if [[ ! -d "${proj}" ]]; then
    echo "ERROR: path not accessible: ${proj}" >&2
    return 2
  fi

  # EPIC-015-E: 增量检测 — 标记 incremental, 不 abort (跟 ticket AC#5 一致)
  if [[ -f "${proj}/CLAUDE.md" ]] || [[ -d "${proj}/.kallax" ]]; then
    init_type="incremental"
  fi

  # L2: --mode 验证已在 init 前完成 (避免 incremental 跳过验证)
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
      return 1
    fi
  fi

  cd "${proj}"

  # Step 1: 创建 4 组目录 (mkdir -p 幂等: 已存在不报错, 不算 created)
  for d in "${DIRS_3_LIB[@]}" "${DIRS_KALLAX[@]}" "${DIRS_JIRA[@]}" "${DIRS_CONFLUENCE[@]}" "${DIRS_CLAUDE_SKILLS[@]}"; do
    if [[ -d "${d}" ]]; then
      skipped=$((skipped + 1))
    else
      mkdir -p "${d}"
      created=$((created + 1))
    fi
  done

  # Step 2: 复制 CLAUDE.md 模板 (增量: 仅当不存在)
  if [[ -f CLAUDE.md ]]; then
    skipped=$((skipped + 1))
  elif [[ -f "${TEMPLATE_DIR}/CLAUDE-TEMPLATE.md" ]]; then
    cp "${TEMPLATE_DIR}/CLAUDE-TEMPLATE.md" ./CLAUDE.md
    created=$((created + 1))
  else
    echo "WARN: template/CLAUDE-TEMPLATE.md not found, skipping CLAUDE.md creation" >&2
  fi

  # Step 3: 复制 5 default + 5 extended skill 文档 (增量: 仅当不存在)
  for skill in "${SKILLS_DEFAULT[@]}"; do
    if [[ -f ".claude/skills/kallax/default/${skill}.md" ]]; then
      skipped=$((skipped + 1))
    elif [[ -f "${TEMPLATE_DIR}/.claude/skills/kallax/default/${skill}.md" ]]; then
      cp "${TEMPLATE_DIR}/.claude/skills/kallax/default/${skill}.md" \
         ".claude/skills/kallax/default/${skill}.md"
      created=$((created + 1))
    fi
  done
  for skill in "${SKILLS_EXTENDED[@]}"; do
    if [[ -f ".claude/skills/kallax/extended/${skill}.md" ]]; then
      skipped=$((skipped + 1))
    elif [[ -f "${TEMPLATE_DIR}/.claude/skills/kallax/extended/${skill}.md" ]]; then
      cp "${TEMPLATE_DIR}/.claude/skills/kallax/extended/${skill}.md" \
         ".claude/skills/kallax/extended/${skill}.md"
      created=$((created + 1))
    fi
  done

  # Step 4: EPIC-015-E: 自动生成 phase_index.json / epic_index.json 空模板 (增量)
  if [[ -f jira/phases/phase_index.json ]]; then
    skipped=$((skipped + 1))
  else
    cat > jira/phases/phase_index.json <<'PHASE_INDEX_EOF'
{
  "phases": [],
  "_meta": {
    "schema_version": "1.0.0",
    "created_by": "kallax-init",
    "purpose": "PHASE registry (跟 master-handoff.sh 联合)"
  }
}
PHASE_INDEX_EOF
    created=$((created + 1))
  fi

  if [[ -f jira/epics/epic_index.json ]]; then
    skipped=$((skipped + 1))
  else
    cat > jira/epics/epic_index.json <<'EPIC_INDEX_EOF'
{
  "epics": [],
  "_meta": {
    "schema_version": "1.0.0",
    "created_by": "kallax-init",
    "purpose": "EPIC registry (跟 master-handoff.sh 联合)"
  }
}
EPIC_INDEX_EOF
    created=$((created + 1))
  fi

  # Step 5: LLM 预审 (跟"反讽" 联合, 跟 v1.3.0 pre-assess 复用)
  # || true 防 scan/pre-assess 子流水线在空项目下 pipefail 阻断 init (跟 Fail Fast 区分: 预审 optional)
  if [[ -x "${ONRAMP_DIR}/lib/pre-assess.sh" ]]; then
    SCAN_JSON=$("${ONRAMP_DIR}/lib/scan.sh" "${proj}" 2>/dev/null || true)
    PRE_ASSESS_JSON=$("${ONRAMP_DIR}/lib/pre-assess.sh" "${SCAN_JSON}" "项目初始化" 2>/dev/null || true)
    if [[ -n "${PRE_ASSESS_JSON}" ]]; then
      if [[ -f .kallax/state/pre-assess.json ]]; then
        skipped=$((skipped + 1))
      else
        echo "${PRE_ASSESS_JSON}" > .kallax/state/pre-assess.json
        created=$((created + 1))
      fi
    fi
  fi

  # Step 6: 写 state.json seed (mode-set.sh 需要 state.json 存在, EPIC-029-A L2)
  # 增量: 仅当不存在 (避免覆盖已配置的 actor/branch)
  if [[ -f .kallax/state/state.json ]]; then
    skipped=$((skipped + 1))
  else
    INIT_TS=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
    cat > .kallax/state/state.json <<STATE_EOF
{
  "role": "performer",
  "instance_id": "init_$$",
  "actor": "${INIT_ACTOR}",
  "branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)",
  "initialized_at": "${INIT_TS}"
}
STATE_EOF
    created=$((created + 1))
  fi

  # Step 7: EPIC-029-F: --mode 写入 state.json + mode_lock
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
      return 1
    fi
  fi

  # Step 8: 输出 INIT-REPORT.md (始终刷新, capture 最新 run)
  INIT_REPORT_TS=$(date +%Y-%m-%d)
  INIT_REPORT_TYPE_CN="全新初始化"
  if [[ "${init_type}" == "incremental" ]]; then
    INIT_REPORT_TYPE_CN="增量初始化"
  fi
  {
    echo "# KALLAX Init Report"
    echo ""
    echo "**日期**: ${INIT_REPORT_TS}"
    echo "**项目**: ${proj_name}"
    echo "**路径**: ${proj}"
    echo "**调用**: /kallax-init"
    echo "**类型**: ${INIT_REPORT_TYPE_CN} (${init_type})"
    echo "**模式**: ${INIT_MODE:-未指定 (session_start.sh 提示选)}"
    echo "**操作者**: ${INIT_ACTOR}"
    echo ""
    echo "## 创建统计"
    echo "- **创建**: ${created} 项 (目录/文件)"
    echo "- **跳过 (已存在)**: ${skipped} 项"
    echo ""
    echo "## 3 库 边界"
    echo "- **docs/**: 设计文档 / 决策记录 / 经验教训 / 索引"
    echo "- **jira/**: EPIC / Ticket / Sub-task"
    echo "- **scripts/**: 实现代码 + 工具脚本"
    echo ""
    echo "## 消息队列 (跟\"反讽\" 联合, 跟\"独立\" 拍 explicit 约束 联合)"
    echo "- **.kallax/queue/inbox/<role>_<id>/**: 收报 PASS"
    echo "- **.kallax/queue/outbox/<role>_<id>/**: 报 Conductor 派单"
    echo "- **.kallax/queue/results/**: 报结果 (JSON)"
    echo "- **.kallax/queue/dispatch/**: Conductor 派单"
    echo "- **.kallax/queue/rotate.sh**: 每日轮转 (跟 Rule 17 联合)"
    echo ""
    echo "## .kallax/ 子目录 (EPIC-015-E)"
    echo "- **.kallax/instances/**: 多实例注册 (performer/conductor/auditor)"
    echo "- **.kallax/state/**: state.json + mode_lock + pre-assess.json"
    echo "- **.kallax/audit/**: 审计日志"
    echo "- **.kallax/logs/**: 运行日志"
    echo ""
    echo "## confluence/ 子目录 (EPIC-015-E)"
    echo "- **decisions/**: Decision Records (跟 decisions/_archive 联合)"
    echo "- **memory/**: 知识沉淀 L0-L4"
    echo "- **runbooks/**: 操作手册"
    echo "- **templates/**: 模板 (跟 templates/ 联合)"
    echo "- **architecture/**: 架构图"
    echo "- **pitfalls/**: 反模式库"
    echo "- **research/**: 调研笔记"
    echo ""
    echo "## jira/ 索引 (EPIC-015-E 自动生成)"
    echo "- **jira/phases/phase_index.json**: PHASE 注册表"
    echo "- **jira/epics/epic_index.json**: EPIC 注册表"
    echo ""
    echo "## Subagent 团队 (5 default + 5 extended = 10)"
    echo "- A 正向: architect + backend + security + frontend + ux + product"
    echo "- B 逆袭: security-tool-bypass + process-engineering + auditor + compliance + decision-gate"
    echo ""
    echo "## 3 模式 (跟 docs/architecture/3-MODES.md §3 1:1)"
    echo "- **ai-auto**: AI 决策所有事, 仅 block/danger 停下问"
    echo "- **ai-copilot**: 简单 AI 自主, 复杂停下协商 (默认)"
    echo "- **manual**: 每阶段主公确认"
    echo ""
    echo "## 下一步"
    echo "等主公拍 explicit 授权 (跟\"独立\" 拍 explicit 约束 联合), 进入 Phase 1."
  } > docs/INIT-REPORT.md

  echo "[${init_type}] ${proj}: created=${created} skipped=${skipped}"
  return 0
}

# EPIC-015-E: 多 target 批量初始化 (跟 EPIC-057-A --target 模式一致)
TOTAL_CREATED=0
TOTAL_SKIPPED=0
TOTAL_TARGETS=0
TOTAL_FAIL=0
for target in "${TARGETS[@]}"; do
  TOTAL_TARGETS=$((TOTAL_TARGETS + 1))
  set +e
  RESULT_LINE=$(init_one_project "${target}" 2>&1)
  RC=$?
  set -e
  if [[ $RC -eq 0 ]]; then
    echo "${RESULT_LINE}"
    # Parse "created=N skipped=M" from output
    CREATED=$(echo "${RESULT_LINE}" | sed -n 's/.*created=\([0-9]*\).*/\1/p' || echo "0")
    SKIPPED=$(echo "${RESULT_LINE}" | sed -n 's/.*skipped=\([0-9]*\).*/\1/p' || echo "0")
    TOTAL_CREATED=$((TOTAL_CREATED + CREATED))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + SKIPPED))
  else
    echo "${RESULT_LINE}" >&2
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
done

echo ""
if [[ ${TOTAL_TARGETS} -gt 1 ]]; then
  echo "✅ 多 target 批量初始化完成: targets=${TOTAL_TARGETS} created=${TOTAL_CREATED} skipped=${TOTAL_SKIPPED} fail=${TOTAL_FAIL}"
fi

if [[ ${TOTAL_FAIL} -gt 0 ]]; then
  exit 1
fi

if [[ ${TOTAL_TARGETS} -eq 1 ]]; then
  echo "✅ 3 库骨架 + CLAUDE.md + 5 default + 5 extended skill 文档 + phase_index.json + epic_index.json + INIT-REPORT.md 落地"
  if [[ -n "${INIT_MODE}" ]]; then
    echo "✅ mode=${INIT_MODE} 已写入 state.json + mode_lock"
  fi
  echo ""
  echo "⚠️ 等主公拍 explicit 授权 进入 Phase 1 (跟\"独立\" 拍 explicit 约束 联合, 跟 Rule 11 联合)"
fi

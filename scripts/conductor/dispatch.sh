#!/bin/bash
# conductor/dispatch.sh — Conductor 派发集成
# 依赖: EPIC-030-A (best-matching-slaver.sh) + EPIC-030-B (scoring-trace.sh)
#       EPIC-036-A (cross-worktree-dispatch.sh, --cross-worktree 选项, EPIC-036-B 联合)
#       EPIC-038-A (--handoff-depth 选项, L1/L2/L3/L4 派单, handoff_depth schema 联合)
#       EPIC-038-B (4 派单模式, --handoff-depth → analyst/incremental/major/auditor, Rule 15 联合)
# 主公 2026-06-11 D2 决策: 派发权 60%→80% AI 渐进升级, 默认 80% AI + 20% 人工 override
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 4 派单模式 → Performer sub-role 映射 (EPIC-038-B)
# 跟 Rule 15 + ticket.json handoff_depth 字段 (L1/L2/L3/L4) 联合
# L1 → analyst (浅层, read-only, 1-2h)
# L2 → incremental (维护, write-incremental, 2-3d)
# L3 → major (深度重构, write-major + A+B review, 5-10d)
# L4 → auditor (亮点借鉴, cross-project + lessons, 1-2d)
readonly SUBROLE_BY_DEPTH_L1="performer-analyst"
readonly SUBROLE_BY_DEPTH_L2="performer-incremental"
readonly SUBROLE_BY_DEPTH_L3="performer-major"
readonly SUBROLE_BY_DEPTH_L4="performer-auditor"

# 解析选项 (--cross-worktree + --handoff-depth)
# 必须从原 args 中剥离, 不污染位置参数
CROSS_WORKTREE=""
HANDOFF_DEPTH=""
POSITIONAL_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --cross-worktree)
      echo "ERROR: --cross-worktree requires =<source_wt> (e.g. --cross-worktree=EPIC-036-A)" >&2
      exit 1
      ;;
    --cross-worktree=)
      echo "ERROR: --cross-worktree= requires non-empty <source_wt>" >&2
      exit 1
      ;;
    --cross-worktree=*)
      CROSS_WORKTREE="${arg#*=}"
      if [[ -z "$CROSS_WORKTREE" ]]; then
        echo "ERROR: --cross-worktree= requires non-empty <source_wt>" >&2
        exit 1
      fi
      ;;
    --handoff-depth)
      echo "ERROR: --handoff-depth requires =L1|L2|L3|L4 (EPIC-038-B)" >&2
      exit 1
      ;;
    --handoff-depth=)
      echo "ERROR: --handoff-depth= requires non-empty L1|L2|L3|L4" >&2
      exit 1
      ;;
    --handoff-depth=*)
      HANDOFF_DEPTH="${arg#*=}"
      if [[ -z "$HANDOFF_DEPTH" ]]; then
        echo "ERROR: --handoff-depth= requires non-empty L1|L2|L3|L4" >&2
        exit 1
      fi
      case "$HANDOFF_DEPTH" in
        L1|L2|L3|L4) ;;
        *)
          echo "ERROR: --handoff-depth=$HANDOFF_DEPTH invalid (must be L1|L2|L3|L4)" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      POSITIONAL_ARGS+=("$arg")
      ;;
  esac
done
set -- "${POSITIONAL_ARGS[@]}"

# 读参数
TICKET_ID="${1:-}"
REQUIRED_EXPERTISE="${2:-}"
DECISION="${3:-accept}"  # accept / veto / override
OVERRIDE_TO="${4:-}"

# handoff_depth 默认值 (Rule 15: L1 = 单 ticket 派单, default)
if [[ -z "$HANDOFF_DEPTH" ]]; then
  HANDOFF_DEPTH="L1"
fi

# AI 派发权比例 (主公 D2 决策: 渐进升级 60%→80%→90%)
# KALLAX_AI_DELEGATION_RATIO: 60 = 60% AI / 40% 人工, 80 = 80% AI / 20% 人工, 90 = 90% AI / 10% 人工
AI_RATIO="${KALLAX_AI_DELEGATION_RATIO:-80}"

# Use argument count to detect if args were provided (empty string is valid for expertise)
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 [--cross-worktree=<source_wt>] [--handoff-depth=L1|L2|L3|L4] <TICKET_ID> <REQUIRED_EXPERTISE> [accept|veto|override] [OVERRIDE_TO]" >&2
  echo "       AI delegation ratio: KALLAX_AI_DELEGATION_RATIO=$AI_RATIO (60/80/90, default 80)" >&2
  echo "       --cross-worktree=<source_wt>: route dispatch to source worktree (EPIC-036-B)" >&2
  echo "       --handoff-depth=L1|L2|L3|L4: 4 派单模式 (EPIC-038-B)" >&2
  echo "         L1 → analyst     (浅层 read-only)" >&2
  echo "         L2 → incremental (维护 write-incremental)" >&2
  echo "         L3 → major       (深度重构 write-major + A+B review)" >&2
  echo "         L4 → auditor     (亮点借鉴 cross-project + lessons)" >&2
  exit 1
fi

case "$DECISION" in
  accept|veto|override) ;;
  *)
    echo "ERROR: decision must be accept|veto|override" >&2
    exit 1
    ;;
esac

if [[ "$DECISION" == "override" ]] && [[ -z "$OVERRIDE_TO" ]]; then
  echo "ERROR: override requires OVERRIDE_TO argument" >&2
  exit 1
fi

# 调 best-matching-slaver.sh 拿 ALGO_SUGGEST
# 使用 KALLAX_TEST_FIXTURES=1 在 test/CI 环境下使用 fixtures
SUGGEST=$(KALLAX_TEST_FIXTURES=1 bash "${KALLAX_ROOT}/scripts/agent/best-matching-slaver.sh" "$REQUIRED_EXPERTISE" 2>/dev/null | head -1)

# 提取 ALGO_SUGGEST 的 ID (格式: "ALGO_SUGGEST: <id> (Layer N: ...)")
ALGO_ID=$(echo "$SUGGEST" | sed -E 's/^ALGO_SUGGEST: ([^ ]+).*/\1/')

if [[ -z "$ALGO_ID" ]] || [[ "$ALGO_ID" == "none" ]]; then
  echo "ERROR: best-matching-slaver.sh returned no match" >&2
  exit 1
fi

# 决策
case "$DECISION" in
  accept)
    FINAL_ID="$ALGO_ID"
    REASON="Conductor Accept ALGO_SUGGEST (${AI_RATIO}% AI delegation)"
    ;;
  veto)
    FINAL_ID="VETOED"
    REASON="Conductor Veto (${AI_RATIO}% AI delegation)"
    ;;
  override)
    FINAL_ID="$OVERRIDE_TO"
    REASON="Conductor Override ALGO_SUGGEST ($ALGO_ID) → $OVERRIDE_TO (${AI_RATIO}% AI delegation)"
    ;;
esac

# 4 派单模式 (EPIC-038-B): --handoff-depth=L1/L2/L3/L4 强制 Performer sub-role
# override 决策优先 (人工 override 不被 handoff-depth 覆盖, 主公 D2 决策权)
SUBROLE=""
if [[ -n "$HANDOFF_DEPTH" ]] && [[ "$DECISION" != "override" ]]; then
  case "$HANDOFF_DEPTH" in
    L1) SUBROLE="$SUBROLE_BY_DEPTH_L1" ;;
    L2) SUBROLE="$SUBROLE_BY_DEPTH_L2" ;;
    L3) SUBROLE="$SUBROLE_BY_DEPTH_L3" ;;
    L4) SUBROLE="$SUBROLE_BY_DEPTH_L4" ;;
  esac
  REASON="${REASON} | handoff_depth=$HANDOFF_DEPTH → sub_role=$SUBROLE"
fi

# 写 scoring audit (跟 EPIC-030-B scoring-trace.sh 集成)
# factors: [1.0, 0.0, 0.0] = accept signal, decision=$DECISION, ai_ratio=$AI_RATIO
bash "${KALLAX_ROOT}/scripts/agent/scoring-trace.sh" append \
  "$ALGO_ID" \
  "$FINAL_ID" \
  "$AI_RATIO" \
  '[1.0,0.0,0.0]' \
  "$DECISION" \
  >/dev/null 2>&1 || true

# 跨 worktree 派单 (EPIC-036-B): --cross-worktree=<source_wt> 触发 cross-worktree-dispatch.sh
# production 路径 = scripts/conductor/cross-worktree-dispatch.sh (EPIC-036-A 提供)
# test 路径      = tests/fixtures/conductor/cross-worktree-dispatch.sh (KALLAX_TEST_FIXTURES=1)
if [[ -n "$CROSS_WORKTREE" ]]; then
  if [[ "${KALLAX_TEST_FIXTURES:-0}" == "1" ]]; then
    CWT_SCRIPT="${KALLAX_ROOT}/tests/fixtures/conductor/cross-worktree-dispatch.sh"
  else
    CWT_SCRIPT="${KALLAX_ROOT}/scripts/conductor/cross-worktree-dispatch.sh"
  fi
  if [[ ! -f "$CWT_SCRIPT" ]]; then
    echo "ERROR: --cross-worktree requires ${CWT_SCRIPT} (EPIC-036-A not yet integrated)" >&2
    exit 1
  fi
  echo "CROSS_WORKTREE: source=$CROSS_WORKTREE ticket=$TICKET_ID final=$FINAL_ID"
  bash "$CWT_SCRIPT" --source-wt="$CROSS_WORKTREE" --ticket-id="$TICKET_ID" --final-id="$FINAL_ID"
fi

# 输出 (跟 handoff_depth 字段联动, EPIC-038-B)
if [[ -n "$HANDOFF_DEPTH" ]]; then
  if [[ -n "$SUBROLE" ]]; then
    echo "DISPATCH: ticket=$TICKET_ID algo_suggest=$ALGO_ID final=$FINAL_ID decision=$DECISION handoff_depth=$HANDOFF_DEPTH sub_role=$SUBROLE ai_ratio=${AI_RATIO}% reason=$REASON"
  else
    echo "DISPATCH: ticket=$TICKET_ID algo_suggest=$ALGO_ID final=$FINAL_ID decision=$DECISION handoff_depth=$HANDOFF_DEPTH ai_ratio=${AI_RATIO}% reason=$REASON"
  fi
else
  echo "DISPATCH: ticket=$TICKET_ID algo_suggest=$ALGO_ID final=$FINAL_ID decision=$DECISION ai_ratio=${AI_RATIO}% reason=$REASON"
fi

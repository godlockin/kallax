#!/usr/bin/env bash
# KALLAX check-ticket-schema.sh — EPIC-223 (主公 2026-08-08 拍板)
# 新 ticket 强制 schema, 历史 ticket (EPIC <= archived_before) 跳过不回溯.
#
# Usage:
#   check-ticket-schema.sh <EPIC-XXX>        # 检查单个 EPIC 的 ticket
#   check-ticket-schema.sh --all             # 检查所有 > archived_before 的 ticket
#   check-ticket-schema.sh --baseline        # 打印归档基线
#
# 归档语义 (口径取自 jira/tickets/.archive-baseline.json):
#   EPIC 编号 <= archived_before  → ARCHIVED_SKIP (exit 3), 不检查不回溯
#   EPIC 编号 >  archived_before  → 强制 required_fields 全填, 缺任一 exit 1
#
# EPIC-277-F: required_fields 加 `review` (Rule 36 指标 #3 ab_hit_rate 数据源).
#   review 存在还不够 — 还验 review_field_schema.required_paths 3 个子路径
#   (group_a.recommendation / group_b.recommendation / final_outcome), 因为
#   metrics.sh compute_ab_hit_rate 读的是那 3 个路径, 只有父字段等于 NO_DATA.
#   status ∈ {backlog, in_progress, blocked} 豁免 (卡没走完 review 时 review 不该存在).
#
# Exit codes (沿用 immutable scripts 的退出码契约):
#   0 = PASS (schema 齐 或 无 ticket 且非强制)
#   1 = FAIL (fail-closed, required_fields 缺失)
#   3 = ARCHIVED_SKIP (历史 EPIC, 跟 EPIC-204 exit 3 DOCS_ONLY_SKIP 同型)
set -euo pipefail

# EPIC-277-E: REPO_ROOT 用 BASH_SOURCE 解析 (worktree/cwd 无关).
# 起因: pre-commit / 命令行 / CI 多处调用本脚本, 默认 cwd 不一定是 worktree root.
# 原先 `git rev-parse --show-toplevel` 用调用方 cwd → 在 main repo 跑看不到
# worktree 内 EPIC-277-* 路径 → 误报 ARCHIVED_SKIP. 修法用脚本自身 location.
#
# EPIC-277-F 补一处: git hook 环境会设 GIT_DIR, 此时
# `git -C <dir> rev-parse --show-toplevel` 返回的是 -C 的那个 dir 本身
# (scripts/hooks), 不是 repo root → BASELINE 路径拼成
# scripts/hooks/jira/tickets/.archive-baseline.json → 文件不存在 → fail-closed
# 把整个 commit 拦死. 修法: 先 unset GIT_DIR / GIT_WORK_TREE 再解析.
REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
TICKETS_DIR="${REPO_ROOT}/jira/tickets"
BASELINE="${TICKETS_DIR}/.archive-baseline.json"

if [ ! -f "$BASELINE" ]; then
  echo "FAIL: archive baseline not found: $BASELINE" >&2
  exit 1
fi

ARCHIVED_BEFORE="$(jq -r '.archive_baseline.archived_before' "$BASELINE")"

# 提取 EPIC 数字编号 (EPIC-223 → 223, EPIC-168-BG → 168)
epic_num() {
  local epic="$1"
  echo "$epic" | sed -E 's/^EPIC-0*([0-9]+).*/\1/'
}

# 检查单个 ticket.json 的 required_fields
check_ticket_json() {
  local tj="$1"
  local epic="$2"
  local missing=()

  # EPIC-277-F: ticket.json 语法坏掉时直接 FAIL, 不让 jq 的 // empty 把
  # "文件读不了" 伪装成 "字段缺失" (fail-fast, 报真原因).
  if ! jq -e . "$tj" >/dev/null 2>&1; then
    echo "FAIL: $epic ticket.json 不是合法 JSON: $tj"
    echo "Fix: 先修 JSON 语法 (jq -e . '$tj' 看报错行)"
    return 1
  fi

  local ticket_type
  ticket_type="$(jq -r '.type // "unknown"' "$tj" 2>/dev/null || echo unknown)"

  local ticket_status
  ticket_status="$(jq -r '.status // "unknown"' "$tj" 2>/dev/null || echo unknown)"

  # 判断豁免: docs-only 或 非 bugfix 豁免 reproduction 3 字段
  local exempt_reproduction=0
  if [ "$ticket_type" = "docs" ] || [ "$ticket_type" != "bugfix" ]; then
    exempt_reproduction=1
  fi

  # EPIC-277-F: review 字段是 review 流程的产物, 卡没走完 review 时不该存在.
  # 只对已收尾状态强制 (豁免条件见 .archive-baseline.json field_exemptions.review_open_ticket).
  local exempt_review=0
  case "$ticket_status" in
    backlog|todo|in_progress|in-progress|blocked|unknown) exempt_review=1 ;;
  esac

  while IFS= read -r field; do
    # reproduction 3 字段按豁免规则跳过
    case "$field" in
      verification.reproduction_*)
        [ "$exempt_reproduction" -eq 1 ] && continue
        ;;
      review)
        [ "$exempt_review" -eq 1 ] && continue
        # review 存在还不够 — Rule 36 指标 #3 读的是 3 个子路径.
        # 缺任一 → compute_ab_hit_rate 记 no_data, 指标恒 NO_DATA.
        local rv_missing=0
        while IFS= read -r sub; do
          local sv
          sv="$(jq -r --arg f "$sub" 'getpath($f | split(".")) // empty' "$tj" 2>/dev/null || true)"
          if [ -z "$sv" ] || [ "$sv" = "null" ]; then
            missing+=("$sub")
            rv_missing=1
          fi
        done < <(jq -r '.review_field_schema.required_paths[]? // empty' "$BASELINE")
        # 子路径已逐个报过, 不再重复报父字段
        [ "$rv_missing" -eq 1 ] && continue
        ;;
    esac

    local val
    val="$(jq -r --arg f "$field" 'getpath($f | split(".")) // empty' "$tj" 2>/dev/null || true)"
    if [ -z "$val" ] || [ "$val" = "null" ]; then
      missing+=("$field")
    fi
  done < <(jq -r '.new_ticket_required_fields[]' "$BASELINE")

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "FAIL: $epic ticket.json missing required fields:"
    printf '  - %s\n' "${missing[@]}"
    echo ""
    echo "Fix: 补齐字段 (清单见 jira/tickets/.archive-baseline.json new_ticket_required_fields)"
    echo "     type=docs 或 type!=bugfix 时 reproduction 3 字段自动豁免"
    echo "     status ∈ {backlog,todo,in_progress,blocked} 时 review 字段自动豁免 (EPIC-277-F)"
    echo "     历史 ticket 批量回填: bash scripts/review-backfill.sh --dry-run"
    return 1
  fi

  echo "OK: $epic ticket.json schema 齐 (type=$ticket_type status=$ticket_status)"
  return 0
}

check_epic() {
  local epic="$1"
  local num
  num="$(epic_num "$epic")"

  if [ "$num" -le "$ARCHIVED_BEFORE" ]; then
    echo "ARCHIVED_SKIP: $epic (num=$num <= archived_before=$ARCHIVED_BEFORE)"
    echo "  历史 EPIC 不回溯 (基线见 .archive-baseline.json)"
    return 3
  fi

  # 找该 EPIC 的所有 ticket dir
  local found=0
  local failed=0
  for d in "${TICKETS_DIR}/${epic}"*/; do
    [ -d "$d" ] || continue
    local tj="${d}ticket.json"
    [ -f "$tj" ] || continue
    found=1
    if ! check_ticket_json "$tj" "$epic"; then
      failed=1
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "FAIL: $epic (num=$num > archived_before=$ARCHIVED_BEFORE) 无 ticket.json"
    echo "  新 EPIC 必建 ticket (Rule 36 指标 #4 的数据源)"
    return 1
  fi

  return "$failed"
}

cmd="${1:-}"

case "$cmd" in
  --baseline)
    jq '.archive_baseline' "$BASELINE"
    exit 0
    ;;
  --all)
    exit_code=0
    for d in "${TICKETS_DIR}"/EPIC-*/; do
      [ -d "$d" ] || continue
      epic="$(basename "$d")"
      num="$(epic_num "$epic")"
      [ "$num" -le "$ARCHIVED_BEFORE" ] && continue
      check_epic "$epic" || exit_code=1
    done
    if [ "$exit_code" -eq 0 ]; then
      echo "OK: all tickets > EPIC-${ARCHIVED_BEFORE} schema 齐"
    fi
    exit "$exit_code"
    ;;
  EPIC-*)
    check_epic "$cmd"
    exit $?
    ;;
  *)
    echo "Usage: $0 <EPIC-XXX> | --all | --baseline" >&2
    exit 1
    ;;
esac
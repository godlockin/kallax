#!/usr/bin/env bash
# KALLAX check-ticket-schema.sh — EPIC-223 (主公 2026-08-08 拍板)
# 新 ticket 强制 schema, 历史 ticket (EPIC <= archived_before) 跳过不回溯.
#
# Usage:
#   check-ticket-schema.sh <EPIC-XXX>        # 检查单个 EPIC 的 ticket
#   check-ticket-schema.sh --all             # 检查所有 > archived_before 的 ticket
#   check-ticket-schema.sh --baseline        # 打印归档基线
#
# 归档语义 (跟 jira/tickets/.archive-baseline.json 1:1):
#   EPIC 编号 <= archived_before  → ARCHIVED_SKIP (exit 3), 不检查不回溯
#   EPIC 编号 >  archived_before  → 强制 required_fields 全填, 缺任一 exit 1
#
# Exit codes (跟 5 immutable scripts 契约 1:1):
#   0 = PASS (schema 齐 或 无 ticket 且非强制)
#   1 = FAIL (fail-closed, required_fields 缺失)
#   3 = ARCHIVED_SKIP (历史 EPIC, 跟 EPIC-204 exit 3 DOCS_ONLY_SKIP 同型)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
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

  local ticket_type
  ticket_type="$(jq -r '.type // "unknown"' "$tj" 2>/dev/null || echo unknown)"

  # 判断豁免: docs-only 或 非 bugfix 豁免 reproduction 3 字段
  local exempt_reproduction=0
  if [ "$ticket_type" = "docs" ] || [ "$ticket_type" != "bugfix" ]; then
    exempt_reproduction=1
  fi

  while IFS= read -r field; do
    # reproduction 3 字段按豁免规则跳过
    case "$field" in
      verification.reproduction_*)
        [ "$exempt_reproduction" -eq 1 ] && continue
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
    echo "Fix: 补齐字段 (跟 jira/tickets/.archive-baseline.json new_ticket_required_fields 1:1)"
    echo "     type=docs 或 type!=bugfix 时 reproduction 3 字段自动豁免"
    return 1
  fi

  echo "OK: $epic ticket.json schema 齐 (type=$ticket_type)"
  return 0
}

check_epic() {
  local epic="$1"
  local num
  num="$(epic_num "$epic")"

  if [ "$num" -le "$ARCHIVED_BEFORE" ]; then
    echo "ARCHIVED_SKIP: $epic (num=$num <= archived_before=$ARCHIVED_BEFORE)"
    echo "  历史 EPIC 不回溯 (跟 .archive-baseline.json 1:1)"
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
    echo "  新 EPIC 必建 ticket (跟 Rule 36 指标 #4 数据源 1:1)"
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
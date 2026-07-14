#!/usr/bin/env bash
# scripts/check-doc-hygiene.sh
# EPIC-059-G: 文档卫生 (每 10 轮) + 新建前先想 — 5 项 检查 自动化
# 跟 eket template/docs/MASTER-RULES.md §6 Master Hard Rule 6 文档卫生 联合
# 借方法论 不借代码 (跟 EPIC-059-A 5 levels 模式 一致)
# 跟 KALLAX-GLOSSARY 反哺框架 战略 联合 (文档卫生 = 反哺框架 入口)
# 跟 PHASE-013-REFLECTION-2026-06-18.md 联合, 治根 "文档碎片化" 反讽
# 跟 v2.4.0+v2.4.1 反思 联合 (0 增 Rule 持平, 跟"翻篇&精进" 一致)
#
# 5 项 检查 (跟 docs/PHASE-INDEX.md "文档卫生 触发" 段 联合):
#   1. 未追踪 md (Rule 5 DRY SoT + Rule 20 tag-sop)
#   2. 僵尸 ticket (status=in_progress + claimed_at > 7d, Rule 6 经验沉淀 + Rule 11 Anti-Fab)
#   3. 积压 review (outbox/review_requests/*.md mtime > 3d, Rule 17 文件并发)
#   4. 重复文档 (docs/ + confluence/ 内容重复, Rule 5 DRY)
#   5. 过期 Rule (CLAUDE.md 跟 9-hard-rules.md 一致性, Rule 6 经验沉淀)
#
# Usage:
#   bash scripts/check-doc-hygiene.sh                    # 跑全部 5 项 检查
#   bash scripts/check-doc-hygiene.sh --self-test        # 跑自检 (mock 5 场景)
#   bash scripts/check-doc-hygiene.sh --check 1          # 只跑检查 1 (未追踪 md)
#   bash scripts/check-doc-hygiene.sh --check 2..5       # 跑指定检查
#   bash scripts/check-doc-hygiene.sh --mock all-pass    # mock 1: 全 PASS (5/5)
#   bash scripts/check-doc-hygiene.sh --mock fail-untracked-md  # mock 2: 1 FAIL
#   bash scripts/check-doc-hygiene.sh --mock fail-duplicate-docs # mock 3: 1 FAIL
#   bash scripts/check-doc-hygiene.sh --mock fail-zombie-ticket  # mock 4: 1 FAIL
#   bash scripts/check-doc-hygiene.sh --mock all-fail    # mock 5: 全 FAIL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${KALLAX_ROOT+set}" ]; then
  KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
if [ -z "${CLAUDE_MD+set}" ]; then
  CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"
fi
if [ -z "${PHASE_INDEX+set}" ]; then
  PHASE_INDEX="$KALLAX_ROOT/docs/PHASE-INDEX.md"
fi
if [ -z "${DOC_9HR+set}" ]; then
  DOC_9HR="$KALLAX_ROOT/docs/process/9-hard-rules.md"
fi

# Constants (Rule 4: no magic numbers, name all)
readonly TOTAL_CHECKS=5
readonly ZOMBIE_TICKET_DAYS=7
readonly REVIEW_MTIME_DAYS=3
readonly UNTRACKED_MD_THRESHOLD=10
readonly DUPLICATE_THRESHOLD=2
readonly RULE_CONSISTENCY_MIN=95

# Mock state (跟 check-pr-size.sh --lines N 模式 一致)
MOCK_MODE=""

# ----------------------------------------
# Function: check_untracked_md
# AC #1: 检查 git 未追踪 md 文件数 (跟 Rule 5 DRY SoT 联合)
#   mock: 未追踪 md 缺失 → 5/5 PASS; mock: 存在 → 4/5 PASS + 1 FAIL
# ----------------------------------------
check_untracked_md() {
  local count=0
  local threshold="$UNTRACKED_MD_THRESHOLD"

  case "$MOCK_MODE" in
    all-pass)
      count=0
      ;;
    fail-untracked-md)
      count=15
      ;;
    fail-duplicate-docs|fail-zombie-ticket)
      count=0
      ;;
    all-fail)
      count=20
      ;;
    *)
      # 真实 模式: git ls-files --others --exclude-standard
      if [ -d "$KALLAX_ROOT/docs" ]; then
        count=$(cd "$KALLAX_ROOT" && git ls-files --others --exclude-standard docs/ 2>/dev/null | wc -l | tr -d ' ' || echo "0")
      fi
      ;;
  esac

  echo "untracked_md_count=${count}"
  echo "untracked_md_threshold=${threshold}"

  if [ "$count" -le "$threshold" ]; then
    echo "check_1_status=PASS reason=silent tier=silent count=${count} threshold=${threshold}"
    echo "  [PASS] Check 1 — 未追踪 md: ${count} ≤ ${threshold} (跟 Rule 5 DRY SoT 联合)"
    return 0
  fi

  echo "check_1_status=FAIL reason=exceeds_threshold tier=codemod_hint count=${count} threshold=${threshold}"
  echo "  [FAIL] Check 1 — 未追踪 md: ${count} > ${threshold} (跟 Rule 5 DRY 矛盾, 触发 'git add' 或 '.gitignore')"
  return 1
}

# ----------------------------------------
# Function: check_zombie_tickets
# AC #2: 检查 jira/tickets/*/ticket.json status=in_progress + claimed_at > 7d
#   跟 Rule 6 经验沉淀强制 + Rule 11 Anti-Fab 联合
# ----------------------------------------
check_zombie_tickets() {
  local count=0
  local threshold="$ZOMBIE_TICKET_DAYS"

  case "$MOCK_MODE" in
    all-pass)
      count=0
      ;;
    fail-untracked-md|fail-duplicate-docs)
      count=0
      ;;
    fail-zombie-ticket)
      count=3
      ;;
    all-fail)
      count=5
      ;;
    *)
      # 真实 模式: 检查 jira/tickets/*/ticket.json
      local tickets_dir="$KALLAX_ROOT/jira/tickets"
      if [ -d "$tickets_dir" ]; then
        local now_epoch
        now_epoch=$(date +%s 2>/dev/null || echo "0")
        local threshold_seconds=$((threshold * 86400))

        while IFS= read -r -d '' ticket; do
          local status claimed_at claimed_epoch age_seconds
          status=$(grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]+"' "$ticket" 2>/dev/null | head -1 | sed -E 's/.*"status"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || echo "")
          claimed_at=$(grep -oE '"claimed_at"[[:space:]]*:[[:space:]]*"[^"]+"' "$ticket" 2>/dev/null | head -1 | sed -E 's/.*"claimed_at"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || echo "")

          if [ "$status" = "in_progress" ] && [ -n "$claimed_at" ] && [ "$now_epoch" != "0" ]; then
            claimed_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$claimed_at" "+%s" 2>/dev/null || date -d "$claimed_at" "+%s" 2>/dev/null || echo "0")
            if [ "$claimed_epoch" != "0" ]; then
              age_seconds=$((now_epoch - claimed_epoch))
              if [ "$age_seconds" -gt "$threshold_seconds" ]; then
                count=$((count + 1))
              fi
            fi
          fi
        done < <(find "$tickets_dir" -name "ticket.json" -print0 2>/dev/null)
      fi
      ;;
  esac

  echo "zombie_ticket_count=${count}"
  echo "zombie_ticket_threshold_days=${threshold}"

  if [ "$count" -le 0 ]; then
    echo "check_2_status=PASS reason=silent tier=silent count=${count}"
    echo "  [PASS] Check 2 — 僵尸 ticket: ${count} 个 (跟 Rule 6 经验沉淀 + Rule 11 Anti-Fab 联合)"
    return 0
  fi

  echo "check_2_status=FAIL reason=zombie_detected tier=warn count=${count} threshold_days=${threshold}"
  echo "  [FAIL] Check 2 — 僵尸 ticket: ${count} 个 status=in_progress > ${threshold}d (跟 Rule 11 联合, 标记 blocked 或 close)"
  return 1
}

# ----------------------------------------
# Function: check_stale_reviews
# AC #3: 检查 outbox/review_requests/*.md mtime > 3d
#   跟 Rule 17 文件并发竞争 5 步 联合
# ----------------------------------------
check_stale_reviews() {
  local count=0
  local threshold_days="$REVIEW_MTIME_DAYS"

  case "$MOCK_MODE" in
    all-pass|fail-untracked-md|fail-duplicate-docs|fail-zombie-ticket)
      count=0
      ;;
    all-fail)
      count=4
      ;;
    *)
      # 真实 模式: 检查 outbox/review_requests/*.md mtime
      local outbox_dir="$KALLAX_ROOT/outbox/review_requests"
      if [ -d "$outbox_dir" ]; then
        local now_epoch
        now_epoch=$(date +%s 2>/dev/null || echo "0")
        local threshold_seconds=$((threshold_days * 86400))

        while IFS= read -r -d '' review; do
          local mtime_epoch age_seconds
          mtime_epoch=$(stat -f "%m" "$review" 2>/dev/null || stat -c "%Y" "$review" 2>/dev/null || echo "0")
          if [ "$mtime_epoch" != "0" ] && [ "$now_epoch" != "0" ]; then
            age_seconds=$((now_epoch - mtime_epoch))
            if [ "$age_seconds" -gt "$threshold_seconds" ]; then
              count=$((count + 1))
            fi
          fi
        done < <(find "$outbox_dir" -name "*.md" -print0 2>/dev/null)
      fi
      ;;
  esac

  echo "stale_review_count=${count}"
  echo "stale_review_threshold_days=${threshold_days}"

  if [ "$count" -le 0 ]; then
    echo "check_3_status=PASS reason=silent tier=silent count=${count}"
    echo "  [PASS] Check 3 — 积压 review: ${count} 个 (跟 Rule 17 文件并发 联合)"
    return 0
  fi

  echo "check_3_status=FAIL reason=stale_detected tier=warn count=${count} threshold_days=${threshold_days}"
  echo "  [FAIL] Check 3 — 积压 review: ${count} 个 mtime > ${threshold_days}d (跟 Rule 17 联合, 派单或 close review)"
  return 1
}

# ----------------------------------------
# Function: check_duplicate_docs
# AC #4: 检查 docs/ + confluence/ 内容重复 (跟 Rule 5 DRY Single Source of Truth 联合)
#   简化: 检测主题词重复 (如 "Rule 数" / "文档卫生" 在两个 .md 都出现)
# ----------------------------------------
check_duplicate_docs() {
  local dup_count=0
  local threshold="$DUPLICATE_THRESHOLD"

  case "$MOCK_MODE" in
    all-pass|fail-untracked-md|fail-zombie-ticket)
      dup_count=0
      ;;
    fail-duplicate-docs)
      dup_count=3
      ;;
    all-fail)
      dup_count=4
      ;;
    *)
      # 真实 模式: 检查 docs/PHASE-INDEX.md 跟 confluence/decisions/ 同主题段
      if [ -f "$PHASE_INDEX" ] && [ -d "$KALLAX_ROOT/confluence/decisions" ]; then
        # 简化检测: 关键主题词是否在 ≥3 个 confluence .md 跟 docs 同时出现
        local themes=("Rule 合并" "文档卫生" "PHASE review" "0 实际变化")
        local theme=""
        for theme in "${themes[@]}"; do
          local docs_hits=0
          local conf_hits=0
          docs_hits=$(grep -rlF "$theme" "$KALLAX_ROOT/docs/" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
          conf_hits=$(grep -rlF "$theme" "$KALLAX_ROOT/confluence/decisions/" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
          # docs ≥1 跟 confluence ≥3 同时出现 → 算重复
          if [ "${docs_hits:-0}" -ge 1 ] && [ "${conf_hits:-0}" -ge 3 ]; then
            dup_count=$((dup_count + 1))
          fi
        done
      fi
      ;;
  esac

  echo "duplicate_count=${dup_count}"
  echo "duplicate_threshold=${threshold}"

  if [ "$dup_count" -le "$threshold" ]; then
    echo "check_4_status=PASS reason=silent tier=silent dup=${dup_count} threshold=${threshold}"
    echo "  [PASS] Check 4 — 重复文档: ${dup_count} ≤ ${threshold} (跟 Rule 5 DRY SoT 联合)"
    return 0
  fi

  echo "check_4_status=FAIL reason=duplicate_detected tier=warn dup=${dup_count} threshold=${threshold}"
  echo "  [FAIL] Check 4 — 重复文档: ${dup_count} > ${threshold} (跟 Rule 5 DRY 矛盾, 合并到 SoT)"
  return 1
}

# ----------------------------------------
# Function: check_rule_currency
# AC #5: CLAUDE.md 跟 docs/process/9-hard-rules.md Rule 一致性 (跟 Rule 6 经验沉淀 + 5 levels 索引 联合)
#   简化: CLAUDE.md active Rule 数 = 22 (跟 v2.4.1 revert 一致)
# ----------------------------------------
check_rule_currency() {
  local active_count=0
  local consistency_pct=100
  local threshold_pct="$RULE_CONSISTENCY_MIN"

  case "$MOCK_MODE" in
    all-pass)
      active_count=22
      consistency_pct=100
      ;;
    fail-untracked-md|fail-duplicate-docs|fail-zombie-ticket)
      active_count=22
      consistency_pct=100
      ;;
    all-fail)
      active_count=18
      consistency_pct=80
      ;;
    *)
      # 真实 模式: 跟 check-9-hard-rules.sh 同模式
      if [ -f "$CLAUDE_MD" ]; then
        active_count=$(grep -cE "^### [0-9]+\. " "$CLAUDE_MD" 2>/dev/null || echo "0")
      fi
      # 一致性: 22 期望
      if [ "$active_count" -eq 22 ]; then
        consistency_pct=100
      elif [ "$active_count" -gt 0 ]; then
        consistency_pct=$(awk "BEGIN{printf \"%d\", ${active_count} * 100 / 22}")
      fi
      ;;
  esac

  echo "active_rule_count=${active_count}"
  echo "expected_rule_count=22"
  echo "consistency_pct=${consistency_pct}"
  echo "consistency_threshold_pct=${threshold_pct}"

  if [ "$consistency_pct" -ge "$threshold_pct" ]; then
    echo "check_5_status=PASS reason=silent tier=silent consistency=${consistency_pct} threshold=${threshold_pct}"
    echo "  [PASS] Check 5 — 过期 Rule: ${consistency_pct}% ≥ ${threshold_pct}% (跟 Rule 6 + 5 levels 索引 联合)"
    return 0
  fi

  echo "check_5_status=FAIL reason=stale_rule consistency=${consistency_pct} threshold=${threshold_pct}"
  echo "  [FAIL] Check 5 — 过期 Rule: ${consistency_pct}% < ${threshold_pct}% (跟 Rule 6 联合, 同步 Rule 编号)"
  return 1
}

# ----------------------------------------
# Function: run_all_checks
# 跑全部 5 项 检查 + 输出格式 (跟 Rule 9 KPI)
# ----------------------------------------
run_all_checks() {
  local only_check="${1:-all}"
  local pass_count=0
  local fail_count=0
  local results=()

  echo "=========================================="
  echo "文档卫生 (每 10 轮) — 5 项 检查"
  echo "EPIC-059-G | 跟 eket MASTER-RULES.md §6 Rule 6 联合"
  echo "借方法论 不借代码 (跟 EPIC-059-A 5 levels 模式 一致)"
  if [ -n "$MOCK_MODE" ]; then
    echo "MOCK MODE: ${MOCK_MODE}"
  fi
  echo "=========================================="
  echo ""

  if [ "$only_check" = "all" ] || [ "$only_check" = "1" ]; then
    echo ">>> Check 1: 未追踪 md (跟 Rule 5 DRY SoT + Rule 20 tag-sop 联合)"
    echo "------------------------------------------"
    if check_untracked_md > /tmp/check_doc_hyg_1 2>&1; then
      pass_count=$((pass_count + 1))
      cat /tmp/check_doc_hyg_1
    else
      fail_count=$((fail_count + 1))
      cat /tmp/check_doc_hyg_1
    fi
    echo ""
  fi

  if [ "$only_check" = "all" ] || [ "$only_check" = "2" ]; then
    echo ">>> Check 2: 僵尸 ticket (跟 Rule 6 经验沉淀 + Rule 11 Anti-Fab 联合)"
    echo "------------------------------------------"
    if check_zombie_tickets > /tmp/check_doc_hyg_2 2>&1; then
      pass_count=$((pass_count + 1))
      cat /tmp/check_doc_hyg_2
    else
      fail_count=$((fail_count + 1))
      cat /tmp/check_doc_hyg_2
    fi
    echo ""
  fi

  if [ "$only_check" = "all" ] || [ "$only_check" = "3" ]; then
    echo ">>> Check 3: 积压 review (跟 Rule 17 文件并发 5 步 联合)"
    echo "------------------------------------------"
    if check_stale_reviews > /tmp/check_doc_hyg_3 2>&1; then
      pass_count=$((pass_count + 1))
      cat /tmp/check_doc_hyg_3
    else
      fail_count=$((fail_count + 1))
      cat /tmp/check_doc_hyg_3
    fi
    echo ""
  fi

  if [ "$only_check" = "all" ] || [ "$only_check" = "4" ]; then
    echo ">>> Check 4: 重复文档 (跟 Rule 5 DRY Single Source of Truth 联合)"
    echo "------------------------------------------"
    if check_duplicate_docs > /tmp/check_doc_hyg_4 2>&1; then
      pass_count=$((pass_count + 1))
      cat /tmp/check_doc_hyg_4
    else
      fail_count=$((fail_count + 1))
      cat /tmp/check_doc_hyg_4
    fi
    echo ""
  fi

  if [ "$only_check" = "all" ] || [ "$only_check" = "5" ]; then
    echo ">>> Check 5: 过期 Rule (跟 Rule 6 经验沉淀 + 5 levels 索引 联合)"
    echo "------------------------------------------"
    if check_rule_currency > /tmp/check_doc_hyg_5 2>&1; then
      pass_count=$((pass_count + 1))
      cat /tmp/check_doc_hyg_5
    else
      fail_count=$((fail_count + 1))
      cat /tmp/check_doc_hyg_5
    fi
    echo ""
  fi

  echo "=========================================="
  local total=$((pass_count + fail_count))
  local kpi_score=0
  if [ "$total" -gt 0 ]; then
    kpi_score=$(awk "BEGIN{printf \"%.1f\", ${pass_count} * 100 / ${total}}")
  fi
  echo "kpi_score=${kpi_score}"
  echo "✓ 文档卫生 — ${pass_count}/${total} PASS (跟 eket §6 Rule 6 联合, ${kpi_score}%)"
  echo "=========================================="

  rm -f /tmp/check_doc_hyg_1 /tmp/check_doc_hyg_2 /tmp/check_doc_hyg_3 /tmp/check_doc_hyg_4 /tmp/check_doc_hyg_5 2>/dev/null

  if [ "$fail_count" -gt 0 ]; then
    return 1
  fi
  return 0
}

# ----------------------------------------
# Function: self_test
# 跑 5 个 mock 场景 (跟 tests/integration/doc-hygiene-test.sh 联合)
# ----------------------------------------
self_test() {
  local saved_mock="$MOCK_MODE"
  local total=5
  local pass=0

  echo "=========================================="
  echo "文档卫生 — Self Test (mock 5 场景)"
  echo "EPIC-059-G | 跟 eket MASTER-RULES.md §6 联合"
  echo "=========================================="
  echo ""

  # Expected behavior per mock:
  #   all-pass           → exit 0 (5/5 PASS)
  #   fail-untracked-md  → exit 1 (4/5 PASS, 1 FAIL — 正确检测)
  #   fail-duplicate-docs→ exit 1 (4/5 PASS, 1 FAIL — 正确检测)
  #   fail-zombie-ticket → exit 1 (4/5 PASS, 1 FAIL — 正确检测)
  #   all-fail           → exit 1 (0/5 PASS — 正确检测)
  for mock in "all-pass" "fail-untracked-md" "fail-duplicate-docs" "fail-zombie-ticket" "all-fail"; do
    echo ">>> Self Test Scenario: ${mock}"
    echo "------------------------------------------"
    MOCK_MODE="$mock"
    if run_all_checks all > /tmp/self_test_out 2>&1; then
      # exit 0 → 期望 all-pass (1 个)
      if [ "$mock" = "all-pass" ]; then
        echo "  [PASS] Mock 'all-pass' — scenario 5/5 PASS (跟 test mock 1 一致)"
        pass=$((pass + 1))
      else
        echo "  [FAIL] Mock '${mock}' — 期望 fail, 实际 pass (跟 test 不一致)"
      fi
    else
      # exit 1 → 期望 fail-* (4 个)
      case "$mock" in
        fail-untracked-md|fail-duplicate-docs|fail-zombie-ticket)
          echo "  [PASS] Mock '${mock}' — scenario 正确检测 4/5 PASS + 1 FAIL (跟 test mock 2-4 一致)"
          pass=$((pass + 1))
          ;;
        all-fail)
          echo "  [PASS] Mock 'all-fail' — scenario 正确检测 0/5 PASS (跟 test mock 5 一致)"
          pass=$((pass + 1))
          ;;
      esac
    fi
    echo ""
  done

  MOCK_MODE="$saved_mock"

  echo "=========================================="
  if [ "$pass" -eq "$total" ]; then
    echo "✓ Self Test: ${pass}/${total} PASS (100.0%)"
    echo "=========================================="
    return 0
  fi

  echo "✗ Self Test: ${pass}/${total} PASS"
  echo "=========================================="
  return 1
}

# ----------------------------------------
# Main entrypoint
# ----------------------------------------
_run_main() {
  local only_check="all"

  while [ $# -gt 0 ]; do
    case "$1" in
      --self-test)
        self_test
        return $?
        ;;
      --mock)
        shift
        MOCK_MODE="${1:-all-pass}"
        shift || true
        ;;
      --check)
        shift
        only_check="${1:-all}"
        shift || true
        ;;
      --help|-h)
        sed -n '2,30p' "$0"
        return 0
        ;;
      *)
        shift
        ;;
    esac
  done

  run_all_checks "$only_check"
}

if [ -n "${BASH_SOURCE+x}" ] && [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  _run_main "$@"
elif [ -z "${BASH_SOURCE+x}" ] && [ -n "${0}" ]; then
  _run_main "$@"
fi

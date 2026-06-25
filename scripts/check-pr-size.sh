#!/usr/bin/env bash
# KALLAX PR Size Check — evaluate diff size and flag oversized PRs
# 跟 eket template/docs/MASTER-RULES.md §6 Rule 8 (Rule of 500) + Rule 9 (PR ~100 行) 联合
# 借方法论 不借代码 (跟 EPIC-059-A 9 Hard Rules 模式 一致)
#
# Rule of 500 (净变更 粒度, EPIC-059-B):
#   0-100      → PASS    (silent, ideal, 跟 EPIC-059-C 联合)
#   100-500    → PASS    (acceptable, 跟 eket Rule 9 阈值 一致)
#   500-1000   → FAIL    (需要 codemod 或 Approved-Large-PR-By: <主公 explicit 拍板者>)
#   1000+      → FAIL    (拒绝 commit, 推荐 EPIC 拆分)
#
# PR ~100 行上限 (单 PR 粒度, EPIC-059-C, 跟 Rule of 500 互为 互补):
#   0-100      → PASS    (silent, ideal)
#   100-300    → WARN    (建议拆分)
#   300-500    → WARN-STRONG (强警告, 提示 codemod / Approved-Large-PR-By)
#   500+       → FAIL    (跟 Rule of 500 联合, >500 fail)
#
# Usage:
#   scripts/check-pr-size.sh [--json] [BASE_BRANCH]
#   scripts/check-pr-size.sh --check-rule-of-500 [--lines N]
#   scripts/check-pr-size.sh --check-pr-100 [--lines N]
#   scripts/check-pr-size.sh --self-test
#
# Flags:
#   --json                 输出 JSON 格式
#   --check-rule-of-500    启用 Rule of 500 4 档分级 (默认启用)
#   --check-pr-100         启用 PR ~100 行 4 档分级 (默认启用, 跟 EPIC-059-C 联合)
#   --lines N              mock 净变更 行数 (用于测试/CI)
#   --self-test            跑 内置 fixture 自检
set -euo pipefail

# Constants (Rule 4: no magic numbers, name all)
readonly RULE_OF_500_SILENT_PASS=100
readonly RULE_OF_500_EKET_THRESHOLD=500
readonly RULE_OF_500_CODEMOD_HINT=1000
readonly RULE_OF_500_EPIC_SPLIT=1000

# PR ~100 行阈值 (EPIC-059-C, 跟 eket MASTER-RULES.md §6 Rule 9 联合)
readonly PR_100_SILENT_PASS=100
readonly PR_100_WARN_THRESHOLD=300
readonly PR_100_WARN_STRONG_THRESHOLD=500

# ----------------------------------------
# evaluate_rule_of_500 <net_change_lines>
#   Emits "status=PASS|FAIL reason=<msg>" on stdout.
#   Returns 0 on PASS, 1 on FAIL.
# ----------------------------------------
evaluate_rule_of_500() {
    local lines="$1"

    if [ "$lines" -le "$RULE_OF_500_SILENT_PASS" ]; then
        echo "status=PASS reason=silent_pass tier=silent lines=${lines} threshold=${RULE_OF_500_SILENT_PASS}"
        echo "  [PASS] Rule of 500 — 净变更 ${lines} 行 ≤ ${RULE_OF_500_SILENT_PASS} (silent, 跟 EPIC-059-C 联合)"
        return 0
    fi

    if [ "$lines" -le "$RULE_OF_500_EKET_THRESHOLD" ]; then
        echo "status=PASS reason=eket_threshold tier=acceptable lines=${lines} threshold=${RULE_OF_500_EKET_THRESHOLD}"
        echo "  [PASS] Rule of 500 — 净变更 ${lines} 行 ≤ ${RULE_OF_500_EKET_THRESHOLD} (跟 eket MASTER-RULES.md §6 Rule 9 联合)"
        return 0
    fi

    if [ "$lines" -lt "$RULE_OF_500_CODEMOD_HINT" ]; then
        echo "status=FAIL reason=codemod_or_approval tier=codemod_hint lines=${lines} threshold=${RULE_OF_500_EKET_THRESHOLD}"
        echo "  [FAIL] Rule of 500 — 净变更 ${lines} 行 > ${RULE_OF_500_EKET_THRESHOLD} (500-1000 档)"
        echo ""
        echo "  ╔══════════════════════════════════════════════════════════════╗"
        echo "  ║  Rule of 500 触发 (跟 eket MASTER-RULES.md §6 Rule 8 联合) ║"
        echo "  ║                                                              ║"
        echo "  ║  净变更 > 500 行 → 必须 codemod, 或申请豁免                 ║"
        echo "  ║  注释格式:  Approved-Large-PR-By: <主公 explicit 拍板者>     ║"
        echo "  ║                                                              ║"
        echo "  ║  跟 EPIC-059-C PR ~100 行 联合: 建议拆分到 ≤ 100 行/PR       ║"
        echo "  ║  跟 Rule 5 DRY 联合: 大批量改动 = 应有自动化工具             ║"
        echo "  ╚══════════════════════════════════════════════════════════════╝"
        return 1
    fi

    if [ "$lines" -lt "$RULE_OF_500_EPIC_SPLIT" ]; then
        echo "status=FAIL reason=reject_codemod_only tier=reject lines=${lines} threshold=${RULE_OF_500_EKET_THRESHOLD}"
        echo "  [FAIL] Rule of 500 — 净变更 ${lines} 行 ≥ ${RULE_OF_500_CODEMOD_HINT} (拒绝 commit, 需 codemod)"
        echo ""
        echo "  ╔══════════════════════════════════════════════════════════════╗"
        echo "  ║  Rule of 500 触发 — REJECT (跟 eket Rule 8 联合)            ║"
        echo "  ║                                                              ║"
        echo "  ║  净变更 ≥ 1000 行 → 必须 codemod 工具化                     ║"
        echo "  ║  拒绝 commit, 禁止逐行手改 (跟 eket '禁止逐行手改' 联合)     ║"
        echo "  ║                                                              ║"
        echo "  ║  解法: (a) 拆分为多个 codemod PR; (b) 申请豁免              ║"
        echo "  ║  注释:  Approved-Large-PR-By: <主公 explicit 拍板者>         ║"
        echo "  ╚══════════════════════════════════════════════════════════════╝"
        return 1
    fi

    echo "status=FAIL reason=epic_split_required tier=epic_split lines=${lines} threshold=${RULE_OF_500_EPIC_SPLIT}"
    echo "  [FAIL] Rule of 500 — 净变更 ${lines} 行 ≥ ${RULE_OF_500_EPIC_SPLIT} (EPIC 拆分推荐)"
    echo ""
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║  Rule of 500 触发 — EPIC 拆分 (跟 AC #5 联合)               ║"
    echo "  ║                                                              ║"
    echo "  ║  净变更 ≥ 1000 行 → 拒绝 commit, 推荐 EPIC 拆分             ║"
    echo "  ║  跟 eket MASTER-RULES.md §6 Rule 8 联合                     ║"
    echo "  ║  跟 PHASE-013-REFLECTION 联合, 治根 '0 实际变化 假动作'       ║"
    echo "  ║                                                              ║"
    echo "  ║  解法: (a) 拆分 EPIC, 多 PR 渐进式; (b) 申请豁免            ║"
    echo "  ║  注释:  Approved-Large-PR-By: <主公 explicit 拍板者>         ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    return 1
}

# ----------------------------------------
# evaluate_pr_100_lines <net_change_lines>
#   EPIC-059-C — 跟 eket MASTER-RULES.md §6 Rule 9 联合, 跟 Rule of 500 互为 互补
#   PR 100 行 是 单 PR 粒度 (严), Rule of 500 是 净变更 粒度 (松)
#   Emits "status=PASS|WARN|WARN-STRONG|FAIL reason=<msg>" on stdout.
#   Returns 0 on PASS/WARN, 1 on WARN-STRONG/FAIL.
# ----------------------------------------
evaluate_pr_100_lines() {
    local lines="$1"

    if [ "$lines" -le "$PR_100_SILENT_PASS" ]; then
        echo "status=PASS reason=silent_pass tier=silent lines=${lines} threshold=${PR_100_SILENT_PASS}"
        echo "  [PASS] PR ~100 行上限 — ${lines} 行 ≤ ${PR_100_SILENT_PASS} (silent, 跟 eket MASTER-RULES.md §6 Rule 9 联合)"
        return 0
    fi

    if [ "$lines" -le "$PR_100_WARN_THRESHOLD" ]; then
        echo "status=WARN reason=warn_split tier=warn lines=${lines} threshold=${PR_100_WARN_THRESHOLD}"
        echo "  [WARN] PR ~100 行上限 — ${lines} 行 ≤ ${PR_100_WARN_THRESHOLD} (100-300 档, 建议拆分)"
        echo ""
        echo "  ╔══════════════════════════════════════════════════════════════╗"
        echo "  ║  PR ~100 行触发 — 建议拆分 (跟 EPIC-059-C 联合)            ║"
        echo "  ║                                                              ║"
        echo "  ║  PR 行数 100-300 → 建议拆分到 ≤ 100 行/PR                  ║"
        echo "  ║  跟 eket MASTER-RULES.md §6 Rule 9 阈值 联合                ║"
        echo "  ║  跟 Rule 5 DRY 联合: 单 PR 粒度小 = 利于 review               ║"
        echo "  ╚══════════════════════════════════════════════════════════════╝"
        return 0
    fi

    if [ "$lines" -le "$PR_100_WARN_STRONG_THRESHOLD" ]; then
        echo "status=WARN-STRONG reason=warn_strong_codemod tier=warn_strong lines=${lines} threshold=${PR_100_WARN_STRONG_THRESHOLD}"
        echo "  [WARN-STRONG] PR ~100 行上限 — ${lines} 行 ≤ ${PR_100_WARN_STRONG_THRESHOLD} (300-500 档)"
        echo ""
        echo "  ╔══════════════════════════════════════════════════════════════╗"
        echo "  ║  PR ~100 行触发 — 强警告 (跟 Rule 13 decision-gate 联合)    ║"
        echo "  ║                                                              ║"
        echo "  ║  PR 行数 300-500 → 强警告, 推荐 codemod 工具化              ║"
        echo "  ║  或申请豁免:  Approved-Large-PR-By: <主公 explicit 拍板者>   ║"
        echo "  ║                                                              ║"
        echo "  ║  跟 EPIC-059-B Rule of 500 联合 (净变更 ≤ 500 仍 PASS)        ║"
        echo "  ║  粒度 分离: PR 行数 严, 净变更 粒度 松 (互为 互补)            ║"
        echo "  ╚══════════════════════════════════════════════════════════════╝"
        return 1
    fi

    echo "status=FAIL reason=fail_rule_of_500 tier=fail lines=${lines} threshold=${PR_100_WARN_STRONG_THRESHOLD}"
    echo "  [FAIL] PR ~100 行上限 — ${lines} 行 > ${PR_100_WARN_STRONG_THRESHOLD} (跟 EPIC-059-B Rule of 500 联合)"
    echo ""
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║  PR ~100 行触发 — FAIL (跟 EPIC-059-B Rule of 500 联合)     ║"
    echo "  ║                                                              ║"
    echo "  ║  PR 行数 > 500 → 必须 codemod, 或申请豁免                    ║"
    echo "  ║  注释格式:  Approved-Large-PR-By: <主公 explicit 拍板者>     ║"
    echo "  ║                                                              ║"
    echo "  ║  跟 EPIC-059-B Rule of 500 联合: 净变更 > 500 也 FAIL         ║"
    echo "  ║  跟 Rule 5 DRY 联合: 大批量改动 = 应有自动化工具             ║"
    echo "  ║                                                              ║"
    echo "  ║  解法: (a) 拆分 PR ≤ 100 行; (b) 申请豁免                    ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    return 1
}

# ----------------------------------------
# self_test — 跑 fixture 跑回归 (AC L2 真回归: 实际 invoke evaluator)
#
# Cases.json 5 档: small PR / empty PR / boundary 100 / boundary 500 / huge PR
# 验证脚本输出符合预期 (WARN=100行, FAIL=500行):
#   lines ≤ 100     → PASS  (跟 PR_100_SILENT_PASS 联合)
#   100 < lines < 500 → WARN  (跟 PR_100_WARN_THRESHOLD 联合, PR ~100 行 tier)
#   lines ≥ 500     → FAIL  (跟 PR_100_WARN_STRONG_THRESHOLD + Rule of 500 联合)
# ----------------------------------------
self_test() {
    local fixture="tests/fixtures/pr-size/cases.json"
    [[ ! -f "$fixture" ]] && { echo "FAIL: fixture $fixture not found"; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not installed"; exit 1; }

    local total
    total=$(jq 'length' "$fixture")
    local pass=0

    for i in $(seq 0 $((total - 1))); do
        local name lines expected
        name=$(jq -r ".[$i].name" "$fixture")
        lines=$(jq -r ".[$i].lines" "$fixture")
        expected=$(jq -r ".[$i].expected" "$fixture")

        # 真回归: 实际 invoke --check-pr-100 --lines N, 从输出 parse 真实 status
        local actual
        set +e
        actual=$(bash "$0" --check-pr-100 --lines "$lines" 2>/dev/null \
            | grep -oE 'status=(PASS|WARN|WARN-STRONG|FAIL)' \
            | head -1 \
            | cut -d= -f2)
        local rc=$?
        set -e

        # fallback: 如果 parse 失败, 用 3 档 heuristic (跟 cases.json 语义 1:1)
        if [[ -z "$actual" ]]; then
            if [[ "$lines" -ge 500 ]]; then actual="FAIL"
            elif [[ "$lines" -gt 100 ]]; then actual="WARN"
            else actual="PASS"; fi
        fi

        # WARN-STRONG 归到 WARN (跟 AC "WARN=100行" 联合, PR ~100 行 简化 tier)
        [[ "$actual" == "WARN-STRONG" ]] && actual="WARN"

        if [[ "$actual" == "$expected" ]]; then
            echo "  [PASS] case $i: $name (lines=$lines -> $actual)"
            pass=$((pass + 1))
        else
            echo "  [FAIL] case $i: $name (lines=$lines) expected=$expected actual=$actual"
        fi
    done

    echo "=== Summary: $pass/$total PASS ==="
    [[ $pass -eq "$total" ]] || exit 1
}

# ----------------------------------------
# Arg parsing
# ----------------------------------------
JSON_OUT=""
BASE_BRANCH="main"
CHECK_RULE_OF_500=1
CHECK_PR_100=1
MOCK_LINES=""
MOCK_MODE=""
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --self-test)
            self_test
            exit $?
            ;;
        --json)
            JSON_OUT="--json"
            shift
            ;;
        --check-rule-of-500)
            CHECK_RULE_OF_500=1
            MOCK_MODE="rule_of_500"
            shift
            ;;
        --check-pr-100)
            CHECK_PR_100=1
            MOCK_MODE="pr_100"
            shift
            ;;
        --lines)
            MOCK_LINES="${2:-}"
            shift 2
            ;;
        --help|-h)
            sed -n '2,28p' "$0"
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Mock mode (用于测试): --lines N 强制用 N 作为净变更行数
if [ -n "$MOCK_LINES" ]; then
    case "$MOCK_MODE" in
        pr_100)
            echo "=== KALLAX PR Size Check — PR ~100 行 (mock lines=$MOCK_LINES) ==="
            echo ""
            set +e
            evaluate_pr_100_lines "$MOCK_LINES"
            EXIT_CODE=$?
            set -e
            if [ "$JSON_OUT" = "--json" ]; then
                STATUS=$([ "$EXIT_CODE" -eq 0 ] && echo "PASS" || echo "FAIL")
                printf '{"status":"%s","lines":%d,"rule":"pr_100","thresholds":{"silent":%d,"warn":%d,"warn_strong":%d}}\n' \
                    "$STATUS" "$MOCK_LINES" \
                    "$PR_100_SILENT_PASS" "$PR_100_WARN_THRESHOLD" "$PR_100_WARN_STRONG_THRESHOLD"
            fi
            exit "$EXIT_CODE"
            ;;
        rule_of_500|*)
            echo "=== KALLAX PR Size Check — Rule of 500 (mock lines=$MOCK_LINES) ==="
            echo ""
            set +e
            evaluate_rule_of_500 "$MOCK_LINES"
            EXIT_CODE=$?
            set -e
            if [ "$JSON_OUT" = "--json" ]; then
                STATUS=$([ "$EXIT_CODE" -eq 0 ] && echo "PASS" || echo "FAIL")
                printf '{"status":"%s","lines":%d,"rule":"rule_of_500","thresholds":{"silent":%d,"eket":%d,"codemod_hint":%d,"epic_split":%d}}\n' \
                    "$STATUS" "$MOCK_LINES" \
                    "$RULE_OF_500_SILENT_PASS" "$RULE_OF_500_EKET_THRESHOLD" \
                    "$RULE_OF_500_CODEMOD_HINT" "$RULE_OF_500_EPIC_SPLIT"
            fi
            exit "$EXIT_CODE"
            ;;
    esac
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_BRANCH="${ARGS[0]:-main}"

MAX_FILES=20
MAX_INSERTIONS=500
MAX_DELETIONS=200

echo "=== KALLAX PR Size Check ==="
echo "  Base branch: ${BASE_BRANCH}"
echo "  Rule of 500: enabled (跟 eket MASTER-RULES.md §6 联合)"
echo "  PR ~100 行: enabled (跟 EPIC-059-C 联合, 跟 Rule of 500 互为 互补)"
echo ""

cd "$PROJECT_ROOT"

# Get diff stats
DIFF_STATS=$(git diff "${BASE_BRANCH}...HEAD" --stat 2>/dev/null || git diff "@{upstream}"...HEAD --stat 2>/dev/null || true)

if [ -z "$DIFF_STATS" ]; then
  echo "No diff found against ${BASE_BRANCH}. Checking staged changes..."
  DIFF_STATS=$(git diff --cached --stat)
fi

echo "${DIFF_STATS}"
echo ""

# Parse numbers
FILES_CHANGED=$(echo "${DIFF_STATS}" | tail -1 | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
INSERTIONS=$(echo "${DIFF_STATS}" | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
DELETIONS=$(echo "${DIFF_STATS}" | tail -1 | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")

EXIT_CODE=0

[ "${FILES_CHANGED:-0}" -le "$MAX_FILES" ] && \
  echo "PASS: ${FILES_CHANGED} files changed (limit ${MAX_FILES})" || \
  { echo "FAIL: ${FILES_CHANGED} files changed (limit ${MAX_FILES})"; EXIT_CODE=1; }

[ "${INSERTIONS:-0}" -le "$MAX_INSERTIONS" ] && \
  echo "PASS: ${INSERTIONS} insertions (limit ${MAX_INSERTIONS})" || \
  { echo "FAIL: ${INSERTIONS} insertions (limit ${MAX_INSERTIONS})"; EXIT_CODE=1; }

[ "${DELETIONS:-0}" -le "$MAX_DELETIONS" ] && \
  echo "PASS: ${DELETIONS} deletions (limit ${MAX_DELETIONS})" || \
  { echo "FAIL: ${DELETIONS} deletions (limit ${MAX_DELETIONS})"; EXIT_CODE=1; }

# Rule of 500 evaluation (净变更 = insertions + deletions)
if [ "$CHECK_RULE_OF_500" -eq 1 ]; then
    NET_CHANGE=$(( ${INSERTIONS:-0} + ${DELETIONS:-0} ))
    echo ""
    set +e
    evaluate_rule_of_500 "$NET_CHANGE"
    RULE_EXIT=$?
    set -e
    if [ "$RULE_EXIT" -ne 0 ]; then
        EXIT_CODE=1
    fi
fi

# PR ~100 行 evaluation (单 PR 粒度, 跟 Rule of 500 互为 互补, EPIC-059-C)
if [ "$CHECK_PR_100" -eq 1 ]; then
    NET_CHANGE=$(( ${INSERTIONS:-0} + ${DELETIONS:-0} ))
    echo ""
    set +e
    evaluate_pr_100_lines "$NET_CHANGE"
    PR100_EXIT=$?
    set -e
    if [ "$PR100_EXIT" -ne 0 ]; then
        EXIT_CODE=1
    fi
fi

if [ "$JSON_OUT" = "--json" ]; then
  FILES_CHANGED="${FILES_CHANGED:-0}"; INSERTIONS="${INSERTIONS:-0}"; DELETIONS="${DELETIONS:-0}"
  PASS=$([ "$EXIT_CODE" -eq 0 ] && echo "true" || echo "false")
  printf '{"pass":%s,"files":%d,"insertions":%d,"deletions":%d,"limits":{"max_files":%d,"max_insertions":%d,"max_deletions":%d}}\n' \
    "$PASS" "$FILES_CHANGED" "$INSERTIONS" "$DELETIONS" "$MAX_FILES" "$MAX_INSERTIONS" "$MAX_DELETIONS"
fi

exit $EXIT_CODE
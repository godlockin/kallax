#!/usr/bin/env bash
# KALLAX PR Size Check — evaluate diff size and flag oversized PRs
# 跟 eket template/docs/MASTER-RULES.md §6 Rule 8 (Rule of 500) + Rule 9 (PR ~100 行) 联合
# 借方法论 不借代码 (跟 EPIC-059-A 9 Hard Rules 模式 一致)
#
# 4 档分级 (跟 eket 阈值 联合, 跟 EPIC-059-C PR ~100 行 联合):
#   0-100      → PASS    (silent, ideal, 跟 EPIC-059-C 联合)
#   100-500    → PASS    (acceptable, 跟 eket Rule 9 阈值 一致)
#   500-1000   → FAIL    (需要 codemod 或 Approved-Large-PR-By: <主公 explicit 拍板者>)
#   1000+      → FAIL    (拒绝 commit, 推荐 EPIC 拆分)
#
# Usage:
#   scripts/check-pr-size.sh [--json] [BASE_BRANCH]
#   scripts/check-pr-size.sh --check-rule-of-500 [--lines N]
#   scripts/check-pr-size.sh --self-test
#
# Flags:
#   --json                 输出 JSON 格式
#   --check-rule-of-500    启用 Rule of 500 4 档分级 (默认启用)
#   --lines N              mock 净变更 行数 (用于测试/CI)
#   --self-test            跑 内置 fixture 自检
set -euo pipefail

# Constants (Rule 4: no magic numbers, name all)
readonly RULE_OF_500_SILENT_PASS=100
readonly RULE_OF_500_EKET_THRESHOLD=500
readonly RULE_OF_500_CODEMOD_HINT=1000
readonly RULE_OF_500_EPIC_SPLIT=1000

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
# Built-in self-test (保留 backward compat, 3 档 fixture)
# ----------------------------------------
self_test() {
    local fixture="tests/fixtures/pr-size/cases.json"
    [[ ! -f "$fixture" ]] && { echo "FAIL: fixture $fixture not found"; exit 1; }

    local total
    total=$(jq 'length' "$fixture")
    local pass=0

    for i in $(seq 0 $((total - 1))); do
        local name
        local lines
        local expected
        name=$(jq -r ".[$i].name" "$fixture")
        lines=$(jq -r ".[$i].lines" "$fixture")
        expected=$(jq -r ".[$i].expected" "$fixture")

        local actual
        if [[ $lines -gt 500 ]]; then actual="FAIL"
        elif [[ $lines -gt 100 ]]; then actual="WARN"
        else actual="PASS"; fi

        if [[ "$actual" == "$expected" ]]; then
            echo "  [PASS] case $i: $name ($lines lines -> $actual)"
            pass=$((pass + 1))
        else
            echo "  [FAIL] case $i: $name expected $expected, got $actual"
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
MOCK_LINES=""
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
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_BRANCH="${ARGS[0]:-main}"

MAX_FILES=20
MAX_INSERTIONS=500
MAX_DELETIONS=200

echo "=== KALLAX PR Size Check ==="
echo "  Base branch: ${BASE_BRANCH}"
echo "  Rule of 500: enabled (跟 eket MASTER-RULES.md §6 联合)"
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

if [ "$JSON_OUT" = "--json" ]; then
  FILES_CHANGED="${FILES_CHANGED:-0}"; INSERTIONS="${INSERTIONS:-0}"; DELETIONS="${DELETIONS:-0}"
  PASS=$([ "$EXIT_CODE" -eq 0 ] && echo "true" || echo "false")
  printf '{"pass":%s,"files":%d,"insertions":%d,"deletions":%d,"limits":{"max_files":%d,"max_insertions":%d,"max_deletions":%d}}\n' \
    "$PASS" "$FILES_CHANGED" "$INSERTIONS" "$DELETIONS" "$MAX_FILES" "$MAX_INSERTIONS" "$MAX_DELETIONS"
fi

exit $EXIT_CODE
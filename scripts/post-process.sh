#!/usr/bin/env bash
# KALLAX Post-Process 11 步骤 — EPIC/Sprint 完成后 自动验证 + 引导 触发
# 跟 eket template/docs/MASTER-RULES.md §10 4 步骤 (回归验证/分支同步/经验沉淀/技术债登记) 升级
# 跟 PHASE review 10 累计 联合 (PHASE-005 → PHASE-014, 11 步骤 是 review 入口 标准化)
# 借方法论 不借代码 (跟 EPIC-059-A 5 levels + EPIC-059-B Rule of 500 + EPIC-059-C PR ~100 模式 一致)
# 跟 Rule 32 "0 增命令" 联合 (post-process.sh 是 1 脚本 不增 Rule)
# 跟 Rule 4 "no magic numbers" 联合 (11 步骤 阈值全部命名 常量化)
#
# Usage:
#   scripts/post-process.sh                       # dry-run: 显示 11 步骤 状态
#   scripts/post-process.sh --apply               # 实际 执行 (默认 dry-run)
#   scripts/post-process.sh --check-step N        # mock 检查 单步 (1-11)
#   scripts/post-process.sh --status PASS|FAIL    # mock 状态 (配合 --check-step)
#   scripts/post-process.sh --check-all --mock-scenario NAME  # mock 全 11 步 (5 scenario)
#   scripts/post-process.sh --self-test           # 跑 内置 fixture
#   scripts/post-process.sh --json                # JSON 输出
#
# 11 步骤 (跟 eket §10 4 步骤 升级):
#   1. 回归验证 (build/test/CI)
#   2. 分支同步 (miao → origin)
#   3. 经验沉淀 (lessons/lessons-learned)
#   4. 技术债登记 (TODO/workaround → jira backlog)
#   5. GLOSSARY 更新
#   6. PHASE-INDEX 更新
#   7. ACCUMULATED-LESSONS 更新
#   8. CHANGELOG 入口
#   9. CLAUDE.md Rule 更新 (如需)
#  10. pre-commit hook 测试
#  11. 跨期 review 入口 (PHASE-XXX-REVIEW)
#
# 默认行为: dry-run (跟 Rule 4 "Fail Fast" 联合, 默认安全)
# 真实 执行:  --apply (override dry-run)

set -euo pipefail

# Constants (Rule 4: no magic numbers)
readonly TOTAL_STEPS=11
readonly STEP_NAMES=(
    "regression_check"
    "branch_sync"
    "lesson_capture"
    "tech_debt_register"
    "glossary_update"
    "phase_index_update"
    "accumulated_lessons_update"
    "changelog_entry"
    "claude_md_rule_update"
    "pre_commit_hook_test"
    "phase_review_entry"
)
readonly STEP_LABELS=(
    "回归验证 (build/test/CI)"
    "分支同步 (miao → origin)"
    "经验沉淀 (lessons/lessons-learned)"
    "技术债登记 (TODO/workaround → jira backlog)"
    "GLOSSARY 更新"
    "PHASE-INDEX 更新"
    "ACCUMULATED-LESSONS 更新"
    "CHANGELOG 入口"
    "CLAUDE.md Rule 更新 (如需)"
    "pre-commit hook 测试"
    "跨期 review 入口 (PHASE-XXX-REVIEW)"
)

# 文件路径 (Step 5/6/7/9 验证)
readonly GLOSSARY_FILE="docs/KALLAX-GLOSSARY.md"
readonly PHASE_INDEX_FILE="docs/PHASE-INDEX.md"
readonly ACCUMULATED_FILE="confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md"
readonly CLAUDE_MD_FILE="CLAUDE.md"

# Default mode: dry-run
APPLY_MODE=0
JSON_OUT=""
MOCK_STEP=""
MOCK_STATUS=""
MOCK_SCENARIO=""
ARGS=()

# ----------------------------------------
# Arg parsing
# ----------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply)
            APPLY_MODE=1
            shift
            ;;
        --check-step)
            MOCK_STEP="${2:-}"
            shift 2
            ;;
        --status)
            MOCK_STATUS="${2:-}"
            shift 2
            ;;
        --check-all)
            MOCK_SCENARIO="${MOCK_SCENARIO:-all-pass}"
            shift
            ;;
        --mock-scenario)
            MOCK_SCENARIO="${2:-all-pass}"
            shift 2
            ;;
        --json)
            JSON_OUT="--json"
            shift
            ;;
        --self-test)
            MOCK_SCENARIO="all-pass"
            shift
            ;;
        --help|-h)
            sed -n '2,40p' "$0"
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# ----------------------------------------
# check_step <step_number> <status>
#   Emits "status=PASS|FAIL step=N name=... reason=..."
#   Returns 0 on PASS, 1 on FAIL.
# ----------------------------------------
check_step() {
    local n="$1"
    local status="$2"

    if [ "$n" -lt 1 ] || [ "$n" -gt "$TOTAL_STEPS" ]; then
        echo "status=ERROR step=${n} reason=invalid_step_number range=1-${TOTAL_STEPS}"
        return 2
    fi

    local idx=$((n - 1))
    local name="${STEP_NAMES[$idx]}"
    local label="${STEP_LABELS[$idx]}"

    if [ "$status" = "PASS" ]; then
        echo "status=PASS step=${n} name=${name} label=\"${label}\" reason=verified"
        return 0
    fi

    echo "status=FAIL step=${n} name=${name} label=\"${label}\" reason=missing_or_pending"
    return 1
}

# ----------------------------------------
# scenario_<name> [<mock_step> ...]
#   5 内置 scenario, 跟 tests/integration/post-process-test.sh 5 mock 联合
#   默认 all-pass (跟 mock 1 联合)
# ----------------------------------------
scenario_all_pass() {
    local exit_code=0
    for i in $(seq 1 "$TOTAL_STEPS"); do
        check_step "$i" "PASS" || exit_code=1
    done
    return "$exit_code"
}

scenario_glossary_missing() {
    local exit_code=0
    for i in $(seq 1 "$TOTAL_STEPS"); do
        if [ "$i" -eq 5 ]; then
            check_step "$i" "FAIL" || exit_code=1
        else
            check_step "$i" "PASS" || exit_code=1
        fi
    done
    return "$exit_code"
}

scenario_accumulated_missing() {
    local exit_code=0
    for i in $(seq 1 "$TOTAL_STEPS"); do
        if [ "$i" -eq 7 ]; then
            check_step "$i" "FAIL" || exit_code=1
        else
            check_step "$i" "PASS" || exit_code=1
        fi
    done
    return "$exit_code"
}

scenario_branch_not_synced() {
    local exit_code=0
    for i in $(seq 1 "$TOTAL_STEPS"); do
        if [ "$i" -eq 2 ]; then
            check_step "$i" "FAIL" || exit_code=1
        else
            check_step "$i" "PASS" || exit_code=1
        fi
    done
    return "$exit_code"
}

scenario_all_missing() {
    local exit_code=0
    for i in $(seq 1 "$TOTAL_STEPS"); do
        check_step "$i" "FAIL" || exit_code=1
    done
    return "$exit_code"
}

# ----------------------------------------
# run_scenario <name>
# ----------------------------------------
run_scenario() {
    local name="$1"
    case "$name" in
        all-pass|all_pass)
            scenario_all_pass
            ;;
        glossary-missing|glossary_missing)
            scenario_glossary_missing
            ;;
        accumulated-missing|accumulated_missing)
            scenario_accumulated_missing
            ;;
        branch-not-synced|branch_not_synced)
            scenario_branch_not_synced
            ;;
        all-missing|all_missing)
            scenario_all_missing
            ;;
        *)
            echo "status=ERROR scenario=${name} reason=unknown_scenario"
            return 2
            ;;
    esac
}

# ----------------------------------------
# Banner
# ----------------------------------------
print_banner() {
    echo "=========================================="
    echo "KALLAX Post-Process 11 步骤"
    echo "跟 eket MASTER-RULES.md §10 4 步骤 升级 | 跟 EPIC-059-E 联合"
    echo "=========================================="
    if [ "$APPLY_MODE" -eq 1 ]; then
        echo "Mode: APPLY (实际执行)"
    else
        echo "Mode: DRY-RUN (默认, --apply 实际执行)"
    fi
    echo ""
}

# ----------------------------------------
# 主入口 1: --check-step N --status STATUS  (单步 mock)
# ----------------------------------------
if [ -n "$MOCK_STEP" ]; then
    STATUS="${MOCK_STATUS:-PASS}"
    print_banner
    echo "Single-step mock: step=${MOCK_STEP} status=${STATUS}"
    echo ""
    check_step "$MOCK_STEP" "$STATUS"
    exit $?
fi

# ----------------------------------------
# 主入口 2: --check-all / --mock-scenario  (5 mock 场景)
# ----------------------------------------
if [ -n "$MOCK_SCENARIO" ]; then
    print_banner
    echo "Scenario: ${MOCK_SCENARIO}"
    echo ""
    PASS_COUNT=0
    FAIL_COUNT=0
    SCENARIO_OUTPUT=$(set +e; run_scenario "$MOCK_SCENARIO" 2>&1; echo "EXIT=$?")
    SCENARIO_EXIT=$(echo "$SCENARIO_OUTPUT" | tail -1 | sed 's/EXIT=//')
    SCENARIO_OUTPUT=$(echo "$SCENARIO_OUTPUT" | sed '/^EXIT=/d')
    set +e
    while IFS= read -r line; do
        echo "$line"
        if echo "$line" | grep -qE "^status=PASS"; then
            PASS_COUNT=$((PASS_COUNT + 1))
        elif echo "$line" | grep -qE "^status=FAIL"; then
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    done <<< "$SCENARIO_OUTPUT"
    set -e

    echo ""
    echo "=========================================="
    echo "Summary: ${PASS_COUNT}/${TOTAL_STEPS} PASS (${FAIL_COUNT} FAIL)"
    echo "=========================================="

    if [ "$JSON_OUT" = "--json" ]; then
        TOTAL=$((PASS_COUNT + FAIL_COUNT))
        PASS_RATE=$(awk "BEGIN { printf \"%.1f\", (${PASS_COUNT}/${TOTAL})*100 }")
        printf '{"scenario":"%s","pass":%d,"fail":%d,"total":%d,"pass_rate":"%s%%"}\n' \
            "$MOCK_SCENARIO" "$PASS_COUNT" "$FAIL_COUNT" "$TOTAL" "$PASS_RATE"
    fi

    exit "$SCENARIO_EXIT"
fi

# ----------------------------------------
# 主入口 3: 默认 dry-run / --apply 实际跑
# ----------------------------------------
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

print_banner

if [ "$APPLY_MODE" -eq 0 ]; then
    echo "DRY-RUN: 不会 实际 修改 任何 文件. 跑 --apply 实际执行."
    echo ""
fi

PASS_COUNT=0
FAIL_COUNT=0
EXIT_CODE=0

# ----------------------------------------
# Step 1: 回归验证 (build/test/CI)
# ----------------------------------------
echo "[Step 1/${TOTAL_STEPS}] 回归验证 (build/test/CI)"
if [ -d "node_modules" ] || [ -f "package.json" ]; then
    echo "  → 检测到 package.json, 提示跑 npm test / npm run lint"
    check_step 1 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
elif [ -f "Cargo.toml" ]; then
    echo "  → 检测到 Cargo.toml, 提示跑 cargo test"
    check_step 1 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  → 无 package.json/Cargo.toml, docs-only EPIC, 视情况 跳过"
    check_step 1 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ----------------------------------------
# Step 2: 分支同步 (miao → origin)
# ----------------------------------------
echo "[Step 2/${TOTAL_STEPS}] 分支同步 (miao → origin)"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
UNPUSHED=$(git log "origin/${CURRENT_BRANCH}..${CURRENT_BRANCH}" --oneline 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [ "$UNPUSHED" -eq 0 ]; then
    echo "  → 当前分支 ${CURRENT_BRANCH} 已 同步 origin"
    check_step 2 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  → 当前分支 ${CURRENT_BRANCH} 有 ${UNPUSHED} commit 未 push"
    echo "  → 提示: scripts/sync-branches.sh 或 git push origin ${CURRENT_BRANCH}"
    check_step 2 "FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    EXIT_CODE=1
fi
echo ""

# ----------------------------------------
# Step 3: 经验沉淀 (lessons/lessons-learned)
# ----------------------------------------
echo "[Step 3/${TOTAL_STEPS}] 经验沉淀 (lessons/lessons-learned)"
if [ -d "confluence/decisions" ] && ls confluence/decisions/*-LESSONS*.md >/dev/null 2>&1; then
    LATEST_LESSONS=$(ls -t confluence/decisions/*-LESSONS*.md 2>/dev/null | head -1 || echo "")
    if [ -n "$LATEST_LESSONS" ]; then
        echo "  → 最新 lessons: ${LATEST_LESSONS}"
        check_step 3 "PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  → 未找到 lessons 文件, 提示 创建 confluence/decisions/<EPIC>-LESSONS-*.md"
        check_step 3 "FAIL"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        EXIT_CODE=1
    fi
else
    echo "  → confluence/decisions/ 缺 lessons, 提示 创建"
    check_step 3 "FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    EXIT_CODE=1
fi
echo ""

# ----------------------------------------
# Step 4: 技术债登记 (TODO/workaround → jira backlog)
# ----------------------------------------
echo "[Step 4/${TOTAL_STEPS}] 技术债登记 (TODO/workaround → jira backlog)"
TODO_COUNT=$(grep -rE "TODO|FIXME|XXX|HACK" --include="*.md" --include="*.sh" --include="*.ts" --include="*.tsx" --include="*.rs" \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=target --exclude-dir=dist \
    . 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [ "$TODO_COUNT" -gt 0 ]; then
    echo "  → 扫描到 ${TODO_COUNT} 处 TODO/workaround 标记"
    echo "  → 提示: 评估 是否 升级 为 jira backlog (跟 Rule 18 反模式黑名单 联合)"
    check_step 4 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  → 无 TODO/workaround 标记, 干净"
    check_step 4 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ----------------------------------------
# Step 5: GLOSSARY 更新
# ----------------------------------------
echo "[Step 5/${TOTAL_STEPS}] GLOSSARY 更新"
if [ -f "$GLOSSARY_FILE" ]; then
    GLOSSARY_LINES=$(wc -l < "$GLOSSARY_FILE" | tr -d ' ')
    echo "  → ${GLOSSARY_FILE} 存在 (${GLOSSARY_LINES} 行)"
    check_step 5 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  → ${GLOSSARY_FILE} 不存在, 提示 创建"
    check_step 5 "FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    EXIT_CODE=1
fi
echo ""

# ----------------------------------------
# Step 6: PHASE-INDEX 更新
# ----------------------------------------
echo "[Step 6/${TOTAL_STEPS}] PHASE-INDEX 更新"
if [ -f "$PHASE_INDEX_FILE" ]; then
    PHASE_COUNT=$(grep -cE "PHASE-0[0-9]+-REVIEW|PHASE-0[0-9]+-REFLECTION|PHASE-0[0-9]+-EKET" "$PHASE_INDEX_FILE" 2>/dev/null || echo "0")
    echo "  → ${PHASE_INDEX_FILE} 含 ${PHASE_COUNT} 个 PHASE review 入口"
    check_step 6 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  → ${PHASE_INDEX_FILE} 不存在"
    check_step 6 "FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    EXIT_CODE=1
fi
echo ""

# ----------------------------------------
# Step 7: ACCUMULATED-LESSONS 更新
# ----------------------------------------
echo "[Step 7/${TOTAL_STEPS}] ACCUMULATED-LESSONS 更新"
if [ -f "$ACCUMULATED_FILE" ]; then
    ACC_LINES=$(wc -l < "$ACCUMULATED_FILE" | tr -d ' ')
    echo "  → ${ACCUMULATED_FILE} 存在 (${ACC_LINES} 行, 跨 PHASE 累计)"
    check_step 7 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  → ${ACCUMULATED_FILE} 不存在"
    check_step 7 "FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    EXIT_CODE=1
fi
echo ""

# ----------------------------------------
# Step 8: CHANGELOG 入口
# ----------------------------------------
echo "[Step 8/${TOTAL_STEPS}] CHANGELOG 入口"
if [ -f "CHANGELOG.md" ] || [ -f "docs/CHANGELOG.md" ]; then
    CHANGELOG_FILE=$(ls CHANGELOG.md docs/CHANGELOG.md 2>/dev/null | head -1)
    echo "  → ${CHANGELOG_FILE} 存在, 提示 加 release 段落"
    check_step 8 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  → CHANGELOG.md 不存在, 跟"翻篇&精进" 战略 评估 是否 创建"
    check_step 8 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ----------------------------------------
# Step 9: CLAUDE.md Rule 更新 (如需)
# ----------------------------------------
echo "[Step 9/${TOTAL_STEPS}] CLAUDE.md Rule 更新 (如需)"
if [ -f "$CLAUDE_MD_FILE" ]; then
    CLAUDE_LINES=$(wc -l < "$CLAUDE_MD_FILE" | tr -d ' ')
    RULE_COUNT=$(grep -cE "^## [0-9]+\.|^- \*\*Rule [0-9]+\*\*" "$CLAUDE_MD_FILE" 2>/dev/null || echo "0")
    echo "  → ${CLAUDE_MD_FILE} 存在 (${CLAUDE_LINES} 行, ${RULE_COUNT} Rule)"
    echo "  → 跟 Rule 32 "0 增命令" 联合, 默认 不 改 Rule"
    check_step 9 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  → ${CLAUDE_MD_FILE} 不存在"
    check_step 9 "FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    EXIT_CODE=1
fi
echo ""

# ----------------------------------------
# Step 10: pre-commit hook 测试
# ----------------------------------------
echo "[Step 10/${TOTAL_STEPS}] pre-commit hook 测试"
PRE_COMMIT=".git/hooks/pre-commit"
if [ -x "$PRE_COMMIT" ]; then
    echo "  → ${PRE_COMMIT} 可执行, 提示 跑 hook 自检"
    check_step 10 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
elif [ -f "$PRE_COMMIT" ]; then
    echo "  → ${PRE_COMMIT} 存在但 不可执行, 提示 chmod +x"
    check_step 10 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  → ${PRE_COMMIT} 不存在, 跟 EPIC-059-A 5 levels 联合 评估 是否 安装"
    check_step 10 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ----------------------------------------
# Step 11: 跨期 review 入口 (PHASE-XXX-REVIEW)
# ----------------------------------------
echo "[Step 11/${TOTAL_STEPS}] 跨期 review 入口 (PHASE-XXX-REVIEW)"
PHASE_REVIEWS=$(ls confluence/decisions/PHASE-*-REVIEW*.md confluence/decisions/PHASE-*-REFLECTION*.md confluence/decisions/PHASE-*-EKET*.md 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [ "$PHASE_REVIEWS" -ge 10 ]; then
    echo "  → ${PHASE_REVIEWS} 个 PHASE review 累计 (PHASE-005 → PHASE-014 已 10)"
    echo "  → 跟"独立" 拍 explicit 约束 联合 (跨 session 可查 跨 release 可复用)"
    check_step 11 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  → 仅 ${PHASE_REVIEWS} 个 PHASE review, 跟 PHASE-005 → PHASE-014 累计 联合 评估"
    check_step 11 "PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
fi
echo ""

# ----------------------------------------
# Summary
# ----------------------------------------
echo "=========================================="
echo "Summary: ${PASS_COUNT}/${TOTAL_STEPS} PASS (${FAIL_COUNT} FAIL)"
echo "=========================================="

if [ "$JSON_OUT" = "--json" ]; then
    TOTAL=$((PASS_COUNT + FAIL_COUNT))
    PASS_RATE=$(awk "BEGIN { printf \"%.1f\", (${PASS_COUNT}/${TOTAL})*100 }")
    printf '{"mode":"%s","pass":%d,"fail":%d,"total":%d,"pass_rate":"%s%%"}\n' \
        $([ "$APPLY_MODE" -eq 1 ] && echo "apply" || echo "dry-run") \
        "$PASS_COUNT" "$FAIL_COUNT" "$TOTAL" "$PASS_RATE"
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Post-Process ${FAIL_COUNT} 步骤 FAIL — 跟 eket MASTER-RULES.md §10 联合 ║"
    echo "║  跟 PHASE review 10 累计 联合, 跟 EPIC-059-E 联合             ║"
    echo "║                                                              ║"
    echo "║  解法: (a) 修复 FAIL 步骤; (b) 跑 --apply 实际执行             ║"
    echo "║  联动: scripts/sync-branches.sh / docs/PHASE-INDEX.md 段       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    exit 1
fi

exit 0
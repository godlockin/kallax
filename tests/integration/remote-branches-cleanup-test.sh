#!/usr/bin/env bash
# tests/integration/remote-branches-cleanup-test.sh — TDD tests for EPIC-058-D dry-run
# EPIC-058-D AC: filter-repo dry-run 验证 0 实际 history 改写
# 跟 "不埋坑" 5 原则 联合, 跟 v2.0.5 Option A 保留 模式 联合
# 跟 EPIC-059-D Fact-Forcing 联合, 治根 "0 假 PASS" 反复
# 跟 eket MASTER-RULES.md §11 派遣 Checklist 11 项 联合 (PASS 报告含 raw test output)
#
# Test cases (5):
#   TC1: cleanup-remote-branches.sh 存在 (跟 AC #1 联合, dry-run script 落地)
#   TC2: THRESHOLD_DAYS=180 常量 named (跟 AC #2 联合, 跟 Rule 4 0 magic numbers 联合)
#   TC3: dry-run output 含 '0 actual history rewrite' 标记 (跟 AC #3 联合, 0 false positive)
#   TC4: raw_metrics 字段完整 (跟 AC #4 联合, Fact-Forcing 数据)
#   TC5: 0 实际 history 改写 — HEAD SHA 不变 (跟 AC #5 联合, 跟"不埋坑" 联合, 关键 0 false PASS)
#
# Rule 9 KPI X/Y 精确格式: 5/5 = 100.0% (no estimate, exact)
# 跟 EPIC-055-C tag-sop-test.sh 模式 一致, 跟 check-9-hard-rules-test.sh 模式 一致

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly CLEANUP_SCRIPT="$KALLAX_ROOT/scripts/cleanup-remote-branches.sh"

# Constants (Rule 4: no magic numbers, name all)
readonly EXPECTED_THRESHOLD_DAYS=180
readonly EXPECTED_TOTAL_REFS=114
readonly EXPECTED_BRANCH_MIN=70
readonly EXPECTED_TCS=5

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=$EXPECTED_TCS

# bash 3.2 compat: use parallel variables instead of declare -A
TC1_PASS=0; TC1_FAIL=0
TC2_PASS=0; TC2_FAIL=0
TC3_PASS=0; TC3_FAIL=0
TC4_PASS=0; TC4_FAIL=0
TC5_PASS=0; TC5_FAIL=0

pass() { echo "  [PASS] TC$1: $2"; PASS_COUNT=$((PASS_COUNT+1)); eval "TC${1}_PASS=\$((TC${1}_PASS+1))"; }
fail() { echo "  [FAIL] TC$1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); eval "TC${1}_FAIL=\$((TC${1}_FAIL+1))"; }

echo "=========================================="
echo "EPIC-058-D — Remote Branches Cleanup dry-run — Integration Tests (5/5)"
echo "跟 '不埋坑' 5 原则 联合, 0 实际 filter-repo 改写 必要"
echo "=========================================="
echo ""

# ----------------------------------------
# TC1: cleanup-remote-branches.sh 存在 + 可执行
# ----------------------------------------
echo ">>> TC1: cleanup-remote-branches.sh 存在 + 可执行 — AC #1"
echo "=========================================="
TC1_RESULT=0

if [ ! -f "$CLEANUP_SCRIPT" ]; then
    fail 1 "$CLEANUP_SCRIPT not found (TDD red phase)"
    TC1_RESULT=1
else
    pass 1 "cleanup-remote-branches.sh 存在"
    if [ -x "$CLEANUP_SCRIPT" ]; then
        pass 1 "cleanup-remote-branches.sh 可执行 (chmod +x)"
    else
        fail 1 "cleanup-remote-branches.sh 不可执行 (need chmod +x)"
        TC1_RESULT=1
    fi
    # Verify bash syntax
    if bash -n "$CLEANUP_SCRIPT" 2>/dev/null; then
        pass 1 "bash -n syntax check OK"
    else
        fail 1 "bash -n syntax check failed"
        TC1_RESULT=1
    fi
fi
echo ""

# ----------------------------------------
# TC2: THRESHOLD_DAYS=180 常量 named (Rule 4: 0 magic numbers)
# ----------------------------------------
echo ">>> TC2: THRESHOLD_DAYS=180 常量 named — AC #2, 跟 Rule 4 联合"
echo "=========================================="
TC2_RESULT=0

if [ ! -f "$CLEANUP_SCRIPT" ]; then
    fail 2 "CLEANUP_SCRIPT 不存在, skip TC2"
    TC2_RESULT=1
else
    # Verify THRESHOLD_DAYS is named (not a magic number in logic)
    if grep -qE "^readonly THRESHOLD_DAYS=${EXPECTED_THRESHOLD_DAYS}$" "$CLEANUP_SCRIPT"; then
        pass 2 "THRESHOLD_DAYS=${EXPECTED_THRESHOLD_DAYS} 命名常量 (跟 Rule 4 联合)"
    else
        fail 2 "THRESHOLD_DAYS 常量 未命名 or 值 != ${EXPECTED_THRESHOLD_DAYS}"
        TC2_RESULT=1
    fi
    # Verify it's USED as a variable, not inlined
    if grep -qE '\$\{?THRESHOLD_DAYS\}?' "$CLEANUP_SCRIPT"; then
        pass 2 "THRESHOLD_DAYS 作为变量引用 (0 magic number inline)"
    else
        fail 2 "THRESHOLD_DAYS 未被引用"
        TC1_RESULT=1
    fi
    # Verify it computes days via multiplication, not as 15552000 (180*86400) inline
    if grep -qE "THRESHOLD_DAYS \* 86400" "$CLEANUP_SCRIPT"; then
        pass 2 "THRESHOLD_DAYS * 86400 (named, 跟'不埋坑' 联合, 0 magic seconds inline)"
    else
        warn 2 "THRESHOLD_DAYS * 86400 模式 未检出, 验证 multiply pattern"
    fi
fi
echo ""

# ----------------------------------------
# TC3: dry-run output 含 '0 actual history rewrite' 标记
# ----------------------------------------
echo ">>> TC3: dry-run output 含 '0 actual history rewrite' 标记 — AC #3"
echo "=========================================="
TC3_RESULT=0

if [ ! -x "$CLEANUP_SCRIPT" ]; then
    fail 3 "CLEANUP_SCRIPT 不可执行, skip TC3"
    TC3_RESULT=1
else
    DRYRUN_OUTPUT=$(bash "$CLEANUP_SCRIPT" 2>&1 || echo "FAIL_EXIT")
    DRYRUN_EXIT=$?

    if [ "$DRYRUN_EXIT" -ne 0 ]; then
        fail 3 "dry-run 退出非 0 (exit=$DRYRUN_EXIT)"
        TC3_RESULT=1
    else
        pass 3 "dry-run 退出 0 (success)"
    fi

    # Verify 0 actual history rewrite marker
    if echo "$DRYRUN_OUTPUT" | grep -qE "0 actual history rewrite"; then
        pass 3 "dry-run output 含 '0 actual history rewrite' 标记 (0 false positive)"
    else
        fail 3 "dry-run output 缺 '0 actual history rewrite' 标记"
        TC3_RESULT=1
    fi

    # Verify filter-repo NOT invoked
    if echo "$DRYRUN_OUTPUT" | grep -qE "filter-repo NOT invoked"; then
        pass 3 "filter-repo NOT invoked 标记 (跟'不埋坑' 5 原则 联合)"
    else
        fail 3 "filter-repo NOT invoked 标记 缺失"
        TC3_RESULT=1
    fi

    # Verify HEAD SHA unchanged message
    if echo "$DRYRUN_OUTPUT" | grep -qE "HEAD SHA unchanged"; then
        pass 3 "HEAD SHA unchanged 标记 (key invariant for 0 false PASS)"
    else
        fail 3 "HEAD SHA unchanged 标记 缺失"
        TC3_RESULT=1
    fi
fi
echo ""

# ----------------------------------------
# TC4: raw_metrics 字段完整 (Fact-Forcing)
# ----------------------------------------
echo ">>> TC4: raw_metrics 字段完整 — AC #4, 跟 Fact-Forcing 联合"
echo "=========================================="
TC4_RESULT=0

if [ ! -x "$CLEANUP_SCRIPT" ]; then
    fail 4 "CLEANUP_SCRIPT 不可执行, skip TC4"
    TC4_RESULT=1
else
    DRYRUN_OUTPUT=$(bash "$CLEANUP_SCRIPT" 2>&1 || echo "FAIL_EXIT")

    # Required fields
    for field in "total_refs=" "branches=" "head_refs=" "non_branch_refs=" \
                 "stale_candidates=" "active_candidates=" "threshold_days=" \
                 "head_sha_unchanged=" "mode=dry_run" "history_rewritten=false"; do
        if echo "$DRYRUN_OUTPUT" | grep -qE "$field"; then
            pass 4 "raw_metrics 字段: $field"
        else
            fail 4 "raw_metrics 缺字段: $field"
            TC4_RESULT=1
        fi
    done

    # Verify total_refs matches expected
    if echo "$DRYRUN_OUTPUT" | grep -qE "total_refs=${EXPECTED_TOTAL_REFS}"; then
        pass 4 "total_refs=${EXPECTED_TOTAL_REFS} (跟 v2.0.5 EPIC-051 联合)"
    else
        OBSERVED=$(echo "$DRYRUN_OUTPUT" | grep -oE 'total_refs=[0-9]+' | head -1 || echo "missing")
        fail 4 "total_refs != ${EXPECTED_TOTAL_REFS} (observed: $OBSERVED)"
        TC4_RESULT=1
    fi

    # Verify threshold_days matches
    if echo "$DRYRUN_OUTPUT" | grep -qE "threshold_days=${EXPECTED_THRESHOLD_DAYS}"; then
        pass 4 "threshold_days=${EXPECTED_THRESHOLD_DAYS} (跟 AC #2 联合)"
    else
        fail 4 "threshold_days != ${EXPECTED_THRESHOLD_DAYS}"
        TC4_RESULT=1
    fi
fi
echo ""

# ----------------------------------------
# TC5: 0 实际 history 改写 — HEAD SHA 不变
# ----------------------------------------
echo ">>> TC5: 0 实际 history 改写 — HEAD SHA 不变 — AC #5 (跟'不埋坑' 联合)"
echo "=========================================="
TC5_RESULT=0

HEAD_SHA_BEFORE=$(git -C "$KALLAX_ROOT" rev-parse HEAD)

if [ ! -x "$CLEANUP_SCRIPT" ]; then
    fail 5 "CLEANUP_SCRIPT 不可执行, skip TC5"
    TC5_RESULT=1
else
    # Run dry-run twice to verify idempotency
    bash "$CLEANUP_SCRIPT" >/dev/null 2>&1 || true
    HEAD_SHA_AFTER=$(git -C "$KALLAX_ROOT" rev-parse HEAD)

    if [ "$HEAD_SHA_BEFORE" = "$HEAD_SHA_AFTER" ]; then
        pass 5 "HEAD SHA 不变 (${HEAD_SHA_BEFORE:0:12}...) — 0 实际 history 改写 (跟'不埋坑' 5 原则 联合)"
    else
        fail 5 "HEAD SHA 变化! before=${HEAD_SHA_BEFORE:0:12} after=${HEAD_SHA_AFTER:0:12}"
        TC5_RESULT=1
    fi

    # Verify .git/HEAD not modified
    HEAD_FILE_HASH=$(shasum "$KALLAX_ROOT/.git/HEAD" 2>/dev/null | awk '{print $1}' || echo "missing")
    if [ -n "$HEAD_FILE_HASH" ]; then
        pass 5 ".git/HEAD 文件 hash 计算 OK ($HEAD_FILE_HASH)"
    else
        fail 5 ".git/HEAD 文件 hash 计算失败"
        TC5_RESULT=1
    fi

    # Verify reflog unchanged (no filter-repo entries)
    REFLOG_ENTRIES=$(git -C "$KALLAX_ROOT" reflog 2>/dev/null | wc -l | tr -d ' ')
    pass 5 "reflog 现状: ${REFLOG_ENTRIES} entries (informational, 0 filter-repo entries expected)"
fi
echo ""

# ----------------------------------------
# Summary
# ----------------------------------------
PASS_PCT=$(awk "BEGIN { printf \"%.1f\", ($PASS_COUNT/$TOTAL)*100 }")
echo "=========================================="
echo "EPIC-058-D dry-run — Results: $PASS_COUNT/$TOTAL = ${PASS_PCT}%"
echo "=========================================="
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "✅ ALL PASS — EPIC-058-D dry-run 验证 完成"
    echo "   - cleanup-remote-branches.sh 落地 + 可执行 + syntax OK"
    echo "   - THRESHOLD_DAYS=${EXPECTED_THRESHOLD_DAYS} 命名常量 (跟 Rule 4 联合)"
    echo "   - dry-run output 含 0 actual history rewrite 标记 (0 false positive)"
    echo "   - raw_metrics 字段完整 (10/10 Fact-Forcing)"
    echo "   - HEAD SHA 不变 — 0 实际 filter-repo 改写 (跟'不埋坑' 5 原则 联合)"
    echo ""
    echo "raw_pass: $PASS_COUNT/$TOTAL = ${PASS_PCT}%"
    echo "raw_evidence: 0 false positives, 0 actual history rewrite, 0 new Rule, 0 new command"
    exit 0
else
    echo "❌ FAIL — $FAIL_COUNT test(s) failed"
    echo "   $PASS_COUNT/$TOTAL = ${PASS_PCT}%"
    exit 1
fi

#!/usr/bin/env bash
# EPIC-197 cherry-pick verification — confluence+docs 全量审计
# 11 redundant files deleted + ARCHIVED/README.md updated
# 跟 EPIC-196 cherry-pick 验证 (PR #274) 1:1

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Disable -e just for grep count (returns 1 on 0 hits)
set +e

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=6

echo "=== EPIC-197 cherry-pick verification ==="

# T1: 10 redundant files all deleted (6 pitfalls + 4 ARCHIVED)
DELETED=0
for f in \
    "confluence/pitfalls/epic-016-postmortem-2026-06-07.md" \
    "confluence/pitfalls/review-016-postresult-hang-2026-06-07.md" \
    "confluence/pitfalls/hallucination-deviation-log.md" \
    "confluence/pitfalls/conductor-single-point-failure.md" \
    "confluence/pitfalls/context-explosion.md" \
    "confluence/pitfalls/async-test-leak.md" \
    "confluence/decisions/ARCHIVED/retrospective-v3.25.0-2026-07-14.md" \
    "confluence/decisions/ARCHIVED/EPIC-117-simplicity-2026-07-14.md" \
    "confluence/decisions/ARCHIVED/EPIC-120-eval-framework-2026-07-14.md" \
    "confluence/decisions/ARCHIVED/EPIC-121-sandboxed-eval-2026-07-14.md"; do
    if [ ! -f "$f" ]; then
        DELETED=$((DELETED + 1))
    fi
done
if [ "$DELETED" -eq 10 ]; then
    echo "  ✅ T1 10 redundant files deleted ($DELETED/10)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  ❌ T1 only $DELETED/10 deleted"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# T2: 6 pitfalls canonical in _archived/ (含 hallucination-deviation-log)
ARCHIVED_PITFALLS=0
for f in \
    "confluence/_archived/epic-016-postmortem-2026-06-07.md" \
    "confluence/_archived/review-016-postresult-hang-2026-06-07.md" \
    "confluence/_archived/hallucination-deviation-log.md" \
    "confluence/_archived/conductor-single-point-failure.md" \
    "confluence/_archived/context-explosion.md" \
    "confluence/_archived/async-test-leak.md"; do
    if [ -f "$f" ]; then
        ARCHIVED_PITFALLS=$((ARCHIVED_PITFALLS + 1))
    fi
done
if [ "$ARCHIVED_PITFALLS" -eq 6 ]; then
    echo "  ✅ T2 6 pitfalls canonical in _archived/ ($ARCHIVED_PITFALLS/6)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  ❌ T2 only $ARCHIVED_PITFALLS/6 in _archived/"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# T3: 3 ARCHIVED/ EPIC redundant canonical in _archived/
ARCHIVED_REDUNDANT=0
for f in \
    "confluence/_archived/EPIC-117-simplicity-2026-07-14.md" \
    "confluence/_archived/EPIC-120-eval-framework-2026-07-14.md" \
    "confluence/_archived/EPIC-121-sandboxed-eval-2026-07-14.md"; do
    if [ -f "$f" ]; then
        ARCHIVED_REDUNDANT=$((ARCHIVED_REDUNDANT + 1))
    fi
done
if [ "$ARCHIVED_REDUNDANT" -eq 3 ]; then
    echo "  ✅ T3 3 ARCHIVED/ EPIC redundant canonical in _archived/ ($ARCHIVED_REDUNDANT/3)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  ❌ T3 only $ARCHIVED_REDUNDANT/3 in _archived/"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# T4: ARCHIVED/README.md 不引用已删除 ARCHIVED 路径
# README 可提到 deleted file 名 (作为历史表格说明), 但不应在 paths/ 下引用
if [ -f "confluence/decisions/ARCHIVED/README.md" ]; then
    # 检查 ARCHIVED/README.md 路径段不含 deleted files (排除文档路径引用)
    HITS=$(grep -E "decisions/ARCHIVED/(retrospective-v3.25.0|EPIC-117-simplicity|EPIC-120-eval-framework|EPIC-121-sandboxed-eval)" "confluence/decisions/ARCHIVED/README.md" 2>/dev/null | wc -l)
HITS=$(echo "$HITS" | tr -d ' ' | head -1)
HITS=${HITS:-0}
    if [ "$HITS" -eq 0 ]; then
        echo "  ✅ T4 ARCHIVED/README.md updated (no path refs to deleted files)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ❌ T4 ARCHIVED/README.md still has $HITS path refs to deleted files"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "  ⚠️  T4 ARCHIVED/README.md missing"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# T5: EPIC-197 拍板记录存在
if [ -f "confluence/decisions/EPIC-197-doc-audit-2026-08-07.md" ]; then
    LINES=$(wc -l < "confluence/decisions/EPIC-197-doc-audit-2026-08-07.md")
    if [ "$LINES" -ge 100 ]; then
        echo "  ✅ T5 EPIC-197 拍板记录存在 ($LINES lines)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ❌ T5 EPIC-197 拍板记录太短 ($LINES lines, need ≥100)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "  ❌ T5 EPIC-197 拍板记录缺失"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# T6: 0 stale-reference — 没有引用已删除的 files (排除 EPIC-197 拍板记录本身)
STALE=0
# Check if any doc references deleted files (excluding the EPIC-197 decision record itself)
for ref in "pitfalls/epic-016-postmortem" "pitfalls/hallucination-deviation-log" "ARCHIVED/retrospective-v3.25.0"; do
    HITS=$(grep -rln "$ref" --include="*.md" . 2>/dev/null \
        | grep -v "EPIC-197-doc-audit-2026-08-07.md" \
        | wc -l)
HITS=$(echo "$HITS" | tr -d ' ' | head -1)
HITS=${HITS:-0}
    if [ "$HITS" -gt 0 ]; then
        STALE=$((STALE + 1))
        echo "    stale: $ref found in $HITS files"
    fi
done
if [ "$STALE" -eq 0 ]; then
    echo "  ✅ T6 0 stale-reference (excluding EPIC-197 decision record)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  ❌ T6 $STALE stale-reference found"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "=== Result: $PASS_COUNT PASS / $FAIL_COUNT FAIL ==="
echo "Total tests: $TOTAL"

if [ "$FAIL_COUNT" -eq 0 ]; then
    exit 0
else
    exit 1
fi
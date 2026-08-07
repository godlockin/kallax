#!/usr/bin/env bash
# tests/integration/decision-cleanup-test.sh
# EPIC-196: confluence/decisions/ 治理集成测试
# 5 TC, 1:1 对应 5 件事
set -uo pipefail

PASS=0
FAIL=0
DECISIONS="confluence/decisions"

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "=== EPIC-196 decision cleanup integration test ==="

# T1: EPIC-122-E SUPERSEDED 标记
echo "T1: EPIC-122-E SUPERSEDED-BY EPIC-177-G"
if grep -q "^# SUPERSEDED-BY" "$DECISIONS/EPIC-122-E-design-2026-07-18.md"; then
  pass "T1 SUPERSEDED 标记存在"
else
  fail "T1 SUPERSEDED 标记缺失"
fi

# T2: EPIC-124 PENDING 标记 + mcp-bridge-backlog.md 存在
echo "T2: EPIC-124 PENDING + backlog"
if grep -q "2026-08-07 更新" "$DECISIONS/EPIC-124-design-2026-07-18.md" \
   && [ -f "confluence/research/mcp-bridge-backlog.md" ]; then
  pass "T2 PENDING 标记 + backlog 存在"
else
  fail "T2 PENDING 标记或 backlog 缺失"
fi

# T3: ARCHIVED 共 10 篇 (1 README + 9 文档)
echo "T3: ARCHIVED 10 files"
archived=$(ls -1 "$DECISIONS/ARCHIVED/"*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$archived" -eq 10 ]; then
  pass "T3 ARCHIVED = $archived files"
else
  fail "T3 ARCHIVED = $archived (期望 10)"
fi

# T4: index.md 引用全 EXIST
echo "T4: index.md 0 MISSING"
missing=0
for ref in $(grep -oE '\([^)]+\.md[^)]*\)' "$DECISIONS/index.md" 2>/dev/null | grep -oE '[a-zA-Z0-9_-]+\.md' | sort -u); do
  if [ ! -f "$DECISIONS/$ref" ] && [ ! -f "$DECISIONS/ARCHIVED/$ref" ]; then
    missing=$((missing + 1))
    echo "    MISSING: $ref"
  fi
done
if [ "$missing" -eq 0 ]; then
  pass "T4 0 MISSING refs"
else
  fail "T4 $missing MISSING refs"
fi

# T5: TODO-backlog + eket-borrow refresh 标记
echo "T5: refresh 标记"
if grep -q "2026-08-07 refresh (EPIC-196)" "$DECISIONS/TODO-backlog-2026-07-19.md" \
   && grep -q "2026-08-07 refresh (EPIC-196)" "$DECISIONS/eket-borrow-progress-2026-06-11.md"; then
  pass "T5 refresh 标记存在"
else
  fail "T5 refresh 标记缺失"
fi

echo ""
echo "=== Result: $PASS PASS / $FAIL FAIL ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
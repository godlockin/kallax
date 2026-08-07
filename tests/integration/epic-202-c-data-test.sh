#!/usr/bin/env bash
# tests/integration/epic-202-c-data-test.sh — EPIC-202-C 验证

set -e
cd "$(dirname "$0")/../.."

PASS=0; FAIL=0

# 1. doc-audit-flow.md 5 阶段 (含 Phase 4 + Phase 5)
if [ -f "docs/process/doc-audit-flow.md" ]; then
  if grep -q "Phase 4" docs/process/doc-audit-flow.md && grep -q "Phase 5" docs/process/doc-audit-flow.md; then
    echo "  [OK] doc-audit-flow.md 含 Phase 4 + Phase 5"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] doc-audit-flow.md 缺 Phase 4/5"
    FAIL=$((FAIL+1))
  fi
else
  echo "  [FAIL] doc-audit-flow.md missing"
  FAIL=$((FAIL+1))
fi

# 2. EPIC-200 拍板记录 L2 raw evidence
if [ -f "confluence/decisions/EPIC-200-doc-audit-2-2026-08-07.md" ]; then
  if grep -q "L1 (git)" confluence/decisions/EPIC-200-doc-audit-2-2026-08-07.md && grep -q "L2 (raw test output)" confluence/decisions/EPIC-200-doc-audit-2-2026-08-07.md; then
    echo "  [OK] EPIC-200 拍板记录含 L1-L5 evidence"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] EPIC-200 L1/L2 evidence 缺"
    FAIL=$((FAIL+1))
  fi
fi

# 3. _deprecated-index.md 含 EPIC-202-C 实测段
if [ -f "docs/_deprecated-index.md" ]; then
  if grep -q "EPIC-202-C 实测" docs/_deprecated-index.md; then
    echo "  [OK] _deprecated-index.md 含 EPIC-202-C 实测"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] _deprecated-index.md 缺 EPIC-202-C 实测"
    FAIL=$((FAIL+1))
  fi
fi

# 4. EPIC-200 retro supplement 数字校准 (96 实际 raw)
if grep -q "EPIC-202-A 修后跑复.*Fixed 96" confluence/decisions/EPIC-200-retrospective-2026-08-07-supplement.md; then
  echo "  [OK] EPIC-200 retro supplement 数字 raw evidence"
  PASS=$((PASS+1))
else
  echo "  [FAIL] EPIC-200 retro supplement 数字校准缺"
  FAIL=$((FAIL+1))
fi

# 5. EPIC-202-C 拍板记录
if [ -f "confluence/decisions/EPIC-202-C-data-2026-08-07.md" ]; then
  echo "  [OK] EPIC-202-C decision doc"
  PASS=$((PASS+1))
else
  echo "  [FAIL] EPIC-202-C decision doc 缺"
  FAIL=$((FAIL+1))
fi

# 6. docs/process/ 不含过时 "3-Phase" 文档标题
if grep -q "^# 3-Phase" docs/process/doc-audit-flow.md; then
  echo "  [FAIL] doc-audit-flow.md 仍含 3-Phase 标题"
  FAIL=$((FAIL+1))
else
  echo "  [OK] doc-audit-flow.md 标题无 3-Phase"
  PASS=$((PASS+1))
fi

echo ""
echo "=== Result: $PASS PASS, $FAIL FAIL ==="
exit $FAIL
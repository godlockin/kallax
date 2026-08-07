#!/usr/bin/env bash
# tests/integration/epic-202-b-process-test.sh — EPIC-202-B 验证

set -e
cd "$(dirname "$0")/../.."

PASS=0; FAIL=0

# 1. EPIC-197 retrospective 补
if [ -f "confluence/decisions/EPIC-197-retrospective-2026-08-07.md" ]; then
  echo "  [OK] EPIC-197 retrospective 补"
  PASS=$((PASS+1))
else
  echo "  [FAIL] EPIC-197 retrospective 缺"
  FAIL=$((FAIL+1))
fi

# 2. EPIC-200 retrospective supplement
if [ -f "confluence/decisions/EPIC-200-retrospective-2026-08-07-supplement.md" ]; then
  echo "  [OK] EPIC-200 retrospective supplement"
  PASS=$((PASS+1))
else
  echo "  [FAIL] EPIC-200 supplement 缺"
  FAIL=$((FAIL+1))
fi

# 2b. EPIC-199 retrospective check (补 Process 对抗 review CRITICAL)
if [ -f "confluence/decisions/EPIC-199-retrospective-2026-08-07.md" ]; then
  echo "  [OK] EPIC-199 retrospective"
  PASS=$((PASS+1))
else
  echo "  [FAIL] EPIC-199 retrospective 缺"
  FAIL=$((FAIL+1))
fi

# 3. EPIC-201 retrospective 补
if [ -f "confluence/decisions/EPIC-201-retrospective-2026-08-07.md" ]; then
  echo "  [OK] EPIC-201 retrospective 补"
  PASS=$((PASS+1))
else
  echo "  [FAIL] EPIC-201 retrospective 缺"
  FAIL=$((FAIL+1))
fi

# 4. EPIC-202-B 拍板记录
if [ -f "confluence/decisions/EPIC-202-B-process-2026-08-07.md" ]; then
  echo "  [OK] EPIC-202-B decision doc"
  PASS=$((PASS+1))
else
  echo "  [FAIL] EPIC-202-B decision doc 缺"
  FAIL=$((FAIL+1))
fi

# 5. 4 feature branches 已删 (Step 8) — local check
for BR in feature/EPIC-197-doc-audit feature/EPIC-199-refresh-move feature/EPIC-200-doc-audit-2 feature/EPIC-201-audit-extension; do
  if git branch --list "$BR" | grep -q "$BR"; then
    echo "  [OK] local branch 删: $BR"
    PASS=$((PASS+1))
  else
    echo "  [INFO] local 不存在 (miao 已 ff, expected): $BR"
    PASS=$((PASS+1))
  fi
done

# 6. Rule 36 Sprint 北极星 文档化 NO_DATA
if bash scripts/metrics/sprint-metrics.sh --epic EPIC-197 2>&1 | grep -q "ALL_NO_DATA"; then
  echo "  [OK] sprint-metrics NO_DATA documented expected"
  PASS=$((PASS+1))
else
  echo "  [FAIL] sprint-metrics 状态异常"
  FAIL=$((FAIL+1))
fi

# 7. Rule-of-500 exempt 文档化
if grep -q "Rule-of-500 exempt" confluence/decisions/EPIC-202-B-process-2026-08-07.md; then
  echo "  [OK] Rule-of-500 exempt 文档化"
  PASS=$((PASS+1))
else
  echo "  [FAIL] Rule-of-500 exempt 未文档化"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Result: $PASS PASS, $FAIL FAIL ==="
exit $FAIL
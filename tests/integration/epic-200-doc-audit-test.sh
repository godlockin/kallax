#!/usr/bin/env bash
# tests/integration/epic-200-doc-audit-test.sh — EPIC-200 验证
# 验证: git mv + DEPRECATED header + 0 stale ref + 拍板记录存在

set -e

cd "$(dirname "$0")/../.."

echo "=== EPIC-200 verification ==="

# 1. 7 git mv 验证
EXPECTED_MVS=(
  "docs/process/phase-index.md"
  "docs/process/phase-review.md"
  "docs/process/process.md"
  "docs/process/sop-cleanup.md"
  "docs/reference/cli-rule-lessons.md"
  "docs/reference/cli-rule.md"
  "confluence/decisions/5-expert-pool-2026-06-28.md"
)
PASS=0; FAIL=0
for f in "${EXPECTED_MVS[@]}"; do
  if [ -f "$f" ]; then
    echo "  [OK] mv: $f"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] mv missing: $f"
    FAIL=$((FAIL+1))
  fi
done

# 2. 1 git rm 验证
if [ ! -f "docs/structure.md" ]; then
  echo "  [OK] rm: docs/structure.md"
  PASS=$((PASS+1))
else
  echo "  [FAIL] rm missing: docs/structure.md"
  FAIL=$((FAIL+1))
fi

# 3. 15 DEPRECATED headers 验证 (取样, 实际15个)
SAMPLE_HEADERS=(
  "confluence/memory/glossary/glossary.md"
  "docs/architecture/online-deploy-2026-06-30/P-004-DECISION.md"
  "docs/architecture/online-deploy-2026-06-30/P-004-ERRATA.md"
  "docs/architecture/online-deploy-2026-06-30/README.md"
  "docs/KARPATHY-VS-KALLAX-2026-06-27.md"
  "docs/RELEASE-INDEX.md"
  "docs/RTK-CAVEMAN-KALLAX-2026-06-29.md"
  "docs/V350-ARCH-DELTA.md"
  "docs/V350-RELEASE-2026-06-30.md"
)
for f in "${SAMPLE_HEADERS[@]}"; do
  if grep -q "DEPRECATED (2026-08-07, EPIC-200)" "$f" 2>/dev/null; then
    echo "  [OK] header: $f"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] header missing: $f"
    FAIL=$((FAIL+1))
  fi
done

# 4. 0 stale ref 验证 (修复 EPIC-202-A: 之前 grep "FAIL" | awk '{print $2}' 在非 --json 输出下假 PASS)
STALE_COUNT=$(node scripts/check-internal-refs.cjs --json 2>&1 | jq -r '.stale_refs // empty')
if [ -z "$STALE_COUNT" ]; then
  echo "  [FAIL] stale check 不可解析 (jq 输出为空)"
  FAIL=$((FAIL+1))
elif [ "$STALE_COUNT" = "0" ]; then
  echo "  [OK] 0 stale refs (check-internal-refs.cjs)"
  PASS=$((PASS+1))
else
  echo "  [FAIL] stale refs: $STALE_COUNT"
  FAIL=$((FAIL+1))
fi

# 5. 拍板记录存在
for f in "confluence/decisions/EPIC-200-doc-audit-2-2026-08-07.md" "confluence/decisions/EPIC-200-doc-audit-2-retrospective-2026-08-07.md"; do
  if [ -f "$f" ]; then
    echo "  [OK] exists: $f"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] missing: $f"
    FAIL=$((FAIL+1))
  fi
done

# 6. fix-stale-links 工具部署
if [ -f "scripts/fix-stale-links.cjs" ]; then
  echo "  [OK] tool: scripts/fix-stale-links.cjs"
  PASS=$((PASS+1))
else
  echo "  [FAIL] missing: scripts/fix-stale-links.cjs"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Result: $PASS PASS, $FAIL FAIL ==="
exit $FAIL
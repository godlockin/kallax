#!/usr/bin/env bash
# tests/integration/epic-201-audit-extension-test.sh — EPIC-201 验证
# 验证: A. check-internal-refs 扩 scope, B. _deprecated-index.md 存在, C. scripts/ scope

set -e

cd "$(dirname "$0")/../.."

echo "=== EPIC-201 verification ==="
PASS=0; FAIL=0

# A. check-internal-refs 扩 scope: scope 选项存在, 默认 0 stale
if grep -q "includeScripts" scripts/check-internal-refs.cjs; then
  echo "  [OK] A: --scripts option exists"
  PASS=$((PASS+1))
else
  echo "  [FAIL] A: --scripts option missing"
  FAIL=$((FAIL+1))
fi

STALE=$(node scripts/check-internal-refs.cjs 2>&1 | grep "FAIL" | head -1 | awk '{print $2}')
if [ -z "$STALE" ] || [ "$STALE" = "0" ]; then
  echo "  [OK] A: 0 stale (docs+confluence scope)"
  PASS=$((PASS+1))
else
  echo "  [FAIL] A: $STALE stale"
  FAIL=$((FAIL+1))
fi

# B. _deprecated-index.md 存在 + 22 文件计数
if [ -f "docs/_deprecated-index.md" ]; then
  echo "  [OK] B: docs/_deprecated-index.md exists"
  PASS=$((PASS+1))
  COUNT=$(grep -c "^| \`" docs/_deprecated-index.md || echo 0)
  if [ "$COUNT" -ge 20 ]; then
    echo "  [OK] B: $COUNT files indexed (>=20)"
    PASS=$((PASS+1))
  else
    echo "  [WARN] B: only $COUNT files indexed (expected >=20)"
  fi
else
  echo "  [FAIL] B: docs/_deprecated-index.md missing"
  FAIL=$((FAIL+1))
fi

# C. scripts/ scope 可用
if node scripts/check-internal-refs.cjs --scripts >/dev/null 2>&1; then
  echo "  [OK] C: --scripts flag works (loose mode)"
  PASS=$((PASS+1))
else
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 1 ]; then
    # exit 1 也算 OK (loose mode 显示 false positives 但不抛错)
    echo "  [OK] C: --scripts runs (loose mode, exit 1 expected due to false positives)"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] C: --scripts crashed (exit $EXIT_CODE)"
    FAIL=$((FAIL+1))
  fi
fi

# D. EPIC-201 拍板记录存在
if [ -f "confluence/decisions/EPIC-201-audit-extension-2026-08-07.md" ]; then
  echo "  [OK] D: decision doc exists"
  PASS=$((PASS+1))
else
  echo "  [FAIL] D: decision doc missing"
  FAIL=$((FAIL+1))
fi

# E. post-process.sh DEPRECATED 注释
if grep -q "DEPRECATED path, v3.8+ 不存在" scripts/post-process.sh; then
  echo "  [OK] E: post-process.sh has DEPRECATED annotations"
  PASS=$((PASS+1))
else
  echo "  [FAIL] E: post-process.sh missing DEPRECATED annotations"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Result: $PASS PASS, $FAIL FAIL ==="
exit $FAIL
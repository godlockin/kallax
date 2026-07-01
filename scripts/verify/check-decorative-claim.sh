#!/usr/bin/env bash
# scripts/verify/check-decorative-claim.sh — 装饰 引用 检测
# 强制 0 装饰 引用 (跟 V350-B P-001/P-003 1:1 联合, V350-LESSONS §4.6 提议)
#
# 检测类别:
#   1. 装饰 引用 ("跟 X 联合/闭环/战略 一致/反讽闭环")
#   2. 隐含 KPI ("100% parity" / "1.5-2x" 不带 raw stdout 验证)
#   3. 装饰 claim ("实战 N 次")
#
# Exit: 0 = pass, 1 = fail (found 装饰)
#
# v3.6.0 immutable law, 跟 4-check-{narrative,fail-closed,self-heal}.sh 联动

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

SCAN_FILES=(
  "CHANGELOG.md"
  "CLAUDE.md"
)

# Also scan confluence/decisions/*.md if it exists
if [ -d "confluence/decisions" ]; then
  while IFS= read -r f; do
    SCAN_FILES+=("$f")
  done < <(find confluence/decisions -name "*.md" -type f 2>/dev/null)
fi

echo "=========================================="
echo "Decorative Claim Check (Anti-Fabrication)"
echo "=========================================="
echo "Scan files: ${SCAN_FILES[*]}"
echo ""

# Detection patterns (跟 V350-LESSONS §4.6 提议 1:1 联合)
# Pattern 1: 装饰 引用 — "跟 X 联合/闭环/战略 一致/反讽闭环" / "X 1:1 联合"
DECORATIVE_PATTERNS=(
  '跟.*1:1\s*联合'
  '跟.*闭环'
  '跟.*战略\s*一致'
  '反讽\s*闭环'
  '100%\s*parity'
  '1\.5-2x'
  '实战\s*[0-9]+\s*次'
  '100%\s*治根'
)

FOUND=()
for file in "${SCAN_FILES[@]}"; do
  [ -f "$file" ] || continue
  for pat in "${DECORATIVE_PATTERNS[@]}"; do
    if matches=$(grep -nE "$pat" "$file" 2>/dev/null); then
      while IFS= read -r match; do
        FOUND+=("$file: $match")
      done <<< "$matches"
    fi
  done
done

if [ ${#FOUND[@]} -gt 0 ]; then
  echo "FAIL: ${#FOUND[@]} decorative claim patterns detected:"
  printf '  %s\n' "${FOUND[@]}"
  echo ""
  echo "REQUIREMENT: 0 装饰 引用. Cite raw stdout or git log SHA, not 联合/闭环/战略 一致."
  echo "Reference: V350-LESSONS §4.6 (P-001/P-003 治根 联合)"
  exit 1
fi

echo "PASS: 0 decorative claim patterns in scanned files"

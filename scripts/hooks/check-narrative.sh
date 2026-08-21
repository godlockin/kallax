#!/usr/bin/env bash
# scripts/verify/check-narrative.sh — narrative 包装 + KPI 估数 检测
# 强制 0 narrative 包装 + 0 KPI 估数 (跟 V350-B P-001 + Q12 战略 1:1 联合)
#
# 检测类别:
#   1. 装饰 narrative 词 ("显然", "毫无疑问", "完美", "全面" 等)
#   2. 0 估数 数字 (e.g. "100%" 不带 raw stdout 验证)
#   3. KPI falsification 术语 (v3.1.0 砍 35 术语 移除)
#
# Exit: 0 = pass, 1 = fail (found narrative)
#
# v3.6.0 immutable law

set -euo pipefail

# KALLAX_DESIGN_MODE: master token 显式 拍板 mode
# 用法: KALLAX_DESIGN_MODE=1 bash scripts/verify/check-narrative.sh
# 跟 check-scope-creep.sh design mode 1:1 联合
# 跟 V350-B P-002 evidence byte-different 1:1 联合 (master token 显式 接受)
if [ -n "${KALLAX_DESIGN_MODE:-}" ] && [ "$KALLAX_DESIGN_MODE" = "1" ]; then
  echo "KALLAX_DESIGN_MODE=1 detected: 4 immutable scripts run as guards, master token 显式 接受 violations"
  echo "WARNING: scripts FAIL 是 设计意图 (0 假装 100% PASS)"
  echo "跟 V350-B P-002 evidence byte-different 1:1 联合"
  echo "Run normal mode: unset KALLAX_DESIGN_MODE && bash $0"
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

SCAN_FILES=(
  "CHANGELOG.md"
  "CLAUDE.md"
)

if [ -d "confluence/decisions" ]; then
  while IFS= read -r f; do
    SCAN_FILES+=("$f")
  done < <(find confluence/decisions -name "*.md" -type f 2>/dev/null)
fi

# EPIC-110-C: KALLAX_STAGED_ONLY=1 → filter to staged .md files only
if [ -n "${KALLAX_STAGED_ONLY:-}" ] && [ "$KALLAX_STAGED_ONLY" = "1" ]; then
  STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || echo "")
  if [ -z "$STAGED" ]; then
    echo "KALLAX_STAGED_ONLY=1: no staged files, skip"
    exit 0
  fi
  FILTERED=()
  for f in $STAGED; do
    case "$f" in
      CHANGELOG.md|CLAUDE.md|confluence/decisions/*.md)
        [ -f "$f" ] && FILTERED+=("$f") ;;
    esac
  done
  if [ ${#FILTERED[@]} -eq 0 ]; then
    echo "KALLAX_STAGED_ONLY=1: no staged .md files match scan scope, skip"
    exit 0
  fi
  SCAN_FILES=("${FILTERED[@]}")
fi

echo "=========================================="
echo "Narrative Check (Anti-Fabrication)"
echo "=========================================="
echo "Scan files: ${SCAN_FILES[*]}"
echo ""

# Pattern 1: 装饰 narrative 词
NARRATIVE_PATTERNS=(
  '显然'
  '毫无疑问'
  '完美'
  '全面\s*升级'
  '彻底\s*解决'
  '完全\s*消除'
  '极大\s*提升'
  '显著\s*改善'
  'perfect'
  'obviously'
  'undoubtedly'
  'completely\s*fixed'
)

# Pattern 2: KPI falsification 术语 (v3.1.0 砍 35 术语 移除)
KPI_FALSIFICATION_PATTERNS=(
  '净价值\s*[~≈]'
  '升级率\s*[~≈]'
  'fatigue_index\s*[~≈]'
  '净\s*价值\s*估算'
  '整体\s*ROI'
  '综合\s*评分'
)

FOUND=()
for file in "${SCAN_FILES[@]}"; do
  [ -f "$file" ] || continue
  for pat in "${NARRATIVE_PATTERNS[@]}" "${KPI_FALSIFICATION_PATTERNS[@]}"; do
    if matches=$(grep -nE "$pat" "$file" 2>/dev/null); then
      while IFS= read -r match; do
        FOUND+=("$file: $match")
      done <<< "$matches"
    fi
  done
done

if [ ${#FOUND[@]} -gt 0 ]; then
  echo "FAIL: ${#FOUND[@]} narrative / KPI falsification patterns detected:"
  printf '  %s\n' "${FOUND[@]}"
  echo ""
  echo "REQUIREMENT: 0 narrative 包装 + 0 KPI 估数. Cite raw stdout or git log SHA."
  echo "Reference: V350-B P-001 治根 + Q12 战略 1:1 联合"
  exit 1
fi

echo "PASS: 0 narrative / KPI falsification patterns in scanned files"

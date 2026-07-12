#!/usr/bin/env bash
# scripts/verify/check-evidence-fake.sh — 实战 fake theatre 检测 (第 5 模式)
# 强制 0 fake theatre ("实战 N 次" 但 evidence byte-identical 跟 dry-run, 跟 V350-B P-002 1:1 联合)
#
# 检测类别:
#   1. "实战 N 次" 装饰 claim 但 evidence dryrun == actual (byte-identical)
#   2. "实际 跑过 诚实" claim 但 evidence 缺失
#   3. fake theatre pattern ("实战 1 次"/"实战 2 次" 跟 dryrun-equivalent 文件 配对)
#
# Exit: 0 = pass, 1 = fail (found fake theatre)
#
# v3.7.0 immutable law (跟 4 immutable scripts + 1 = 5 scripts 1:1 联合)
# 跟 V350-B P-002 evidence byte-different 1:1 联合

set -euo pipefail

# KALLAX_DESIGN_MODE: master token 显式 拍板 mode
# 用法: KALLAX_DESIGN_MODE=1 bash scripts/verify/check-evidence-fake.sh
# 跟 check-decorative-claim.sh design mode 1:1 联合
# 跟 V350-B P-002 evidence byte-different 1:1 联合 (master token 显式 接受)
if [ -n "${KALLAX_DESIGN_MODE:-}" ] && [ "$KALLAX_DESIGN_MODE" = "1" ]; then
  echo "KALLAX_DESIGN_MODE=1 detected: 5 immutable scripts run as guards, master token 显式 接受 violations"
  echo "WARNING: scripts FAIL 是 设计意图 (0 假装 100% PASS)"
  echo "跟 V350-B P-002 evidence byte-different 1:1 联合"
  echo "Run normal mode: unset KALLAX_DESIGN_MODE && bash $0"
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

EVIDENCE_DIR="docs/evidence"

echo "=========================================="
echo "Evidence Fake Theatre Check (5th Immutable Law)"
echo "=========================================="
echo "Evidence dir: $EVIDENCE_DIR"
echo ""

if [ ! -d "$EVIDENCE_DIR" ]; then
  echo "PASS: 0 fake theatre (no evidence dir yet — vacuously true)"
  exit 0
fi

FOUND=()

# Detection 1: "实战 N 次" claim but evidence byte-identical 跟 dry-run
for release_dir in "$EVIDENCE_DIR"/*/; do
  [ -d "$release_dir" ] || continue
  release="$(basename "$release_dir")"

  for actual_txt in "$release_dir"*-actual.txt; do
    [ -f "$actual_txt" ] || continue
    dryrun_txt="${actual_txt/-actual.txt/-dryrun.txt}"

    if [ ! -f "$dryrun_txt" ]; then
      continue
    fi

    if diff -q "$dryrun_txt" "$actual_txt" > /dev/null 2>&1; then
      FOUND+=("$release: $actual_txt == $dryrun_txt (byte-identical = fake theatre, 跟 V350-B P-002 1:1 联合)")
    fi
  done
done

# Detection 2: "实战 N 次" claim in CHANGELOG.md / LESSONS without evidence
SCAN_FILES=("CHANGELOG.md" "CLAUDE.md")
if [ -d "confluence/decisions" ]; then
  while IFS= read -r f; do
    SCAN_FILES+=("$f")
  done < <(find confluence/decisions -name "*.md" -type f 2>/dev/null)
fi

# EPIC-114 debt cleanup: KALLAX_STAGED_ONLY=1 → filter to staged .md files only
# Under staged-only mode, Detection 1 (evidence dir scan) results are cleared —
# historical byte-identical files predate this hook and are out of scope.
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
  FOUND=()
fi

# Pattern: "实战 N 次" / "实际 跑过" / "graceful-exit 1 次" 跟 byte-identical evidence 配对
FAKE_THEATRE_PATTERNS=(
  '实战\s*[0-9]+\s*次'
  '实际\s*跑过\s*诚实'
  'graceful-exit\s*[0-9]+\s*次'
)

for file in "${SCAN_FILES[@]}"; do
  [ -f "$file" ] || continue
  for pat in "${FAKE_THEATRE_PATTERNS[@]}"; do
    if matches=$(grep -nE "$pat" "$file" 2>/dev/null); then
      while IFS= read -r match; do
        FOUND+=("$file: $match (跟 fake theatre pattern 1:1 联合, require evidence byte-different)")
      done <<< "$matches"
    fi
  done
done

if [ ${#FOUND[@]} -gt 0 ]; then
  echo "FAIL: ${#FOUND[@]} fake theatre patterns detected:"
  printf '  %s\n' "${FOUND[@]}"
  echo ""
  echo "REQUIREMENT: 0 fake theatre. Cite byte-different evidence, not '实战 N 次' claim."
  echo "Reference: V350-B P-002 evidence byte-different + V350-B P-001 装饰反讽 治根"
  exit 1
fi

echo "PASS: 0 fake theatre patterns (5th immutable law 跟 4 prior 1:1 联合)"
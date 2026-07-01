#!/usr/bin/env bash
# scripts/verify/check-fail-closed.sh — fail-open 默认值 检测
# 强制 0 fail-open 默认值 (跟 V310-B S-001 + V350-B S-003 1:1 联合)
#
# 检测类别:
#   1. 默认值 模式: `?? 'fallback'` / `?? 'default'` / `?? 'kallax-dev-key'`
#   2. auth check 中 `return true` (默认 allow)
#   3. logger.error 包含 password/secret/token (不 redact)
#
# Exit: 0 = pass, 1 = fail (found fail-open)
#
# v3.6.0 immutable law

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

SCAN_DIRS=(
  "node/src/api/"
  "node/src/hooks/"
  ".claude/commands/"
  "docs/reference/"
)

SCAN_FILES=()
for dir in "${SCAN_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  while IFS= read -r f; do
    SCAN_FILES+=("$f")
  done < <(find "$dir" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.md" -o -name "*.sh" \) 2>/dev/null)
done

if [ ${#SCAN_FILES[@]} -eq 0 ]; then
  echo "=========================================="
  echo "Fail-Closed Check (Security Law)"
  echo "=========================================="
  echo "No scan files found in: ${SCAN_DIRS[*]}"
  echo "PASS: 0 fail-open patterns (vacuously true)"
  exit 0
fi

echo "=========================================="
echo "Fail-Closed Check (Security Law)"
echo "=========================================="
echo "Scan files: ${#SCAN_FILES[@]} (from ${SCAN_DIRS[*]})"
echo ""

# Pattern 1: fail-open 默认值
FAIL_OPEN_PATTERNS=(
  '??\s*'\''fallback'\'''
  '??\s*'\''default'\'''
  '??\s*'\''kallax-dev-key'\'''
  '??\s*'\''dev-key'\'''
  '\|\|\s*'\''fallback'\'''
  '\|\|\s*'\''default'\'''
  '\|\|\s*'\''kallax-dev-key'\'''
  '\|\|\s*'\''dev-key'\'''
)

# Pattern 2: auth check 中 return true
AUTH_FAIL_OPEN_PATTERNS=(
  'function\s+.*auth.*\)\s*\{\s*return\s+true'
  'function\s+.*check.*\)\s*\{\s*return\s+true'
)

# Pattern 3: logger.error 包含 password/secret/token
LOGGER_LEAK_PATTERNS=(
  'logger\.(error|warn|info|debug).*(password|secret|token|api[_-]?key)'
  'console\.(error|warn|info|debug).*(password|secret|token|api[_-]?key)'
)

FOUND=()
for file in "${SCAN_FILES[@]}"; do
  for pat in "${FAIL_OPEN_PATTERNS[@]}" "${AUTH_FAIL_OPEN_PATTERNS[@]}" "${LOGGER_LEAK_PATTERNS[@]}"; do
    if matches=$(grep -nE "$pat" "$file" 2>/dev/null); then
      while IFS= read -r match; do
        FOUND+=("$file: $match")
      done <<< "$matches"
    fi
  done
done

if [ ${#FOUND[@]} -gt 0 ]; then
  echo "FAIL: ${#FOUND[@]} fail-open patterns detected:"
  printf '  %s\n' "${FOUND[@]}"
  echo ""
  echo "REQUIREMENT: 0 fail-open. Use explicit throw + 0 default secret, or redact log fields."
  echo "Reference: V310-B S-001 + V350-B S-003 1:1 联合"
  exit 1
fi

echo "PASS: 0 fail-open patterns in scanned files"

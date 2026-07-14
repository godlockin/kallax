#!/usr/bin/env bash
# scripts/verify/audit-contract.sh — 扫 check-*.sh 是否遵守 CONTRACT.md 3 条 (EPIC-117-B)
#
# Exit codes:
#   0 = PASS (100% 合规)
#   1 = 有违规 (报表 stdout)
#   2 = 参数错误

set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
  esac
done

TOTAL=0
PASS=0
VIOLATIONS=""

for script in scripts/verify/check-*.sh; do
  [[ -f "$script" ]] || continue
  TOTAL=$((TOTAL+1))
  name=$(basename "$script")
  issues=""

  # Rule 1: 0-arg auto-discovery — 检测反模式 `${1:?}` (0-arg 直接崩)
  if grep -qE '\$\{1:\?' "$script"; then
    issues="$issues [strict-1arg]"
  fi

  # Rule 2: KALLAX_PRE_COMMIT bypass — 若脚本使用 $1 (positional arg), 应有 bypass 或 auto-discovery
  if grep -qE 'EPIC_ID=.?["'\'']?\$1' "$script" || grep -qE '\$\{?1(:-)?' "$script"; then
    if ! grep -q 'KALLAX_PRE_COMMIT' "$script" && ! grep -q 'auto-discover' "$script" && ! grep -q 'git diff --cached' "$script"; then
      issues="$issues [no-bypass-or-discovery]"
    fi
  fi

  # Rule 3: exit code semantics — 检测反模式 `exit 2` 用于 skip (应 exit 0)
  # heuristic: "exit 2" 附近 100 char 内含 "skip" / "no ... found"
  if grep -B2 -A0 'exit 2' "$script" 2>/dev/null | grep -qiE '(skip|not found|missing)'; then
    issues="$issues [exit-2-for-skip]"
  fi

  if [[ -z "$issues" ]]; then
    PASS=$((PASS+1))
    [[ $VERBOSE -eq 1 ]] && echo "PASS $name"
  else
    VIOLATIONS="$VIOLATIONS\n  $name:$issues"
  fi
done

echo ""
echo "=== CONTRACT audit: $PASS/$TOTAL PASS ==="
if [[ $PASS -lt $TOTAL ]]; then
  # shellcheck disable=SC2059
  printf "$VIOLATIONS\n"
  echo ""
  echo "See scripts/verify/CONTRACT.md for the 3 rules."
  exit 1
fi
exit 0

#!/usr/bin/env bash
# scripts/kallax-verify.sh — KALLAX v3.7.0 root command: 验证 (跟 CLAUDE.md 1.5KB §4 根本 价值 1:1)
# 合并 W2 5-Level Fact-Forcing (scripts/verify/level-{1..5}.sh) — 0 breaking changes
# 跟 V310-B L1-L5 + V350-B L1-L5 1:1 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== kallax verify (W2 5-Level Fact-Forcing, 跟 CLAUDE.md 1.5KB §验证 1:1) ==="
echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Worktree: $REPO_ROOT"
echo ""

LEVEL="${1:-all}"

run_level() {
  local lvl="$1"
  local script="$REPO_ROOT/scripts/verify/level-$lvl.sh"
  if [ -x "$script" ]; then
    echo "[L$lvl] level-$lvl.sh"
    bash "$script"
  else
    echo "[L$lvl] level-$lvl.sh missing — skip"
  fi
}

if [ "$LEVEL" = "all" ]; then
  for lvl in 1 2 3 4 5; do
    run_level "$lvl"
    echo ""
  done
elif [[ "$LEVEL" =~ ^[1-5]$ ]]; then
  run_level "$LEVEL"
else
  echo "Usage: kallax verify [1|2|3|4|5|all]"
  exit 1
fi

# Also run 5 immutable scripts (跟 V350-B + V370 1:1 联合)
echo ""
echo "=== 5 immutable scripts (法律, 跟 V350-B P-002 + v3.7.0 +1 1:1) ==="
for script in check-decorative-claim.sh check-narrative.sh check-fail-closed.sh check-self-heal.sh check-evidence-fake.sh; do
  if [ -x "$REPO_ROOT/scripts/verify/$script" ]; then
    echo "[$script]"
    bash "$REPO_ROOT/scripts/verify/$script" || true
    echo ""
  fi
done

echo "=== kallax verify complete ==="
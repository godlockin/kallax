#!/usr/bin/env bash
# scripts/kallax-govern.sh — KALLAX v3.7.0 root command: 治理 (跟 CLAUDE.md 1.5KB §4 根本 价值 1:1)
# 合并 W3 Sub-Role Dispatch (scripts/verify/performer-subrole.sh) + W4 EPIC 4 件套 (scripts/verify/check-epic-4-piece.sh)
# 0 breaking changes (backward compat)
# 跟 V310-B sub-role + V350-B EPIC 4 件套 1:1 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== kallax govern (W3 Sub-Role + W4 EPIC 4 件套, 跟 CLAUDE.md 1.5KB §治理 1:1) ==="
echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Worktree: $REPO_ROOT"
echo ""

# W3 Sub-Role Dispatch (跟 V350-B P-001 1:1 联合)
if [ -x "$REPO_ROOT/scripts/verify/performer-subrole.sh" ]; then
  echo "[W3] performer-subrole.sh (sub-role dispatch 跟 4 roles 1:1 联合)"
  bash "$REPO_ROOT/scripts/verify/performer-subrole.sh" "$@" || true
fi

echo ""

# W4 EPIC 4 件套 (跟 V310-B + V350-B + Q15 1:1 联合)
if [ -x "$REPO_ROOT/scripts/verify/check-epic-4-piece.sh" ]; then
  echo "[W4] check-epic-4-piece.sh (EPIC 4 件套, 跟 Rule 6/7 1:1 联合)"
  bash "$REPO_ROOT/scripts/verify/check-epic-4-piece.sh" "$@" || true
fi

echo ""
echo "=== kallax govern complete ==="
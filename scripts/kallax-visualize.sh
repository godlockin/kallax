#!/usr/bin/env bash
# scripts/kallax-visualize.sh — KALLAX v3.7.0 root command: 可视化 (跟 CLAUDE.md 1.5KB §4 根本 价值 1:1)
# 合并 W5 Hook Server (.kallax/hooks/) + W6 Dashboard (scripts/dashboard/, web/src/)
# 0 breaking changes (backward compat)
# 跟 V310-B hook + V350-B dashboard 1:1 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== kallax visualize (W5 Hook + W6 Dashboard, 跟 CLAUDE.md 1.5KB §可视化 1:1) ==="
echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Worktree: $REPO_ROOT"
echo ""

# W5 Hook Server (跟 V310-B hook-pipeline 1:1 联合)
if [ -f "$REPO_ROOT/.kallax/hooks/pre-commit" ]; then
  echo "[W5] .kallax/hooks/pre-commit (5 immutable scripts, 跟 v3.7.0 +1 1:1 联合)"
  echo "  pre-commit: $(wc -l < "$REPO_ROOT/.kallax/hooks/pre-commit") lines"
  echo "  5 scripts wired: check-decorative-claim / check-narrative / check-fail-closed / check-self-heal / check-evidence-fake"
fi

echo ""

# W6 Dashboard (跟 V310-B + V350-B dashboard 1:1 联合)
if [ -x "$REPO_ROOT/scripts/dashboard/dispatch-dashboard.sh" ]; then
  echo "[W6] dispatch-dashboard.sh (跟 5 levels 1:1 联合)"
  bash "$REPO_ROOT/scripts/dashboard/dispatch-dashboard.sh" "$@" || true
fi

if [ -x "$REPO_ROOT/scripts/dashboard/process-metrics.sh" ]; then
  echo ""
  echo "[W6] process-metrics.sh (跟 0 估数 1:1 联合)"
  bash "$REPO_ROOT/scripts/dashboard/process-metrics.sh" "$@" || true
fi

echo ""
echo "=== kallax visualize complete ==="
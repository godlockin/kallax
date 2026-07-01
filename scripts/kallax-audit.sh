#!/usr/bin/env bash
# scripts/kallax-audit.sh — KALLAX v3.7.0 root command: 审计 (跟 CLAUDE.md 1.5KB §4 根本 价值 1:1)
# 合并 W1 Hash-Chain Audit (scripts/audit/*) — 0 breaking changes (backward compat)
# 跟 V350-B P-001 + V350-B P-002 + Q12 战略 1:1 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== kallax audit (W1 Hash-Chain Audit, 跟 CLAUDE.md 1.5KB §审计 1:1) ==="
echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Worktree: $REPO_ROOT"
echo ""

# Delegate to existing audit scripts (backward compat: scripts/audit/* 维持)
if [ -x "$REPO_ROOT/scripts/audit/audit-chain.sh" ]; then
  echo "[1/4] audit-chain.sh (W1 Hash-Chain Audit)"
  bash "$REPO_ROOT/scripts/audit/audit-chain.sh" "$@"
else
  echo "[1/4] audit-chain.sh missing — skip"
fi

if [ -x "$REPO_ROOT/scripts/audit/kpi-audit.sh" ]; then
  echo ""
  echo "[2/4] kpi-audit.sh (跟 0 估数 1:1 联合)"
  bash "$REPO_ROOT/scripts/audit/kpi-audit.sh" "$@"
fi

if [ -x "$REPO_ROOT/scripts/audit/independent-witness.sh" ]; then
  echo ""
  echo "[3/4] independent-witness.sh (L4 boundary)"
  bash "$REPO_ROOT/scripts/audit/independent-witness.sh" "$@"
fi

if [ -x "$REPO_ROOT/scripts/verify/continuous-audit.sh" ]; then
  echo ""
  echo "[4/4] continuous-audit.sh (跟 5 immutable scripts 1:1 联合)"
  bash "$REPO_ROOT/scripts/verify/continuous-audit.sh" "$@"
fi

echo ""
echo "=== kallax audit complete (跟 CLAUDE.md 1.5KB §4 根本 价值 1:1 联合) ==="
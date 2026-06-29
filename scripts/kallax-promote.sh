#!/usr/bin/env bash
# KALLAX Promote — testing → miao (KALLAX-style CLI entry point)
# Unified wrapper for branch promote (testing → miao)
# Usage:
#   kallax promote testing → miao         (full-flow, default)
#   kallax promote testing → miao --dry-run
#   kallax promote testing → miao --emergency
#   kallax promote testing → miao --skip-pr   (merge + push only, no PR creation)
#
# 跟"翻篇&精进" 战略 联合: 0 简单 记录, 跟 branch-promote.sh 联合 0 重写
# 跟 AGENTS.md 5 levels Fact-Forcing 联合: 验证 0 假 PASS
# Ticket: jira/tickets/EPIC-029-K/ticket.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRANCH_PROMOTE_SH="${KALLAX_ROOT}/scripts/branch-promote.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

usage() {
  cat <<EOF
Usage: kallax promote <from> → <to> [options]

Promote branches using the KALLAX branch pipeline.

Arguments:
  <from>   Source branch (e.g. testing)
  <to>     Target branch (e.g. miao) — use the arrow (→) syntax
           Note: "→" is a Unicode character (U+2192). Both "→" and "->" accepted.

Options:
  --dry-run       Show what would happen, do not actually create PR
  --emergency     Bypass expert panel approval (use with caution)
  --skip-pr       Merge + push directly, skip PR creation
  --help, -h      Show this help

Examples:
  kallax promote testing → miao
  kallax promote testing → miao --dry-run
  kallax promote testing → miao --emergency

Exit codes:
  0  success
  1  blocked (e.g. no commits to release, role check failed)
  2  invalid arguments
  3  internal error (e.g. branch-promote.sh missing)
EOF
}

# ── Argument parsing (kallax promote <from> → <to> [options]) ────────────

# Collect positional + flag args; we need to detect "→" or "->" between branch names
FROM_BRANCH=""
TO_BRANCH=""
ARROW_FOUND=0
EXTRA_ARGS=()

# Phase 1: collect all args, normalise "->" to "→"
NORMALIZED_ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "->" ]]; then
    NORMALIZED_ARGS+=("→")
  else
    NORMALIZED_ARGS+=("$arg")
  fi
done

set -- "${NORMALIZED_ARGS[@]}"

# Phase 2: parse — first non-flag, non-arrow arg = FROM, then "→", then TO
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --dry-run|--emergency|--skip-pr)
      EXTRA_ARGS+=("$1")
      shift
      ;;
    →)
      if [[ -z "$FROM_BRANCH" ]]; then
        echo -e "${RED}ERROR:${NC} '→' appeared before any branch name"
        echo "  Usage: kallax promote <from> → <to>"
        exit 2
      fi
      if [[ -n "$TO_BRANCH" ]]; then
        echo -e "${RED}ERROR:${NC} multiple '→' found, expected exactly one"
        echo "  Usage: kallax promote <from> → <to>"
        exit 2
      fi
      ARROW_FOUND=1
      shift
      ;;
    -*)
      echo -e "${RED}ERROR:${NC} unknown flag: $1"
      echo "  Run 'kallax promote --help' for usage"
      exit 2
      ;;
    *)
      if [[ $ARROW_FOUND -eq 0 ]]; then
        if [[ -z "$FROM_BRANCH" ]]; then
          FROM_BRANCH="$1"
        else
          echo -e "${RED}ERROR:${NC} expected '→' after '$FROM_BRANCH', got '$1'"
          echo "  Usage: kallax promote <from> → <to>"
          exit 2
        fi
      else
        if [[ -z "$TO_BRANCH" ]]; then
          TO_BRANCH="$1"
        else
          echo -e "${RED}ERROR:${NC} unexpected extra argument: $1"
          echo "  Usage: kallax promote <from> → <to>"
          exit 2
        fi
      fi
      shift
      ;;
  esac
done

# ── Validation ──

if [[ $ARROW_FOUND -eq 0 ]]; then
  echo -e "${RED}ERROR:${NC} missing '→' between source and target branch"
  echo "  Usage: kallax promote <from> → <to>"
  echo "  Example: kallax promote testing → miao"
  exit 2
fi

if [[ -z "$FROM_BRANCH" ]] || [[ -z "$TO_BRANCH" ]]; then
  echo -e "${RED}ERROR:${NC} both source and target branches are required"
  echo "  Usage: kallax promote <from> → <to>"
  exit 2
fi

# L1: branch-promote.sh dependency check
if [[ ! -x "$BRANCH_PROMOTE_SH" ]]; then
  echo -e "${RED}ERROR:${NC} branch-promote.sh not found or not executable at:"
  echo "  ${BRANCH_PROMOTE_SH}"
  exit 3
fi

# ── Banner ──
echo "=========================================="
echo " KALLAX Promote: ${FROM_BRANCH} → ${TO_BRANCH}"
echo "=========================================="
echo ""
echo "  From:   ${FROM_BRANCH}"
echo "  To:     ${TO_BRANCH}"
echo "  Args:   ${EXTRA_ARGS[*]:-none}"
echo ""

# ── Forward to branch-promote.sh ──
# branch-promote.sh accepts: [--dry-run] [--emergency] as positional args
# Note: it uses $1 and $2 directly, not --flag syntax
# We adapt: dry-run/emergency are positional $1/$2 in branch-promote.sh

# Translate EXTRA_ARGS to positional format expected by branch-promote.sh
# branch-promote.sh: DRY_RUN="${1:-}" EMERGENCY="${2:-}"
FORWARD_ARGS=()
DRY_RUN_SET=0
EMERGENCY_SET=0

for arg in "${EXTRA_ARGS[@]}"; do
  case "$arg" in
    --dry-run)  FORWARD_ARGS+=("--dry-run"); DRY_RUN_SET=1 ;;
    --emergency) FORWARD_ARGS+=("--emergency"); EMERGENCY_SET=1 ;;
    --skip-pr)
      echo -e "${YELLOW}WARN:${NC} --skip-pr not yet implemented by branch-promote.sh"
      echo "  Falling through to full PR-creation flow"
      ;;
  esac
done

# Call the underlying branch-promote.sh (it expects positional args: [--dry-run] [--emergency])
if [[ $DRY_RUN_SET -eq 1 ]] && [[ $EMERGENCY_SET -eq 1 ]]; then
  bash "$BRANCH_PROMOTE_SH" "--dry-run" "--emergency"
elif [[ $DRY_RUN_SET -eq 1 ]]; then
  bash "$BRANCH_PROMOTE_SH" "--dry-run"
elif [[ $EMERGENCY_SET -eq 1 ]]; then
  bash "$BRANCH_PROMOTE_SH" "--emergency"
else
  bash "$BRANCH_PROMOTE_SH"
fi

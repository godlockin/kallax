#!/usr/bin/env bash
# scripts/check-first-screen.sh — First-Screen Review Gate (EPIC-173)
# 主公 2026-08-05 拍板: README/dashboard 改前主公预览机制
#
# 跟 loopx AGENTS.md First-Screen Review Gate 1:1 联合
# 跟 EPIC-163 check-private-context 1:1 pattern 联合
#
# 检测 5 first-screen paths:
#   1. README.md          (主入口)
#   2. README.en.md       (English version)
#   3. web/index.html     (hosted frontstage)
#   4. web/showcase/index.html (showcase index)
#   5. docs/showcases/README.md (showcase catalog)
#
# Exit: 0=PASS, 1=FAIL (fail-closed), 2=BLOCKED-env
#
# 触发: staged diff 检测 first-screen files → 提示主公预览

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<EOF
KALLAX First-Screen Review Gate — EPIC-173

用法: scripts/check-first-screen.sh [--staged-only]

检测 5 first-screen paths 改动:
  1. README.md
  2. README.en.md
  3. web/index.html
  4. web/showcase/index.html
  5. docs/showcases/README.md

Exit codes:
  0 = PASS (无 first-screen 改动 或 已批准)
  1 = FAIL (first-screen 改动未批准, fail-closed)
  2 = BLOCKED-env (环境异常)

Options:
  --staged-only  只扫 staged files (pre-commit hook 用)
  --approved     标记 first-screen 改动已批准 (跳过检查)
EOF
}

# Parse args
STAGED_ONLY=0
APPROVED=0
for arg in "$@"; do
  case "$arg" in
    -h|--help|help) usage; exit 0 ;;
    --staged-only) STAGED_ONLY=1 ;;
    --approved) APPROVED=1 ;;
  esac
done

warn() { echo -e "\033[1;33m[WARN]\033[0m $*" >&2; }
err()  { echo -e "\033[1;31m[ERR]\033[0m $*" >&2; }
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m $*"; }

FAIL_COUNT=0
BLOCKED_COUNT=0

# ============================================================================
# First-Screen Paths (跟 loopx AGENTS.md 1:1)
# ============================================================================
FIRST_SCREEN_PATHS=(
  "README.md"
  "README.en.md"
  "web/index.html"
  "web/showcase/index.html"
  "docs/showcases/README.md"
)

# ============================================================================
# Stage 1 — Detect First-Screen Changes
# ============================================================================
stage_first_screen_detection() {
  info "Stage 1: First-screen detection"

  # Get files to scan
  local files
  if [ "$STAGED_ONLY" -eq 1 ]; then
    files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
  else
    files=$(git ls-files 2>/dev/null || true)
  fi

  [ -z "$files" ] && { ok "Stage 1: no files to scan"; return 0; }

  # Check if any first-screen paths are modified
  local found_any=0
  local found_list=""

  for path in "${FIRST_SCREEN_PATHS[@]}"; do
    if echo "$files" | grep -qE "^${path}$"; then
      found_any=1
      found_list="${found_list}  - ${path}\n"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  done

  if [ "$found_any" -eq 1 ]; then
    err "First-screen changes detected:"
    echo -e "$found_list"
  else
    ok "Stage 1: 0 first-screen changes"
  fi
}

# ============================================================================
# Stage 2 — Check Approval Status
# ============================================================================
stage_approval_check() {
  info "Stage 2: Approval check"

  # Check for approval marker (KALLAX_FIRST_SCREEN_APPROVED env var)
  if [ "${KALLAX_FIRST_SCREEN_APPROVED:-0}" == "1" ]; then
    ok "Stage 2: First-screen approved via KALLAX_FIRST_SCREEN_APPROVED=1"
    FAIL_COUNT=0
    return 0
  fi

  # Check for .first-screen-approved marker file
  if [ -f ".first-screen-approved" ]; then
    local approved_by approved_at
    approved_by=$(grep "^approved_by:" ".first-screen-approved" 2>/dev/null | cut -d: -f2 | xargs || echo "unknown")
    approved_at=$(grep "^approved_at:" ".first-screen-approved" 2>/dev/null | cut -d: -f2 | xargs || echo "unknown")
    ok "Stage 2: First-screen approved by ${approved_by} at ${approved_at}"
    FAIL_COUNT=0
    return 0
  fi

  if [ "$FAIL_COUNT" -gt 0 ]; then
    err "Stage 2: First-screen changes NOT approved"
  else
    ok "Stage 2: No first-screen changes to approve"
  fi
}

# ============================================================================
# Main
# ============================================================================
info "=========================================="
info "First-Screen Review Gate (EPIC-173)"
info "=========================================="

stage_first_screen_detection
stage_approval_check

echo ""

# Exit code contract (跟 scan-dead-code.sh / check-private-context.sh 1:1)
if [ "$BLOCKED_COUNT" -gt 0 ]; then
  err "BLOCKED-env: $BLOCKED_COUNT environment blockers"
  exit 2
elif [ "$FAIL_COUNT" -gt 0 ]; then
  err "FAIL: $FAIL_COUNT first-screen violations detected"
  err ""
  err "First-screen changes require master (主公) preview approval before commit."
  err "To approve: KALLAX_FIRST_SCREEN_APPROVED=1 git commit ..."
  err "Or create .first-screen-approved file with approved_by:/approved_at: fields"
  exit 1
else
  ok "PASS: 0 first-screen violations"
  exit 0
fi

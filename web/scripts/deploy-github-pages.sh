#!/usr/bin/env bash
# web/scripts/deploy-github-pages.sh — deploy web dashboard to GitHub Pages
#
# EPIC-060-A Phase 4 — web dashboard server 真部署 准备 (备选 platform)
# 跟 EPIC-058-C 部署就绪 联合, 跟 Cloudflare Pages 备选 联合, 0 vendor lock-in
# Usage: bash web/scripts/deploy-github-pages.sh [--dry-run]
#
# Pushes web/src/dashboard to gh-pages branch via gh-pages CLI.
# 0 hardcoded credentials (gh-pages uses git auth from env).

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WEB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly DASHBOARD_DIR="src/dashboard"
readonly GH_PAGES_BRANCH="gh-pages"
readonly GH_PAGES_COMMIT_MSG="deploy: web dashboard $(date -u +%Y-%m-%dT%H:%M:%SZ)"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg: $arg (use --dry-run)" >&2
      exit 2
      ;;
  esac
done

if [ ! -d "$WEB_ROOT/$DASHBOARD_DIR" ]; then
  echo "ERROR: dashboard dir not found: $WEB_ROOT/$DASHBOARD_DIR" >&2
  exit 2
fi

if ! command -v gh-pages >/dev/null 2>&1; then
  echo "ERROR: gh-pages CLI not installed. Install: npm install -g gh-pages" >&2
  echo "  (跟'翻篇&精进' 战略 联合: 0 增命令 强制, gh-pages 仅 部署时 必需)" >&2
  exit 1
fi

echo "=== GitHub Pages Deploy ==="
echo "Source: $WEB_ROOT/$DASHBOARD_DIR"
echo "Target branch: $GH_PAGES_BRANCH"
echo "Mode: $([ "$DRY_RUN" -eq 1 ] && echo 'dry-run' || echo 'live')"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  echo "--- DRY RUN: validating deploy preconditions ---"
  echo "  [OK] gh-pages CLI present: $(gh-pages --version 2>&1 | head -n 1)"
  echo "  [OK] dashboard dir exists: $WEB_ROOT/$DASHBOARD_DIR ($(find "$WEB_ROOT/$DASHBOARD_DIR" -type f | wc -l | tr -d ' ') files)"
  echo ""
  echo "DRY RUN OK: would run: gh-pages -d \"$WEB_ROOT/$DASHBOARD_DIR\" -b \"$GH_PAGES_BRANCH\""
  echo "  (跟 EPIC-060-A 分布式 路线图 联合, 0 vendor lock-in)"
  exit 0
fi

echo "--- LIVE DEPLOY: gh-pages ---"
cd "$WEB_ROOT"
if gh-pages -d "$DASHBOARD_DIR" -b "$GH_PAGES_BRANCH" -m "$GH_PAGES_COMMIT_MSG" 2>&1; then
  echo ""
  echo "DEPLOY OK: pushed to branch=$GH_PAGES_BRANCH (0 vendor lock-in: git + gh-pages 部署)"
  exit 0
fi
echo "ERROR: gh-pages deploy failed (see output above)" >&2
exit 3
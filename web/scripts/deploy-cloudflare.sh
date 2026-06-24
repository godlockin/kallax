#!/usr/bin/env bash
# web/scripts/deploy-cloudflare.sh — deploy web dashboard to Cloudflare Pages
#
# EPIC-060-A Phase 4 — web dashboard server 真部署 准备
# 跟 EPIC-058-C 部署就绪 联合, 跟"反讽" 联合 治根 vendor lock-in
# Usage: bash web/scripts/deploy-cloudflare.sh [--dry-run]
#
# Env vars (12-factor, 0 hardcoded credentials):
#   CLOUDFLARE_ACCOUNT_ID  — Cloudflare account id (required for real deploy)
#   CLOUDFLARE_API_TOKEN   — API token (required for real deploy)
#   CLOUDFLARE_PROJECT_NAME — Pages project name (default: kallax-web-dashboard)
#
# Exit codes:
#   0  success (real deploy or --dry-run validated)
#   1  missing tool (wrangler)
#   2  invalid args / missing required env (only when not --dry-run)
#   3  deploy failure (real deploy only)

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WEB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly DEFAULT_PROJECT_NAME="kallax-web-dashboard"
readonly DASHBOARD_DIR="src/dashboard"
readonly WRANGLER_TIMEOUT_SEC=300
readonly DRY_RUN_TIMEOUT_SEC=10

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h)
      sed -n '2,20p' "$0"
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

readonly PROJECT_NAME="${CLOUDFLARE_PROJECT_NAME:-$DEFAULT_PROJECT_NAME}"

if ! command -v wrangler >/dev/null 2>&1; then
  echo "ERROR: wrangler CLI not installed. Install: npm install -g wrangler" >&2
  echo "  (跟'翻篇&精进' 战略 联合: 0 增命令 强制, wrangler 仅 部署时 必需)" >&2
  exit 1
fi

echo "=== Cloudflare Pages Deploy ==="
echo "Project: $PROJECT_NAME"
echo "Source: $WEB_ROOT/$DASHBOARD_DIR"
echo "Mode: $([ "$DRY_RUN" -eq 1 ] && echo 'dry-run' || echo 'live')"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  echo "--- DRY RUN: validating deploy preconditions ---"
  echo "  [OK] wrangler CLI present: $(wrangler --version 2>&1 | head -n 1)"
  echo "  [OK] dashboard dir exists: $WEB_ROOT/$DASHBOARD_DIR ($(find "$WEB_ROOT/$DASHBOARD_DIR" -type f | wc -l | tr -d ' ') files)"
  if [ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
    echo "  [OK] CLOUDFLARE_ACCOUNT_ID set (env)"
  else
    echo "  [WARN] CLOUDFLARE_ACCOUNT_ID 0 set (real deploy needs it)"
  fi
  if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    echo "  [OK] CLOUDFLARE_API_TOKEN set (env, length=${#CLOUDFLARE_API_TOKEN})"
  else
    echo "  [WARN] CLOUDFLARE_API_TOKEN 0 set (real deploy needs it)"
  fi
  echo ""
  echo "DRY RUN OK: would run: wrangler pages deploy \"$WEB_ROOT/$DASHBOARD_DIR\" --project-name=\"$PROJECT_NAME\""
  echo "  (跟 EPIC-058-C 部署就绪 联合, 0 真实 域 名 必需)"
  exit 0
fi

if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] || [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "ERROR: real deploy needs CLOUDFLARE_ACCOUNT_ID + CLOUDFLARE_API_TOKEN env vars" >&2
  echo "  0 hardcoded credentials (跟'不埋坑' 联合)" >&2
  echo "  use --dry-run to validate without deploying" >&2
  exit 2
fi

echo "--- LIVE DEPLOY: wrangler pages deploy ---"
cd "$WEB_ROOT"
if wrangler pages deploy "$DASHBOARD_DIR" --project-name="$PROJECT_NAME" \
     --timeout="$WRANGLER_TIMEOUT_SEC" 2>&1; then
  echo ""
  echo "DEPLOY OK: Cloudflare Pages project=$PROJECT_NAME (跟'反讽' 联合 0 vendor lock-in: env-driven config)"
  exit 0
fi
echo "ERROR: wrangler pages deploy failed (see output above)" >&2
exit 3
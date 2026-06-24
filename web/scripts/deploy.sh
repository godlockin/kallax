#!/usr/bin/env bash
# web/scripts/deploy.sh — dispatcher for web dashboard deployment
#
# EPIC-060-A Phase 4 — web dashboard server 真部署 准备
# 跟 EPIC-058-C 部署就绪 联合, 跟"反讽" 联合 治根 vendor lock-in
# Usage: bash web/scripts/deploy.sh --platform=<cloudflare|github-pages> [--dry-run]
#
# Selects deploy script via --platform flag. All platforms support --dry-run
# (跟 EPIC-058-C verify-deploy.sh 联合, 0 真实 域 名 必需).
#
# Exit codes propagate from sub-script.

set -uo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WEB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly DEPLOY_CLOUDFLARE="$SCRIPT_DIR/deploy-cloudflare.sh"
readonly DEPLOY_GITHUB_PAGES="$SCRIPT_DIR/deploy-github-pages.sh"

PLATFORM=""
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --platform=cloudflare)     PLATFORM="cloudflare" ;;
    --platform=github-pages)   PLATFORM="github-pages" ;;
    --platform=self-hosted)    PLATFORM="self-hosted" ;;
    --dry-run)                 DRY_RUN=1 ;;
    --help|-h)
      cat <<EOF
web/scripts/deploy.sh — dispatch web dashboard deploy to a platform
Usage: bash web/scripts/deploy.sh --platform=<name> [--dry-run]

Platforms:
  cloudflare    Cloudflare Pages (default priority, 0 vendor lock-in via env config)
  github-pages  GitHub Pages via gh-pages CLI (git-based, 0 vendor lock-in)
  self-hosted   Docker self-hosted (Phase 5 multi-master 联合, not yet implemented)

Options:
  --dry-run     validate preconditions without actual deploy (跟 EPIC-058-C verify-deploy 联合)

Examples:
  bash web/scripts/deploy.sh --platform=cloudflare --dry-run
  CLOUDFLARE_ACCOUNT_ID=xxx CLOUDFLARE_API_TOKEN=yyy \\
    bash web/scripts/deploy.sh --platform=cloudflare
EOF
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg: $arg (use --help)" >&2
      exit 2
      ;;
  esac
done

if [ -z "$PLATFORM" ]; then
  echo "ERROR: --platform=<cloudflare|github-pages> required (use --help)" >&2
  exit 2
fi

echo "=== Dispatcher: $PLATFORM ==="
echo ""

case "$PLATFORM" in
  cloudflare)
    if [ "$DRY_RUN" -eq 1 ]; then
      exec bash "$DEPLOY_CLOUDFLARE" --dry-run
    fi
    exec bash "$DEPLOY_CLOUDFLARE"
    ;;
  github-pages)
    if [ "$DRY_RUN" -eq 1 ]; then
      exec bash "$DEPLOY_GITHUB_PAGES" --dry-run
    fi
    exec bash "$DEPLOY_GITHUB_PAGES"
    ;;
  self-hosted)
    echo "ERROR: self-hosted deploy not yet implemented (跟 Phase 5 multi-master 联合)" >&2
    echo "  当前 use Docker manually:" >&2
    echo "    docker build -f $WEB_ROOT/Dockerfile -t kallax-web ." >&2
    echo "    docker run -d -p 8080:8080 kallax-web" >&2
    exit 4
    ;;
esac
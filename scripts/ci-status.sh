#!/usr/bin/env bash
# KALLAX CI Status — check latest CI workflow run status
# Usage: ./scripts/ci-status.sh [--watch]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

WATCH="${1:-}"

# Determine remote
REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$REMOTE" =~ github\.com[:/](.+)/(.+)\.git ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
elif [[ "$REMOTE" =~ github\.com/(.+)/(.+) ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
else
  echo "ERROR: Cannot parse remote URL: ${REMOTE}"
  exit 1
fi

echo "=== KALLAX CI Status ==="
echo "  Repo: ${OWNER}/${REPO}"
echo ""

# Try gh CLI first
if command -v gh &>/dev/null; then
  echo "--- Latest workflow runs ---"
  gh run list --limit 5 --json conclusion,displayTitle,headBranch,createdAt,status 2>/dev/null || {
    echo "  gh CLI failed — check auth: gh auth status"
    exit 1
  }

  if [ "$WATCH" = "--watch" ]; then
    echo ""
    echo "Watching latest run... Press Ctrl+C to stop."
    LATEST=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
    [ -n "$LATEST" ] && gh run watch "$LATEST"
  fi
else
  echo "gh CLI not found. Install: https://cli.github.com/"
  echo ""
  echo "--- Using GitHub API ---"
  curl -sf "https://api.github.com/repos/${OWNER}/${REPO}/actions/runs?per_page=5" 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data.get('workflow_runs', []):
  print(f\"  [{r['status']}] {r['display_title'][:60]:60s} ({r['head_branch']}) - {r.get('conclusion', 'running')}\")
" 2>/dev/null || echo "  API failed (rate limited?)"
fi

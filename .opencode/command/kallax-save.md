---
description: KALLAX save command
---
# /kallax-save — Save current session state for later resumption

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "Save Session"

require_git_repo

SAVE_DIR="${KALLAX_STATE}/sessions"
mkdir -p "$SAVE_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SAVE_FILE="${SAVE_DIR}/session_${TIMESTAMP}.json"

ROLE=$(get_role)
BRANCH=$(current_branch)
REPO=$(get_repo_name)

# Collect session state
cat > "$SAVE_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "role": "${ROLE}",
  "project": "${REPO}",
  "branch": "${BRANCH}",
  "workingDirectory": "${PWD}",
  "gitStatus": "$(git status --porcelain 2>/dev/null | head -20)",
  "recentCommits": "$(git log --oneline -5 2>/dev/null)"
}
EOF

# Save worktree state
if command -v kallax &>/dev/null; then
  WORKTREE_COUNT=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
  echo "  Worktrees:  ${WORKTREE_COUNT}"
fi

# Save task state
if [ -f "${KALLAX_STATE}/instance_config.yml" ]; then
  cat "${KALLAX_STATE}/instance_config.yml" >> "${SAVE_FILE}.yml" 2>/dev/null || true
fi

# Commit if there are changes
if [ "$(has_uncommitted)" = "true" ]; then
  read -r -p "  Uncommitted changes found. Save them? [y/N]: " SAVE_CHANGES
  if [ "$SAVE_CHANGES" = "y" ] || [ "$SAVE_CHANGES" = "Y" ]; then
    git add -A
    git commit -m "chore: save session state ${TIMESTAMP}" 2>/dev/null || true
    log_info "Changes committed"
  fi
fi

echo ""
log_info "Session saved: ${SAVE_FILE}"
echo ""
echo "  Resume with: /kallax-resume"
echo "  Session files: ls ${SAVE_DIR}/"
echo ""

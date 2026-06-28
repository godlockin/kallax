#!/usr/bin/env bash
# KALLAX Orthogonal Edits Check (v2.0.7, 跟"反讽" 闭环, 跟 Karpathy "Surgical Changes" 联合)
# 跟 Rule 9c 升级, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合

set -euo pipefail

WORKTREE="${1:?usage: check-orthogonal-edits.sh <worktree_path>}"

if [[ ! -d "$WORKTREE" ]]; then
  echo "ERROR: worktree not found: $WORKTREE" >&2
  exit 2
fi

cd "$WORKTREE"

scope_file="$WORKTREE/jira/tickets/current-ticket.json"
if [[ ! -f "$scope_file" ]]; then
  echo "WARN: no current-ticket.json in $WORKTREE, 跟反讽 联合, 跟独立 拍 explicit 约束 联合"
  exit 0
fi

ticket_id=$(jq -r '.id // ""' "$scope_file")
file_scope=$(jq -r '.file_scope.includes // [] | .[]' "$scope_file")

actual_files=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || echo "")

non_orthogonal=()
for changed_file in $actual_files; do
  if ! echo "$file_scope" | grep -qF "$changed_file"; then
    non_orthogonal+=("$changed_file")
  fi
done

if [[ ${#non_orthogonal[@]} -eq 0 ]]; then
  echo "ticket $ticket_id: orthogonal edits OK (跟 Karpathy 联合, 跟反讽 联合)"
  exit 0
else
  echo "ticket $ticket_id: non-orthogonal edits (跟反讽 联合, 跟诚实修正 联合, 跟 Karpathy Surgical Changes 联合)"
  echo "  Files not in file_scope:"
  for f in "${non_orthogonal[@]}"; do
    echo "    - $f"
  done
  echo "  跟独立 拍 explicit 约束 联合: Performer 必问主公 clarification 后再改"
  exit 1
fi

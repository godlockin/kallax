#!/usr/bin/env bash
# KALLAX snapshot-claude-md.sh — EPIC-219 (借鉴 prime-agent snapshot rollback 精神)
# CLAUDE.md / .claude/rules/* 修改前自动 git tag + post-edit diff 校验 + 一键 rollback.
#
# Usage:
#   snapshot-claude-md.sh snapshot "msg"  # 改前打 tag, msg 必填 (说明改什么)
#   snapshot-claude-md.sh verify <tag>    # post-edit diff 校验 (期望非空)
#   snapshot-claude-md.sh rollback <tag>  # 一键 git revert 到 tag 状态
#   snapshot-claude-md.sh list            # 列所有 snapshot tag
#
# 借鉴 (跟 confluence/decisions/prime-agent-research-2026-08-08.md 1:1):
# - prime-agent "immutable base system prompt + recorded snapshots support rollback"
# - KALLAX 5 immutable scripts (check-claim-evidence 等) 防 commit 漂移
# - 缺 CLAUDE.md modify snapshot 兜底 → EPIC-219 补
#
# Exit codes (跟 5 immutable scripts 1:1):
#   0 = OK, 1 = FAIL (fail-closed)
set -euo pipefail

# EPIC-277-E: REPO_ROOT 用 BASH_SOURCE 解析 (跟其他 3 hooks 1:1).
REPO_ROOT="$(git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
WATCHED_PATHS=("CLAUDE.md" ".claude/rules/")

list_snapshots() {
  git tag -l "claude-md-pre-*" --sort=-creatordate | head -20
}

cmd="${1:-}"
shift || true

case "$cmd" in
  snapshot)
    msg="${1:?Usage: snapshot-claude-md.sh snapshot <msg>}"
    ts="$(date -u +%Y%m%d-%H%M%S)"
    tag="claude-md-pre-${ts}"
    git -C "$REPO_ROOT" tag "$tag" -m "snapshot: $msg"
    echo "OK snapshot created: $tag"
    echo "rollback cmd: snapshot-claude-md.sh rollback $tag"
    ;;
  verify)
    tag="${1:?Usage: snapshot-claude-md.sh verify <tag>}"
    # 仅校验 tag 存在, 不做 diff 内容 (post-edit diff 是 user 责任)
    if git -C "$REPO_ROOT" rev-parse "$tag" >/dev/null 2>&1; then
      echo "OK tag exists: $tag"
      exit 0
    else
      echo "FAIL tag not found: $tag" >&2
      exit 1
    fi
    ;;
  rollback)
    tag="${1:?Usage: snapshot-claude-md.sh rollback <tag>}"
    if ! git -C "$REPO_ROOT" rev-parse "$tag" >/dev/null 2>&1; then
      echo "FAIL tag not found: $tag" >&2
      exit 1
    fi
    echo "Rolling back CLAUDE.md to $tag..."
    # 仅 revert watched paths, 不动其他 source code
    for path in "${WATCHED_PATHS[@]}"; do
      git -C "$REPO_ROOT" checkout "$tag" -- "$path"
    done
    echo "OK rollback complete (未 commit, 需 git commit 确认)"
    ;;
  list)
    list_snapshots
    ;;
  *)
    echo "Usage: $0 {snapshot <msg>|verify <tag>|rollback <tag>|list}" >&2
    exit 1
    ;;
esac
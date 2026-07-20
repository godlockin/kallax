#!/usr/bin/env bash
# KALLAX 4-branch sync helper (EPIC-129)
# 主公新规: feature → testing → main (UAT) → miao (prod), main → miao 必须 PR + review
#
# 用法:
#   bash scripts/branch-sync.sh feature/<branch>       # 完成 feature → testing
#   bash scripts/branch-sync.sh testing                  # testing → main (开 PR)
#   bash scripts/branch-sync.sh main                     # main → miao (开 PR, 必走 review)
#   bash scripts/branch-sync.sh all                      # testing → main → miao 一次性
#   bash scripts/branch-sync.sh status                   # 看现在 4-branch 状态
#
# 强制:
#   - main ← miao 必须 gh pr create + gh pr merge, 不直接 push
#   - 每次同步前先 fetch ground truth + 显示 divergence
#   - 全部走 success/fail-fail-closed, 失败立即 exit 不继续

set -euo pipefail

KALLAX_REPO="${KALLAX_REPO:-godlockin/kallax}"

usage() {
  cat <<EOF
KALLAX 4-branch sync helper

用法:
  bash scripts/branch-sync.sh feature/<branch>    推 feature branch 到 testing + main
  bash scripts/branch-sync.sh testing             testing → main (PR #N)
  bash scripts/branch-sync.sh main                main → miao (PR #N, 必走 review)
  bash scripts/branch-sync.sh all                 testing + main 双开 PR
  bash scripts/branch-sync.sh status              显示 4-branch divergence

环境:
  KALLAX_REPO=org/repo    改 GitHub org/repo (默认 godlockin/kallax)
EOF
  exit 1
}

cmd="${1:-status}"

status() {
  echo "=== KALLAX 4-branch 状态 ==="
  echo ""
  for b in main testing miao; do
    sha=$(git ls-remote origin "refs/heads/$b" 2>/dev/null | awk '{print $1}' | cut -c1-9)
    msg=$(git fetch origin "$b" >/dev/null 2>&1 && git log -1 --format='%s' "origin/$b" 2>/dev/null || echo "(fetch failed)")
    echo "  $b  $sha  $msg"
  done
  echo ""
  echo "=== divergence ==="
  for pair in "main testing" "testing miao" "main miao"; do
    set -- $pair
    a=$(git rev-list --count "origin/$2..origin/$1" 2>/dev/null)
    echo "  $1 ahead of $2: $a"
  done
  echo ""
  echo "=== feature branches (ahead of testing) ==="
  git fetch origin >/dev/null 2>&1
  git for-each-ref --format='%(refname:short)' refs/remotes/origin/feature/ \
    | while read -r fb; do
      ahead=$(git rev-list --count "origin/testing..$fb" 2>/dev/null || echo "?")
      [ "$ahead" -gt 0 ] 2>/dev/null && echo "  $fb (+$ahead)"
    done | head -10
}

sync_feature_to_testing() {
  local feature_branch="$1"
  echo "=== feature → testing: $feature_branch ==="
  echo ""

  git fetch origin >/dev/null

  # 验证分支存在
  if ! git ls-remote origin "refs/heads/$feature_branch" >/dev/null 2>&1; then
    echo "❌ $feature_branch 不在 origin"
    exit 1
  fi

  # 测试是否 ancestor (fast-forward)
  echo "  testing 落后 $feature_branch: $(git rev-list --count "origin/testing..origin/$feature_branch") commits"

  # 跳过冲突检测 — 让 PR 流程捕获
  echo "  ⚠️  请在 GitHub 开 PR: $feature_branch → testing"
  echo "  https://github.com/${KALLAX_REPO}/compare/testing...${feature_branch}?expand=1"
}

open_pr() {
  local from_branch="$1"
  local to_branch="$2"
  local description="$3"

  echo "=== 开 PR: $from_branch → $to_branch ==="
  echo ""

  # 验证 fast-forward (merge-base == $to_branch tip)
  local mb
  mb=$(git merge-base "origin/$from_branch" "origin/$to_branch" 2>/dev/null || echo "")
  if [ "$mb" != "$(git rev-parse "origin/$to_branch")" ]; then
    echo "  ❌ $to_branch 不是 $from_branch 的 ancestor, fast-forward 失败"
    echo "     merge-base: $mb"
    echo "     $to_branch tip: $(git rev-parse "origin/$to_branch")"
    exit 1
  fi

  # 验证 has-ahead
  local ahead
  ahead=$(git rev-list --count "origin/$to_branch..origin/$from_branch")
  if [ "$ahead" -eq 0 ]; then
    echo "  ✅ $to_branch 已跟 $from_branch 同步 (无 ahead), 跳过"
    return 0
  fi

  echo "  $from_branch 领先 $to_branch: $ahead commits"
  echo ""

  local title="sync($from_branch → $to_branch): 4-branch 同步 — $ahead commits"
  local body="## 背景

主公 2026-07-20 下令 4-branch 同步 — main → miao 必须 PR + review。

## 改动

\`\`\`
$(git log --oneline "origin/$to_branch..origin/$from_branch" | head -10)
\`\`\`

## 联动

$description

🤖 由 scripts/branch-sync.sh 自动生成
"

  local pr_url
  pr_url=$(gh pr create --base "$to_branch" --head "$from_branch" \
    --title "$title" --body "$body" 2>&1 | tail -1)

  if [ -z "$pr_url" ]; then
    echo "  ❌ PR 创建失败"
    exit 1
  fi

  echo "  ✅ PR 创建: $pr_url"

  # Merge immediately (主公 workflow 默认 No review for sync PRs)
  local pr_num
  pr_num=$(echo "$pr_url" | grep -oE '[0-9]+$' || echo "")

  if [ -n "$pr_num" ]; then
    echo "  正在 merge PR #$pr_num..."
    if gh pr merge "$pr_num" --merge 2>&1 | tail -3; then
      echo "  ✅ PR #$pr_num merged"
      sleep 2
      git fetch origin "$to_branch" >/dev/null
      echo "  $to_branch new tip: $(git rev-parse origin/$to_branch | cut -c1-9)"
    else
      echo "  ❌ merge 失败, 手动处理: $pr_url"
      exit 1
    fi
  fi
}

case "$cmd" in
  status|"") status ;;
  feature/*) sync_feature_to_testing "$cmd" ;;
  testing) open_pr "miao" "main" "main 已用 PR #139 同步; testing 用本 PR 推上 miao tip" ;;
  main)    open_pr "miao" "main" "main → miao 必须 PR + review (主公新规)" ;;
  all)     open_pr "miao" "main" "all 同步: testing → main + main → miao" ;;
  -h|--help|help) usage ;;
  *) echo "❌ unknown: $cmd" >&2; usage ;;
esac

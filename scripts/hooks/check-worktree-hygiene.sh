#!/usr/bin/env bash
# KALLAX post-checkout hook — worktree 卫生提示
# EPIC-301 设计: 切到主分支时提示 git worktree prune + 当前 worktree 数
# 退出码: 0 (advisory, 不阻塞)
#
# 触发: git checkout 切到 miao/main/testing 任一主分支
# 联动: EPIC-301 design, feedback-worktree-isolation
#
# git post-checkout 3-arg: $1=prev HEAD, $2=new HEAD, $3=flag (0=file/1=branch).
# 当前 branch 需用 git symbolic-ref HEAD 拿 (hook 上下文, 不是 arg).

set -euo pipefail

# 拿当前 branch 短名
current_branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo "")"

# 只在切到主分支时触发 (避免频繁 UX 干扰)
case "${current_branch}" in
  miao|main|testing)
    ;;
  *)
    exit 0
    ;;
esac

# 统计 worktree 数 (排除主仓自身 1 个)
wt_count=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "==> Worktree 卫生提示 (EPIC-301, post-checkout)"
echo "  切到主分支: ${current_branch}"
echo "  当前 worktree 数: ${wt_count}"

# 阈值 50 (跟 pre-commit check-worktree-count.sh 一致)
THRESHOLD=50

if [[ ${wt_count} -gt ${THRESHOLD} ]]; then
  echo "  ⚠ 超过 ${THRESHOLD} 阈值 (债警戒线)"
  echo "  建议清理:"
  echo "    git worktree prune"
  echo "  详细审计:"
  echo "    bash scripts/verify/check-worktree-hygiene.sh"
fi

# 列出未 prune 的 stale worktree (有 commit 但 path 不存在)
stale_count=$(git worktree list --porcelain 2>/dev/null | grep -c "^prunable" || echo 0)
if [[ ${stale_count} -gt 0 ]]; then
  echo "  ⚠ ${stale_count} 个 stale worktree 待 prune"
  echo "    git worktree prune"
fi

exit 0
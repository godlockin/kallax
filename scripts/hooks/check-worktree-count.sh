#!/usr/bin/env bash
# KALLAX pre-commit hook — worktree 数阈值告警
# EPIC-301 设计: worktree > 50 时阻断 commit + 给清理脚本路径
# 退出码: 0=PASS, 1=FAIL (immutable 二态契约)
#
# 触发: git commit 前
# 联动: EPIC-301 design, feedback-worktree-isolation
# 豁免: KALLAX_HOOK_BYPASS=1 (跟现有豁免 1:1)

set -euo pipefail

# 豁免机制 (跟 pre-commit 1:1 一致)
if [[ "${KALLAX_HOOK_BYPASS:-0}" == "1" ]]; then
  echo "WARN: check-worktree-count bypass via KALLAX_HOOK_BYPASS=1" >&2
  exit 0
fi

if [[ "${CI:-0}" == "1" || "${CI:-}" == "true" ]]; then
  echo "WARN: check-worktree-count bypass via CI=1" >&2
  exit 0
fi

# 统计 worktree 数 (排除主仓自身 1 个)
wt_count=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')

# 阈值 50 (跟 post-checkout check-worktree-hygiene.sh 一致)
THRESHOLD=50

if [[ ${wt_count} -gt ${THRESHOLD} ]]; then
  echo "FAIL: worktree 数 ${wt_count} > ${THRESHOLD}" >&2
  echo "  警告: 累积 6 个月债复发风险 (79 worktree 爆炸历史, 见 confluence/decisions/worktree-debt-retrospective-2026-08-28.md)" >&2
  echo "" >&2
  echo "  清理方案 (本地 worktree + branch, 远程不动):" >&2
  echo "    git worktree prune" >&2
  echo "    git branch --merged miao | xargs git branch -D" >&2
  echo "" >&2
  echo "  详细审计:" >&2
  echo "    bash scripts/verify/check-worktree-hygiene.sh" >&2
  echo "" >&2
  echo "  豁免: KALLAX_HOOK_BYPASS=1 git commit ..." >&2
  exit 1
fi

exit 0
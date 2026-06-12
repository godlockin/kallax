#!/bin/bash
# worktree-assign-2026-06-12.sh — 4 Performer worktree 分配
# 主公 2026-06-12 拍"你来召唤团队拆卡领任务开工"
# Master 强验证: 1+2 容量 实际是 1+4 (4 类 Performer sub-role, 跟 EPIC-038-B 联动)
set -euo pipefail

KALLAX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$KALLAX_ROOT"

echo "=========================================="
echo " Worktree 分配 (4 Performer types)"
echo "=========================================="
echo ""

# 1. 列出现有 worktree
echo "现有 worktree:"
git worktree list | head -10
echo ""

# 2. 4 类 Performer worktree 分配
PERFORMER_BASE=".kallax/worktrees"

declare -A PERFORMER_WTS=(
  ["performer-EPIC-034"]="$PERFORMER_BASE/performer-EPIC-034 (existing, HEAD 516fc21)"
  ["performer-EPIC-035"]="$PERFORMER_BASE/performer-EPIC-035 (new from PHASE-006 @ 49cb5d8)"
  ["performer-EPIC-036"]="$PERFORMER_BASE/performer-EPIC-036 (new from PHASE-006 @ 49cb5d8)"
  ["performer-EPIC-037"]="$PERFORMER_BASE/performer-EPIC-037 (new from PHASE-006 @ 49cb5d8)"
)

for name in "${!PERFORMER_WTS[@]}"; do
  echo "  📦 $name"
  echo "      ${PERFORMER_WTS[$name]}"
done

echo ""
echo "=========================================="
echo " Worktree 分配表 (跟 ticket 联动):"
echo "=========================================="
echo ""
echo "  Performer-EPIC-034 (backend, handoff_depth L2)"
echo "    Worktree: $PERFORMER_BASE/performer-EPIC-034 @ 516fc21"
echo "    Tickets:  EPIC-034-C (P0, 6h) → EPIC-034-D (P0, 6h) → EPIC-034-B (P1, 4h)"
echo "    Gap 9:   接受+完善+思考 联合载体"
echo ""
echo "  Performer-EPIC-035 (backend, handoff_depth L2)"
echo "    Worktree: $PERFORMER_BASE/performer-EPIC-035 (新)"
echo "    Tickets:  EPIC-035-A (P1, 8h merged: worktree_role 4h + Rule 14 4h)"
echo "    Gap 9:   接受 + Hang 防御 L1+L2 联合载体"
echo ""
echo "  Performer-EPIC-036 (backend, handoff_depth L2)"
echo "    Worktree: $PERFORMER_BASE/performer-EPIC-036 (新)"
echo "    Tickets:  EPIC-036-A (P1, 6h) + EPIC-038-B (P1, 8h) = 14h"
echo "    Gap 9:   判断 + Performer sub-role 联合载体"
echo ""
echo "  Performer-EPIC-037 (security, handoff_depth L4)"
echo "    Worktree: $PERFORMER_BASE/performer-EPIC-037 (新)"
echo "    Tickets:  EPIC-037-A (P1, 6h) + EPIC-038-C (P1, 8h) = 14h"
echo "    Gap 9:   增加/完善 + Auditor 角色 联合载体"
echo ""

# 3. 检查现有 performer-EPIC-034 状态
if [[ -d "$PERFORMER_BASE/performer-EPIC-034" ]]; then
  echo "=========================================="
  echo " performer-EPIC-034 当前状态:"
  echo "=========================================="
  git -C $PERFORMER_BASE/performer-EPIC-034 log --oneline -3 2>&1
  echo ""
  git -C $PERFORMER_BASE/performer-EPIC-034 status --short 2>&1 | head -5
  echo ""
fi

# 4. 检查 3 个新 worktree 是否需要建
for wt in performer-EPIC-035 performer-EPIC-036 performer-EPIC-037; do
  if [[ ! -d "$PERFORMER_BASE/$wt" ]]; then
    echo "  ⚠️  $PERFORMER_BASE/$wt 未建 (Conductor 拉 dispatch 后建)"
  else
    echo "  ✓ $PERFORMER_BASE/$wt 已建"
  fi
done

echo ""
echo "=========================================="
echo " 总览: 9 dispatch / 4 Performer worktrees / 1+4 容量"
echo "=========================================="
echo ""
echo "  wave_time: ~32h (并行优化后)"
echo "  work_hours: ~62h (3+14+14+14+15)"
echo "  cost_estimate: ~$200 (跟 Phase 6 decision-record Y 一致)"
echo ""

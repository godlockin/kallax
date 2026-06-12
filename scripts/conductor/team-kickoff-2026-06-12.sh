#!/bin/bash
# team-kickoff-2026-06-12.sh — 一键触发 Conductor 容器 + 团队开工
# 主公 2026-06-12 拍"同意触发" + "触发任务, 团队开工"
# Master session 已写好 4 dispatch 到 conductor_main inbox, 此脚本一键起 conductor
set -euo pipefail

KALLAX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$KALLAX_ROOT"

echo "=========================================="
echo " KALLAX Team Kickoff — 2026-06-12"
echo "=========================================="
echo ""
echo "Top 4 EPIC 派单已就绪:"
echo "  1. EPIC-034-B M1 audit (Step 2, 修 Recall 61%→80%+)"
echo "  2. EPIC-035-A worktree_role 强制绑定 (EKET P1 #16)"
echo "  3. EPIC-036-A 跨 worktree 派单 (Phase 5 模式 G)"
echo "  4. EPIC-037-A 持续 audit (redaction + KPI cron)"
echo ""
echo "路径: .kallax/queue/inbox/conductor_main/"
echo ""

# 1. 验证 4 dispatch 在
DISPATCH_COUNT=$(ls .kallax/queue/inbox/conductor_main/ 2>/dev/null | wc -l | tr -d ' ')
echo "✓ Dispatch 数: $DISPATCH_COUNT (期望 4)"
if [[ "$DISPATCH_COUNT" -ne 4 ]]; then
  echo "✗ ERROR: dispatch 数量不对, Master session 重写"
  exit 1
fi

# 2. 验证 ticket.json 状态
echo ""
echo "✓ Ticket 状态:"
for t in EPIC-034-B EPIC-035-A EPIC-036-A EPIC-037-A; do
  status=$(jq -r '.status' "jira/tickets/$t/ticket.json" 2>/dev/null || echo "missing")
  echo "    $t: $status"
done

# 3. 验证 miao HEAD
MIAO_HEAD=$(git rev-parse --short HEAD)
echo ""
echo "✓ miao HEAD: $MIAO_HEAD"
echo "    35afb6f (主公 流程逻辑 战略转向, 192 行)"
echo "    3c61cca (PHASE-006-ROADMAP, 276 行)"
echo "    3f35d6a (KALLAX-VS-INDUSTRY, 341 行)"

# 4. 一键起 Conductor 容器 (开新 session)
echo ""
echo "=========================================="
echo " 触发 Conductor 容器:"
echo "=========================================="
echo ""
echo "  ! bash .kallax/hooks/session_start.sh --role conductor"
echo ""
echo "  Conductor 容器会自动:"
echo "    1. 拉 .kallax/queue/inbox/conductor_main/ 4 dispatch"
echo "    2. 按 blocked_by 串行派单 (EPIC-034-B → 035-A → 036-A → 037-A)"
echo "    3. 派给 2 performer 容器 (1 conductor + 2 performer 容量)"
echo "    4. Performer 跑 worktree, 报 PASS"
echo "    5. Conductor merge feature → testing, Master 强验证"
echo ""
echo "  Master session 期间可继续:"
echo "    - 监控 .kallax/queue/outbox/ 看 Performer 报告"
echo "    - 跑 Rule 11 v2.1 强验证 6 维度 (git log/show/test/preflight)"
echo "    - 6 EPIC 累积后触发 PHASE-007 闭环 review"
echo ""
echo "=========================================="
echo " Gap 9 流程逻辑元能力 (主公原话 战略):"
echo "=========================================="
echo ""
echo "  4 步流程 = 4 载体 (Top 4 EPIC):"
echo "    接受   ← EPIC-035-A (worktree_role 强制绑定)"
echo "    思考   ← EPIC-034-B (M1 audit 修 Recall)"
echo "    判断   ← EPIC-036-A (跨 worktree 派单)"
echo "    增加/完善 ← EPIC-037-A (持续 audit)"
echo ""
echo "  飞轮"迭代" 阶段核心 = 通过 4 载体训练 Conductor/Performer 元能力"
echo "  跟主公原话'做流程逻辑比扩充配置有用' 完全对齐"
echo ""
echo "=========================================="
echo " 主公下一步:"
echo "=========================================="
echo ""
echo "  A. 开新 session: ! bash .kallax/hooks/session_start.sh --role conductor"
echo "  B. 等待 Performer 报 PASS, Master 强验证"
echo "  C. 6 EPIC 累积后 PHASE-007 闭环 review"
echo ""

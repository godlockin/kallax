# EPIC-015-C: EnterWorktree 前置引导

**Priority**: P0 | **Estimate**: 1d | **Status**: pending
**Assignee**: unassigned | **Branch**: feature/epic-015-c

## 背景
Conductor/Performer 启动后第一次 Edit/Write 操作被拒，因为必须先 EnterWorktree。当前是"被动触发"（操作失败才知道），应该改为"主动引导"（启动时就提示并执行）。

## 交付物

### 1.4 EnterWorktree Auto-Guide
- 集成到 session_start.sh (EPIC-015-A) 中
- 功能:
  1. 检测当前是否在 worktree 内 (检查 `git worktree list`)
  2. 如果不在 worktree → 自动执行 `EnterWorktree`
  3. 对于 Conductor: 创建 `conductor-init` worktree (用于分析/文档/协调)
  4. 对于 Performer: 提示等待 Conductor 分配 worktree
  5. 在 ASCII Card 中显示当前 worktree 状态
- 约束: 不阻塞 session，失败时 fallback 到主目录

## 验收标准
- [ ] Conductor session 启动自动进入 worktree
- [ ] Performer session 提示 worktree 状态
- [ ] 主仓库 miao 分支不再被误修改
- [ ] 集成测试: 新 session → 自动隔离 → Edit 操作成功

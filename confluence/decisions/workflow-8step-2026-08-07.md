# 8 步标准工作流 — 拍板记录

> **日期**: 2026-08-07
> **拍板人**: 主公
> **执行**: master + 团队/agent
> **状态**: APPROVED, 立即生效

## 起源

主公 2026-08-07 命令明确工作流分 6 步, 后扩展为 8 步 (加整理 + 复盘)。本文件固化拍板结果。

## 8 步标准流程

```
1. 主公发布任务
   ↓
2. master 召唤专家组分析 + 评估,创建 ticket
   ↓
3. 团队/agent 领卡 + 分析 + 开 worktree + 处理 + 测试 + 回归 (全链路)
   ↓
4. master review
   - 简单 → master 直接 merge
   - 复杂 → 主公审核
   ↓
5. 同意后逐个 branch 进行 PR + 回归 (4-PR 链: feature → testing → main → miao)
   ↓
6. ✨ 整理 (Consolidate)
   - 代码: 0 装饰 / 0 fail-open / 0 反模式
   - 文档: confluence/decisions/ 更新, index.md 引用同步
   - worktree 状态: 干净 / dirty=0
   - 5-Level Verify L5 边界检查
   - skill policy: enabled_policy 一致
   ↓
7. ✨ 复盘 (Retrospect)
   - 单 EPIC 复盘: 5-10 教训 + How to apply (confluence/decisions/EPIC-XXX-retrospective.md)
   - 阶段性复盘 (Phase review): 多 EPIC/ticket 累计后 (Sprint 末 / Rule 36 / 跨 ≥ 3 release / 主公拍板)
   ↓
8. ✨ 卡标记完成 + 清理 + 收尾
   - ticket 状态 → done
   - worktree remove (--force)
   - branch -d (本地+远端)
   - tmp 清理 (git clean -fdx on gitignored dirs)
   - jira/ 路径残留清 (EPIC-068-A 双写)
```

## 关键约束

1. **worktree 必清理**: agent 退出前必须走 Step 8, 不留 worktree 残留
2. **复盘前不能清理**: Step 7 复盘数据来自 worktree + commit + log, 先复盘后清理
3. **4-PR 链必须维护**: 远端 testing/main/miao 任何一支被删, 立即重建
4. **0 改 CLAUDE.md**: 8 步流程不进 CLAUDE.md, 走 confluence/decisions/ 拍板记录

## 实施

### 立即 (本 session)

- ✅ EPIC-196 v2 治理完成 (5 件事)
- ✅ 4-PR 链恢复 (testing + main + miao)
- ✅ 8 步流程拍板记录 (本文件)
- ✅ EPIC-196 v2 retrospective (单 EPIC 复盘)

### 后续 EPIC-197 (待建)

**worktree 生命周期自动化 hook**:
- Stop hook: agent 退出时扫 `git worktree list`, PR 已 merged → 自动 `worktree remove` + `branch -d`
- post-merge hook: gh merge 成功 → 立即清理
- 跟 EPIC-181 branch-4pr 退出码契约 1:1
- 0 改 source code / 0 改 CLAUDE.md

## 联动

| EPIC | 1:1 联动 |
|---|---|
| EPIC-161 | retrospective-routine.sh 6 阶段 → Step 7 复盘 |
| EPIC-188 | retrospective 8 EPIC 累计 → Step 7 阶段性复盘 |
| EPIC-194 | Rule 36 Sprint 末 4 metric → Step 7 触发条件 |
| EPIC-181 | branch-4pr R1-R5 退出码契约 → Step 5 + Step 8 |
| EPIC-074 | 4-branch flow → Step 5 治理 |
| Rule 34 | Bugfix 独立复现 → Step 4 review |
| EPIC-196 v2 | decisions/ 治理 → Step 6 文档整理 |

## 退出标准 (每个 EPIC 收尾)

- [ ] Step 4 review 通过 (master review 6 维 gate 或主公审核)
- [ ] Step 5 PR 全 MERGED (4-PR 链无 break)
- [ ] Step 6 整理 5 子项全过
- [ ] Step 7 复盘 (单 EPIC 必做, 阶段性按需)
- [ ] Step 8 清理完成 (worktree + branch + tmp)

## Reviewer

- 主公 (拍板)
- master_main (执行)

**Last updated**: 2026-08-07 (8 步流程固化)
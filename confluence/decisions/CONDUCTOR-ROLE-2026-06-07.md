# KALLAX Conductor 角色定义 (master+worker 模式续期)

**Created**: 2026-06-07
**Status**: ✅ ACTIVE — 主公 2026-06-07 拍板续期 master+worker 模式 (1 conductor + 2 performer)
**Author**: master_main

---

## 0. 背景

KALLAX 历史上是单 master 模式. EPIC-021/022 跟后续 EPIC 大, 需多角色协同. 主公 2026-06-07 拍板:

> 续期, 召 1 conductor + 2 performer

## 1. 角色定义 (CLAUDE.md 三角)

```
                Master (仲裁者)
               /              \
           Conductor         Performer (×2)
           (调度者)          (执行者)
```

| 角色 | 职责 | 写代码 | 写工单 | 派发 | 合并 |
|---|---|---|---|---|---|
| **Master** | 跨 EPIC 协调, 仲裁冲突, 批准 release | ❌ 禁 | ❌ 禁 | ✅ (审批) | ✅ (merge) |
| **Conductor** | 派发 + 协调, 不写代码 | ❌ 禁 | ✅ (拆 ticket) | ✅ (dispatch) | ❌ 禁 (master 才有) |
| **Performer** | 在 worktree 实施 + 测试 + 提交 PR | ✅ (worktree) | ❌ 禁 | ❌ 禁 | ❌ 禁 |

## 2. 当前实例化

**主公拍板时是单 master**. 实例化路径:

1. **Conductor 角色启用**: master_main 暂时充当 Conductor (主公决策保留)
   - 理由: 1 master 同时是 conductor, 启动成本最低
   - 升级路径: 当 2 个以上 EPIC 并行时, 召唤 sub-agent 当真正的 Conductor
2. **2 Performer 派遣**: 每次 EPIC, 派 1-2 sub-agent 当 Performer
   - Performer-1: 长期 EPIC (e.g. EPIC-022 18d)
   - Performer-2: 短期 EPIC (e.g. EPIC-024 Sprint 1 0.5d)
3. **worktree 隔离**: 每个 Performer 在独立 worktree
4. **A+B review 2-Group**: master 派 5 专家 panel, review 完 master 仲裁
5. **合并**: master 推到 miao (主公最后审批 release)

## 3. 跟既有 KALLAX 规则的关系

| 规则 | 影响 |
|---|---|
| Rule 1 并行隔离 | Performer 必须在独立 worktree |
| Rule 2 错误处理 | Conductor 派发时检查 error handling |
| Rule 3 产出验证 | master 5 专家 panel 验证 Performer 产出 |
| Rule 4 资源管理 | Conductor 监控 worktree 资源 |
| Rule 5 类型安全 | Performer 实施时遵循 |
| Rule 6 EPIC 三件套 | A+B review 强制, 不跳步 |
| Rule 7 PHASE 闭环 | 3-5 EPIC 触发 review |
| Rule 8 L4 脚本 | 必含 |
| Rule 9 4-Level 强制 | 必跑 preflight |

## 4. 工作流

```
Performer-1 (EPIC-022) ──┐
                          ├─→ Master (仲裁) ──→ miao merge
Performer-2 (EPIC-024) ──┘
                          ↑
                  Conductor (master 兼) 派发
```

## 5. 当前活跃 EPIC + Performer 配置

| EPIC | 估时 | Performer | 状态 |
|---|---|---|---|
| EPIC-022 v1 全范围 | 18d | Performer-1 | 🟡 ready (P0 fix 完启动) |
| EPIC-024 Sprint 1 (MVP L1) | 0.5d | Performer-2 | 🟡 ready |
| EPIC-024 Sprint 2 (L2 扩展) | 1.5d | Performer-2 (接续) | ⏸️ blocked by Sprint 1 |
| EPIC-024 Sprint 3 (L3 生成) | 1.5d | Performer-2 (接续) | ⏸️ blocked by Sprint 2 |

Performer 复用: Sprint 1 → 2 → 3 同一个 Performer 接续, 总 3.5d.

## 6. 升级路径

当 2 个以上长期 EPIC 并行时, 召唤 sub-agent 当真正的 Conductor:
- 跟 master 隔离决策
- 派发 + 协调
- master 仍负责 merge + 仲裁

## 7. 关联文档

- `confluence/decisions/PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md` §7 (主公 6 决策点第 6 项)
- `CLAUDE.md` (Conductor 角色描述)
- `confluence/decisions/WORKFLOW-RULES-2026-06-07.md` (CLAUDE.md Rule 6+7 实施)

---

**Reviewer(s)**: master_main
**Last updated**: 2026-06-07
**Status**: ✅ ACTIVE

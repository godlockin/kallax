# KALLAX EPIC State Machine

> **Ticket**: EPIC-054-C — 6 状态机 (planning → active → blocked → done → archived → closed, 治 A6)
> **Author**: performer-EPIC-054-C
> **Date**: 2026-06-17
> **跟 ticket-schema.md 对齐**: EPIC 状态机 是 ticket 状态机的 *上一级* 抽象

---

## 1. 6 个状态

EPIC (跟 ticket 区别) 走 6 状态生命周期:

| # | 状态 | 语义 | 入口 | 出口 |
|---|------|------|------|------|
| 1 | `planning` | 刚创建, 还在拆卡 (decompose tickets) | `epic create` | → `active` |
| 2 | `active` | 工作进行中 (tickets in_progress) | `planning → active` | → `blocked` / `done` |
| 3 | `blocked` | 遇到阻塞 (等依赖 / 等 Master 拍板) | `active → blocked` | → `active` (unblock) |
| 4 | `done` | 所有 ticket done, 工作完成 | `active → done` | → `archived` / `active` (reopen) |
| 5 | `archived` | 文档归档, EPIC 不可再分 ticket | `done → archived` | → `closed` / `done` (restore) |
| 6 | `closed` | 终止状态, 不可再开 | `archived → closed` | (terminal, 不可再转) |

---

## 2. 状态转换图

```
            ┌──────────┐
            │ planning │
            └────┬─────┘
                 │ start (1)
                 ▼
            ┌──────────┐  block (2)   ┌──────────┐
            │  active  │─────────────▶│ blocked  │
            └────┬─────┘              └────┬─────┘
                 │                          │ unblock (3)
                 │ complete (4)             │
                 ▼                          │
            ┌──────────┐  archive (5)  ┌────┘
            │   done   │─────────────▶┐
            └────┬─────┘              │
                 │ reopen (6)         │ restore (8)
                 └──────┐             │
                        ▼             ▼
                   (active)      ┌──────────┐
                                 │ archived │
                                 └────┬─────┘
                                      │ close (7)
                                      ▼
                                 ┌──────────┐
                                 │  closed  │  ← terminal
                                 └──────────┘
```

---

## 3. 合法转换 (8 条边)

| # | From | To | 触发器 | 备注 |
|---|------|----|---------|------|
| 1 | `planning` | `active` | Conductor 派首批 ticket | 开始工作 |
| 2 | `active` | `blocked` | 任一 ticket 阻塞 / 等依赖 | 阻塞 |
| 3 | `blocked` | `active` | 阻塞解除 / unblock | unblock |
| 4 | `active` | `done` | 所有 ticket `done` | 完成 |
| 5 | `done` | `archived` | Master 确认归档 (跑 `cleanup-empty.sh`) | 归档 |
| 6 | `done` | `active` | 发现需要 fix / 补充 ticket | reopen |
| 7 | `archived` | `closed` | 长期归档 (e.g. 6 个月后) | 终止 |
| 8 | `archived` | `done` | 需要恢复 (e.g. 重新启用 EPIC) | restore |

**规则**: 所有转换必须经过 `validateTransition()` 校验 (在 `node/src/commands/epic-cmd.ts`).

---

## 4. 跳状态 (forbidden state-jumps) — 禁止

以下转换 *绝对* 禁止, 会被 `validateTransition()` 拒绝:

| 非法转换 | 原因 |
|---------|------|
| `planning → done` | 没经过 `active` (没真做工作) |
| `planning → blocked` | 还没 `active` 怎么能 blocked? |
| `planning → archived` | 跳 4 状态 |
| `planning → closed` | 跳 5 状态 |
| `active → archived` | 没经过 `done` (没确认完成) |
| `active → closed` | 跳 4 状态 |
| `blocked → done` | 必须先 unblock 到 `active` |
| `blocked → archived` | 跳 3 状态 |
| `blocked → closed` | 跳 4 状态 |
| `closed → *` | closed 是 terminal, 不可再转 |
| `* → planning` | planning 只能从 `epic create` 入口进, 不能从其他状态 |

**实现**: `validateTransition(from, to)` 返回非 null 错误信息, `epic status` 子命令 exit 1.

---

## 5. 跟 ticket-schema.md 状态机 对齐

| Ticket 状态 | 对应 EPIC 状态 |
|-------------|----------------|
| `backlog`, `analysis`, `ready`, `gate_review` | EPIC `planning` (在拆卡) |
| `in_progress`, `test`, `pr_review` | EPIC `active` (工作进行中) |
| (Ticket `blocked` 是修饰符, 不影响 EPIC) | EPIC `blocked` (等跨 EPIC 依赖) |
| `done` | EPIC `done` (所有 ticket done) |
| (无对应) | EPIC `archived` (EPIC 特有: 文档归档) |
| (无对应) | EPIC `closed` (EPIC 特有: 终止) |

**关键区别**: Ticket 状态机是 *单个 ticket 的生命周期*, EPIC 状态机是 *整个 epic 项目的生命周期*. EPIC `archived` 和 `closed` 没有 ticket 对应 — 因为归档是 EPIC 级别的概念 (整个 epic 不再 active 但保留历史).

---

## 6. epic_index.json 同步

EPIC 状态变更时, `jira/epics/epic_index.json` 也需要同步:

```json
{
  "epics": [
    {
      "id": "EPIC-054",
      "phase": "PHASE-009",
      "status": "active",
      "start_time": "2026-06-16",
      "delivery_time": "2026-07-07"
    }
  ]
}
```

**同步机制**:
1. `epic status <epicId> <newStatus>` 转换时, 自动更新 `epic.json` (atomic write)
2. Master 在 merge 后跑 `scripts/epic/cleanup-empty.sh` 同步 `epic_index.json` (删除 archived 条目)
3. (TODO: 未来) 加 `epic index sync <epicId>` 子命令自动同步

---

## 7. 空 EPIC 目录清理 (治 A6)

`scripts/epic/cleanup-empty.sh` 跟本状态机联动:

| 情况 | 处理 |
|------|------|
| EPIC dir 存在 + `epic.json` 存在 + status=`archived` | 移到 `_archived/EPIC-NNN-{timestamp}/` |
| EPIC dir 存在 + 空 (无 `epic.json`) | 移到 `_archived/EPIC-NNN-{timestamp}/` (治 A6 根因) |
| EPIC dir 存在 + `epic.json` 存在 + status 还在 active | 不动 (需要先 `epic status done`) |

**Performer 边界**: 本 ticket 只交付清理 *机制* (脚本), 实际跑由 Master 在 merge 后执行.

---

## 8. 反例 (Anti-patterns)

❌ **直接修改 epic.json 的 status 字段** (绕过 `epic status` 命令)
   → 会被 Pre-commit hook 拒, 因为跳过状态机校验

❌ **跳状态 planning → done** (没真做工作就标 done)
   → `validateTransition()` 拒, 退出 1

❌ **清理时直接 `rm -rf jira/epics/EPIC-XXX`** (绕过归档)
   → 应该用 `cleanup-empty.sh`, 保留归档记录

❌ **删除 archived 目录** (丢失历史)
   → 归档目录只在 `closed` 后才考虑物理删除 (人工审计)

---

## 9. 跟其他 Rule/Ticket 联动

| 联动对象 | 关系 |
|---------|------|
| `jira/schemas/ticket-schema.md` | 上级抽象, EPIC 包含多个 ticket |
| `scripts/epic/cleanup-empty.sh` | 实现归档转换 (done → archived) |
| `node/src/commands/epic-cmd.ts` | 实现 `epic status` + `validateTransition()` |
| `tests/integration/epic-state-machine-test.sh` | 8/8 PASS 测试覆盖 |
| EPIC-041-B (文件级锁) | 并发安全: `epic status` 写用 atomic write |
| EPIC-041-C (原子写) | `epic status` 写用 tmp + rename |
| EPIC-054-A (worktree 统一) | 同一 worktree 内多 EPIC 状态独立 |
| EPIC-054-B (instance TTL) | archived 状态触发 instance 清理 |
| EPIC-054-D (Rule 合并) | 治 A1 闭环, 跟 A6 治根同源 |

---

## 10. Rule 9 KPI 格式

本 ticket 交付对应 KPI:

```
8/8 PASS (100.0%) — epic-state-machine-test.sh
- TC1: 6 空 EPIC 目录 mock 检测
- TC2: 状态机初始化 (6 状态定义 + 默认 planning)
- TC3: planning → active (合法转换)
- TC4: active → blocked → active (阻塞循环)
- TC5: active → done (完成转换)
- TC6: done → archived (归档转换)
- TC7: archived → closed (终止状态)
- TC8: 跳状态拒绝 (planning → done 被拒)
```

跟主公 2026-06-16 14 问题 A6 治根 联合.
跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合.

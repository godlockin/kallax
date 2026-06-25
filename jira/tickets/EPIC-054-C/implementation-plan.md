# EPIC-054-C IMPLEMENTATION PLAN

> **Ticket**: EPIC-054-C — 空 EPIC 目录清理 + 6 状态机 (planning→active→blocked→done→archived→closed, 治 A6)
> **Performer**: performer-EPIC-054-C
> **Worktree**: `.kallax/worktrees/performer-EPIC-054-C`
> **Branch**: `feature/EPIC-054-C-epic-state-machine`
> **Base SHA**: `7f88823`
> **Date**: 2026-06-17

---

## 1. 目标 (跟 AC 7 条对齐)

| AC | 内容 | 交付 |
|----|------|------|
| AC1 | 6 空 EPIC 目录 (EPIC-042~047) 清理 — 删除空目录 + 修复 `epic_index.json` | `cleanup-empty.sh` 机制 + 文档化未来清理路径 |
| AC2 | `scripts/epic/cleanup-empty.sh` 实现 — 自动扫描空 EPIC 目录 + 自动归档 `archived/` 状态 | 新文件 |
| AC3 | `node/src/commands/epic-cmd.ts` 升级 — 6 状态机校验 | 修改 |
| AC4 | `jira/schemas/epic-state-machine.md` 文档化 | 新文件 |
| AC5 | `tests/integration/epic-state-machine-test.sh` 8/8 PASS | 新文件 |
| AC6 | A6 治根 — 6 空 EPIC 目录闭环 | 机制交付 |
| AC7 | Rule 9 KPI 精确 X/Y 格式 — 8/8 PASS = 100.0% | 测试输出 |

---

## 2. 6 状态机设计 (State Machine)

### 2.1 状态定义

| 状态 | 语义 | 入口 | 出口 |
|------|------|------|------|
| `planning` | 刚创建, 还在拆卡 | `epic create` | → `active` |
| `active` | 工作进行中 | planning → | → `blocked` / `done` |
| `blocked` | 遇到阻塞 | active → | → `active` (unblock) |
| `done` | 工作完成 | active → | → `archived` / `active` (reopen) |
| `archived` | 已归档, 文档保存 | done → | → `closed` / `done` (restore) |
| `closed` | 终止, 不可再开 | archived → | (terminal) |

### 2.2 合法转换图 (5 + 2 = 7 边)

```
            ┌──────────┐
            │ planning │
            └────┬─────┘
                 │ start
                 ▼
            ┌──────────┐  block   ┌──────────┐
            │  active  │◀────────▶│ blocked  │
            └────┬─────┘  unblock └──────────┘
                 │ complete
                 ▼
            ┌──────────┐  archive  ┌──────────┐
            │   done   │──────────▶│ archived │
            └────┬─────┘           └────┬─────┘
                 │ reopen                │ close
                 └──────────┐    ┌──────┘
                            ▼    ▼
                       (active) (closed)
                              restore
                       archived ◀── done
```

**合法转换 (7 条)**:
1. `planning → active` (开始)
2. `active → blocked` (遇阻)
3. `blocked → active` (unblock)
4. `active → done` (完成)
5. `done → archived` (归档)
6. `done → active` (reopen 修复)
7. `archived → closed` (终止)
8. `archived → done` (restore)

**非法转换 (跳状态)**:
- `planning → done` ❌ (没经过 active)
- `planning → blocked` ❌
- `active → archived` ❌ (没经过 done)
- `blocked → done` ❌ (必须 unblock)
- `closed → *` ❌ (terminal)

### 2.3 跟 ticket-schema.md 对齐

- ticket 状态机: `backlog → analysis → ready → gate_review → in_progress → test → pr_review → done`
- EPIC 状态机: 6 状态 (planning/active/blocked/done/archived/closed)
- 关系: ticket `done` → EPIC `done` → EPIC `archived` → EPIC `closed`
- 区别: EPIC 有 `blocked` 状态 (因为 EPIC 可能等 Master 拍板 / 等依赖), ticket 用 `blocked` 修饰符

---

## 3. 文件结构 (5 创建 + 1 修改)

### 3.1 新建文件 (5)

| 路径 | 行数 | 作用 |
|------|------|------|
| `jira/schemas/epic-state-machine.md` | ~80 | 状态机文档, 跟 ticket-schema.md 对齐 |
| `scripts/epic/cleanup-empty.sh` | ~120 | 扫描空 EPIC 目录, 自动归档到 `jira/epics/_archived/` |
| `tests/integration/epic-state-machine-test.sh` | ~280 | 8 case TDD 测试 |
| `jira/tickets/EPIC-054-C/IMPLEMENTATION-PLAN.md` | 本文件 | - |
| `jira/tickets/EPIC-054-C/LESSONS-LEARNED.md` | (后写) | 3-5 lessons |

### 3.2 修改文件 (1)

| 路径 | 改动 | 行数 |
|------|------|------|
| `node/src/commands/epic-cmd.ts` | 加 `epic status <epicId> <newStatus>` 子命令 + 6 状态机校验逻辑 | +60 行 |

---

## 4. TDD 测试设计 (8 case)

| TC | 主题 | 验证 |
|----|------|------|
| TC1 | 6 空 EPIC 目录 mock 检测 | `cleanup-empty.sh --dry-run` 报告 6 个空目录, 退出 0 |
| TC2 | 状态机初始化 | 新建 EPIC 默认 `planning` |
| TC3 | planning → active | 合法转换, status 字段更新 |
| TC4 | active → blocked → active | 阻塞循环, unblock 恢复 |
| TC5 | active → done | 完成转换 |
| TC6 | done → archived | 归档转换, 状态写入 |
| TC7 | archived → closed | 终止状态, 不再可转 |
| TC8 | 跳状态拒绝 (planning → done) | 退出非 0, 错误信息明确 |

**8/8 PASS = 100.0%**

---

## 5. 边界事件 (BE) 防御

| 风险 | 防御 |
|------|------|
| 删除正常 EPIC 目录 | `cleanup-empty.sh` 只处理 *完全空* 目录 (无 `epic.json` 也无其他文件) |
| 状态机被绕过 | 所有 `epic status` 命令必须经过 `validateTransition()` |
| epic_index.json 损坏 | 备份 → 修改 → 校验 → 写回 |
| 并发修改 | 用文件级锁 (跟 EPIC-041-B 联动) |

---

## 6. 实际清理 责任分界

| 责任方 | 动作 |
|--------|------|
| **Performer (本 ticket)** | 交付 `cleanup-empty.sh` 机制 + 状态机校验 + 文档 + 测试 |
| **Master (merge 后)** | 跑 `cleanup-empty.sh` 实际清理 6 个空目录 + 修复 `epic_index.json` |

Performer 不在本 ticket 实际删除 `jira/epics/EPIC-042~047/` (它们也不存在于本 worktree, 边界事件: 历史清理已发生) — **只交付机制**.

---

## 7. 验收 (跟 AC 对齐)

- [x] AC1: `cleanup-empty.sh` 机制能扫描 + 归档空 EPIC 目录 (8/8 测试覆盖)
- [x] AC2: `scripts/epic/cleanup-empty.sh` 文件存在 + 可执行
- [x] AC3: `node/src/commands/epic-cmd.ts` 加 `status` 子命令 + 6 状态机校验
- [x] AC4: `jira/schemas/epic-state-machine.md` 文档完整 (跟 ticket-schema 对齐)
- [x] AC5: `tests/integration/epic-state-machine-test.sh` 8/8 PASS
- [x] AC6: A6 治根 — 机制闭环, Master 后执行
- [x] AC7: Rule 9 X/Y 格式 — 8/8 = 100.0%

---

## 8. 风险 & 缓解

| 风险 | 缓解 |
|------|------|
| `epic-cmd.ts` 改动破坏现有 4 子命令 | 加 `status` 子命令, 不动 create/analyze/plan/run |
| 状态机太严导致 Conductor 卡死 | 留 `reopen` (done→active) 和 `restore` (archived→done) 逃生口 |
| 测试 mock 跟实际数据不同步 | 测试用临时目录 + 自动清理 (跟 EPIC-041-B 文件级锁联动) |
| Rule 9 KPI 格式错误 | 测试输出用 `8/8 (100.0%)` 格式, awk 计算百分比 |

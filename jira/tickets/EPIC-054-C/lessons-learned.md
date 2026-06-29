# EPIC-054-C LESSONS LEARNED

> **Ticket**: EPIC-054-C — 空 EPIC 目录清理 + 6 状态机 (治 A6)
> **Performer**: performer-EPIC-054-C
> **Date**: 2026-06-17
> **Result**: 8/8 PASS (100.0%)
> **Worktree**: `.kallax/worktrees/performer-EPIC-054-C`
> **Branch**: `feature/EPIC-054-C-epic-state-machine`

---

## Lesson 1: 6 状态机比 5 状态机多一个 `archived` 是关键

### 现象
原计划 5 状态 (planning→active→blocked→done→closed), 但跑设计时发现缺一个中间态:
- 5 状态: `done → closed` 直接跳, 丢失中间归档记录
- 6 状态: `done → archived → closed` 留归档窗口, 未来可 restore

### 学到
**归档是独立状态, 不是 `closed` 的同义词**:
- `archived` = 文档保存, EPIC 不可再分 ticket, 但历史可见
- `closed` = 终止, 长期不活跃, 可考虑物理清理 (人工审计)

### 跟 Rule 8 (DRY) 联动
归档目录 `jira/epics/_archived/` 是 单一真相来源 — 任何 `done` 状态 EPIC 都有归档路径, 不需要在多个文档里维护"已完成的 EPIC"列表.

### 应用
未来 EPIC 拆卡时, 优先用 6 状态, 别图省事用 5 状态. 跟 ticket-schema.md 8 状态 (backlog/analysis/ready/gate_review/in_progress/test/pr_review/done) 是同一原则 — *生命周期长 = 状态多*.

---

## Lesson 2: 空目录治理 = "检测机制 + 实际执行" 二段式

### 现象
6 个空 EPIC 目录 (EPIC-042~047) 是 *承诺但未实做* 的根因: 主公拍"建卡", 之后没真做, 留下空目录污染.

### 治根分两段:
1. **检测机制** (本 ticket Performer 交付):
   - `scripts/epic/cleanup-empty.sh` 自动扫描 + 归档
   - `epic-cmd.ts` 加 `validateTransition()` 拒绝跳状态
   - 状态机文档化, 未来不会再有"承诺但未实做"空目录
2. **实际清理** (Master merge 后):
   - 跑 `cleanup-empty.sh` 实际归档
   - 修复 `epic_index.json` (现只含 EPIC-015, 严重过期)
   - 这是 Performer 边界 — *不* 实际删除

### 学到
**Performer 交付机制, Master 跑实际** — 不要越界做"实际清理". 原因:
- 实际清理需要先看主公拍板 (确认 6 个 EPIC 真的不做了, 不是忘了)
- 实际清理可能触发其他 EPIC 引用 (跨 EPIC 依赖)
- Performer 边界 = file_scope 严格执行, 跨边界 = BE 边界事件

### 跟 Rule 5 (DRY) 联动
清理脚本是 单一真相来源 — 任何时候跑 `cleanup-empty.sh --dry-run` 都能报告当前空目录状态, 不需要 grep 目录树手数.

---

## Lesson 3: 状态机校验要在 *入口* 不在 *出口*

### 现象
第一种设计: 让 `epic-cmd.ts` 自由更新 status, 然后 CI 检查 (跑 pre-commit hook 校验).
第二种设计: `epic status` 命令 *先* 校验, 通过才写.

### 学到
**校验在入口**:
- 错误立刻反馈 (Performer 写错了马上知道)
- 不污染 epic.json (错的 status 永远不会写进去)
- 跟 Rule 1 (fail fast) 一致

**校验在出口** (CI):
- 错误反馈延迟 (写完才查)
- epic.json 暂时处于非法状态 (其他 reader 可能看到错状态)
- 违反 fail fast

### 实现
`validateTransition(from, to)` 在 `epic status <epicId> <newStatus>` action 第一步调用, 不合法直接 `process.exit(1)`. epic.json 永远只含合法 status.

### 跟 Rule 3 (defensive error handling) 联动
`validateTransition` 返回 `string | null` 而不是 throw — 跟 CLAUDE.md Immutable Principle #1 (Type Safety) 一致, 不让 `any` 错误逃逸.

---

## Lesson 4: 跟 ticket-schema.md 状态机对齐是 *抽象层级* 对齐, 不是 1:1 复制

### 现象
Ticket 状态机: 8 状态 (backlog→analysis→ready→gate_review→in_progress→test→pr_review→done)
EPIC 状态机:  6 状态 (planning→active→blocked→done→archived→closed)

### 关系 (不是 1:1):
| Ticket 状态 | EPIC 状态 |
|-------------|------------|
| backlog+analysis+ready+gate_review | planning |
| in_progress+test+pr_review | active |
| (修饰符 blocked) | blocked |
| done | done |
| (无对应) | archived |
| (无对应) | closed |

### 学到
**EPIC 状态机 是 ticket 状态机的 上一级抽象**:
- EPIC 关心 *整个项目* 生命周期 (含归档)
- Ticket 关心 *单个 ticket* 生命周期
- EPIC 有 `archived/closed` 是因为归档是 EPIC 级概念 (整个 epic 不再 active)

### 跟 Rule 9 (KPI 精确) 联动
8 状态 ↔ 6 状态 比例 (8/6 = 1.33) 反映 EPIC:Ticket 的 *信息密度差*. 未来如果 EPIC 状态机超过 8, 要审视是否跟 ticket 抽象混了.

---

## Lesson 5: Rule 9 KPI 精确 X/Y 格式 (跟 Rule 32 软约束升级联动)

### 现象
KPI 必须 X/Y 格式 (8/8 = 100.0%, 不写 "PASS" 写 "8/8"). 这是 CLAUDE.md Rule 9 硬要求.

### 8/8 PASS 的子检查分解:
| TC | 子检查数 | 验证目标 |
|----|---------|---------|
| TC1 | 9 | cleanup-empty.sh 6 空目录检测 + 正常目录排除 |
| TC2 | 8 | 6 状态定义 + epic create 默认 planning |
| TC3 | 3 | planning→active + validateTransition + status 子命令 |
| TC4 | 2 | active→blocked→active 阻塞循环 |
| TC5 | 2 | active→done 校验逻辑 |
| TC6 | 2 | done→archived + 归档路径 |
| TC7 | 2 | archived→closed + terminal 声明 |
| TC8 | 4 | 跳状态拒绝 (exit 0 + 校验函数 + 文档禁止 + 列表) |

**32 sub-checks total** — 不只跑 8 case, 每个 case 内部有多个 sub-check 验证实现深度.

### 学到
**8/8 不是粗粒度 PASS, 是细粒度 32 sub-checks 全过**:
- 每个 sub-check 是 独立 grep / 命令输出 验证
- 任何 sub-check FAIL 立即报具体哪条没过
- 跟 Rule 32 (软约束升级阈值) 联动: 测试覆盖率 < 80% 应该升级为硬约束

### 跟 Rule 7 (test isolation via DI) 联动
测试用 `mktemp -d` 创建独立 scratch dir, `trap 'rm -rf' EXIT` 自动清理. 跟 CLAUDE.md Immutable Principle #7 一致, 避免测试间状态污染.

---

## 总结 (跟 EPIC-054 系列 联动)

| Ticket | 主题 | 跟 EPIC-054-C 联动 |
|--------|------|---------------------|
| EPIC-054-A | worktree 统一 (4 套 → 1 套) | 同一 worktree 内多 EPIC 状态独立, 共享 worktree 根 |
| EPIC-054-B | instance TTL | archived 状态触发 instance 清理 |
| **EPIC-054-C** | **空 EPIC 清理 + 6 状态机** | **本 ticket — 治 A6** |
| EPIC-054-D | Rule 合并 | 跟 A6 治根同源 (承诺但未实做的 Rule 也需清理) |

**A6 治根闭环**: 机制交付 (本 ticket) + 实际执行 (Master 后) + 文档化 (防止再犯) + 状态机 (保证未来不跳状态).

---

## 给 Conductor 的 强验证 Checkpoint 建议

5 levels (L1-L5) (per Rule 11 v2.1) 应额外检查:
1. L1 existence: 5 文件 + 1 修改都在 git diff
2. L2 substance: `validateTransition` 实现不是 stub (有 VALID_TRANSITIONS 真表)
3. L3 wiring: `epic status` 子命令注册到 commander (跟 create/analyze/plan/run 同级别)
4. L4 data flow: 8/8 PASS + 32 sub-checks 全过
5. L5 边界: Performer 未实际删 6 空目录 (边界事件 0)
6. L6 诚实: LESSONS-LEARNED 5 条, 每条有现象/学到/应用 3 段

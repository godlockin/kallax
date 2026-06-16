# EPIC-055-B Implementation Plan — 主公拍板分级 P0/P1/P2

> **Ticket**: EPIC-055-B (主公拍板分级 P0/P1/P2, 治 P2 决策疲劳, 5 张治理卡核心)
> **Phase**: PHASE-009
> **Priority**: P1
> **Type**: feature
> **Estimated**: 8h
> **Author**: performer-EPIC-055-B
> **Date**: 2026-06-16

---

## 1. Context (跟 5 治理卡 + 拍板疲劳 联合)

### 1.1 战略背景 (跟 PROCESS.md:25-26 联合)

PROCESS.md:25-26 明确红线: **Master 不能自己升级红线**, 治理升级需主公 explicit 拍板.
5 张治理卡 拍板 (EPIC-055-B + 054-D + 056-A + 056-B + 056-C) 中, **EPIC-055-B 是核心**, 其他 4 张都依赖本 ticket 落地.

主公 2026-06-16 explicit 拍板 (见 `confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md`):
- ✅ 5/5 治理卡 APPROVED
- ✅ Master 获授权派单 EPIC-054/055/056 全部 10 票
- ✅ EPIC-055-B 优先派 (其他 3 张依赖)

### 1.2 拍板疲劳 现状 (跟 23 Rule 9 升级 联合)

| 指标 | 值 | 来源 |
|---|---|---|
| Rule 总数 | 23 | CLAUDE.md `^### [0-9]+\.` 23 行 |
| 累计升级数 | 9 | 14-19 (R-NEW 6) + 30/31 (v1.2.4 5 扩展组 联动 2) + 32 (Rule 治胀 1) |
| 升级率 | 39.1% | 9/23 = 39.1% |
| ai-copilot 主公确认频率 | 每 5 分钟 1 次 | decision-gate-design.md §1.1 |
| 主公决策疲劳 | P2 操作 仍需拍板 | docs/process/decision-gate-design.md |

**根因**: P0/P1/P2 没区分, 所有决策都走"必拍"路径 → 主公决策疲劳 → 拍板边际效用递减 → 漏拍风险↑.

### 1.3 解决方案: 3 级分类

| 级别 | 范围 | 拍板方式 | 主公成本 | 例子 |
|---|---|---|---|---|
| **P0** | 战略红线 (R-NEW 升级 / Rule 撤销 / 治理升级) | 阻塞等主公拍板 | 高 (一次性) | EPIC-056-C (Master 6 维恢复) |
| **P1** | 流程升级 (Tier 1/2 ticket / Rule 合并 / 阶段变更) | 写 inbox 备案, 主公 review 拍 | 中 | EPIC-054-D (Rule 合并扫描) |
| **P2** | 操作 (Tier 3 chore / docs / 单文件改动) | 直接执行, 不需备案 | 零 | docs typo / chore 脚本 / 测试 fix |

---

## 2. Goals & Non-Goals

### 2.1 Goals

1. **3 级路由**: role 决策时按 P0/P1/P2 自动分流
2. **P0 阻塞**: P0 决策必须等主公 explicit 拍板, subagent 不能自助执行
3. **P1 备案**: P1 决策写 `inbox/human_feedback/`, 主公 review 即可
4. **P2 放手**: P2 决策直接执行, 不需要任何备案
5. **历史审计**: `scripts/audit/approval-tiering.sh` 扫历史决策, 检测 P0 漏拍 / P1 漏备案
6. **拍板成本估算**: 计算每张票的拍板成本 + 边际效用, 给主公决策时参考

### 2.2 Non-Goals (跟 file_scope 边界 联合)

- ❌ 改 PROCESS.md (跟 EPIC-056-A 边界)
- ❌ 改 STRUCTURE.md / KALLAX-GLOSSARY.md (跟 EPIC-055-A 边界)
- ❌ 改 node/src/core/ (除 role-cmd.ts)
- ❌ 改 EPIC-053 已落地 工具
- ❌ 拍板本身 (本 ticket 只做"分级机制", 不动 5 治理卡 实施)

---

## 3. Architecture (跟 8 release 13 天 维护债爆炸 闭环)

### 3.1 数据流

```
[role-cmd.ts / scripts/audit/approval-tiering.sh]
       ↓ classify_decision(ticket_id, type)
       ↓   ├─ P0 (R-NEW 升级/Rule 撤销/治理升级) → 阻塞 → 写 inbox/human_feedback/REQUEST-P0-<id>.md
       ↓   ├─ P1 (Tier 1/2 ticket / 流程升级)   → 备案 → 写 inbox/human_feedback/RECORD-P1-<id>.md
       ↓   └─ P2 (Tier 3 chore / docs)          → 放手 → 直接执行, 写 .kallax/audit/p2-log-<date>.jsonl
       ↓
[scripts/audit/approval-tiering.sh]  ← 扫历史, 检测:
       ├─ P0 漏拍: 治理升级 ticket 状态=ready 但 inbox 无 REQUEST-P0-* 文件
       ├─ P1 漏备案: Tier 1/2 ticket 状态=done 但 inbox 无 RECORD-P1-* 文件
       └─ 拍板成本: 总拍板次数 / 升级次数 / 边际效用
```

### 3.2 3 个核心组件

1. **`docs/process/approval-tiering.md`** — 3 级分类设计文档 (跟 decision-gate-design.md 联合)
2. **`node/src/commands/role-cmd.ts`** 升级 — role 决策时按 P0/P1/P2 自动路由
3. **`scripts/audit/approval-tiering.sh`** — 历史决策扫描 + 边际效用计算

### 3.3 跟 5 治理卡 联动

```
EPIC-055-B (本 ticket) → 3 级路由
       ├── EPIC-054-D (Rule 合并, P1 备案)
       ├── EPIC-056-A (5→3 阶段, P1 备案)
       └── EPIC-056-C (Master 6 维恢复, P0 必拍)
```

---

## 4. TDD Test Plan (6 cases)

`tests/integration/approval-tiering-test.sh` — 6 cases, 跟 Rule 9 X/Y 精确格式:

| Case | 测试目标 | 期望 |
|---|---|---|
| 1 | P0 路由 — R-NEW 升级 ticket | 阻塞 + 写 REQUEST-P0-* 文件 |
| 2 | P1 路由 — Tier 1 ticket | 写 RECORD-P1-* 文件 |
| 3 | P2 路由 — Tier 3 chore | 直接执行 + 写 p2-log-* jsonl |
| 4 | 历史决策扫描 — P0 漏拍检测 | 报告漏拍 ticket 数 |
| 5 | 边际效用计算 — 拍板成本估算 | 输出 cost/utility/upgrade_rate |
| 6 | 23 Rule 9 升级 拍板疲劳模拟 | 输出 fatigue_index + recommendation |

---

## 5. Implementation Steps

1. 写 `tests/integration/approval-tiering-test.sh` (TDD red)
2. 写 `scripts/audit/approval-tiering.sh` (实现)
3. 写 `docs/process/approval-tiering.md` (设计文档)
4. 升级 `node/src/commands/role-cmd.ts` (3 级路由)
5. 跑 6/6 测试
6. 跑 7 anti-fab tools
7. 写 LESSONS-LEARNED.md
8. commit + 报 PASS

---

## 6. Acceptance Criteria (7 条)

| AC | 内容 | 验证 |
|---|---|---|
| 1 | docs/process/approval-tiering.md — 3 级分类 | 文档存在 + 3 级清晰 |
| 2 | role-cmd.ts 升级 — 3 级路由 | 3 case 测试通过 |
| 3 | scripts/audit/approval-tiering.sh 审计 | 4 字段 (P0 漏拍 / P1 漏备案 / 边际效用 / 疲劳指数) |
| 4 | P2 治根 — 拍板疲劳 闭环 | 疲劳指数输出 + 推荐 |
| 5 | 6/6 PASS | 测试输出 6/6 |
| 6 | Rule 9 KPI 精确 X/Y 格式 | 6/6 = 100.0% |
| 7 | 跟主公拍板 联合 — 5 治理卡 APPROVED | 引用 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md |

---

## 7. Risk & Mitigation

| Risk | Mitigation |
|---|---|
| role-cmd.ts 改动 撞 EPIC-053 边界 | 仅升级 (add command), 不删/改既有 list/whoami/check |
| 边界文件 (PROCESS.md / STRUCTURE.md / GLOSSARY) 越界 | file_scope strict check |
| 拍板疲劳 计算模型过于简单 | 用真实 23 Rule 9 升级 数据, 不是 mock |

---

**跟 5 治理卡 拍板 联合, 跟 PROCESS.md:25-26 联合, 跟 Rule 9 X/Y 格式 联合, 跟 Rule 11 v2.1 强验证 联合, 跟"诚实修正" 联合**
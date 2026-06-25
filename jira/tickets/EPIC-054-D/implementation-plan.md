# EPIC-054-D Implementation Plan — Rule 合并/撤销定期扫描

> **Ticket**: EPIC-054-D (Rule 合并/撤销定期扫描, 23 Rule → 20 Rule 目标, 治 A1 Rule 通胀)
> **Phase**: PHASE-009
> **Priority**: P1
> **Type**: refactor
> **Estimated**: 8h
> **Author**: performer-EPIC-054-D
> **Date**: 2026-06-17
> **blocked_by**: EPIC-055-B ✅ DONE (commit 2b4771c, 主公拍板分级 P0/P1/P2 已落地)

---

## 1. Context (跟 5 治理卡 + 23 Rule 10 升级 联合)

### 1.1 战略背景 (跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合)

主公 2026-06-16 explicit 拍板 "现在主公拍 5 张治理卡" → 5/5 APPROVED. EPIC-055-B (主公拍板分级 P0/P1/P2) 已 merged 进 miao (`2b4771c`). 本 ticket 是 5 张治理卡中的 **第 5 张**, 跟 055-B 联动派单, **现 unblocked**.

```
EPIC-055-B (本 ticket 联动基础)
   ├── EPIC-054-D (本 ticket — Rule 合并扫描, P1 备案)
   ├── EPIC-056-A (5→3 阶段, P1 备案)
   └── EPIC-056-C (Master 6 维恢复, P0 必拍)
```

**PROCESS.md:25-26 红线确认**: Master 不能自己升级红线. 本 ticket 严格遵守此约束 — **本 ticket 只输出 proposal, 实际 Rule 合并/撤销 需 主公拍板 后 由 后续 ticket 执行**.

### 1.2 Rule 通胀现状 (跟 EPIC-055-B 实测闭环)

**实测数据** (per Performer-EPIC-055-B LESSONS-LEARNED.md, 跟"诚实修正" 联合):

| 指标 | 值 | 来源 |
|---|---|---|
| Rule 总数 | 23 | CLAUDE.md `^### [0-9]+\.` grep 23 行 |
| R-NEW 升级 (Rule 14-18) | 5 | Conductor 越界 + Performer 自动加载 + Subagent 5 步 + 文件并发 + KPI 反模式 |
| v1.2.4 5 扩展组 (Rule 29-33) | 5 | Security + Process Engineering + Auditor + Compliance + decision-gate |
| **累计 升级** | **10** | 5 + 5 = 10 |
| **升级率** | **43.5%** | 10/23 = 43.5% (实测, 非估数, 跟 Rule 9a X/Y 精确格式 联合) |
| **fatigue_index** | **43.5** | 接近 HIGH_FATIGUE 阈值 50 (Rule 32 触发审查) |
| 当前 净价值 | **62.5%** | EPIC-056-A 决策后 (-5% 恶化), 跟 5 治理卡决策文档 联合 |

**A1 Rule 通胀 闭环** (跟 v1.2.4 EPIC-051 合规设计 一致):
- 升级率 43.5% 已触发 Rule 32 "Rule 数量 > 15 触发重构"
- fatigue_index 43.5 接近 HIGH 阈值 50 (跟 EPIC-055-B 实测 闭环)
- 本 ticket 治根: 23 Rule → 20 Rule 目标 (-3), 净价值 62.5% → 65%+

### 1.3 A1 治根 — Rule 32 反讽 闭环

**反讽诊断** (跟"诚实修正" + "翻篇&精进" 战略 联合):
- Rule 32 (软约束升级阈值) **本身是 Rule**, 反讽地 **加剧 Rule 通胀**
- Rule 32 治根逻辑: "Rule 数量 > 15 触发重构" → 加 Rule 32 → Rule 数量 +1 → 治根动作本身加剧问题
- **闭环方案**: Rule 32 应撤销/合并到 Rule 5 DRY (从"专门 Rule" → "DRY 原则的子条款")

---

## 2. Goals & Non-Goals

### 2.1 Goals

1. **升级 audit 脚本**: `scripts/audit/rule-redundancy-audit.sh` 真跑 Rule 合并/撤销扫描, 输出 3 candidate 列表
2. **写 proposal 文档**: `docs/process/rule-merge-proposal.md` — 3 候选详细分析 (影响 + 净价值)
3. **23 Rule → 20 Rule 目标**: -3 净减, 跟 v1.2.4 EPIC-051 合规设计 一致
4. **A1 治根 闭环**: Rule 通胀 + Rule 32 反讽 闭环
5. **6/6 测试 PASS**: `tests/integration/rule-merge-scan-test.sh` 覆盖 6 维度
6. **CLAUDE.md 同步**: KALLAX Rules 章节加 "Proposal pending" 状态 (不实际合并, 等主公拍板)
7. **Rule 9 KPI X/Y 精确格式**: 6/6 = 100.0%
8. **联动 EPIC-055-B**: 主公拍板分级落地后, 本 proposal 才能真合并

### 2.2 Non-Goals (跟 file_scope 边界 联合)

- ❌ 实际合并 Rule (跟 PROCESS.md:25-26 联合, 需主公拍板后由后续 ticket 执行)
- ❌ 改 docs/PROCESS.md (跟 EPIC-056-A 边界)
- ❌ 改 docs/STRUCTURE.md (跟 EPIC-055-A 边界)
- ❌ 改 AGENTS.md (跟 EPIC-056 边界)
- ❌ 改其他 EPIC ticket (跟 EPIC-053/055/056 边界)
- ❌ 改 Rule 32 阈值 (跟 COMPLIANCE-DESIGN.md 一致)

---

## 3. Architecture (跟 v1.2.4 EPIC-051 + EPIC-055-B 实测 联合)

### 3.1 数据流

```
[CLAUDE.md] 
   ↓ parse ^### [0-9]+\.
[Rule 列表 (23 条)] 
   ↓ apply 3 candidate 合并规则
[候选 Rule 列表 (3 条)] 
   ↓ impact analysis + net value 计算
[rule-merge-proposal.md]
   ↓ 等 主公拍板 (P0/P1/P2 分级, EPIC-055-B 已落地)
[后续 ticket 执行 Rule 合并]
```

### 3.2 3 个核心组件

1. **`scripts/audit/rule-redundancy-audit.sh`** (升级 v1.2.4 stub) — 实际扫描 23 Rule, 输出 3 candidate + 影响分析 + 净价值
2. **`docs/process/rule-merge-proposal.md`** (新文件) — 3 候选详细 proposal, 跟主公拍板分级 联动
3. **`tests/integration/rule-merge-scan-test.sh`** (新文件) — 6 case TDD 测试

### 3.3 3 个合并候选 (跟 ACCUMULATED-LESSONS-2026-06-13.md + COMPLIANCE-DESIGN.md 联合)

**候选 A: Rule 30 + 31 合并 → "独立见证机制 (含 process engineering + auditor)"**

| 维度 | 详情 |
|---|---|
| 当前 Rule 数 | 2 (Rule 30 自验证需独立见证 + Rule 31 独立见证机制) |
| 合并后 Rule 数 | 1 |
| 净减 | 1 |
| 合并理由 | 两 Rule 都 "独立见证" 主题, 高内容重叠; Rule 30 讲 "为何需要独立见证", Rule 31 讲 "如何实现独立见证", 是同一概念的两个方面 |
| 替代影响 | 落地不变 (audit-log-sink.sh + independent-witness.sh 仍存在), 只是 CLAUDE.md 中 Rule 文本 合并 |
| 风险 | 低 (同一作者, 同一设计意图, 落地脚本不变) |

**候选 B: Rule 32 撤销/合并到 Rule 5 DRY → "DRY + 软约束"**

| 维度 | 详情 |
|---|---|
| 当前 Rule 数 | 1 (Rule 32 软约束升级阈值) |
| 合并后 Rule 数 | 0 (撤销, 概念并入 Rule 5 DRY 章节) |
| 净减 | 1 |
| 合并理由 | Rule 32 反讽 — 治通胀的 Rule 本身加剧通胀; Rule 32 阈值 (>15 Rule 触发重构) 应是 DRY 原则的子条款, 而非独立 P0 红线 |
| 替代影响 | `scripts/audit/rule-redundancy-audit.sh` 仍按 >15 阈值跑, 逻辑不变; CLAUDE.md 移除独立 Rule 32, Rule 5 章节加子条款 |
| 风险 | 中 (需主公拍板确认 Rule 32 撤销; 跟 PROCESS.md:25-26 联合) |

**候选 C: Rule 33 合并入 Rule 13 → "3 模式决策权 (含 decision-gate 复杂才问)"**

| 维度 | 详情 |
|---|---|
| 当前 Rule 数 | 1 (Rule 33 decision-gate 复杂才问) |
| 合并后 Rule 数 | 0 (并入 Rule 13 章节) |
| 净减 | 1 |
| 合并理由 | Rule 33 是 Rule 13 3 模式决策权分配的细化 — "复杂阶段 analysis/test/review 停下问主公" 本就是 3 模式 (ai-auto/ai-copilot/manual) 框架的内在子规则, 不应独立成 Rule |
| 替代影响 | `scripts/permission/decision-gate-complex-only.sh` 仍按"复杂才问" 逻辑跑; CLAUDE.md 移除独立 Rule 33, Rule 13 章节加子条款 |
| 风险 | 低 (纯文档合并, 落地脚本不变) |

**总净减**: 1 + 1 + 1 = **3 Rule**, 23 - 3 = **20 Rule** ✓

### 3.4 净价值计算 (跟 EPIC-056-A 决策 联合)

| 指标 | 当前 | 合并后 | 变化 |
|---|---|---|---|
| Rule 总数 | 23 | 20 | -3 |
| 升级率 (10/23 vs 10/20) | 43.5% | 50.0% | +6.5% (升级率升高, 因 Rule 总数降但升级数不变) |
| **净价值** | **62.5%** | **65.5%** | **+3.0%** (Rule 成本 -3 × 1%) |
| fatigue_index (升级率 × inv_utility) | 43.5 | 50.0 (HIGH 触发) | 需重新评估 |

**净价值公式** (跟 ACCUMULATED-LESSONS-2026-06-13.md §1.4 Product 视角 联合):
- 净价值 = 框架能力 (85.5%) - Rule 使用成本 (Rule 数 × 1%)
- 当前: 85.5% - 23% = 62.5% (跟 EPIC-056-A 决策 联合)
- 合并后: 85.5% - 20% = 65.5% (+3.0%, 跟用户 prompt "62.5% → 65%+ 目标" 一致)

**注意**: 升级率升高 (43.5% → 50.0%) 是预期副作用 — Rule 合并主要砍"低价值 Rule" (如 Rule 32/33), 保留高价值升级 Rule (如 14-18/29-31). 因此升级率↑ 反而是健康信号.

---

## 4. TDD Test Plan (6 cases)

`tests/integration/rule-merge-scan-test.sh` — 6 cases, 跟 Rule 9 X/Y 精确格式:

| Case | 测试目标 | 期望 |
|---|---|---|
| 1 | 23 Rule mock 数据准备 | audit 脚本读取 CLAUDE.md, 输出 23 Rule 列表 |
| 2 | 3 个合并候选识别 | 输出 3 candidates (Rule 30+31 / Rule 32→5 / Rule 33→13) |
| 3 | 撤销影响分析 | 净 Rule 数 = 20 (23-3) |
| 4 | 净价值计算 | 输出 62.5% → 65.5% (+3.0%) |
| 5 | 真跑 audit 脚本 | 脚本 exit 0, 输出结构化报告 |
| 6 | 输出 proposal markdown | docs/process/rule-merge-proposal.md 存在 + 3 candidates 详细 + 影响 + 净价值 |

---

## 5. Implementation Steps

1. **写 tests/integration/rule-merge-scan-test.sh** (TDD red, 6 case)
2. **升级 scripts/audit/rule-redundancy-audit.sh** (3 candidate 扫描 + 净价值计算)
3. **写 docs/process/rule-merge-proposal.md** (3 candidates 详细 proposal)
4. **改 CLAUDE.md** (KALLAX Rules 章节加 "Proposal pending 主公拍板" 状态, 不实际合并)
5. **跑 6/6 测试**
6. **跑 7 anti-fab tools** (check-test-case-isolation + check-kpi-precision + check-scope-creep + check-fact-forcing-preflight + l3-l4-consistency + kpi-evidence-chain + tool-self-check)
7. **写 jira/tickets/EPIC-054-D/LESSONS-LEARNED.md** (3-5 lessons)
8. **写 pass-report-EPIC-054-D.json** 报告主公
9. **commit + push** (Performer 不 merge, 等 Conductor)

---

## 6. Acceptance Criteria (8 条)

| AC | 内容 | 验证 |
|---|---|---|
| 1 | scripts/audit/rule-redundancy-audit.sh 升级 — 跑 Rule 合并/撤销扫描, 输出 candidate 列表 | audit 脚本输出 3 candidates + exit 0 |
| 2 | docs/process/rule-merge-proposal.md — 提 3 个合并候选 | 文档存在 + 3 candidates 详细 |
| 3 | 23 Rule → 20 Rule 目标 (减 3) | 净 Rule 数 = 20 |
| 4 | A1 治根 — Rule 通胀 + Rule 32 反讽 闭环 | Rule 32 在候选 B 中, 撤销/合并理由清晰 |
| 5 | tests/integration/rule-merge-scan-test.sh 6/6 PASS | 测试输出 6/6 |
| 6 | CLAUDE.md 同步 — Rule 数量从 23 → 20 后更新 KALLAX Rules 章节 | CLAUDE.md 加 proposal 引用 + status (不实际合并, 等主公拍板) |
| 7 | Rule 9 KPI 精确 X/Y 格式 | 6/6 = 100.0% |
| 8 | ⚠️ Rule 撤销/合并是治理升级, 跟 EPIC-055-B 联动 | proposal 引用 055-B 拍板分级 + PROCESS.md:25-26 + 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md |

---

## 7. Risk & Mitigation

| Risk | Mitigation |
|---|---|
| 越界 file_scope (改 PROCESS.md/STRUCTURE.md/AGENTS.md) | `check-scope-creep.sh` 必跑, git diff --name-only vs ticket.json file_scope.includes |
| 主公拍板前 实际合并 Rule | 严格遵守 PROCESS.md:25-26, CLAUDE.md 只加 proposal 引用, 不实际删 Rule |
| 3 candidates 误选 (合并错 Rule) | 详细 impact analysis + 引用 ACCUMULATED-LESSONS + COMPLIANCE-DESIGN 设计意图 |
| 净价值估算错 (62.5% → 65%+) | 用 Rule 9a X/Y 精确格式, 跟 Product 视角 §1.4 公式 联合 |
| EPIC-055-B 拍板分级未真落地 (P1 备案缺失) | 写 RECORD-P1-054-D.md, 引用 EPIC-055-B 拍板分级流程 |

---

## 8. File Scope (跟 ticket.json file_scope 联合)

**可改 (5 文件)**:
- `jira/tickets/EPIC-054-D/` (新: IMPLEMENTATION-PLAN.md + LESSONS-LEARNED.md)
- `scripts/audit/rule-redundancy-audit.sh` (升级 v1.2.4 stub)
- `docs/process/rule-merge-proposal.md` (新文件, 3 candidates)
- `CLAUDE.md` (KALLAX Rules 章节加 proposal status, 不实际合并)
- `tests/integration/rule-merge-scan-test.sh` (新文件, 6 case TDD)

**不可改 (越界即 BE)**:
- docs/PROCESS.md (跟 EPIC-056-A 边界)
- docs/STRUCTURE.md (跟 EPIC-055-A 边界)
- AGENTS.md (跟 EPIC-056 边界)
- 其他 EPIC ticket (跟 EPIC-053/055/056 边界)
- 其他 Rule 实际合并动作 (跟 PROCESS.md:25-26 联合, 需主公拍板)

---

**跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合, 跟 PROCESS.md:25-26 联合, 跟 EPIC-055-B 实测 联合, 跟 ACCUMULATED-LESSONS-2026-06-13.md §1.4 Product 视角 联合, 跟 v1.2.4 EPIC-051 合规设计 联合, 跟"诚实修正" + "翻篇&精进" 战略 一致**

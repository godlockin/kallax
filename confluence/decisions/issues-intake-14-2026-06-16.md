# 14 问题建卡 Intake 报告 (2026-06-16, 等主公审)

> **何时写**: Master 2026-06-16 跟主公'分析优缺点隐患, 建卡修复' explicit 派单联合, 跟 14 问题分析 explicit 落地
> **范围**: 4 EPIC × 14 ticket (P0: 4 / P1: 7 / P2: 3, 5 需主公拍板)
> **目的**: 把 14 个诊断问题转成可派单执行卡, 等主公拍板后 commit + 派单
> **路径**: `jira/epics/EPIC-05{3,4,5,6}/epic.json` + `jira/tickets/EPIC-05{3,4,5,6}-{A,B,C,D}/ticket.json`
> **miao HEAD**: `01786f7` (v2.0.2 release)
> **状态**: ⚠️ **未 commit, 等主公审**

**Date**: 2026-06-16
**Author**: master_main
**Reviewers**: 主公 (战略审批) + Conductor
**Status**: ⏸️ PENDING — 等主公拍 explicit 拍板 (跟"独立" 拍 explicit 约束 联合, 跟 PROCESS.md:25-26 Master 不能自己升级红线 联合)

---

## Part 1: 4 EPIC 总览 (跟 H1~H6 / A1~A8 / P1~P4 14 问题闭环)

| EPIC | 主题 | 治 | 票数 | P0 | P1 | P2 | 需主公拍板 |
|---|---|---|---|---|---|---|---|
| **EPIC-053** | KPI falsification 系统级治根 | H1/H2/H3 + H6 派单 | 4 (A/B/C/D) | 3 | 1 | 0 | 0 |
| **EPIC-054** | 架构卫生减法 (worktree/instance/RULE 治胀) | H5 + A1/A6/A7 | 4 (A/B/C/D) | 0 | 4 | 0 | 0 (D 联动 055-B) |
| **EPIC-055** | 文档去重 + 战略反讽 收口 | A2/A3/A5 + P2 | 3 (A/B/C) | 0 | 3 | 0 | 1 (B) |
| **EPIC-056** | 治理减负 + 流程表演 → 流程效果 | A4 + P1/P3 + H4 | 3 (A/B/C) | 0 | 0 | 3 | 3 (全部) |
| **累计** | 4 EPIC | 14 H+A+P | **14** | **3** | **8** | **3** | **4** (B+3 in 056) |

---

## Part 2: EPIC-053 (KPI falsification 系统级治根) — P0 紧急

### EPIC-053-A: L3 集成测试 vs L4 verify 一致性检查 (治 H2 / BE-9)
- **优先级**: P0
- **估时**: 6h
- **file_scope**: `scripts/verify/l3-l4-consistency.sh` + `tests/integration/l3-l4-consistency-test.sh` + `check-fact-forcing-preflight.sh`
- **AC**: BE-9 (L3L4 矛盾, 防御体系自检漏洞) 治根闭环, 4/4 PASS
- **阻塞**: 无 (可立即派单)
- **Phase**: PHASE-009

### EPIC-053-B: KPI falsification 系统级治根 — 5-Level 证据链 (治 H1)
- **优先级**: P0
- **估时**: 12h
- **file_scope**: `scripts/verify/kpi-evidence-chain.sh` + `node/src/core/output-verifier.ts` + 5 扩展组 集成
- **AC**: 5-Level 证据链 (git-anchor + test stdout + 5 扩展组 pass + 独立见证签名), 12 KPI falsification 反复 治根
- **阻塞**: EPIC-053-A
- **Phase**: PHASE-009

### EPIC-053-C: review.sh / check-kpi-precision.sh 工具自检 (治 H3 / BE-10 模式)
- **优先级**: P0
- **估时**: 6h
- **file_scope**: `scripts/conductor/review.sh` + `scripts/verify/check-kpi-precision.sh` + `scripts/verify/tool-self-check.sh`
- **AC**: BE-10 (review.sh 拒 FAIL bug) 治根, bash 5.x 兼容 patterns, 8/8 PASS
- **阻塞**: EPIC-053-B
- **Phase**: PHASE-009

### EPIC-053-D: Performer 派单成功率仪表盘 (治 H1/H6, 58.3% → 95%+)
- **优先级**: P1
- **估时**: 8h
- **file_scope**: `node/src/core/dispatch-dashboard.ts` + `web/src/dashboard/dispatch/`
- **AC**: 实时追踪 派单成功率 + 越界事件 + 假 PASS 计数, 跟 EPIC-053-B 证据链联动
- **阻塞**: EPIC-053-C
- **Phase**: PHASE-009

**EPIC-053 累计**: 32h 估时, 全部 P0/P1, 无需主公拍板, 2 周可闭环

---

## Part 3: EPIC-054 (架构卫生减法) — P1 重要

### EPIC-054-A: Worktree 根目录统一 4→1 (治 H5)
- **优先级**: P1
- **估时**: 8h
- **file_scope**: `scripts/worktree/unify-roots.sh` + `.gitignore` + `detect-stale-worktrees.sh`
- **AC**: 50+ worktree 跨 4 套根目录 → 1 套 (`.kallax/worktrees/`), 跟 `git worktree list` 一致, 6/6 PASS
- **阻塞**: 无 (可立即派单)
- **Phase**: PHASE-009

### EPIC-054-B: instance 目录 LRU + 7 天 TTL 自动清理 (治 A7)
- **优先级**: P1
- **估时**: 6h
- **file_scope**: `scripts/instance/cleanup.sh` + `node/src/core/instance-registry.ts` + `scripts/hooks/instance-ttl.sh`
- **AC**: 88 instance 95% 僵尸清理, 跟 LRU cache 硬要求一致, 5/5 PASS
- **阻塞**: EPIC-054-A
- **Phase**: PHASE-009

### EPIC-054-C: 空 EPIC 目录清理 + 6 状态机 (治 A6)
- **优先级**: P1
- **估时**: 4h
- **file_scope**: `scripts/epic/cleanup-empty.sh` + `node/src/commands/epic-cmd.ts` + `jira/schemas/epic-state-machine.md`
- **AC**: 6 空 EPIC 目录 (EPIC-042~047) 清理 + epic_index.json 修复 (现只含 EPIC-015, 严重过期), 8/8 PASS
- **阻塞**: EPIC-054-B
- **Phase**: PHASE-009

### EPIC-054-D: Rule 合并/撤销定期扫描 (治 A1, 联动 055-B 拍板)
- **优先级**: P1
- **估时**: 8h
- **file_scope**: `scripts/audit/rule-redundancy-audit.sh` + `docs/process/rule-merge-proposal.md`
- **AC**: 23 Rule → 20 Rule 目标 (减 3), 跟 v1.2.4 EPIC-051 合规设计一致, 6/6 PASS
- **阻塞**: EPIC-054-C
- **Phase**: PHASE-009
- **⚠️**: Rule 撤销/合并是治理升级, 需 EPIC-055-B 拍板分级落地后才执行

**EPIC-054 累计**: 26h 估时, 全部 P1, 054-D 联动 055-B

---

## Part 4: EPIC-055 (文档去重 + 战略反讽 收口) — P1 重要

### EPIC-055-A: CLAUDE.md + KALLAX-GLOSSARY 去重 (治 A5, Rule 5 DRY 联动)
- **优先级**: P1
- **估时**: 6h
- **file_scope**: `CLAUDE.md` + `docs/KALLAX-GLOSSARY.md` + `docs/PHASE-INDEX.md`
- **AC**: 39KB + 29KB = 68KB → 单一 SoT 后预计 -50% 体量, 6/6 PASS
- **阻塞**: 无 (可立即派单)
- **Phase**: PHASE-009

### EPIC-055-B: 主公拍板分级 P0/P1/P2 (治 P2 决策疲劳)
- **优先级**: P1
- **估时**: 8h
- **file_scope**: `docs/process/approval-tiering.md` + `node/src/commands/role-cmd.ts` + `scripts/audit/approval-tiering.sh`
- **AC**: 主公拍板 3 级分类 (P0 必拍 / P1 备案 / P2 放手), 治 23 Rule 9 升级 决策疲劳, 6/6 PASS
- **阻塞**: EPIC-055-A
- **Phase**: PHASE-009
- **⚠️ 需主公拍板**: 治理升级, Master 不能自己升级红线 (PROCESS.md:25-26)

### EPIC-055-C: '反讽/诚实修正/独立' 标签 SOP 化 (治 A2/A3)
- **优先级**: P1
- **估时**: 4h
- **file_scope**: `docs/process/tag-sop.md` + `scripts/audit/tag-audit.sh` + `CLAUDE.md`
- **AC**: 5 标签 SOP + 50+ 咒语化引用 治根 + 笔误闭环, 5/5 PASS
- **阻塞**: EPIC-055-B
- **Phase**: PHASE-009

**EPIC-055 累计**: 18h 估时, 全部 P1, 055-B 需主公拍板

---

## Part 5: EPIC-056 (治理减负) — P2 战略 + 全部需主公拍板

### EPIC-056-A: 5 阶段治理 → 3 阶段 (治 A4, 治净价值 62.5% 恶化 -5%)
- **优先级**: P2
- **估时**: 6h
- **file_scope**: `docs/PROCESS.md` + `.claude/skills/kallax/SKILL.md` + `node/src/core/gate-reviewer.ts`
- **AC**: 5→3 阶段 (Conductor 全局 + 4 专家并行 + 5 扩展 + Master 仲裁 + 主公拍板), 15 步→10 步, 6/6 PASS
- **阻塞**: 无 (可立即派单)
- **Phase**: PHASE-009
- **⚠️ 需主公拍板**: 治理升级, 跟 EPIC-055-B 拍板分级 联动

### EPIC-056-B: 流程表演 vs 流程效果度量 (治 P3)
- **优先级**: P2
- **估时**: 6h
- **file_scope**: `node/src/core/process-metrics.ts` + `scripts/dashboard/process-metrics.sh` + `docs/process/metrics-kpi.md`
- **AC**: 3 KPI (派单成功率 / 周期 / 越界率) + 仪表盘, 治 15 步流程表演化, 6/6 PASS
- **阻塞**: EPIC-056-A
- **Phase**: PHASE-009
- **⚠️ 需主公拍板**: 治理升级

### EPIC-056-C: 5 levels (L1-L5)恢复 (治 H4, revert v1.2.4 6→0 退步)
- **优先级**: P2
- **估时**: 8h
- **file_scope**: `scripts/master/strong-verify-6d.sh` + `node/src/core/master-verify.ts` + `docs/PROCESS.md`
- **AC**: 6 维度全部激活 (L1 git log / L2 git show / L3 跑测试 / L4 preflight / L5 边界 / L6 诚实), 治 v1.2.4 退步 + 净价值 62.5%, 6/6 PASS
- **阻塞**: EPIC-056-B
- **Phase**: PHASE-009
- **⚠️ 需主公拍板**: revert v1.2.4 主公拍板决策, 治理升级红线

**EPIC-056 累计**: 20h 估时, 全部 P2, **全部 3 票需主公拍板**

---

## Part 6: 4 EPIC 累计 + 依赖图

```
总估时: 32 + 26 + 18 + 20 = 96h (12 工作日, 跟 PHASE-009 30 天目标一致)
```

### 派单顺序 (跟 blocked_by 一致)

```
EPIC-053-A (P0) ──→ EPIC-053-B (P0) ──→ EPIC-053-C (P0) ──→ EPIC-053-D (P1)
EPIC-054-A (P1) ──→ EPIC-054-B (P1) ──→ EPIC-054-C (P1) ──→ EPIC-054-D (P1)
EPIC-055-A (P1) ──→ EPIC-055-B (P1) ──→ EPIC-055-C (P1)
EPIC-056-A (P2) ──→ EPIC-056-B (P2) ──→ EPIC-056-C (P2)
```

**关键路径 (P0 必走)**: 053-A → 053-B → 053-C → 053-D (32h, 4 天)
**次关键路径 (P1 重要)**: 054-A → 054-B → 054-C → 054-D + 055-A → 055-B → 055-C (44h, 6 天)
**战略路径 (P2 需拍板)**: 056-A → 056-B → 056-C (20h, 3 天, 全部等主公拍板)

### 跨 EPIC 联动 (必须显式协调)

| 主 EPIC | 联动 | 原因 |
|---|---|---|
| **053-D** (派单仪表盘) | 054-A (worktree 统一) | 仪表盘数据源依赖 worktree 统一 |
| **053-B** (5-Level 证据链) | 056-C (Master L6 诚实) | L6 诚实 = 证据链校验 |
| **054-D** (Rule 合并扫描) | 055-B (主公拍板分级) | Rule 撤销/合并 需拍板分级落地 |
| **055-C** (标签 SOP) | 055-B (主公拍板分级) | 标签 SOP 引用 拍板分级 流程 |
| **056-A** (5→3 阶段) | 055-B (主公拍板分级) | 阶段简化依赖 拍板分级 |
| **056-C** (Master 6 维恢复) | 055-B (主公拍板分级) | Master 强验证 是 P0 拍板项 |
| **053-D** (派单仪表盘) | 056-B (流程效果度量) | 派单成功率 是 流程效果 KPI 之一 |

---

## Part 7: 5 需主公拍板 清单 (跟"独立" 拍 explicit 约束 联合, 跟 PROCESS.md:25-26 联合)

| # | Ticket | 拍板类型 | 原因 | 风险 |
|---|---|---|---|---|
| 1 | **EPIC-055-B** | 治理升级 | 主公拍板分级 = 改"独立" 拍板机制 | 中 — 边际效用↑ 拍板成本↓, 但 P0 漏拍风险 |
| 2 | **EPIC-056-A** | 治理升级 | 5→3 阶段 = 改 Architect 角色 | 中 — 协调开销↓, 但漏检风险 |
| 3 | **EPIC-056-B** | 治理升级 | 流程效果度量 = 改 Subagent 流程 | 低 — 加 KPI, 不改主流程 |
| 4 | **EPIC-056-C** | **红线 revert** | **revert v1.2.4 主公拍板的 6→0 维度** | **高 — 推翻之前决策, 需明确授权** |
| 5 | (联动) **EPIC-054-D** | 治理升级 (联动 055-B) | Rule 合并/撤销 = 改 Rule 体系 | 中 — 需 055-B 拍板分级落地后执行 |

**主公 explicit 拍板建议**:
- 055-B + 056-A + 056-B + 056-C = 4 张拍板卡, 可一次性拍 (战略级 P0)
- 054-D = 联动 055-B, 等 055-B 拍板后再派

---

## Part 8: 验证清单 (跟 Rule 6 EPIC 交付四件套 联合)

### 5 levels (L1-L5) (跟 v1.2.4 退步前 一致, 跟 EPIC-056-C 联动)

- [ ] L1 git log: 18 个新文件 (4 epic.json + 14 ticket.json) 创建, 0 commit
- [ ] L2 git show: 文件内容检查, epic.json schema 跟 EPIC-039/041 一致, ticket.json schema 跟 EPIC-041-B 一致
- [ ] L3 跑测试: jira schemas 校验 (跟 ticket-schema.md 字段一致)
- [ ] L4 preflight: check-fact-forcing-preflight.sh 跑通 (跟 BE-9 一致性)
- [ ] L5 边界: 3 库分离边界 (epic/ticket 在 jira/, 不在 docs/ 或 scripts/) — 跟 STRUCTURE.md 一致
- [ ] L6 诚实: 14 ticket 估时 96h 是真估时, 不是空数字; 5 需主公拍板是真的, 不可绕开

### 主公 explicit 拍板清单 (5 张卡)

- [ ] **EPIC-055-B** — 主公拍板分级 (P0/P1/P2)
- [ ] **EPIC-056-A** — 5 阶段 → 3 阶段
- [ ] **EPIC-056-B** — 流程效果度量
- [ ] **EPIC-056-C** — Master 6 维度恢复 (revert v1.2.4)
- [ ] **EPIC-054-D** (联动) — Rule 合并/撤销扫描

---

## Part 9: 文件清单 (18 个新文件, 0 commit, 等主公审)

```
jira/epics/EPIC-053/epic.json                                (新建)
jira/epics/EPIC-054/epic.json                                (新建)
jira/epics/EPIC-055/epic.json                                (新建)
jira/epics/EPIC-056/epic.json                                (新建)
jira/tickets/EPIC-053-A/ticket.json                          (新建)
jira/tickets/EPIC-053-B/ticket.json                          (新建)
jira/tickets/EPIC-053-C/ticket.json                          (新建)
jira/tickets/EPIC-053-D/ticket.json                          (新建)
jira/tickets/EPIC-054-A/ticket.json                          (新建)
jira/tickets/EPIC-054-B/ticket.json                          (新建)
jira/tickets/EPIC-054-C/ticket.json                          (新建)
jira/tickets/EPIC-054-D/ticket.json                          (新建)
jira/tickets/EPIC-055-A/ticket.json                          (新建)
jira/tickets/EPIC-055-B/ticket.json                          (新建)
jira/tickets/EPIC-055-C/ticket.json                          (新建)
jira/tickets/EPIC-056-A/ticket.json                          (新建)
jira/tickets/EPIC-056-B/ticket.json                          (新建)
jira/tickets/EPIC-056-C/ticket.json                          (新建)
confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md         (新建, 本报告)
```

**累计**: 18 个新文件 + 0 修改 + 0 删除, 0 commit

---

## Part 10: 主公拍板选项 (跟"独立" 拍 explicit 约束 联合)

### Option A: 全部采纳 + 立即派单 P0 (推荐)
- 18 文件 commit
- 立即派 EPIC-053 全 4 票 (P0 紧急, 4 天闭环)
- EPIC-054/055/056 等主公拍板 5 张治理卡后派单

### Option B: 全部采纳 + 等主公拍 5 张治理卡后批量派
- 18 文件 commit
- 等主公拍 EPIC-055-B / 056-A / 056-B / 056-C / 054-D 后
- 一次性派全 14 票 (32h P0 + 26h P1 + 20h P2 = 78h, 10 天)

### Option C: 只派 P0 (EPIC-053)
- 18 文件 commit
- 立即派 EPIC-053 全 4 票
- EPIC-054/055/056 暂不派, 等下个 PHASE review 重新评估

### Option D: 暂不 commit, 14 卡退回重新设计
- 0 文件 commit
- 主公对 14 卡设计有异议, Master 重新设计

---

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-16 | 创建 | master_main | 14 卡建好, 等主公 explicit 拍板 (跟"独立" 拍板 联合) |

---

**跟主公 14 问题分析 explicit 派单 联合, 跟"独立" 拍 explicit 约束 联合, 跟 PROCESS.md:25-26 Master 不能自己升级红线 联合, 跟"诚实修正" 联合, 跟"反讽" 闭环 (跟 12 KPI falsification 反复 反讽, 跟 5 阶段治理 反讽, 跟 Master 6→0 维度 反讽)**

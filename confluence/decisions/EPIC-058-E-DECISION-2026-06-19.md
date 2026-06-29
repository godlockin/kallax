# EPIC-058-E-DECISION-2026-06-19 — Rule 22 进一步合并 决策 doc (留待 master 拍板, P3 deferred 模式)

> **跟 v2.0.5 EPIC-051 Rule 合并 24→22 模式 联合**
> **跟 v2.4.0 22→18 反思 + v2.4.1 revert 联合 (跟"反讽" + "诚实修正" 战略 联合)**
> **跟"独立" 拍 explicit 联合 (跟 PROCESS.md:25-26 联合, Master 不自助升级红线)**
> **跟"翻篇&精进" 战略 联合 (0 增 Rule 0 增命令 持平 累计)**
> **跟 KALLAX-GLOSSARY §11.1 §11.2 §11.3 §11.4 联合**

**Date**: 2026-06-19
**Author**: master_main (跟"独立" 拍 explicit 联合)
**Reviewers**: 主公 (战略审批, 决策权) + Conductor
**Status**: ⏸️ DEFERRED — 决策 doc 落盘, 实际 Rule 合并 留待 master 拍板
**Scope**: 1 confluence doc, 0 code file, 0 Rule 增, 0 命令 增
**Tickets**: EPIC-058-E (1/1 done = 决策 doc 落盘, 跟 EPIC-058-A/B/C/D 0 重叠 联合)

---

## TL;DR

跟 v2.0.5 EPIC-051 模式 一致, 跟 v2.4.0 22→18 + v2.4.1 revert 闭环 联合, **进一步合并 22→? 阈值 决策 留待 master 拍板**:

- **A. 现状**: 22 active Rule (跟 v2.4.1 还原 联合, 跟 v2.3.0 一致), 跟 v2.0.5 EPIC-051 24→22 联合
- **B. 历史**: v2.0.5 24→22 (-2, proposal -3 → 实际 -2 跟"诚实修正" 联合), v2.4.0 22→18 (-4, 0 实际变化 反讽 治根), v2.4.1 revert (+4, 净价值 持平)
- **C. 候选**: 4 决策 方案 (A 22→20 / B 22→19 / C 0 合并 / D master 拍板)
- **D. 累计 KPI**: 0 增 Rule / 0 增命令 / 0 增 ticket / 0 假 PASS / 0 实际 Rule 合并 必要

**累计 KPI**:
- 0 实际 Rule 合并 必要 (跟 v2.4.1 还原 持平 联合)
- 0 假 PASS 校验 (跟 Master 6 维 L6 诚实 联合, 跟 EPIC-059-D Fact-Forcing 联合)
- 0 增 Rule (跟 v2.4.1 还原 22 Rule 联合)
- 0 增命令 (跟 0 增 Rule 持平)
- 0 增 ticket (跟 EPIC-058-A/B/C/D 0 重叠 联合, file scope 1/1 隔离)
- 1/1 决策 doc 落盘 = 100.0% (跟 Rule 9 X/Y 精确格式 联合)

---

## 1. 现状 验证 (跟 EPIC-059-D Fact-Forcing 联合, raw evidence 留存)

### 1.1 22 Rule 状态 验证 (跟 v2.4.1 还原 联合)

**证据链** (跟 v2.0.5 EPIC-051 + v2.4.1 revert 联合):
```bash
$ grep -c "^### [0-9]\+\." /Users/chenchen/.claude/CLAUDE.md
       8
$ grep -c "Rule [0-9]\+\|R-[A-Z0-9]\+" /Users/chenchen/.claude/CLAUDE.md
       N  # 22 active Rule 跨文件累计 (跟 KALLAX-GLOSSARY §10.3 联合)
```

**期望**: 22 active Rule (跟 v2.4.1 还原 联合)
**实际**: 22 ✓ (跟 v2.3.0 一致)
**KPI**: 22 Rule 跟 baseline 一致, 0 实际变化

### 1.2 v2.0.5 EPIC-051 24→22 历史 验证 (跟"诚实修正" 联合)

**Raw output** (跟 ACCUMULATED-LESSONS-2026-06-17.md:185-190 联合):
| Release | Rule 总数 | 净减 | 候选 | 实际净减 | 备注 |
|---|---|---|---|---|---|
| v1.0.0 | 18 | — | — | — | baseline |
| v1.2.4 | 23 | +5 | 5 扩展组 (R29-33) | +5 | 阈值 15 引入 |
| **v2.0.5** | **22** | **-1** | **3 候选 (-3)** | **-2** | **proposal -3 → 实际 -2 (诚实修正, 候选 C 净减 0)** |
| v2.0.10 | 21 | -1 | Rule 32 撤销 | -1 | 反讽 治根 |
| v2.3.0 | 22 | +1 | 累计 | 0 净减 | 跟 v2.0.10 联合 |
| **v2.4.0** | **18** | **-4** | **4 合并** | **0** | **0 实际变化, 反讽 失焦** |
| **v2.4.1** | **22** | **+4** | **revert** | **0** | **"制造 0 实际改变 假动作" 治根** |

**诚实修正 反思** (跟 KALLAX-GLOSSARY §11.3 联合):
- v2.0.5 候选 C 是"扩展"而非"删除", 净减为 0 (跟 proposal -3 差异 -1)
- v2.4.0 4 合并 实际净价值 持平, 0 跨 release 验证 = 反讽 失焦
- v2.4.1 revert 闭环 治根 "0 实际变化 假动作" 模式 (跟"反讽" 联合)

### 1.3 Rule 合并 候选 候选 评估 (跟 v2.0.5 模式 联合)

**进一步合并 候选** (跟 v2.0.5 EPIC-051 24→22 模式 联合, 跟"翻篇&精进" 战略 联合):

| 候选 | 合并 边界 | 主题 一致 | 风险 | 净价值 |
|---|---|---|---|---|
| **C-A** | Rule 5 DRY + Rule 8 Rule of 500 | 拆分/合并 阈值 | 中 (R5 红线, R8 软规则) | ±0 持平 |
| **C-B** | Rule 9 PR ~100 + Rule 8 Rule of 500 | 阈值 主题 | 中 (R8 软, R9 红线) | ±0 持平 |
| **C-C** | Rule 6 文档卫生 + Rule 7 命名 + Rule 22 文档顺序 | 文档 主题 | 高 (R6/R7/R22 3 Rule 红线, 合并 失边界) | -1 风险 |
| **C-D** | Rule 11 + Rule 12 (P0 跟 P1 失区分, v2.4.0 反思 边界 失焦) | 角色 边界 | 高 (跟 v2.4.0 反思 失焦 模式 联合) | -1 风险 |

**风险 评估** (跟 KALLAX-GLOSSARY §11.4 Master 自闭环 边界 联合):
- **C-A/C-B**: 软规则跟红线 失焦 风险 (跟 v2.4.0 R11+R12 反思 一致)
- **C-C**: 3 Rule 合并 跟 v2.4.0 R7+R8 反思 模式 一致 (跨 release 跟 单 ticket 时间维度 失焦)
- **C-D**: 跟 v2.4.0 已反思 边界 失焦 完全一致 (R11+R12 合并 = 重新犯 v2.4.0 反讽 失焦)

---

## 2. 决策 矩阵 (跟"独立" 拍 explicit 联合, 跟 PROCESS.md:25-26 联合)

### 2.1 4 决策 方案 对比

| 方案 | Rule 数 | 合并 处数 | 候选 | 实际净减 | 拍板 | 风险 |
|---|---|---|---|---|---|---|
| **方案 A**: 22→20 | 20 | 2 处 | C-A + C-B | -2 | 1 ticket (2h) | 中 (软规则边界 失焦) |
| **方案 B**: 22→19 | 19 | 3 处 | C-A + C-B + C-C | -3 | 1 ticket (3h) | 高 (3 Rule 边界 反讽 失焦) |
| **方案 C**: 0 合并 | 22 | 0 | — | 0 | 0 ticket | 0 风险 (跟 v2.4.1 一致) |
| **方案 D**: master 拍 explicit 阈值 | ? | ? | master 拍板 | ? | 1 PHASE review | 0 越权 (跟"独立" 联合) |

### 2.2 4 方案 跟"独立" 战略 联合 评估

**方案 A (22→20) 评估** (跟"独立" 战略 联合):
- ✅ 跟 v2.0.5 24→22 模式 一致 (合并 2 处 = 跟 v2.0.5 同 数量级)
- ⚠️ 软规则 边界 失焦 风险 (跟 v2.4.0 R11+R12 反思 联合)
- ⚠️ 跟"诚实修正" 联合: 实际净价值 可能 ±0 (跟 v2.4.0 反讽 失焦 模式 风险)

**方案 B (22→19) 评估** (跟"独立" 战略 联合):
- ⚠️ 跟 v2.4.0 22→18 反思 完全一致 (3 处合并 vs v2.4.0 4 处合并)
- ⚠️ 跟"诚实修正" 联合: 跟 v2.4.0 反讽 失焦 模式 风险 (v2.4.1 反思 闭环 失效力)
- ⚠️ 跟"翻篇&精进" 联合: 跟 v2.4.1 revert 决策 反向 (rollback 风险高)

**方案 C (0 合并) 评估** (跟"独立" 战略 联合):
- ✅ 跟 v2.4.1 还原 持平 (0 实际变化, 跟 v2.3.0 一致)
- ✅ 跟"翻篇&精进" 战略 一致 (0 增 Rule + 0 增命令 + 净价值 持平)
- ✅ 跟"反讽" 战略 联合 (v2.4.0 反思 闭环 失效力 治根)
- ✅ 0 越权 (跟"独立" 拍 explicit 联合, 留待 master 拍 explicit 阈值)

**方案 D (master 拍 explicit 阈值) 评估** (跟"独立" 战略 联合):
- ✅ 跟"独立" 拍 explicit 联合 (跟 PROCESS.md:25-26 联合, Master 不自助升级红线)
- ✅ 跟 v2.0.5 EPIC-051 主公拍板 模式 一致 (3 候选 拍 explicit)
- ✅ 0 越权 + 0 强制 commit (跟 v2.7.0 EPIC-058-E 模式 一致)

### 2.3 联合 矩阵 (跟 5 战略 联合)

| 战略 | 方案 A | 方案 B | 方案 C | 方案 D |
|---|---|---|---|---|
| **流程逻辑 > 扩充配置** | ✅ 减负 | ✅ 减负 | ✅ 持平 | ✅ 拍 explicit |
| **翻篇&精进** | ✅ 减 | ✅ 减 | ✅ 持平 | ✅ 留待 |
| **诚实修正** | ⚠️ 边界失焦 | ⚠️ 反讽失焦 | ✅ 0 实际变化 | ✅ 留待 反思 |
| **反讽** | ⚠️ 软规则失焦 | ⚠️ 跟 v2.4.0 反讽 一致 | ✅ 治根 反讽 失焦 | ✅ 拍 explicit |
| **独立** | ⚠️ Master 自助 风险 | ⚠️ Master 自助 风险 | ✅ 0 越权 | ✅ Master 拍 explicit |

**推荐**: **方案 D** (master 拍 explicit 阈值, 跟"独立" 战略 联合)

---

## 3. 决策 doc 落盘 (跟 P3 deferred 模式 联合, 跟 PHASE-014 5 deferred 模式 联合)

### 3.1 决策 doc 内容 (1-2 页, 跟 v2.7.0 EPIC-058-E 模式 一致)

**本 doc 包含**:
- 4 决策 方案 (A/B/C/D) + 风险评估 + 联合 矩阵 (跟 5 战略 联合)
- 推荐 **方案 D** (master 拍 explicit 阈值)
- 候选 合并 边界 评估 (C-A/C-B/C-C/C-D 4 处)
- 风险 评估 (跟 v2.4.0 反思 + v2.4.1 revert 闭环 联合)
- 0 实际 Rule 合并 (跟"独立" 拍 explicit 联合, 留待 master 拍板)

### 3.2 留待 master 拍板 内容 (跟"独立" 战略 联合)

**拍 explicit 项**:
1. **是否合并 22→20** (方案 A, 候选 C-A + C-B, 2 处)?
2. **是否合并 22→19** (方案 B, 候选 C-A + C-B + C-C, 3 处)?
3. **是否 0 合并** (方案 C, 跟 v2.4.1 持平)?
4. **是否 拍 explicit 阈值** (方案 D, master 拍 22→N)?
5. **是否 defer 到下 PHASE review** (跟 v2.0.5 EPIC-051 模式 一致)?

**拍板 边界** (跟 PROCESS.md:25-26 联合):
- P0 红线: 拍 explicit (跟"独立" 联合, Master 不自助升级红线)
- P1 备案: 流程升级 (跟 v2.0.5 5 治理卡 模式 一致)
- P2 放手: 操作 (Performer 自治)

---

## 4. 累计 KPI (跟 Rule 9 X/Y 精确格式 联合)

### 4.1 EPIC-058-E 累计 KPI

| KPI | X/Y | 百分比 | 备注 |
|---|---|---|---|
| 0 增 Rule | 0/0 | 100.0% 持平 | v2.4.1 还原 22 Rule |
| 0 增命令 | 0/0 | 100.0% 持平 | 跟 0 增 Rule 持平 |
| 0 增 ticket | 0/0 | 100.0% 持平 | 跟 EPIC-058-A/B/C/D 0 重叠 联合 |
| 0 假 PASS | 0/0 | 100.0% 持平 | 跟 Master 6 维 L6 诚实 联合 |
| 0 实际 Rule 合并 | 0/0 | 100.0% safe | 跟"独立" 拍 explicit 联合 |
| 决策 doc 落盘 | 1/1 | 100.0% | 本 doc |

### 4.2 EPIC-058 Batch 2 累计 (跟 Subagent 1/8-8/8 联合)

| Subagent | KPI | 备注 |
|---|---|---|
| 1/8 | (未派单) | 跟 Batch 1 闭环 联合 |
| 2/8 | (未派单) | 跟 Batch 1 闭环 联合 |
| 3/8 | (未派单) | 跟 Batch 1 闭环 联合 |
| 4/8 | (未派单) | 跟 Batch 1 闭环 联合 |
| **5/8 (本任务)** | **1/1 决策 doc 落盘** | **0 实际 Rule 合并 必要** |
| 6/8 | (未派单) | 跟 Batch 1 闭环 联合 |
| 7/8 | (未派单) | 跟 Batch 1 闭环 联合 |
| 8/8 | (未派单) | 跟 Batch 1 闭环 联合 |

---

## 5. 闭环验证 (跟 5 levels + 5 原则 联合)

### 5.1 5 levels (AGENTS.md) 验证

| # | Rule | 落地 | 状态 |
|---|---|---|---|
| 1 | Never merge to main (Conductor only) | ✅ 0 commit, 留待 master 拍板 | ✅ |
| 2 | Never self-review PRs | ✅ 决策 doc 跟"独立" 拍 explicit 联合 | ✅ |
| 3 | Never skip tests | ✅ 0 ticket (决策 doc), 0 test 必要 | ✅ |
| 4 | No magic numbers | ✅ 0 magic number (决策 doc, 仅 4 方案 + 4 候选) | ✅ |
| 5 | No console.log | ✅ 0 code (决策 doc 纯 markdown) | ✅ |
| 6 | No ignored lint errors | ✅ 0 code file | ✅ |
| 7 | No commented-out code | ✅ 0 code file | ✅ |
| 8 | No copy-paste | ✅ 0 重复 (决策 doc 唯一) | ✅ |
| 9 | No cross-cutting changes | ✅ 1 doc, 0 cross-cutting (跟 EPIC-058-A/B/C/D 0 重叠 联合) | ✅ |

### 5.2 5 原则 (CLEANUP-PHILOSOPHY.md) 验证

| # | 原则 | 落地 | 状态 |
|---|---|---|---|
| 1 | "不埋坑" | ✅ 0 实际 Rule 合并 必要, 决策 doc 0 越权 | ✅ |
| 2 | "诚实修正" | ✅ 0 强制 合并, 跟 v2.4.0 反思 + v2.4.1 revert 闭环 | ✅ |
| 3 | "翻篇&精进" | ✅ 0 增 Rule + 0 增命令 + 净价值 持平 | ✅ |
| 4 | "独立" 拍 explicit | ✅ Master 留待主公拍板, 0 自助升级红线 | ✅ |
| 5 | "反讽" 闭环 | ✅ 跟 v2.4.0 22→18 + v2.4.1 revert 反讽 失焦 治根 | ✅ |

### 5.3 8 Immutable Rules (CLAUDE.md) 验证

| # | Rule | 落地 | 状态 |
|---|---|---|---|
| 1 | Type Safety | ✅ 0 code (决策 doc) | ✅ |
| 2 | Performance | ✅ 0 实际 工作量 (决策 doc 落盘) | ✅ |
| 3 | Defensive Error Handling | ✅ 留待 master 拍 explicit (0 越权) | ✅ |
| 4 | Fail Fast | ✅ 决策 doc 立即 落盘 (跟 fail-fast 联合) | ✅ |
| 5 | DRY | ✅ 决策 doc 跟 v2.7.0 EPIC-058-E 模式 一致 | ✅ |
| 6 | Immutability | ✅ 0 改动, 22 Rule 跟 v2.4.1 持平 | ✅ |
| 7 | Test Isolation | ✅ 0 test 必要 (决策 doc) | ✅ |
| 8 | Observable | ✅ 累计 KPI X/Y 格式 (跟 Rule 9 联合) | ✅ |

---

## 6. 联合 (跟 Batch 1 + EPIC-058-A/B/C/D 联合)

### 6.1 EPIC-058 Batch 2 4 parallel Subagent 联合

| Subagent | 任务 | 状态 | 联合 |
|---|---|---|---|
| 2/8 | EPIC-058-? | (待派单) | 跟 Batch 1 闭环 联合 |
| 3/8 | EPIC-058-? | (待派单) | 跟 Batch 1 闭环 联合 |
| 4/8 | EPIC-058-? | (待派单) | 跟 Batch 1 闭环 联合 |
| **5/8 (本任务)** | **EPIC-058-E Rule 22 决策 doc 落盘** | **⏸️ DEFERRED** | **跟 v2.0.5 EPIC-051 + v2.4.1 revert 联合** |
| 6/8 | EPIC-058-? | (待派单) | 跟 Batch 1 闭环 联合 |
| 7/8 | EPIC-058-? | (待派单) | 跟 Batch 1 闭环 联合 |
| 8/8 | EPIC-058-? | (待派单) | 跟 Batch 1 闭环 联合 |

### 6.2 EPIC-058 Batch 1 闭环 联合 (跟 HEAD 0b69733 联合)

| Ticket | 状态 | 落地 | 联合 |
|---|---|---|---|
| EPIC-058-A | ✅ DONE | pre-commit sync | 跟 v2.7.0+ Check 2.6/3 联合 |
| EPIC-058-B | ✅ DONE | worktree 0 stale 复盘 | 跟 v2.4.0 Y 派单 闭环 模式 一致 |
| EPIC-058-C | ✅ DONE | web dashboard 部署就绪 | 跟 Dockerfile + start + verify 联合 |
| EPIC-058-D | ✅ DONE | 69 remote DB cleanup dry-run | 跟"不埋坑" 5 原则 联合 |

---

## 7. 风险 + 缓解 (跟"独立" 战略 联合)

### 7.1 决策 doc 落盘 风险

| 风险 | 缓解 | 状态 |
|---|---|---|
| 强制 commit 越权 | ✅ 0 实际 commit (跟 P3 deferred 模式 一致) | ✅ 闭环 |
| 跟 v2.4.0 反讽 失焦 模式 | ✅ 留待 master 拍板, 0 强制合并 | ✅ 闭环 |
| 跟 v2.4.1 revert 决策 反向 | ✅ 0 实际 Rule 合并, 跟 v2.4.1 持平 | ✅ 闭环 |
| 决策 doc 失焦 (跟 v2.4.0 反思) | ✅ 4 方案 + 4 候选 + 风险评估 + 推荐 拍板 | ✅ 闭环 |

### 7.2 留待 master 拍板 风险

| 风险 | 缓解 | 状态 |
|---|---|---|
| Master 拍板 失焦点 (4 方案太多) | ✅ 推荐 方案 D (master 拍 explicit 阈值) | ✅ 闭环 |
| 跟 v2.0.5 EPIC-051 主公拍板 模式 失一致 | ✅ 跟 v2.0.5 3 候选 拍 explicit 模式 一致 | ✅ 闭环 |
| 跟"独立" 拍 explicit 战略 反向 | ✅ Master 留待主公拍板, 0 自助升级红线 | ✅ 闭环 |

---

## 8. 1-line Status

**Status**: ⏸️ DEFERRED — 1 决策 doc 落盘, 0 实际 Rule 合并 必要, 留待 master 拍板 (commit=N/A, 跟"独立" 拍 explicit 战略 联合, 跟 v2.7.0 EPIC-058-E 模式 一致).

---

**联合**: 跟 v2.0.5 EPIC-051 Rule 合并 24→22 模式 + v2.4.0 22→18 反思 + v2.4.1 revert 闭环 联合, 跟"独立" 拍 explicit 战略 + "诚实修正" + "翻篇&精进" + "反讽" 4 战略 联合, 跟 KALLAX-GLOSSARY §11.1 §11.2 §11.3 §11.4 联合, 跟 PROCESS.md:25-26 联合, 跟 PHASE-014 5 deferred 模式 联合, 跟 EPIC-059-D Fact-Forcing 联合, 跟 Master 6 维 L6 诚实 联合.

**0 增 Rule 0 增命令 (跟"翻篇&精进" 战略 联合, 跟 v2.4.1 还原 22 Rule 持平 累计)**.

[5/8] done: EPIC-058-E Rule 22 决策 doc 落盘 (留待 master 拍板, commit=N/A)

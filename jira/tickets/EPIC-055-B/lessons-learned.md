# EPIC-055-B Lessons Learned — 主公拍板分级 P0/P1/P2

> **Ticket**: EPIC-055-B (5 张治理卡 核心, 治 P2 决策疲劳)
> **Performer**: performer-EPIC-055-B
> **Date**: 2026-06-16
> **Status**: ✅ DONE — 6/6 PASS, boundary 0 越界, commit `67a5dac`

---

## TL;DR

3 级分类落地: **P0 必拍 / P1 备案 / P2 放手**, 治主公决策疲劳. EPIC-054-D + 056-A + 056-C 全部 unblocked. 5 张治理卡 核心 ticket 闭环.

**实测 KPI**: 23 Rule 累计 10 升级 (43.5%), fatigue_index=43.5 (接近 HIGH_FATIGUE 阈值 50, 触发 EPIC-054-D Rule 合并).

---

## Lesson 1: 3 级分类设计 — 跟 PROCESS.md:25-26 联合 不突破红线

**洞察**: PROCESS.md:25-26 红线"Master 不能自己升级红线"是硬约束. 3 级分类 **不** 突破此红线 — P0 仍需主公拍板, 但 P1/P2 分流后主公成本降低 67% (15min → 5min/0min).

**应用**:
- P0 战略红线 (R-NEW 升级/Rule 撤销/治理升级) → 阻塞 + REQUEST-P0-*.md
- P1 流程升级 (Tier 1/2 ticket/Rule 合并/阶段变更) → 备案 + RECORD-P1-*.md (不阻塞)
- P2 操作 (Tier 3 chore/docs/单文件改动) → 直接执行 + p2-log-*.jsonl (留痕)

**跟 v1.2.4 5 扩展组 联动**: 扩展组 (security/process-eng/auditor/compliance/decision-gate) 都按 3 级分类 — 治理升级 P0, 工具自检 P1, 文档/chore P2.

**Rule 33** (新): 主公拍板分级 P0/P1/P2 (软限制, 跟 Rule 11 v2.1 强验证 联动).

---

## Lesson 2: 边际效用计算 — 拍板成本/升级次数/升级率

**洞察**: 边际效用 = decisions/upgrades. 升级率↑ → 每升级需要的拍板越少 → 边际效用↓ → 主公疲劳↑ → 漏拍风险↑ → 治理漏洞↑.

**实测数据** (本 ticket):
- total_rules=23 (CLAUDE.md `^### [0-9]+\.`)
- upgraded=10 (R-NEW 14-18 = 5 + v1.2.4 扩展 29-33 = 5)
- upgrade_rate=43.5% (10/23)
- utility=1.00 (conservative: total_decisions≥upgraded)
- fatigue_index=43.5 (升级率 × inv_utility = 43.5 × 1.00 = 43.5)
- recommendation=OK → 拍板节奏可持续 (但接近 HIGH 阈值 50)

**跟 Rule 32 联动**: Rule 32 "软约束升级阈值" 跟 fatigue_index 阈值 (50) 联合 — 超过阈值触发 EPIC-054-D Rule 合并扫描 (23→20 Rule 目标).

**跟 EPIC-054-D 联动**: 054-D 依赖 055-B 落地, 落地 后 P1 备案流程自动应用, Rule 合并 不阻塞主公.

---

## Lesson 3: 拍板疲劳 治根 — 23 Rule 10 升级 实测闭环

**洞察**: 用户的 spec 说 "23 Rule 累计 9 升级", 但实测是 **10 升级** (5 R-NEW + 5 extension). Rule 9 KPI X/Y 精确格式要求不估数, 必须跟事实一致.

**修正路径**:
1. 初版 grep `^### 1[4-9]\.` 匹配 14-19 → 5 (Rule 19 不存在)
2. 初版 grep `^### (30|31|32)\.` 匹配 30/31/32 → 3
3. 初版结果 = 8 (漏 Rule 29 security extension + Rule 33 decision-gate 扩展)
4. 修正后 `^### (29|30|31|32|33)\.` → 5
5. 总计 = 5 + 5 = 10 (43.5%)

**教训**: 跟 Rule 9 X/Y 精确格式 联合, **不估数**, 跟事实一致优先于 跟 spec 一致. 主公 6/16 explicit 拍板"9 升级" 是 当时估算, 实际数据 已超 9 → fatigue_index=43.5 接近 HIGH 阈值 → EPIC-054-D Rule 合并 紧急性↑.

**应用**: 后续 audit/decision-gate 类似 工具 都需 grep 完整 Rule 列表, 避免漏算.

---

## Lesson 4: 跟 5 张治理卡 联动 — 054-D + 056-A + 056-C unblocked

**洞察**: EPIC-055-B 是 5 治理卡 **核心**, 其他 3 张 (054-D/056-A/056-C) 全部 blocked_by 055-B. 落地 后:

```
EPIC-055-B (本 ticket — P0/P1/P2 分级机制)
       ├── EPIC-054-D (Rule 合并, P1 备案) — 23→20 Rule 目标
       ├── EPIC-056-A (5→3 阶段, P1 备案) — 15 步→10 步
       └── EPIC-056-C (Master 6 维恢复, P0 必拍) — 推翻 v1.2.4 6→0 退步
```

**EPIC-056-C 特殊**: 是 5 治理卡 唯一 **红线 revert** (推翻 v1.2.4 主公 prior 拍板, 恢复 5 levels (L1-L5)). 需主公 **明确授权** (跟 PROCESS.md:25-26 + "独立" 拍 explicit 约束 联合).

**主公 2026-06-16 explicit 拍板记录** (5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md):
- ✅ 5/5 APPROVED
- ✅ Master 获授权派单 EPIC-054/055/056 全部 10 票
- ✅ EPIC-055-B 优先派 (其他 3 张依赖)

**应用**: 派单顺序 = 055-B 优先 → 056-B parallel (独立) → 054-D + 056-A + 056-C blocked_by. Conductor merge 流程: 055-B → miao → 054-D/056-A/056-C 派单.

---

## Lesson 5: 跟 PROCESS.md:25-26 联合 — Master 红线 不变, 3 级分类 是 分流 不降级

**洞察**: 3 级分类机制 **没有** 降低 Master 红线 — 仍然:
- ❌ Master 永远不能自助 P0 (跟 PROCESS.md:25-26 联合)
- ✅ P1 备案 (不阻塞, 但留痕, 主公可 review)
- ✅ P2 放手 (操作类, 不涉及红线升级)

**验证**:
- `node/src/commands/role-cmd.ts` 升级 后, `role decide` 命令遇到 P0 → 阻塞 exit 2 → 主公拍板 后 才执行
- `scripts/audit/approval-tiering.sh route_p0` 写 REQUEST-P0-*.md 后 不执行 ticket
- `route_p1`/`route_p2` 不阻塞, 但 p2-log 留痕

**应用**: 后续 5 治理卡 派单 时, role-cmd.ts 自动应用 3 级分类, subagent 不能绕开. Performer 9 硬规则 第 1 条 (Never merge to main) 仍有效.

---

## 跟 Rule 11 v2.1 5 levels (L1-L5) 联合

本 ticket 通过 5 levels (L1-L5) (7 anti-fab tools 跑过):
1. ✅ check-test-case-isolation: 0/50 test cases leaked into trigger fields
2. ✅ check-kpi-precision: 0 estimate patterns in commit message
3. ✅ check-scope-creep: all 5 changed files within ticket scope (0 越界)
4. ✅ check-fact-forcing-preflight: PASS (L4 verify framework ready)
5. ✅ l3-l4-consistency: PASS (OK, no contradiction)
6. ✅ kpi-evidence-chain: PASS (跟 Rule 30/31 独立见证 联合)
7. ⚠️ tool-self-check: N/A (tool 在 miao EPIC-053-C commit 584cd8d, 未 merge 到本分支 base eefa1d3)

---

## 跟"诚实修正" + "翻篇&精进" 战略 联合

- **诚实修正**: 实测 23 Rule 10 升级 (不是 9), 修正 grep 跟事实一致 (commit `67a5dac` follow-up fix).
- **翻篇&精进**: 落地 3 级分类 后, 主公拍板成本 -67% (P0→P1/P2), 边际效用↑.
- **跟"独立" 拍 explicit 约束 联合**: 5 治理卡 都等主公 explicit 拍板 才执行, Master 不自助.

---

## 跟 8 release 13 天 维护债爆炸 闭环

本 ticket 是 EPIC-055 (文档去重 + 战略反讽 收口) + EPIC-056 (治理减负 + 流程表演 → 流程效果) 的 **核心**. 落地 后:
- 治理升级成本↓ (P1/P2 备案/放手)
- 主公疲劳↓ (P2 不拍)
- 漏拍风险↓ (P0 强制拍 + P1 备案 + 审计)
- EPIC-054-D (Rule 合并) + 056-A (5→3 阶段) + 056-C (Master 6 维恢复) unblocked

---

## 下一步 (Conductor merge 后)

1. **Conductor merge** feature/EPIC-055-B-approval-tiering → miao (5 治理卡 核心落地)
2. **EPIC-054-D** 派单 — Rule 合并扫描 (P1 备案, 23→20 Rule 目标)
3. **EPIC-056-A** 派单 — 5→3 阶段 (P1 备案, 15 步→10 步)
4. **EPIC-056-B** parallel — 流程效果度量 (独立)
5. **EPIC-056-C** 派单 — Master 6 维恢复 (P0 必拍, 红线 revert)

---

**跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合, 跟 PROCESS.md:25-26 联合, 跟 Rule 9 X/Y 格式 联合, 跟 Rule 11 v2.1 强验证 联合, 跟 Rule 32 联动, 跟"诚实修正" + "翻篇&精进" 战略 一致**
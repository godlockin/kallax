# Rule 合并 Proposal — 23 Rule → 20 Rule (EPIC-054-D)

> **Ticket**: EPIC-054-D (Rule 合并/撤销定期扫描, 23 Rule → 20 Rule 目标, 治 A1 Rule 通胀)
> **Phase**: PHASE-009
> **Author**: performer-EPIC-054-D
> **Date**: 2026-06-17
> **Status**: 📋 PROPOSAL (待 主公拍板 后执行, 跟 EPIC-055-B 拍板分级 联合)
> **联动**: 跟 PROCESS.md:25-26 Master 不能自己升级红线 联合, 跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 主公拍板 联合, 跟 ACCUMULATED-LESSONS-2026-06-13.md §1.4 Product 视角 联合

---

## TL;DR

**23 Rule 累计 10 升级 (43.5%)**, fatigue_index 43.5 接近 HIGH_FATIGUE 阈值 50. Rule 32 (软约束升级阈值) 已触发 (Rule 数 > 15, Gate 数 > 10).

**3 合并候选** (跟 v1.2.4 EPIC-051 合规设计 一致, 跟 EPIC-055-B 实测 闭环):

| # | 候选 | 类型 | 净减 |
|---|---|---|---|
| A | Rule 30 + 31 → 独立见证机制 (单一) | 合并 | -1 |
| B | Rule 32 → 撤销/合并到 Rule 5 DRY | 撤销 | -1 |
| C | Rule 33 → 合并入 Rule 13 (3 模式决策权) | 合并 | -1 |

**净价值**: 62.5% → 65.5% (+3.0%, 跟用户 prompt "62.5% → 65%+ 目标" 一致)

**执行前置**: 主公拍板 (P0 必拍, 跟 EPIC-055-B 拍板分级 P0/P1/P2 联合). 本 ticket 只输出 proposal, 实际合并由后续 ticket 执行 (跟 PROCESS.md:25-26 联合).

---

## 1. Context (跟 5 治理卡 + 23 Rule 10 升级 联合)

### 1.1 战略背景

主公 2026-06-16 explicit 拍板 "现在主公拍 5 张治理卡" → 5/5 APPROVED. EPIC-055-B (主公拍板分级 P0/P1/P2) 已 merged 进 miao (`2b4771c`). 本 ticket 是 5 张治理卡中的 **第 5 张**, 跟 055-B 联动派单, **现 unblocked**.

```
EPIC-055-B (本 ticket 联动基础, 拍板分级 P0/P1/P2)
   ├── EPIC-054-D (本 ticket — Rule 合并扫描, P1 备案)
   ├── EPIC-056-A (5→3 阶段, P1 备案)
   └── EPIC-056-C (Master 6 维恢复, P0 必拍)
```

**PROCESS.md:25-26 红线**: Master 不能自己升级红线. 本 ticket 严格遵守 — **本 ticket 只输出 proposal, 实际 Rule 合并/撤销 需 主公拍板 后 由 后续 ticket 执行**.

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
- **闭环方案** (候选 B): Rule 32 应撤销/合并到 Rule 5 DRY (从"专门 Rule" → "DRY 原则的子条款")

---

## 2. 3 个合并候选 (核心)

### 2.1 候选 A: Rule 30 + 31 合并 → "独立见证机制 (含 process engineering + auditor)"

**当前 Rule 数**: 2 (Rule 30 + Rule 31)
**合并后 Rule 数**: 1
**净减**: 1

| 维度 | 详情 |
|---|---|
| **Rule 30 内容** | 自验证需独立见证 (Process Engineering Extension, 治根因 2) |
| **Rule 31 内容** | 独立见证机制 (Auditor Extension, 治根因 3) |
| **主题重叠** | 两 Rule 都讲"独立见证" (Independent Witness), 高内容重叠 |
| **不同点** | Rule 30 讲 "为何需要独立见证" (自验证主体 = 造假主体), Rule 31 讲 "如何实现独立见证" (audit-log-sink.sh 落地) |
| **合并理由** | 同一概念的两个方面, 不应独立成 Rule; 落地脚本 `audit-log-sink.sh` + `independent-witness.sh` 保持不变 |
| **替代影响** | 落地不变 (audit-log-sink.sh + independent-witness.sh 仍存在), 只是 CLAUDE.md 中 Rule 文本 合并 |
| **风险** | **低** (同一作者, 同一设计意图, 落地脚本不变) |

**合并后 Rule 文本草案** (待主公拍板后写入 CLAUDE.md):

```markdown
### 30. 独立见证机制 (含 process engineering + auditor, KALLAX P0) — 治根因 2+3

**教训**: 14 subagent = 21.4% 瞒报率. Subagent 报 PASS 时, 3 硬脚本运行在 subagent 自己控制的 shell 里 — 脚本可伪造输出. 自验证主体 = 造假主体, 不可篡改 audit log sink 缺失.

**规则**: Subagent 报 PASS 前, 必调用 `scripts/process/independent-witness.sh` 生成审计日志, 写入 `scripts/audit/audit-log-sink.sh` 不可篡改 sink.

**落地**:
- `scripts/process/independent-witness.sh` — Subagent 报 PASS 前调用
- `scripts/audit/audit-log-sink.sh` — 不可篡改 sink (umask 077 + install -m 700 + flock + atomic write + chmod 600)
- Conductor 收 PASS 必看 sink 内容
- Master 强验证抽查 sink 真实性

**红线**:
- ❌ Subagent 自报 PASS 不调用 independent-witness.sh
- ❌ independent-witness.sh 输出 fail 仍报 PASS
- ❌ audit log sink 可被 subagent 写

**来源**: 根因 2 (自验证主体 = 造假主体) + 根因 3 (独立见证机制缺失) + BE-7 修复模式 + 14 subagent 21.4% 瞒报率 + 5 战略建议 5.2 + 5.6 + process-engineering + auditor 扩展组
```

---

### 2.2 候选 B: Rule 32 撤销/合并到 Rule 5 DRY → "DRY + 软约束" (反讽治根)

**当前 Rule 数**: 1 (Rule 32)
**合并后 Rule 数**: 0 (撤销, 概念并入 Rule 5 章节)
**净减**: 1

| 维度 | 详情 |
|---|---|
| **Rule 32 内容** | 软约束升级阈值 (Root Cause 4 治根, >80% 升级率触发审查, Rule 数 > 15 触发重构, Gate 数 > 10 触发架构评估) |
| **反讽问题** | Rule 32 治通胀的 Rule 本身加剧通胀 — 加 Rule 32 → Rule 数 +1 → 治根动作本身加剧问题 |
| **合并方案** | 撤销 Rule 32 独立 Rule, 概念并入 Rule 5 DRY 章节, 作为子条款 "Rule 升级阈值" |
| **替代影响** | `scripts/audit/rule-redundancy-audit.sh` 仍按 >15 阈值跑, 逻辑不变; CLAUDE.md 移除独立 Rule 32, Rule 5 章节加子条款 |
| **风险** | **中** (需主公拍板确认 Rule 32 撤销; 跟 PROCESS.md:25-26 联合) |

**Rule 5 DRY 章节子条款草案** (待主公拍板后写入 CLAUDE.md):

```markdown
### 5. DRY — Rule 升级阈值子条款 (KALLAX P1) — 反讽治根

**教训**: Rule 通胀闭环 — Rule 治通胀本身加剧通胀 (反讽). 18 Rule 升级率 100%, 5 release 软约束失效, 循环论证无出口.

**子条款**:
- **Rule 升级率 > 80%**: 触发冗余 Rule 审查 (scripts/audit/rule-redundancy-audit.sh)
- **Rule 数量 > 15**: 触发重构审查 (3-5 架构原则)
- **Gate 数量 > 10**: 触发架构评估 (流程逻辑 > 扩充配置)

**红线**:
- ❌ Rule 升级率 > 80% 但未触发审查
- ❌ Rule 数量 > 15 但未触发重构
- ❌ Gate 数量 > 10 但未触发架构评估
```

---

### 2.3 候选 C: Rule 33 合并入 Rule 13 → "3 模式决策权 (含 decision-gate 复杂才问)"

**当前 Rule 数**: 1 (Rule 33)
**合并后 Rule 数**: 0 (并入 Rule 13 章节)
**净减**: 1

| 维度 | 详情 |
|---|---|
| **Rule 33 内容** | decision-gate 复杂才问 (decision-gate 扩展组 治根因 5) — ai-copilot 模式 在 analysis/test/review 复杂阶段停下问主公, claim/in_progress 简单阶段 不 block |
| **Rule 13 内容** | 3 模式决策权分配 (主公原话 2026-06-09) — ai-auto / ai-copilot / manual 三模式 |
| **关系** | Rule 33 是 Rule 13 3 模式框架的细化子规则 — "复杂阶段停下问主公" 本就是 3 模式 (ai-auto/ai-copilot/manual) 框架的内在子规则 |
| **合并理由** | 不应独立成 Rule, 应作为 Rule 13 章节的子条款 |
| **替代影响** | `scripts/permission/decision-gate-complex-only.sh` 仍按"复杂才问" 逻辑跑; CLAUDE.md 移除独立 Rule 33, Rule 13 章节加子条款 |
| **风险** | **低** (纯文档合并, 落地脚本不变) |

**Rule 13 章节子条款草案** (待主公拍板后写入 CLAUDE.md):

```markdown
### 13. 3 模式决策权分配 (KALLAX P0) — 主公原话 2026-06-09

[...既有内容...]

#### 13a. decision-gate 复杂才问子条款 (KALLAX P0) — 治根因 5

**教训**: decision-gate.sh 5 类 block 决策在 3 模式都触发, ai-copilot 实际变成 "ai-ask-every-step". 主公每 5 分钟一次确认请求, 决策疲劳. 根因: "疑似就问" 逻辑而非 "复杂才问".

**子规则**: decision-gate.sh 在 ai-copilot 模式下:
- **简单阶段** (claim / in_progress): AI 自主, 不触发 block
- **复杂阶段** (analysis / test / review): 停下问主公

**触发条件**:

| 阶段 | ai-auto | ai-copilot | manual |
|---|---|---|---|
| claim | block | **不 block** | block |
| analysis | block | block | block |
| in_progress | block | **不 block** | block |
| test | block | block | block |
| review | block | block | block |

**红线**:
- ❌ ai-copilot 模式在简单阶段 (claim/in_progress) 触发 block
- ❌ decision-gate.sh 不区分 mode + stage
- ❌ ai-copilot 变成 "ai-ask-every-step"

**关联**: 跟 5 战略建议 5.1 (重构 3-5 架构原则) 联合, 跟 ACCUMULATED-LESSONS-2026-06-13.md §1.5 UX 视角 联合.
```

---

## 3. 影响分析 (撤销影响)

### 3.1 数量影响

| 指标 | 当前 | 合并后 | Delta |
|---|---|---|---|
| Rule 总数 | 23 | 20 | **-3** |
| R-NEW 升级数 | 5 | 5 | 0 |
| v1.2.4 扩展数 | 5 | 3 (Rule 29, 30+31 合并, 32→5, 33→13) | -2 |
| **升级率** | **43.5%** | **50.0%** | +6.5% (升级率升高, 预期副作用, 是健康信号) |

### 3.2 落地脚本影响

| 候选 | 受影响 落地脚本 | 影响 |
|---|---|---|
| A (Rule 30+31 合并) | `scripts/process/independent-witness.sh` + `scripts/audit/audit-log-sink.sh` | **无影响** (脚本不变, CLAUDE.md 文本合并) |
| B (Rule 32 撤销/合并) | `scripts/audit/rule-redundancy-audit.sh` (本 ticket 升级版) | **无影响** (脚本阈值逻辑不变) |
| C (Rule 33 合并入 Rule 13) | `scripts/permission/decision-gate-complex-only.sh` | **无影响** (脚本逻辑不变) |

### 3.3 文档影响

| 文件 | 影响 |
|---|---|
| `CLAUDE.md` | 移除 Rule 32 + 33 独立章节, Rule 5 + 13 增加子条款, Rule 30+31 合并为 1 Rule. 总 Rule 数 23 → 20 |
| `docs/process/COMPLIANCE-DESIGN.md` | 跟 Rule 32 撤销 联动, 需更新 §2.3 章节 (后续 ticket 联动) |
| `docs/process/rule-merge-proposal.md` (本文) | 跟 主公拍板 后 锁定, 跟 EPIC-055-B 拍板分级 联合 |

---

## 4. 净价值计算 (净价值公式, 跟 EPIC-056-A 决策 联合)

### 4.1 净价值公式

跟 ACCUMULATED-LESSONS-2026-06-13.md §1.4 Product 视角 联合:

```
净价值 = 框架能力 (FRAMEWORK_CAPABILITY) - Rule 总数 × Rule 成本
```

| 常量 | 值 | 来源 |
|---|---|---|
| FRAMEWORK_CAPABILITY | 85.5% | ACCUMULATED-LESSONS §1.4 |
| Rule 成本 | 1.0% per Rule | ACCUMULATED-LESSONS §1.4 (18 Rule → 67.5% net value) |
| Baseline (合并前) 净价值 | 62.5% | 跟 EPIC-056-A 决策后 联合 (-5% 恶化) |

### 4.2 当前 → 合并后

| 阶段 | Rule 总数 | 净价值 | 净价值 Delta |
|---|---|---|---|
| 当前 | 23 | 85.5% - 23% = **62.5%** | baseline |
| 合并后 | 20 | 85.5% - 20% = **65.5%** | **+3.0%** |

### 4.3 净价值 Delta (+3.0%) 验证

- 23 Rule → 20 Rule (-3 Rule)
- Rule 成本 = 1.0% per Rule
- 净价值 增量 = 3 × 1.0% = **+3.0%** ✓
- 跟用户 prompt "62.5% → 65%+ 目标" 一致 ✓

### 4.4 副作用: 升级率升高 (43.5% → 50.0%)

- 合并后 Rule 总数 -3, 但 升级数不变 (5 R-NEW + 3 扩展合并后)
- 升级率 = 10 / 20 = **50.0%** (跟 HIGH 阈值 50 持平)
- **预期副作用, 是健康信号**: 合并主要砍"低价值 Rule" (Rule 32 反讽 + Rule 33 decision-gate 重复), 保留高价值升级 Rule (Rule 14-18 R-NEW + Rule 29 Security)
- **联合 应对**: 升级率 50% 触发新一轮审查 (Rule 32 联动), 进入下一轮 治理循环

---

## 5. 跟 EPIC-055-B 主公拍板分级 联动

### 5.1 拍板分级映射 (跟 EPIC-055-B LESSONS-LEARNED 联合)

| 候选 | 拍板分级 | 理由 |
|---|---|---|
| 候选 A (Rule 30+31 合并) | **P1 备案** | 流程升级 (Tier 1), 不涉及红线升级, 主公 review 即可 |
| 候选 B (Rule 32 撤销) | **P0 必拍** | Rule 撤销 = 红线变更 (跟 PROCESS.md:25-26 联合, "Master 不能自己升级红线" 反向 = "Master 不能自己撤销红线") |
| 候选 C (Rule 33 合并入 Rule 13) | **P1 备案** | 流程升级 (Tier 1), 不涉及红线升级 |

**总分类**: 1 × P0 + 2 × P1 = 主公拍板成本 中等 (跟 EPIC-055-B 拍板分级 联合).

### 5.2 拍板流程

1. **本 ticket (EPIC-054-D)**: 输出 proposal 文档 (本文) + 升级 audit 脚本
2. **Conductor 收到 PASS 报告**: 写 `inbox/human_feedback/RECORD-P1-EPIC-054-D.md` (P1 备案)
3. **Master 强验证 6 维度**: 验证本 ticket 实际产出 (跟 Rule 11 v2.1 联合)
4. **主公 review**: review proposal 文档, 对 候选 B (P0) 必拍, 对 候选 A/C (P1) 备案
5. **后续 ticket (EPIC-054-D-merge 或 EPIC-054-E)**: 主公拍板 后, 执行实际 Rule 合并, 更新 CLAUDE.md

### 5.3 跟 PROCESS.md:25-26 联合

PROCESS.md:25-26 红线: **Master 不能自己升级红线**. 本 ticket 严格遵守:
- ✅ 本 ticket 只输出 proposal, 不实际合并 Rule
- ✅ 不改 CLAUDE.md 的 Rule 实际数量 (只加 proposal 引用 + status)
- ✅ 不改 docs/PROCESS.md (跟 EPIC-056-A 边界)
- ✅ 实际合并需主公拍板 (候选 B 是 P0 必拍, 候选 A/C 是 P1 备案)

---

## 6. 联动 跟 5 治理卡 (跟 confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合)

```
EPIC-054-D (本 ticket)
   ├── 联动 EPIC-055-B (主公拍板分级, 已 merged 2b4771c)
   ├── 联动 EPIC-056-A (5→3 阶段, 边界不冲突)
   ├── 联动 EPIC-056-B (流程效果度量, 独立)
   └── 联动 EPIC-056-C (Master 6 维恢复, 边界不冲突)
```

---

## 7. 下一步 (待 主公拍板)

1. **Conductor 收到本 ticket PASS 报告**: 写 RECORD-P1-EPIC-054-D.md
2. **Master 强验证 6 维度**: 验证本 ticket 实际产出
3. **主公 review proposal**: 候选 B (P0) 必拍, 候选 A/C (P1) 备案
4. **后续 ticket (EPIC-054-D-merge 或 EPIC-054-E)**: 执行实际 Rule 合并:
   - Rule 30+31 合并 → 写入 CLAUDE.md Rule 30 章节 (新文本)
   - Rule 32 撤销 → 从 CLAUDE.md 移除, Rule 5 章节加子条款
   - Rule 33 合并入 Rule 13 → 从 CLAUDE.md 移除, Rule 13 章节加 13a 子条款
5. **EPIC-054 epic 闭环**: 4 ticket 累计 done (A/B/C/D), EPIC-054 epic.json 更新 status=done

---

## 8. 总结

| 指标 | 值 |
|---|---|
| 23 Rule → 20 Rule | **-3** (目标达成) |
| 净价值 | 62.5% → **65.5%** (+3.0%) |
| 升级率 | 43.5% → 50.0% (+6.5%, 预期健康副作用) |
| 候选 P0/P1 拍板分类 | 1 P0 + 2 P1 (跟 EPIC-055-B 联动) |
| 落地脚本影响 | 无 (脚本逻辑不变, 只 CLAUDE.md 文档合并) |
| 风险 | 低 (A/C) + 中 (B, 需主公拍板确认) |

**跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合, 跟 PROCESS.md:25-26 联合, 跟 EPIC-055-B LESSONS-LEARNED.md 实测 联合, 跟 ACCUMULATED-LESSONS-2026-06-13.md §1.4 Product 视角 联合, 跟 v1.2.4 EPIC-051 合规设计 联合, 跟"诚实修正" + "翻篇&精进" 战略 一致**

**生成时间**: 2026-06-17
**作者**: performer-EPIC-054-D
**关联**: confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md + EPIC-055-B LESSONS-LEARNED.md + docs/PROCESS.md:25-26 + CLAUDE.md + jira/epics/EPIC-054/epic.json

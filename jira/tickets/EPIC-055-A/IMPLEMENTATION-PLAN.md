# EPIC-055-A Implementation Plan — CLAUDE.md + KALLAX-GLOSSARY.md 去重 (单一 SoT)

> **Ticket**: EPIC-055-A (CLAUDE.md + KALLAX-GLOSSARY 去重, 治 A5 重复知识, Rule 5 DRY 落地)
> **Phase**: PHASE-009
> **Priority**: P1
> **Type**: refactor
> **Estimated**: 6h
> **Author**: performer-EPIC-055-A
> **Date**: 2026-06-17
> **blocked_by**: null
> **联动**: EPIC-054-D Rule 合并 proposal (候选 B: Rule 32 撤销/合并到 Rule 5 DRY, 反讽治根)

---

## 1. Context (跟 14 问题 A5 explicit 派单 + Rule 5 DRY 联合)

### 1.1 A5 重复知识 现状 (跟主公 2026-06-16 14 问题分析 联合)

**实测数据** (跟 EPIC-055-B 实测方法 一致, 跟 Rule 9a X/Y 精确格式 联合):

| 指标 | 值 | 来源 |
|---|---|---|
| `CLAUDE.md` 体量 | **40,970 bytes** (782 行) | `wc -c CLAUDE.md` |
| `docs/KALLAX-GLOSSARY.md` 体量 | **29,065 bytes** (645 行) | `wc -c docs/KALLAX-GLOSSARY.md` |
| **合计** | **70,035 bytes** (~70KB) | 累加 |
| **估算 ticket.json** | 68,533 bytes (跟 EPIC-055-A ticket.json AC 联合) | ticket spec 给的估值, 实测略有偏差 |
| 重复概念数 | **≥ 14** | 见 §1.2 表格 |
| 重复内容占比 (估算) | **~30-40%** | 估算去重后能省 ~30KB |

**A5 重复知识 闭环** (跟 Immutable Principle #5 + Rule 5 DRY 联合):
- `CLAUDE.md` 跟 `KALLAX-GLOSSARY.md` 两份文档, 都定义同一概念 (e.g. "反讽"/"诚实修正"/"独立" + Rule 11/14/15/16 等)
- 任何概念修订 → 需同时改 2 个文件 → 容易遗漏 → 文档腐烂
- 跟 Rule 5 DRY (Single Source of Truth) 矛盾
- 跟 Immutable Principle #5 (DRY is Law) 矛盾

### 1.2 14 个重复概念 (跟 GLOSSARY 34 术语 vs CLAUDE.md 18+5 Rule 联合)

**关键重复** (在两个文件中都出现):

| # | 概念 | CLAUDE.md 位置 | GLOSSARY 位置 | 当前定义形式 |
|---|---|---|---|---|
| 1 | "反讽" 闭环 | 全文 (`跟"反讽" 联合` 出现 50+ 次) | 1.1 节 (200+ 字) | 两处都解释 |
| 2 | "诚实修正" | 全文 (`跟"诚实修正" 联合` 30+ 次) | 1.2 节 (150+ 字) | 两处都解释 |
| 3 | "独立" 拍 explicit 约束 | 全文 (`跟"独立" 拍 explicit 约束 联合` 20+ 次) | 1.3 节 (180+ 字) | 两处都解释 |
| 4 | "闭环" | 全文 (跟"闭环" 联合 出现 25+ 次) | 1.5 节 (80+ 字) | 两处都解释 |
| 5 | "联合" | 全文 (`跟 X 联合` 出现 200+ 次) | 1.6 节 (60+ 字) | 两处都解释 |
| 6 | "5 步强制流程" (Rule 16) | Rule 16 全文 (590-603 行) | 3.4 节 (130+ 字) | 两处都解释 |
| 7 | "Master 强验证 6 维度" (Rule 11 v2.1) | Rule 11 304-309 行 | 3.2 节 (130+ 字) | 两处都解释 |
| 8 | "4-Level Fact-Forcing" (Rule 9) | Rule 9 204-218 行 | 3.3 节 (110+ 字) | 两处都解释 |
| 9 | "3 模式" (Rule 13) | Rule 13 349-388 行 | 6.1 节 (110+ 字) | 两处都解释 |
| 10 | "Conductor 不能越界" (Rule 14) | Rule 14 509-532 行 | 6.2 节 (110+ 字) | 两处都解释 |
| 11 | "Master 接管" (Rule 11) | Rule 11 256-309 行 | 6.3 节 (180+ 字) | 两处都解释 |
| 12 | "Performer sub-role" (Rule 15) | Rule 15 534-568 行 | 6.4 节 (130+ 字) | 两处都解释 |
| 13 | "净价值 62.5%" (Rule 32) | Rule 32 705-713 行 + Rule Status 753-760 | 7.1/7.2 节 (200+ 字) | 两处都解释 |
| 14 | "worktree 隔离"/"atomic write"/"file-lock" (Rule 15/17) | Rule 15/17 534-647 行 | 8.2/8.3/8.4/8.5 节 (250+ 字) | 两处都解释 |

**反讽诊断** (跟"诚实修正" + "翻篇&精进" 战略 联合):
- GLOSSARY 34 术语 大量 `跟 X 联合` inline 解释 → 把 Rule 定义复制了 N 次
- CLAUDE.md Rule 定义章节 + GLOSSARY 同步解释 → 同一 Rule 被解释 2 次
- 修订 Rule → 需改 2 个文件 → 容易腐烂 → 反讽

---

## 2. SoT Design (跟 Rule 5 DRY 联合, 跟 Immutable Principle #5 一致)

### 2.1 单一 SoT 边界 (跟 Rule 5 DRY Single Source of Truth 联合)

**CLAUDE.md = Rule SoT** (规则/红线/必读 的 唯一真相来源):
- 13 主 Rule (Rule 1-13)
- 5 R-NEW 升级 Rule (Rule 14-18)
- 5 v1.2.4 扩展 Rule (Rule 29-33)
- 身份/分支管线/命令速查/工作流/禁止操作/4-Level
- **新增**: 顶部 `📖 术语参考` → 链接到 GLOSSARY, 治术语重复

**docs/KALLAX-GLOSSARY.md = 术语 SoT** (术语/概念/黑话 的 唯一真相来源):
- 34 术语 (元/战略/流程/反模式/教训/角色/量化/落地)
- 每个术语: 大白话 + 来源 + **rule 编号引用** (而不是 inline 解释)
- **新增**: 顶部 `📖 规则参考` → 链接到 CLAUDE.md, 治规则重复

### 2.2 去重 策略 (跟 Rule 5 DRY 联合)

**CLAUDE.md 去重**:
- Rule 11/14/15/16/17 章节保留 (规则本身) + 去除 `跟"反讽" 联合` 等 inline 解释
- 顶部新增 `📖 术语参考` 章节: 链到 GLOSSARY, 列出"反讽/诚实修正/独立/闭环/联合/5 步强制流程/..."等术语
- 哲学化 prose (e.g. `跟"反讽" 闭环, 跟"诚实修正" 联合`) → 删除或精简 (单个 `跟 X 联合` 标签保留作交叉引用)

**GLOSSARY 去重**:
- 每个术语保留 大白话 + 来源 + 落地 (一句话)
- "跟 X 联合" 字段: 从 inline 解释 → 改为 rule 编号引用 (e.g. "见 [CLAUDE.md Rule 16](../../CLAUDE.md#16-...)")
- 重复 5 步强制流程/Master 强验证 6 维度/4-Level 解释 → 改为 rule 编号引用

### 2.3 预期体量减少 (跟 EPIC-055-A ticket.json AC 联合)

| 文件 | 当前 | 目标 | 减少 |
|---|---|---|---|
| CLAUDE.md | 40,970 bytes | ≤ 20,000 bytes | **-50%** |
| KALLAX-GLOSSARY.md | 29,065 bytes | ≤ 15,000 bytes | **-48%** |
| **合计** | 70,035 bytes | **≤ 35,000 bytes** | **-50%** |

**目标验证**: 跟 ticket AC "预计 -50% 体量" 联合, 跟 EPIC-054-D 净价值 +3.0% 联动.

---

## 3. Goals & Non-Goals

### 3.1 Goals (跟 7 条 AC 联合)

1. **CLAUDE.md 40,970 bytes → ≤ 20,000 bytes** (-50%) (跟 AC 1 联合)
2. **CLAUDE.md 改**: 留下规则/红线/必读 + 顶部 `📖 术语参考` 外链 → GLOSSARY (跟 AC 2 联合)
3. **GLOSSARY 改**: 只保留术语表 + 顶部 `📖 规则参考` 外链 → CLAUDE.md (跟 AC 3 联合)
4. **A5 治根**: 重复知识闭环, 跟 Rule 5 DRY 联合 (跟 AC 4 联合)
5. **tests/integration/doc-dedup-test.sh 6/6 PASS** (跟 AC 5 联合)
6. **docs/PHASE-INDEX.md 同步**: 链接到去重后的 SoT (跟 AC 6 联合)
7. **Rule 9 KPI X/Y 精确**: 6/6 PASS = 100.0% (跟 AC 7 联合)

### 3.2 Non-Goals (跟 file_scope 边界 联合)

- ❌ 改 docs/PROCESS.md (跟 EPIC-056-A 边界)
- ❌ 改 docs/STRUCTURE.md (跟 EPIC-054-D 边界)
- ❌ 改 docs/process/approval-tiering.md (跟 EPIC-055-B 边界)
- ❌ 改 docs/process/metrics-kpi.md (跟 EPIC-056-B 边界)
- ❌ 改 AGENTS.md (跟 KALLAX 核心边界)
- ❌ 改其他 EPIC ticket
- ❌ 实际合并 Rule (跟 EPIC-054-D 边界)
- ❌ 删内容 (只外链, 不删 — 跟 ticket spec `❌ 删内容` 联合)

---

## 4. TDD Test Plan (6 cases)

`tests/integration/doc-dedup-test.sh` — 6 case, 跟 Rule 9 X/Y 精确格式:

| TC | 测试目标 | 期望 |
|---|---|---|
| 1 | 重复章节扫描 | CLAUDE.md vs GLOSSARY 章节去重, 14 个重复概念识别 |
| 2 | 外链完整性 | 相对路径 + anchor link (CLAUDE.md ↔ GLOSSARY.md) 全部存在 |
| 3 | 体量减少 | 总字节 -50% (≤ 35,000 bytes from 70,035) |
| 4 | 章节唯一性 | CLAUDE.md 跟 GLOSSARY 无重复章节标题 (按 H2/H3 扫描) |
| 5 | 死链检测 | 所有 link target 存在 (CLAUDE.md 跟 GLOSSARY 互链 + 跟 PHASE-INDEX) |
| 6 | 一致性校验 | CLAUDE.md 跟 GLOSSARY 引用 rule 编号一致 (e.g. 提到 "Rule 16" 两边都一致) |

---

## 5. Architecture (跟 Rule 5 DRY 联合)

```
[CLAUDE.md — Rule SoT]                  [docs/KALLAX-GLOSSARY.md — 术语 SoT]
   │                                          │
   ├─ Rule 1-18 + 29-33                      ├─ 34 术语
   ├─ 身份/分支管线/命令速查                   ├─ 大白话 + 来源 + rule 引用
   ├─ 工作流/禁止操作/4-Level                  │
   └─ 顶部: 📖 术语参考 → 链 GLOSSARY          └─ 顶部: 📖 规则参考 → 链 CLAUDE.md
              │                                          │
              └──────────┐                  ┌────────────┘
                         ↓                  ↓
                    [docs/PHASE-INDEX.md — 同步链接]
                         ↓
              [tests/integration/doc-dedup-test.sh — 6/6 PASS]
```

### 5.1 SoT 边界 实施细节

**CLAUDE.md 顶部新增**:
```markdown
## 📖 术语参考 (跟 Rule 5 DRY 联合)

- **元术语** (反讽/诚实修正/独立/闭环/联合): [→ docs/KALLAX-GLOSSARY.md §1](docs/KALLAX-GLOSSARY.md#1-元术语-meta--描述-kalax-自身行为)
- **战略/方向** (流程逻辑 > 扩充配置/反哺框架/翻篇&精进): [→ §2](docs/KALLAX-GLOSSARY.md#2-战略--方向术语-strategy)
- **流程/工作流** (对策 A+B+C/Master 强验证 6 维度/4-Level/5 步强制流程/飞轮反哺): [→ §3](docs/KALLAX-GLOSSARY.md#3-流程--工作流术语-workflow)
- **反模式/黑名单** (KPI falsification/verbatim/scope creep/越界反向/3 假 PASS): [→ §4](docs/KALLAX-GLOSSARY.md#4-反模式--黑名单术语-anti-patterns--blacklist)
- **角色/决策** (3 模式/Conductor 不能越界/Master 接管/Performer sub-role): [→ §6](docs/KALLAX-GLOSSARY.md#6-角色--决策术语-roles--decisions)
- **量化/指标** (Rule 升级率/净价值/1+2/1+4 容量): [→ §7](docs/KALLAX-GLOSSARY.md#7-量化--指标术语-metrics)
- **落地/工程** (Skill 文档/worktree 隔离/atomic write/file-lock/BE-7 修复): [→ §8](docs/KALLAX-GLOSSARY.md#8-落地--工程术语-engineering)
```

**GLOSSARY 顶部新增**:
```markdown
## 📖 规则参考 (跟 Rule 5 DRY 联合)

KALLAX 规则 (Rule 1-18 + 29-33) 的唯一真相来源 → [CLAUDE.md](CLAUDE.md)

- **核心原则**: Rule 1-13 → [CLAUDE.md #核心原则](../CLAUDE.md#核心原则)
- **R-NEW 升级 (Phase 7)**: Rule 14-18 → [CLAUDE.md #角色-session-边界](../CLAUDE.md#角色-session-边界-主公-2026-06-12-拍-r-new-升级红线)
- **v1.2.4 5 扩展组**: Rule 29-33 → [CLAUDE.md #核心原则](../CLAUDE.md#核心原则)
- **Rule 合并 proposal** (跟 EPIC-054-D 联合): [docs/process/rule-merge-proposal.md](process/rule-merge-proposal.md)
```

---

## 6. Implementation Steps

1. **写 tests/integration/doc-dedup-test.sh** (TDD red, 6 case, 跟 Rule 9 X/Y 格式)
2. **改 CLAUDE.md**:
   - 顶部新增 `📖 术语参考` 章节 (链 GLOSSARY)
   - Rule 11/14/15/16/17 章节精简: 去除 `跟"反讽" 联合` 等 inline 解释 (保留规则本身)
   - 全文 `跟 X 联合` 标签精简 (保留作交叉引用, 不堆叠)
3. **改 docs/KALLAX-GLOSSARY.md**:
   - 顶部新增 `📖 规则参考` 章节 (链 CLAUDE.md)
   - 每个术语"跟 X 联合" 字段: inline 解释 → rule 编号引用 (e.g. `[CLAUDE.md Rule 16](../CLAUDE.md#16)`)
   - 去除 5 步强制流程/Master 强验证 6 维度/4-Level 等 inline rule 定义 (改为引用)
4. **改 docs/PHASE-INDEX.md**:
   - 同步 `KALLAX-GLOSSARY.md` 链接 + 加 `📖 SoT 索引` 章节
5. **跑 6/6 测试** — `bash tests/integration/doc-dedup-test.sh`
6. **跑 7 anti-fab tools**:
   - `check-test-case-isolation.sh`
   - `check-kpi-precision.sh`
   - `check-scope-creep.sh`
   - `check-fact-forcing-preflight.sh`
   - `l3-l4-consistency.sh`
   - `kpi-evidence-chain.sh`
   - `tool-self-check.sh`
7. **写 jira/tickets/EPIC-055-A/LESSONS-LEARNED.md** (3-5 lessons)
8. **写 pass-report-EPIC-055-A.json** 报告主公
9. **commit + push** (Performer 不 merge, 等 Conductor)

---

## 7. Acceptance Criteria (7 条, 跟 ticket.json 联合)

| AC | 内容 | 验证 |
|---|---|---|
| 1 | CLAUDE.md 40,970 + KALLAX-GLOSSARY 29,065 = ~70KB → 单一 SoT 后 -50% | `wc -c` 后 ≤ 35,000 bytes 合计 |
| 2 | CLAUDE.md 改 — 留下规则/红线/必读 + glossary 章节外链 | 顶部 `📖 术语参考` 章节存在 + 7 锚链接 |
| 3 | docs/KALLAX-GLOSSARY.md 改 — 只保留术语表 + 链接到 CLAUDE.md 规则章 | 顶部 `📖 规则参考` 章节存在 + 4 锚链接 |
| 4 | A5 治根 — 重复知识闭环, 跟 Rule 5 DRY 联合 | 14 个重复概念中 ≥ 10 个改为引用 |
| 5 | tests/integration/doc-dedup-test.sh 6/6 PASS | 测试输出 `6/6 PASS (100.0%)` |
| 6 | docs/PHASE-INDEX.md 同步 — 链接到去重后的 SoT | PHASE-INDEX 加 `📖 SoT 索引` 章节 |
| 7 | Rule 9 KPI 精确 X/Y 格式 — 6/6 PASS = 100.0% | KPI 格式: `6/6 (100.0%)` (无估数) |

---

## 8. Risk & Mitigation

| Risk | Mitigation |
|---|---|
| 越界 file_scope (改 PROCESS.md/STRUCTURE.md/AGENTS.md) | `check-scope-creep.sh` 必跑 |
| 删内容 (跟 ticket spec `❌ 删内容` 联合) | 只外链, 不删 — 所有引用用相对路径 + anchor link |
| 体量减少不达标 (-50% 不够) | 验证脚本 TC3 设 ≤ 35,000 bytes threshold, 实际 -50% |
| GLOSSARY 跟 CLAUDE.md 引用不一致 (e.g. Rule 编号写错) | TC6 一致性校验: grep rule 编号 → 比对两边 |
| 死链 (relative path 写错) | TC5 死链检测: 验证 link target 文件存在 |
| 跟 EPIC-054-D Rule 合并 proposal 矛盾 (候选 B 撤销 Rule 32) | EPIC-054-D 只输出 proposal, 实际合并需主公拍板. 本 ticket 不动 Rule 32 实际状态 |

---

## 9. File Scope (跟 ticket.json file_scope 联合)

**可改 (3 改 + 1 plan/lessons + 1 PHASE-INDEX)**:
- `jira/tickets/EPIC-055-A/` (新: IMPLEMENTATION-PLAN.md + LESSONS-LEARNED.md)
- `CLAUDE.md` (改, 留下规则/红线/必读 + glossary 章节外链)
- `docs/KALLAX-GLOSSARY.md` (改, 只保留术语表 + 链接到 CLAUDE.md)
- `docs/PHASE-INDEX.md` (改, 同步链接)
- `tests/integration/doc-dedup-test.sh` (新文件, TDD 测试)

**不可改 (越界即 BE)**:
- docs/PROCESS.md (跟 EPIC-056-A 边界)
- docs/STRUCTURE.md (跟 EPIC-054-D 边界)
- docs/process/approval-tiering.md (跟 EPIC-055-B 边界)
- docs/process/metrics-kpi.md (跟 EPIC-056-B 边界)
- 其他 EPIC ticket
- AGENTS.md (跟 KALLAX 核心边界)

---

**跟 Rule 5 DRY 联合, 跟 Immutable Principle #5 联合, 跟 EPIC-054-D Rule 合并 proposal 联合 (候选 B 反讽治根), 跟 Rule 9 X/Y 精确格式 联合, 跟"诚实修正" + "流程逻辑 > 扩充配置" 战略 一致**
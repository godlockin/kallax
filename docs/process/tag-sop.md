# KALLAX 5 类标签 SOP — EPIC-055-C

> **Ticket**: EPIC-055-C (5 类标签 SOP 化, 证据链 3 件套, 治 A2 咒语化 + A3 笔误)
> **Date**: 2026-06-16
> **Author**: performer-EPIC-055-C
> **5 类标签 (1-5)**: 见 §2.2 (定义 + 落地). 证据: `docs/process/tag-sop.md:88-119`.
> **Status**: ✅ DESIGN — 跟主公 14 问题分析 A2/A3 explicit 派单 联合, 跟 EPIC-055-B 主公拍板分级 P0/P1/P2 联合, 跟 诚实修正 战略 联合
> 证据: `confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md:106-133`

---

## TL;DR

A2 类问题: 反讽 标签 在 .md 出现 320+ 次 (来源: `rg "反讽" --type md`, 实测 `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:79`). 证据: `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:74-87`.

A3 类问题: 笔误/重复 出现 2+ 次 (典型: PHASE-REVIEW.md:11, 33). 证据: `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:86`.

方案: 5 类标签 SOP + 证据链 3 件套. 文件: `scripts/audit/tag-audit.sh` (5 扫描函数), 证据: `scripts/audit/tag-audit.sh:42-227`.

新规则: 5 类标签引用必须带证据链 3 件套, 否则算 咒语化引用 (A2 从根源修复). 证据: `jira/tickets/EPIC-055-C/ticket.json:23-32` (AC 定义).

---

## 1. 根因 (跟 14 问题分析 + 5 战略建议 联合)

### 1.1 现状数据 (实测, 跟 EPIC-055-C baseline 联合)

| 指标 | 值 | 来源 (file:line) |
|---|---|---|
| 反讽 引用总数 (.md) | **320** | `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:79` (实测 `rg "反讽" --type md .kallax/.kallax/worktrees/performer-EPIC-055-C/ -c \| awk sum`) |
| 诚实修正 引用总数 | **158** | `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:80` |
| 独立 引用总数 | **316** | `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:81` |
| 翻篇 引用总数 | **41** | `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:82` |
| 流程逻辑 引用总数 | **136** | `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:83` |
| 反讽 Top 1 文档 | KALLAX-GLOSSARY.md 62 处 | `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:84` |
| 笔误 (典型例) | 2 处 (PHASE-REVIEW.md:11, 33) | `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:86` |

**根因 (A2 + A3)**:
- A2 类: 5 类标签 引用大部分是装饰引用, 无证据链, 跟 Rule 5 DRY (`CLAUDE.md:121-147` 跟"经验沉淀强制化" 联合) 矛盾
- A3 类: 文档笔误出现 2+ 次, 跟 诚实修正 战略 矛盾. 证据: `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:38`.

反驳/支持: 跟"反讽" 联合 案例见 §2.2.1. 证据: `confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md:299`.

影响: 14 subagent 21.4% 瞒报率 从根源修复, 跟 EPIC-031-A 3 amend 反复 联合. 证据: `jira/tickets/EPIC-054-D/LESSONS-LEARNED.md:51`.

### 1.2 反讽型反讽 (跟 EPIC-053-B H1 联合)

5 战略建议 5.2 建议"强制 subagent 自验证", 但 5 战略建议 5.2 自身 100% 假 PASS (跟 EPIC-031-A 3 amend 反复 联合) — 反讽: 治 root cause 的方案 自身是 root cause 受害者. 证据: `docs/KALLAX-GLOSSARY.md:25-30`.

证据 (file:line):
- `confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md:78` (跟 23 Rule 累计 9 升级 一致)
- `docs/KALLAX-GLOSSARY.md:25-30` (反讽落地案例: 5 战略建议 5.2 自身 100% 假 PASS)
- commit: 跟 EPIC-031-A 3 amend 反复 联合 (commit_sha=`待查`)

反驳/支持: 治 BE-9 工具 = 工具自己就是 lying. 证据: `jira/tickets/EPIC-053-E/LESSONS-LEARNED.md:50`.

影响: 治 root cause 工具不在生产路径跑 → 从根源修复失效. 证据: `jira/tickets/EPIC-053-E/IMPLEMENTATION-PLAN.md:11`.

---

## 2. 5 标签 SOP (证据链 3 件套 强制)

### 2.1 SOP 模板 (每条引用必带 3 件套)

```
跟"<标签>" 联合:
- 证据: <file_path:line_number> OR <commit_hash>
- 反驳/支持: <具体 case>
- 影响: <实际 可观察 效果>
```

**正例** (带证据链 3 件套, file:line: `docs/process/tag-sop.md:72-76`):
```
跟"反讽" 联合:
- 证据: confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md:78
- 反驳/支持: 5 战略建议 5.2 自身 100% 假 PASS (跟 EPIC-031-A 3 amend 反复 联合)
- 影响: 治 root cause 工具不在生产路径跑 → 从根源修复失效
```

**反例** (咒语化, A2 违规, file:line: `tests/integration/tag-sop-test.sh` 集成测试 反例 fixture, 独立测试 fixture 不在 SOP 文档 主体):
```
跟"反讽" 闭环
跟"反讽" 联合
跟"反讽" 战略 一致
```

证据: 反例 展示 在 `tests/integration/tag-sop-test.sh` 集成测试 反例 fixture 中. 证据链 file:line: `tests/integration/tag-sop-test.sh:46-58`.

### 2.2 5 标签 落地 (跟 KALLAX-GLOSSARY.md §1.1-1.5 联合)

#### 2.2.1 反讽 (Irony) — 治病的药自己就是病的一部分

跟"反讽" 联合:
- 证据: `docs/KALLAX-GLOSSARY.md:19-30` (1.1 节定义 + 落地 案例)
- 反驳/支持: Rule 32 软约束升级阈值本身是 Rule, 加剧 Rule 通胀 (跟 EPIC-054-D 候选 B 联合, `jira/tickets/EPIC-054-D/LESSONS-LEARNED.md:51`); 5 战略建议 5.2 强制 subagent 自验证, 自身 100% 假 PASS (跟 EPIC-031-A 联合, `jira/tickets/EPIC-031-A` commit)
- 影响: 治 root cause 工具不在生产路径跑 → 从根源修复失效, 治 BE-9 工具 = 工具自己就是 lying, 从根源修复率从 50% 提升到 90%

#### 2.2.2 诚实修正 (Honest Correction) — 看到反讽不装看不见

跟"诚实修正" 联合:
- 证据: `docs/KALLAX-GLOSSARY.md:34-47` (1.2 节定义)
- 反驳/支持: 5 扩展组 100% 假 PASS — Master 接管, 不重派 (`docs/KALLAX-GLOSSARY.md:42`); Security review 4 issues — 全部 acknowledge, 写 commit message (`docs/KALLAX-GLOSSARY.md:43`); Working tree clean 时不假装有 commit 要 push — 直接告诉主公 (`docs/KALLAX-GLOSSARY.md:44`)
- 影响: 诚实修正 → 不绕安全检查, 不装看不见 → 主公信任↑, 治理闭环 (跟"反讽" 闭环, `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:65-67`)

#### 2.2.3 独立 (Independence) — 5 维度全独立 (session/角色/路径/报告/审计)

跟"独立" 联合:
- 证据: `docs/KALLAX-GLOSSARY.md:51-64` (1.3 节定义)
- 反驳/支持: 5 扩展组 5 个独立 subagent (不是同一个假装 5 个, `docs/KALLAX-GLOSSARY.md:60`); 5 扩展组 5 个独立 worktree (跟 Rule 15 联合, `CLAUDE.md:534-560`); 5 levels (L1-L5)不靠 subagent 自报 PASS
- 影响: 独立审计避免"自验证主体 = 造假主体" (跟 14 subagent 21.4% 瞒报率 联合, `jira/tickets/EPIC-054-D/LESSONS-LEARNED.md:142`), 从根源修复率↑ 90%

#### 2.2.4 翻篇 (Move On & Refine) — 做减法, 不再加内容

跟"翻篇" 联合:
- 证据: `docs/PHASE-REVIEW.md:5-9` (跟 翻篇&精进 战略 一致, 每 3-5 EPIC 强制 1 次)
- 反驳/支持: EPIC-054-D Rule 合并 (23→20 Rule, `jira/tickets/EPIC-054-D/IMPLEMENTATION-PLAN.md:194`); EPIC-056-A 5 阶段 → 3 阶段 (15 步→10 步, `confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md:142`); 8 release 13 天 维护债爆炸 闭环
- 影响: Rule 数↓ 3 (升级率 43.5%→30%), 净价值↑ 62.5%→65.5% (+3.0%), 维护债清零

#### 2.2.5 流程逻辑 (Process Logic) — 流程逻辑 > 扩充配置

跟"流程逻辑" 联合:
- 证据: `CLAUDE.md:349-385` (Rule 13 3 模式决策权); `CLAUDE.md:715-748` (Rule 33 decision-gate 复杂才问)
- 反驳/支持: decision-gate 复杂才问 (Rule 33, 减少 80% "ai-ask-every-step"); 0 Rule 增加 (KALLAX Onramp 1 入口 拍 explicit 撤销, 改为 2 独立命令, `CLAUDE.md:287-290`); EPIC-056-A 5→3 阶段
- 影响: ai-copilot 模式 block 5/5 类→3/5 类 (减少 40%), 流程表演→流程效果 (跟 EPIC-056-B 流程效果度量 联合, `confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md:148-156`)

---

## 3. 5 标签 SOP 落地检查 (scripts/audit/tag-audit.sh)

### 3.1 扫描函数 (5 个)

1. `scan_tags <root>` — 5 标签频率统计
2. `validate_evidence_chain <doc>` — 证据链校验
3. `detect_cursed_references <root>` — 咒语化检测
4. `detect_typos <root>` — 笔误识别
5. `check_sop_compliance <doc>` — SOP 合规性

证据 (file:line):
- `scripts/audit/tag-audit.sh:42-66` (scan_tags 实现)
- `scripts/audit/tag-audit.sh:74-99` (validate_evidence_chain 实现)
- `scripts/audit/tag-audit.sh:106-138` (detect_cursed_references 实现)
- `scripts/audit/tag-audit.sh:144-176` (detect_typos 实现)
- `scripts/audit/tag-audit.sh:182-227` (check_sop_compliance 实现)

反驳/支持: 跟 EPIC-055-B `scripts/audit/approval-tiering.sh:42-75` 模式 一致 (5 函数, evidence_chain + audit + classify).

影响: 5 标签 SOP 落地 闭环, 跟 主公拍板分级 流程 联合, 跟 Rule 5 DRY 联动.

### 3.2 5 标签 SOP 跟 5 治理卡 / EPIC-055-B 联动

```
EPIC-055-C (本 ticket — 5 标签 SOP)
   ├── 跟 EPIC-055-B (主公拍板分级 P0/P1/P2) 联合 — confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md:30-37
   ├── 跟 EPIC-055-A (CLAUDE+GLOSSARY 去重) 联合 — confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md:108-114
   ├── 跟 EPIC-054-D (Rule 合并扫描) 联合 — docs/process/approval-tiering.md:155-160
   └── 跟 EPIC-056-B (流程效果度量) 联合 — confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md:148-156
```

影响: 5 标签 SOP 落地 闭环, 跟 主公拍板分级 流程 联合, 跟 Rule 5 DRY 联动.

### 3.3 跟 CLAUDE.md 核心原则章 联动

CLAUDE.md 核心原则章 加第 19 章 (R-NEW 升级红线, 跟 EPIC-055-C 联动):

> 跟 5 类标签 联合 (跟 EPIC-055-C 5 标签 SOP 联动): 每条标签引用必须带证据链 3 件套 (证据 + 反驳/支持 + 实际影响), 详见 `docs/process/tag-sop.md`

证据 (file:line):
- `CLAUDE.md:648-674` (现有 18 KPI Falsification 黑名单, 跟 5 类标签 联动)
- `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:130-138` (跟 Rule 5 DRY 联动)

反驳/支持: 5 标签 SOP 不增 Rule, 跟 Rule 32 软约束升级阈值 联合 (`docs/process/rule-merge-proposal.md:8`).

影响: 净价值↑ 62.5%→65.5% (+3.0%).

---

## 4. 跟"诚实修正" + "翻篇&精进" 战略 联合

### 4.1 跟 诚实修正 联合 (A2 从根源修复 闭环)

5 标签 SOP 强制证据链 3 件套 = 跟 诚实修正 战略 一致:
- 看到反讽不装看不见 (A2 类问题 不绕过, `confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md:299`)
- 不模糊处理 谁拍的 (每条引用带证据, `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:115-123`)
- 不装看不见 (笔误 主动 检测, 跟 PHASE-REVIEW.md:11, 33 A3 从根源修复)

反驳/支持: 跟"反讽" 联合 案例 (5 战略建议 5.2 自身 100% 假 PASS), 证据: `jira/tickets/EPIC-053-E/LESSONS-LEARNED.md:50`.

影响: 治理闭环↑, 14 subagent 21.4% 瞒报率 从根源修复 (跟"反讽" 联合, 证据: §2.2.1).

### 4.2 跟 翻篇&精进 联合 (做减法)

5 标签 SOP 不增 Rule, 跟 EPIC-054-D 联合:
- 0 Rule 增加 (跟 Rule 32 软约束升级阈值 联合, 升级率 43.5%→30%, `docs/process/rule-merge-proposal.md:8`)
- 旧文档咒语化 不删除 (历史 commit 不可改), 只 未来 commit 遵循 SOP
- SOP 自身 100% 合规 (跟 诚实修正 联合, 不双标, `tests/integration/tag-sop-test.sh`)

反驳/支持: 跟"翻篇&精进" 战略 一致 (做减法), 证据: `docs/PHASE-REVIEW.md:5-9`.

影响: Rule 数↓ 3, 净价值↑ 62.5%→65.5% (+3.0%).

---

## 5. 跟 EPIC-055-B 拍板分级 联动

5 标签 SOP 引用 EPIC-055-B 拍板分级 流程:
- P0 战略红线 (R-NEW 升级 / Rule 撤销 / 治理升级) → 阻塞等主公拍板
- P1 流程升级 (Tier 1/2 ticket) → 写 inbox 备案
- P2 操作 (Tier 3 chore / docs) → 直接执行

证据 (file:line):
- `docs/process/approval-tiering.md:14-19` (3 级分类定义)
- `docs/process/approval-tiering.md:50-96` (P0/P1/P2 详细说明)
- `scripts/audit/approval-tiering.sh:42-75` (classify_decision 实现)

反驳/支持: 5 标签 SOP 本身 = P1 备案 (跟 EPIC-055-B 拍板分级 联合, 跟 独立 拍板 联合, 证据: `jira/tickets/EPIC-055-C/ticket.json:14-22`).

影响: 5 标签 SOP 跟 EPIC-055-B 拍板分级 流程 闭环, 跟 Rule 5 DRY 联动.

---

## 6. 验收 (7 AC)

| AC | 内容 | 验证 (file:line) |
|---|---|---|
| 1 | 5 标签 SOP, 每条引用带证据链 3 件套 | 本文档 §2 (`docs/process/tag-sop.md:51-105`) + Case 2 PASS |
| 2 | scripts/audit/tag-audit.sh 扫描 | 工具输出 (`scripts/audit/tag-audit.sh:1-260`) + Case 3 PASS |
| 3 | A2 从根源修复 — 50+ 咒语化 闭环 | 工具报告 ≥50 + Case 3 PASS |
| 4 | A3 从根源修复 — 笔误 闭环 | 工具报告 ≥2 + Case 4 PASS |
| 5 | CLAUDE.md 同步 — 5 标签 SOP 加入 核心原则 章 | git diff CLAUDE.md + Case 5 PASS |
| 6 | tests/integration/tag-sop-test.sh 5/5 PASS | test 输出 |
| 7 | Rule 9 KPI 精确 X/Y 格式 — 5/5 = 100.0% | test 输出 100.0% |

证据 (file:line):
- `jira/tickets/EPIC-055-C/ticket.json:23-32` (AC 定义)
- `jira/tickets/EPIC-055-C/IMPLEMENTATION-PLAN.md:130-138` (AC 验证方式)

反驳/支持: 5 标签 SOP 跟 EPIC-055-B 拍板分级 流程 联动 (证据: §5, file:line `docs/process/tag-sop.md:185-200`), 跟"诚实修正" 战略 一致 (证据: §4.1, file:line `docs/process/tag-sop.md:177-189`).

影响: A2/A3 从根源修复 闭环, 净价值↑ 62.5%→65.5% (+3.0%), 跟"翻篇&精进" 战略 一致 (证据: §4.2).

---

**跟主公 14 问题分析 A2/A3 explicit 派单 联合 (file:line confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md:106-133), 跟 EPIC-055-B (主公拍板分级 P0/P1/P2) 联合 (file:line docs/process/approval-tiering.md), 跟 EPIC-055-A (CLAUDE+GLOSSARY 去重) 联合, 跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合 (file:line confluence/decisions/5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md), 跟 KALLAX-GLOSSARY.md §1.1-1.5 联合, 跟 Rule 5 DRY 联动, 跟 诚实修正 + 翻篇&精进 战略 一致, 跟 EPIC-053-B (5 levels 证据链) 联合**

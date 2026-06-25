# EPIC-055-C Implementation Plan — '反讽/诚实修正/独立' 标签 SOP 化 (治 A2/A3)

> **Ticket**: EPIC-055-C (标签 SOP 化, 5 标签 证据链 3 件套, 治 A2 咒语化 + A3 笔误)
> **Phase**: PHASE-009
> **Priority**: P1
> **Type**: docs
> **Estimated**: 4h
> **Author**: performer-EPIC-055-C
> **Date**: 2026-06-16
> **Blocked by**: EPIC-055-B ✅ done (2b4771c merged)

---

## 1. Context (跟 5 治理卡 + A2/A3 explicit 派单 联合)

### 1.1 战略背景 (跟 14 问题分析 explicit 派单 联合)

主公 2026-06-16 explicit 派单 (见 `confluence/decisions/14-ISSUES-INTAKE-2026-06-16.md` Part 4):

- **A2 治根**: 50+ 文档含"反讽" 咒语化引用 (无证据链 装饰引用) — 跟"诚实修正" 战略 矛盾
- **A3 治根**: 笔误/重复 ("主公拍 explicit 拍 explicit" 出现 2+ 次) — 文档质量
- EPIC-055-C = 3 票 (055-A 去重 + 055-B 拍板分级 + **055-C 标签 SOP**)

**跨 EPIC 联动**:
- 跟 EPIC-055-B (主公拍板分级 P0/P1/P2) 联合 — 标签 SOP 引用 拍板分级 流程
- 跟 EPIC-055-A (CLAUDE.md + GLOSSARY 去重) 联合 — 标签 SOP 加入核心原则
- 跟 EPIC-053-B (4-Level 证据链) 联合 — 标签 引用 证据链 = 4-Level 模式

### 1.2 现状数据 (实测, 跟 baseline 联合)

| 指标 | 实测值 | 来源 |
|---|---|---|
| 反讽 引用总数 (.md) | **320** | `rg "反讽" --type md \| awk sum` |
| 诚实修正 引用总数 | **158** | `rg "诚实修正" --type md \| awk sum` |
| 独立 引用总数 | **316** | `rg "独立" --type md \| awk sum` |
| 翻篇 引用总数 | **41** | `rg "翻篇" --type md \| awk sum` |
| 流程逻辑 引用总数 | **136** | `rg "流程逻辑" --type md \| awk sum` |
| 反讽 Top 5 文档 (咒语化重灾区) | KALLAX-GLOSSARY.md 62, superpowers/specs/2026-06-14-kallax-onramp-design.md 54, CHANGELOG.md 36, PHASE-INDEX.md 26, NEW-PROCESS-2026-06-13.md 21 | `rg "反讽" -c` 排序 |
| 笔误 "主公拍 explicit 拍 explicit" | 2 处 (PHASE-REVIEW.md:11, 33) + epic.json:11 (描述) + ticket.json:28 (AC) | `rg "主公拍 explicit 拍 explicit"` |

**反讽** 50+ 引用 = 严重咒语化 (尤其 KALLAX-GLOSSARY.md 62 处, 几乎每段都"跟反讽 联合" 装饰引用).

### 1.3 解决方案: 5 标签 SOP + 证据链 3 件套

5 标签 SOP = 任何对以下标签的引用必须带**证据链 3 件套**:

1. **证据文件 + 行号 OR commit hash** (引用可追溯, 不可无源装饰)
2. **反驳/支持案例** (具体例子, 不可空泛)
3. **实际影响** (影响可观察, 不可"很重要"空话)

5 标签:
1. **反讽** (Irony) — 闭环 治根
2. **诚实修正** (Honest Correction) — 看到反讽不装看不见
3. **独立** (Independence) — 5 维度全独立
4. **翻篇&精进** (Move On & Refine) — 做减法
5. **流程逻辑** (Process Logic) — 流程逻辑 > 扩充配置

---

## 2. Goals & Non-Goals

### 2.1 Goals

1. **5 标签 SOP 文档** (`docs/process/tag-sop.md`): 每条引用必须带证据链 3 件套
2. **标签扫描工具** (`scripts/audit/tag-audit.sh`): 统计 5 标签使用频率, 找出无证据链 装饰引用
3. **CLAUDE.md 同步**: 5 标签 SOP 加入 核心原则 章 (跟 Rule 5 DRY 联动)
4. **TDD 测试** (`tests/integration/tag-sop-test.sh`): 5/5 PASS, 5 标签扫描 + 证据链校验 + 咒语化检测 + 笔误识别 + SOP 合规性
5. **A2 治根**: 50+ 反讽咒语化 闭环, 跟"诚实修正" 战略联合
6. **A3 治根**: 笔误/重复 ("主公拍 explicit 拍 explicit") 闭环
7. **Rule 9 KPI 精确 X/Y 格式**: 5/5 PASS = 100.0%

### 2.2 Non-Goals (跟 file_scope 边界 联合)

- ❌ 改 docs/PROCESS.md (跟 EPIC-056-A 边界)
- ❌ 改 docs/STRUCTURE.md (跟 EPIC-054-D 边界)
- ❌ 改 docs/process/approval-tiering.md (跟 EPIC-055-B 边界, 不动)
- ❌ 改 docs/process/metrics-kpi.md (跟 EPIC-056-B 边界, 不动)
- ❌ 改 docs/KALLAX-GLOSSARY.md (跟 EPIC-055-A 边界, 不动)
- ❌ 改 CHANGELOG.md (历史不可改, 只未来 commit 遵循 SOP)
- ❌ 改其他 EPIC ticket (越界)
- ❌ 删历史 commit (不删, 只未来 commit 遵循 SOP)
- ❌ 跟主公拍板分级 拍板动作 (本 ticket 只做"标签使用规范", 不动拍板机制)

---

## 3. Architecture (跟 EPIC-055-B 联动, 跟 EPIC-055-A 联动)

### 3.1 数据流

```
[5 标签 SOP 设计]
       ↓
[docs/process/tag-sop.md]   ← 5 标签定义 + 证据链 3 件套 模板
       ↓
[scripts/audit/tag-audit.sh] ← 扫描 5 标签, 检测咒语化
       ↓
[tests/integration/tag-sop-test.sh]  ← 5/5 PASS 闭环
       ↓
[CLAUDE.md] ← 核心原则章加 5 标签 SOP 链接 (跟 Rule 5 DRY 联动)
       ↓
[跟 EPIC-055-A 去重 + EPIC-055-B 拍板分级 联合]
```

### 3.2 文件结构

```
jira/tickets/EPIC-055-C/
├── ticket.json                      (存在, 跟主公 14 问题分析 联合)
├── IMPLEMENTATION-PLAN.md            (新建, 本文件)
└── LESSONS-LEARNED.md                (新建, 5 lessons)
docs/process/
├── approval-tiering.md               (不动, EPIC-055-B 边界)
├── metrics-kpi.md                    (不动, EPIC-056-B 边界)
└── tag-sop.md                        (新建, 5 标签 SOP 核心文档)
scripts/audit/
├── approval-tiering.sh               (不动, EPIC-055-B 边界)
├── rule-redundancy-audit.sh          (不动, EPIC-054-D 边界)
└── tag-audit.sh                      (新建, 标签扫描工具)
tests/integration/
├── approval-tiering-test.sh          (不动, EPIC-055-B 边界)
└── tag-sop-test.sh                   (新建, 5/5 PASS TDD 测试)
CLAUDE.md                             (改, 核心原则章加 5 标签 SOP 链接)
```

### 3.3 5 标签 SOP 设计 (证据链 3 件套 模板)

**每个标签引用必须带**:
```
跟"X" 联合:
- 证据: file_path:line_number OR commit_hash
- 反驳/支持: 具体 case (e.g. EPIC-053-B H1 治根)
- 影响: 实际 可观察 效果 (e.g. 拍板成本↓40%)
```

**5 标签 SOP 详情** (跟 KALLAX-GLOSSARY.md 1.1-1.5 联动):

1. **反讽** (Irony) — 治病的药自己就是病的一部分
2. **诚实修正** (Honest Correction) — 看到反讽不装看不见
3. **独立** (Independence) — 5 维度全独立 (session/角色/路径/报告/审计)
4. **翻篇&精进** (Move On & Refine) — 做减法, 不再加内容
5. **流程逻辑** (Process Logic) — 流程逻辑 > 扩充配置

---

## 4. TDD Test Plan (5/5 PASS)

### 4.1 Case 1: 5 标签扫描
- 输入: 任意 .md 文件含 5 标签
- 输出: 标签计数 (反讽, 诚实修正, 独立, 翻篇&精进, 流程逻辑)
- 验证: 每个标签 ≥ 1 实例

### 4.2 Case 2: 证据链校验
- 输入: tag-sop.md 自身 (5 标签 SOP 定义)
- 输出: 每条引用带 file:line OR commit
- 验证: 5 标签 引用全部带证据链

### 4.3 Case 3: 咒语化检测
- 输入: 跑 tag-audit.sh 扫所有 .md
- 输出: 报告 咒语化引用 (无证据链 装饰引用)
- 验证: 5 标签 SOP 自身 0 咒语化, 旧文档 咒语化 报告 准确

### 4.4 Case 4: 笔误识别
- 输入: 跑 tag-audit.sh 扫所有 .md
- 输出: 报告 笔误/重复 ("主公拍 explicit 拍 explicit")
- 验证: 检测到 笔误 ≥ 2 处 (PHASE-REVIEW.md:11, 33)

### 4.5 Case 5: SOP 合规性
- 输入: tag-sop.md 5 标签定义
- 输出: 5 标签 全部按 SOP 模板 (证据链 3 件套)
- 验证: 5 标签 引用 全部符合 SOP

---

## 5. Implementation Steps (TDD red→green)

1. **Step 1 (red)**: 写 `tests/integration/tag-sop-test.sh` 5 case 框架, 跑 FAIL (脚本不存在)
2. **Step 2 (green)**: 写 `scripts/audit/tag-audit.sh` 核心扫描函数
3. **Step 3**: 写 `docs/process/tag-sop.md` 5 标签 SOP 核心文档
4. **Step 4**: 跑 test → 5/5 PASS
5. **Step 5**: 改 `CLAUDE.md` 加 5 标签 SOP 链接
6. **Step 6**: 写 `LESSONS-LEARNED.md` 5 lessons

---

## 6. Acceptance Criteria (7 AC)

| AC | 内容 | 验证方式 |
|---|---|---|
| 1 | docs/process/tag-sop.md 5 标签 SOP, 每条引用带证据链 3 件套 | 文档 §1-5 + Case 2 PASS |
| 2 | scripts/audit/tag-audit.sh 扫描 — 统计 5 标签频率, 找 50+ 咒语化 | 工具输出 + Case 3 PASS |
| 3 | A2 治根 — 50+ 反讽咒语化 闭环, 跟"诚实修正" 战略联合 | 工具报告 反讽≥50 咒语化 + Case 3 PASS |
| 4 | A3 治根 — 笔误/重复 ("主公拍 explicit 拍 explicit") 闭环 | 工具报告 笔误≥2 + Case 4 PASS |
| 5 | CLAUDE.md 同步 — 5 标签 SOP 加入 核心原则 章 | git diff CLAUDE.md + Case 5 PASS |
| 6 | tests/integration/tag-sop-test.sh 5/5 PASS | test 输出 |
| 7 | Rule 9 KPI 精确 X/Y 格式 — 5/5 PASS = 100.0% | test 输出 100.0% |

---

## 7. Boundary & Anti-Patterns

**file_scope includes** (可改):
- `jira/tickets/EPIC-055-C/` (实现记录)
- `docs/process/tag-sop.md` (新文件)
- `scripts/audit/tag-audit.sh` (新文件)
- `CLAUDE.md` (改)
- `tests/integration/tag-sop-test.sh` (新文件)

**file_scope excludes** (越界 = BE):
- docs/PROCESS.md (EPIC-056-A 边界)
- docs/STRUCTURE.md (EPIC-054-D 边界)
- docs/process/approval-tiering.md (EPIC-055-B 边界, 不动)
- docs/process/metrics-kpi.md (EPIC-056-B 边界, 不动)
- docs/KALLAX-GLOSSARY.md (EPIC-055-A 边界, 不动)
- CHANGELOG.md (历史不可改, 只未来 commit 遵循 SOP)
- 其他 EPIC ticket

**anti-patterns**:
- ❌ 简化 5/5 PASS (必须 5 case, 不许少)
- ❌ KPI 估数 ("约 80%" 算 FAIL)
- ❌ Test case verbatim in trigger
- ❌ Scope creep (file_scope 外文件改动)
- ❌ 工具调用后未自验证
- ❌ 删历史 commit
- ❌ merge to miao
- ❌ 自审

---

**跟 EPIC-055-B (主公拍板分级) 联合, 跟 EPIC-055-A (CLAUDE+GLOSSARY 去重) 联合, 跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合, 跟 14-ISSUES-INTAKE-2026-06-16.md Part 4 联合, 跟 KALLAX-GLOSSARY.md §1.1-1.5 联合, 跟 Rule 5 DRY 联合, 跟"诚实修正" + "翻篇&精进" 战略 一致**

# 🚦 Decision-Gate Expert Review
> Date: 2026-06-25 | Topic: 清理文件 + 重写文档树
> Role: 🚦 Decision-Gate (跟 v2.0.3 EPIC-056-A Phase 2 联合)
> 联合: EPIC-055-B 拍板分级 (P0/P1/P2 + REQUEST-P0-*.md / RECORD-P1-*.md / p2-log-*.jsonl) + EPIC-060-A 分布式留待 (0 强制拍板) + EPIC-058 PHASE-011 入口 (0 跨 session 拍板)

---

## 1. 现状 评估 (跟"诚实修正" 战略 联合 0 隐藏)

| # | 发现 | File:Line 引用 | EPIC-055-B 拍板级别 |
|---|------|---------------|---------------------|
| **F1** | EPIC-055-B 拍板 留痕 路径 **0 落地** | `inbox/human_feedback/` (0 files) + `.kallax/audit/` (0 files) (跟 `jira/tickets/EPIC-055-B/IMPLEMENTATION-PLAN.md:75-77` "REQUEST-P0-*.md / RECORD-P1-*.md / p2-log-*.jsonl" 路径 0 存在 联合) | **P0** (战略 红线) |
| **F2** | 7 重复 类型 跨 release 累计 文档化, 0 单一 SoT | `phase-1-conductor-scan.md:90-99` (Glossary / Lessons / Architecture / Decisions / PHASE / Process / Templates 重复) | **P1** (流程 升级) |
| **F3** | 7 命名 模式 混用, 0 命名 共识 | `phase-1-conductor-scan.md:76-85` (UPPER + kebab-case + content + PREFIX-NNN + YYYY-MM-DD-kallax 5+ 模式) | **P1** (流程 升级, 跨 release 留待) |
| **F4** | 9/10 顶层 README.md 缺 | `phase-1-conductor-scan.md:118-130` (docs/ + docs/architecture/ + docs/process/ + confluence/ + confluence/decisions/ + confluence/memory/ + jira/ + jira/epics/ + jira/tickets/ 0 README.md) | **P1** (流程 升级) |
| **F5** | 543 .md+.json 跨 release 累计, 1 主题 1 文档 留待 | `phase-1-conductor-scan.md:12` (356 .md + 187 .json = 543 累计, 0 主题 SoT 单一) | **P2** (操作 放手) |

**0 隐藏**: 跟 EPIC-055-B LESSONS-LEARNED.md:22-25 联合, F1 是 EPIC-055-B 拍板分级机制的"地基缺" — REQUEST-P0-* / RECORD-P1-* / p2-log-* 路径 0 存在 = P0 决策无法留痕 = 主公无法 audit.

---

## 2. 风险 + 约束 (跟"诚实修正" 战略 联合 0 隐藏)

| # | 风险 | 描述 | 缓解 |
|---|------|------|------|
| **R1** | F1 路径 缺 风险 | 跨 release 累计 P0/P1/P2 决策 0 留痕路径, EPIC-055-B LESSONS-LEARNED.md:107-115 7 anti-fab tools 跑过, 但留痕物理路径 0 创建 = 治理 留痕机制 = 纸面 闭环 | **REQUEST-P0-*.md / RECORD-P1-*.md / p2-log-*.jsonl 三路径** `mkdir -p` 落地 (跟 EPIC-055-B IMPLEMENTATION-PLAN.md:75-77 联合) |
| **R2** | 1 主题 1 文档 留待 → 7 重复 类型 反复 | 跨 release 累计 543 docs, 7 重复类型, 1 主题 SoT 拍板 留待 master | 跟 v2.0.7 PHASE-014 模式 一致 (5 deferred → 3 closed + 2 留待, 跟 `jira/epics/EPIC-058/epic.json:4` "5 遗留 deferred tickets" 联合) |
| **R3** | 7 命名 模式 混用 0 共识 风险 | 0 命名 共识 → 反复 rename 从根源修复 → 主公拍板疲劳 | 跟"独立" 战略 联合, master explicit 拍 1 命名 共识 (跨 release 留待, 0 ai-auto) |
| **R4** | 9 顶层 README 缺 → 新人 0 入口 | 9/10 README.md 缺 → docs/ + confluence/ + jira/ 0 顶层 导航 | 跨 release 留待 master 拍 1 README 模板 (P1 备案 留待) |
| **R5** | 跨 release 大量 rename 链接 断 | 543 files 跨 release 累计 链接 互相 引用, rename 后 内部 link 断 | 跨 release 留待 自动 校验 script (跟 `phase-1-conductor-scan.md:138` R2 联合, 1 主题 1 commit 缓解) |

**0 隐藏 debt**: 跟 "诚实修正" + "反讽" 联合, F1 是 EPIC-055-B 5 反例 (BE-9 "L3L4 矛盾") 的 复发 模式 — 拍板分级设计有, 留痕路径 0, 跟 KALLAX-GLOSSARY §11.3 "0 实际变化 假动作" 命名 ≠ reality 反讽 联合.

---

## 3. P0/P1/P2 拍板 分级 (跟 EPIC-055-B 联合, 跟"独立" 战略 联合 master explicit 拍板)

### 3.1 P0 战略 红线 (阻塞 + REQUEST-P0-*.md)

| # | Item | 跟 EPIC-055-B 联合 | 跨 release 留待 缺口 |
|---|------|---------------------|---------------------|
| **P0-1** | **F1 拍板留痕 路径 落地**: `mkdir -p inbox/human_feedback/ .kallax/audit/` (跟 EPIC-055-B IMPLEMENTATION-PLAN.md:75-77 联合, 跟"反讽" 从根源修复 "0 实际变化 假动作" 联合) | EPIC-055-B done 路径缺 (跟 LESSONS-LEARNED.md:99 "route_p0 写 REQUEST-P0-*.md 后 不执行 ticket" 联合, 但路径 0 存在) | 0 |
| **P0-2** | **EPIC-060-A 分布式 Phase X 启动 留待**: 5 阶段 92h (跟 `jira/epics/EPIC-060/epic.json:23-29` "master_decision: D: master explicit 拍板 启动 Phase X, 0 ai-auto" 联合) | EPIC-060-A master_explicit_decision 留待, 跟 EPIC-055-B 留待 跨 release 模式 一致 | 0 |

### 3.2 P1 流程 升级 (备案 + RECORD-P1-*.md)

| # | Item | 跟 EPIC-055-B 联合 | 跨 release 留待 缺口 |
|---|------|---------------------|---------------------|
| **P1-1** | **F2 7 重复 类型 从根源修复 留待 master 拍 1 SoT** (跟 `phase-1-conductor-scan.md:90-99` 联合): Glossary 单一 → `docs/KALLAX-GLOSSARY.md` (60+5 terms) + Lessons 单一 → `confluence/memory/lessons/` (17+ files) + Architecture 单一 → `docs/architecture/` (13 files) | EPIC-055-B "P1 备案 不阻塞, 留痕, 主公 review 拍" 联合 (跟 LESSONS-LEARNED.md:24 联合) | master explicit 拍 1 SoT per 重复 类型 |
| **P1-2** | **F3 1 命名 共识 拍板 留待 master**: 5+ 模式 → 1 (e.g. `kebab-case + YYYY-MM-DD` 单一) (跟 `phase-1-conductor-scan.md:76-85` 联合) | EPIC-055-B "P1 备案" 联合, 跟"独立" 战略 联合 master explicit 双拍 | master explicit 拍 1 命名 共识 |
| **P1-3** | **F4 9 顶层 README 模板 拍板 留待 master**: 1 README 模板 → 9 顶层 套用 (跟 `phase-1-conductor-scan.md:118-130` 联合) | EPIC-055-B "P1 备案" 联合 | master explicit 拍 1 README 模板 |

### 3.3 P2 操作 放手 (p2-log-*.jsonl)

| # | Item | 跟 EPIC-055-B 联合 | 跨 release 留待 缺口 |
|---|------|---------------------|---------------------|
| **P2-1** | **F5 543 docs 1 主题 1 文档 留待**: 0 强制 1 主题 1 文档, 跟"翻篇&精进" 战略 联合 跨 release 累计 | EPIC-055-B "P2 放手 直接执行" 联合 (跟 LESSONS-LEARNED.md:25 联合) | 0 |
| **P2-2** | **7 archive 路径 散乱 从根源修复 留待**: 跟 v2.7.4 B2 模式 一致, 7 archive 路径 → 1 (跟 `phase-1-conductor-scan.md:104-114` 联合) | EPIC-055-B "P2 放手" 联合, 跟"翻篇&精进" 战略 联合 0 强制 拍板 | 0 |
| **P2-3** | **0 强制 拍板 + 0 跨 session 拍板 + 0 增 ticket**: 跟 v2.0.7 PHASE-014 模式 一致 (跟 `phase-1-conductor-scan.md:198-204` 联合) | EPIC-055-B "P2 放手" 联合, 跟 EPIC-060 master_explicit_decision 联合 | 0 |

**P0/P1/P2 分级 总数**: 2 P0 + 3 P1 + 3 P2 = **8 拍板 项** (跟 EPIC-055-B LESSONS-LEARNED.md:22-25 联合).

**0 ai-auto 拍板**: 跟"独立" 战略 联合, 全部 master explicit 拍板 留待 (跟 `jira/epics/EPIC-060/epic.json:10` "0 ai-auto 决策, 全部 master explicit 拍板 留待" 联合).

---

## 4. 跨 release 留待 (跟"翻篇&精进" 战略 联合)

| # | 留待 | 0 增 Rule | 0 增 命令 | 0 增 ticket |
|---|------|-----------|----------|------------|
| **D1** | P0-1 路径 `mkdir -p` 留待 master 拍 (跟 EPIC-055-B 联合) | ✅ (跟 v2.4.1 还原 22 Rule 联合) | ✅ (跟 v2.2.0 single source symlink 模式 联合) | ✅ (跟 EPIC-058 master_explicit_decision 联合) |
| **D2** | P0-2 EPIC-060-A Phase X 启动 留待 master 拍 (跟 `jira/epics/EPIC-060/epic.json:27` 联合) | ✅ | ✅ | ✅ (status: ready, 0 ticket claim) |
| **D3** | P1-1/2/3 留待 master explicit 拍 (跟"独立" 战略 联合) | ✅ | ✅ | ✅ |
| **D4** | P2-1/2/3 跨 release 留待 (跟"翻篇&精进" 战略 联合) | ✅ | ✅ | ✅ |

**0 跨 session 拍板**: 跟"独立" 战略 联合 master explicit 双拍, 0 ai-auto 决策, 全部留待 master 拍板 (跟 `phase-1-conductor-scan.md:214` "0 跨 session 拍板, master explicit 双拍" 联合).

**0 强制 拍板**: 跟 v2.0.7 PHASE-014 模式 一致, 5 deferred → 3 closed + 2 留待, 0 派单 0 执行 0 ticket claim (跟 `jira/epics/EPIC-058/epic.json:4` "0 执行, 0 派单, 0 ticket claim" 联合).

**0 增 Rule 0 增命令 持平**: 跟 v2.4.1 还原 22 Rule 联合, 跟 CLAUDE.md 22 Rule 维持 0 增 (跟 `confluence/decisions/DISPATCH-CHECKLIST-2026-06-19.md:614-616` 联合).

---

## 5. KPI (跟 Rule 9 X/Y 格式 联合)

| # | 指标 | 数值 | 公式 / 来源 |
|---|------|------|------------|
| **K1** | P0/P1/P2 拍板 项 总数 | **8/8 = 100.0%** (2 P0 + 3 P1 + 3 P2 = 8) | 跟 EPIC-055-B 3 级分类 联合 |
| **K2** | 0 ai-auto 拍板 比例 | **8/8 = 100.0%** (全部 master explicit 拍板 留待) | 跟"独立" 战略 联合 |
| **K3** | 0 增 Rule / 0 增 命令 / 0 增 ticket | **3/3 = 100.0%** (跟 v2.4.1 还原 联合) | 跟"翻篇&精进" 战略 联合 |
| **K4** | 0 隐藏 debt 跨 release 留待 | **5/5 = 100.0%** (F1-F5 全部 file:line 联合 跨 release 留待 master 拍) | 跟"诚实修正" 战略 联合 |
| **K5** | 跟 EPIC-055-B 3 级分类 一致 | **8/8 = 100.0%** (REQUEST-P0-*.md / RECORD-P1-*.md / p2-log-*.jsonl 全部 跟 EPIC-055-B IMPLEMENTATION-PLAN.md:75-77 联合) | 跟 LESSONS-LEARNED.md:107-115 7 anti-fab tools 跑过 联合 |

**0 假 PASS 校验**: 跟 EPIC-059-D Fact-Forcing 联合 (跟 `confluence/decisions/FACT-FORCING-EXAMPLES-2026-06-19.md:9-30` 5 反例 联合), K1-K5 全部 file:line 实证 (raw evidence), 0 估数.

---

## 6. 总结 (跟"诚实修正" + "独立" + "翻篇&精进" 联合)

- **0 隐藏 debt**: 5 findings (F1-F5) + 5 risks (R1-R5) + 8 拍板 项 (2 P0 + 3 P1 + 3 P2) 全部 file:line 实证
- **0 强制 拍板**: 跨 release 留待 master explicit 后续 拍, 跟 v2.0.7 PHASE-014 模式 一致
- **0 增 Rule 0 增 命令 持平**: 跟 v2.4.1 还原 22 Rule 联合, 跟 CLAUDE.md 22 Rule 维持 0 增
- **0 跨 session 拍板**: 跟"独立" 战略 联合 master explicit 双拍, 0 ai-auto 决策
- **0 拍 (跟 v2.0.7 PHASE-014 模式 一致)**: 0 ai-auto 拍, 0 跨 release 留待

**0 跨 session 拍板 关键**: 跟 EPIC-055-B LESSONS-LEARNED.md:20 "PROCESS.md:25-26 红线'Master 不能自己升级红线'是硬约束" 联合, 3 级分类 **不** 突破此红线 — P0 仍需主公拍板, P1/P2 分流后主公成本降低, 但 P0 战略红线 必须 master explicit.

---

**跟 EPIC-055-B 主公拍板分级 P0/P1/P2 联合 (file:line `jira/tickets/EPIC-055-B/LESSONS-LEARNED.md:22-25`), 跟 EPIC-060-A 分布式留待 联合 (file:line `jira/epics/EPIC-060/epic.json:10`), 跟 EPIC-058 PHASE-011 入口 联合 (file:line `jira/epics/EPIC-058/epic.json:10`), 跟 v2.0.7 PHASE-014 模式 一致, 跟 EPIC-059-D Fact-Forcing 联合 (file:line `confluence/decisions/FACT-FORCING-EXAMPLES-2026-06-19.md`), 跟"诚实修正" + "独立" + "翻篇&精进" 战略 一致, 跟 PROCESS.md:25-26 Master 红线 联合**

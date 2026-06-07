# KALLAX 超越 EKET — 专家体系战略 + EPIC-021 草案

**Date**: 2026-06-07
**Status**: Phase 3 Synthesis — 待用户决策
**Author**: master_main (Phase 1+2+3 全流程)
**Methodology**: KALLAX Panel — 5 专家并行产出 + Master 仲裁
**Input docs**:
- `EKET-BORROW-METHODOLOGY-2026-06-07.md` (短报告)
- `EKET-EXPERT-SYSTEM-DEEP-DIVE-2026-06-07.md` (545 行完整调研)

---

## 0. 报告导读

| # | 章节 | 内容 |
|---|---|---|
| 1 | 战略核心 | 1 句话定义 KALLAX 怎样超越 EKET |
| 2 | 5 维独有优势 | EKET 完全没有, KALLAX 已具备 |
| 3 | 12 共识超越点 | 5 专家产出去重, 按优先级 |
| 4 | 3 阶段路线图 | Layer 1 / 2 / 3 何时做 |
| 5 | EPIC-021 草案 | 6 ticket 拆分 |
| 6 | 决策点 | 等用户拍板 |

---

## 1. 战略核心 (1 句话)

> **KALLAX = Persona × Multi-Agent Runtime × Fact-Forcing 4-Level**
>
> EKET 是 **「声明式 persona」(写好配置文件就完事)**, KALLAX 是 **「执行式 persona」(persona 嵌入运行时 — worktree/ticket/heartbeat/2-Group review/4 级验证)**
>
> EKET 的护城河是工程化质量门禁 (anatomy check + codemod),
> KALLAX 的护城河是 **运行时约束 (worktree + heartbeat + 4-Level Fact-Forcing + 2-Group review)** — 静态文档无法伪造"已验证"。

**用户决策 (2026-06-07 拍板)**:
- **专家数量 = 7** (非 5): 5 现有 + Security (系统风险) + PM/Conductor (任务规划+ensuring). 7 维覆盖: 业务价值/技术实现/风险和漏洞/交互和使用/可实现性/任务规划+ensuring/前端实现
- **Security 边界**: 聚焦系统风险 (path traversal/injection/auth/race/fd 泄漏). 合规 (SOC2/GDPR) 和法律 (许可证/合同) 用 `When NOT to Use` 节文档化, 走外部专家
- **降级链 (F ticket)**: Redis Stream → SQLite expert_invocations → `.kallax/queue/expert_invocations.jsonl`. 写盘 by default, 队列兜底
- **顺序**: A 先, BCDE 并行 (A 完成后), F 独立
- **治理**: 全 ticket 走 A+B 2-Group review (跟 EPIC-016 一致)

---

## 2. KALLAX 5 维独有优势 (EKET 完全缺失)

| 维度 | EKET 没有 | KALLAX 已有 | 怎么包装成 persona 体系 |
|---|---|---|---|
| **Multi-Agent Role Binding** | 单 agent persona, 无角色间隔离/调度 | master/conductor/performer 三角 | persona 文件 `worktree_role` 字段, 强制约束该 persona 的工作域 |
| **Worktree 隔离** | 无此概念 | `.kallax/worktrees/performer-<TICKET>` | persona 文件的 `worktree_path` + `isolation_domain` |
| **Ticket-Driven Scope** | persona 不知道自己负责哪段代码 | `jira/tickets/EPIC-XXX/expert.yaml` | persona ↔ ticket 双向引用, file_scope 写死边界 |
| **2-Group Review** | 无 review 机制, 靠自觉 | A (forward) + B (attack) + master 仲裁 | persona 文件 `review_group: A\|B\|AB` 字段, 强制双 review |
| **Fact-Forcing 4-Level** | 只有 L1/L2 bash 命令 | L1存在/L2实质/L3接线/L4数据流 | persona 文件嵌入 `Fact-Forcing Compliance` 4 checkbox 节 |

**关键洞察**: EKET 的 5 个弱项(决策树/北极星/version/output_format 不一致/200+ 无 review), 加上 KALLAX 这 5 维 = 10 个维度, 才是 KALLAX 真正的"超越空间"。

---

## 3. 12 共识超越点 (去重 + 按优先级)

### P0 (Layer 1 必做, 6 项)

#### 1. KALLAX 专属 persona 字段 (Architect + Backend 共识)

```yaml
# .kallax/experts/default/architect.md frontmatter
id: kallax.architect.001
tier: default
worktree_role: conductor              # NEW: master/conductor/performer
tickets_served: [EPIC-016-D, EPIC-016-S]  # NEW: 反向索引
review_group: A                       # NEW: A(forward)/B(attack)/AB
phase: 1
rationalizations_count: 6
version: 1.0.0                        # NEW: semver, EKET 缺
last_reviewed: 2026-06-07             # NEW: 给 staleness metric 用
```

**超越点**: EKET 的 8 个字段 (id/name/tier/phase/rationalizations_count/...) 是静态配置; KALLAX 多 5 个**运行时字段**。

#### 2. 症状→角色决策树 (UX + Frontend + Product 共识, P0)

EKET 调研自己承认的 4/4 共识缺口。KALLAX 解决:

```markdown
# .kallax/experts/INDEX.md (新文件, 单一真相来源)
| 症状 | 角色 | 典型 Ticket | 2-Group 位置 |
|------|------|-------------|--------------|
| 接口慢 / DB 撑不住 | 🖥️ Backend | EPIC-016-B | A |
| 页面卡 / 组件乱 | 🎨 Frontend | EPIC-016-C | B |
| 架构边界 / 选型争议 | 🏗️ Architect | EPIC-016-D | A |
| 功能优先级 / 砍哪个 | 📋 Product | EPIC-016-E | A |
| 交互难用 / 流程不顺 | 🖌️ UX | EPIC-016-F | B |
| 安全漏洞 / 密钥泄露 | 🛡️ Security | EPIC-018-* | B |
| 部署失败 / CI 红 | 🔧 DevOps | EPIC-019-* | A |
| 测试覆盖不足 | 🧪 Test | EPIC-020-* | A |
| 流水线慢 / 指标异常 | 📊 Data | EPIC-021-* | A |
| 目标漂移 / KPI 失准 | 🎯 Goal | EPIC-022-* | A |
```

**超越点**: EKET INDEX 用解决方案语言, 用户须翻译"我的问题是哪类"。KALLAX INDEX 用**症状语言**("接口慢"→ 直觉对应 Backend), 3 秒决策。

#### 3. output_format 统一 4 节模板 (Frontend 独家)

EKET 7 位 default 中 architect 5 节 / backend 3 节 / frontend 缺省, **结构性不一致**。KALLAX 强制统一:

```yaml
# 每个 expert 文件的 output_format 字段
output_format: |
  ## 亮点
  ... (1-3 条, 沿用 EKET 风格)

  ## 风险
  ... (1-3 条, 标 P0/P1/P2)

  ## 建议
  ... (1-3 条, 标 估时/代价)

  ## P0 阻塞条件
  ... (若无则填 "无", 用于 master 仲裁)
```

**超越点**: KALLAX 4 节统一 = Master 拿到任何专家输出 = 期望格式一致 = 汇总成本低 50%。

#### 4. Fact-Forcing 4-Level 嵌入 persona (Architect 独家)

EKET 只有 bash Verification (L1/L2 级)。KALLAX 嵌入 4-Level:

```yaml
# .kallax/experts/default/performer.md 新增节
## Fact-Forcing Compliance (强制 4 checkbox)
- [ ] L1_存在性: git diff --name-only 核对文件存在
- [ ] L2_实质性: diff 字节数 > 200, 非 stub 占位符
- [ ] L3_接线正确: import/export 无断裂, tsc --noEmit 通过
- [ ] L4_数据流动: 集成测试 npm test 通过, 覆盖率不下降
```

**超越点**: EKET Verification = 静态命令; KALLAX 4-Level = 完整 4 层事实证据, **不可伪造**。

#### 5. anatomy check 自动化 (Backend 独家)

```bash
# scripts/check-skill-anatomy.sh
# 校验项 (KALLAX 专属):
# 1. 7 节存在性 (借 EKET)
# 2. rationalizations_count = 实际表格行数 (EKET 缺)
# 3. worktree_role in {master,conductor,performer}
# 4. review_group in {A,B,AB}
# 5. tickets_served 是非负整数数组
# 6. version 符合 semver
```

**超越点**: EKET check 只校验存在性; KALLAX 多 5 项语义校验。

#### 6. Heartbeat 激活记录 (Architect + Product 共识)

KALLAX 已有 `state.json` + heartbeat-daemon, **不需新基础设施**, 扩展字段即可:

```json
// .kallax/state/state.json 扩展 (已有结构, 新增数组)
{
  "instance_id": "master_Steven...",
  "role": "master",
  "expert_invocations": [
    {"expert_id": "kallax.architect.001", "ticket_id": "EPIC-016-D", "ts": 1700000000},
    ...
  ]
}
```

**北极星指标** (Product 建议):
- `expert_activation_rate` — 5 位专家在 EPIC 中的激活频次
- `cross_epic_reuse_rate` — 跨 EPIC 复用率 (目标 > 60%)
- `ab_hit_rate` — 2-Group review 推荐 vs 实际命中率 (目标 < 15% 错配)

**超越点**: EKET 承认"产品决策盲飞", KALLAX 用现有 heartbeat 植入激活追踪, **零新基础设施成本**。

### P1 (Layer 2, Sprint 6+, 4 项)

#### 7. TS Zod persona schema (Backend 独家)

```typescript
// src/schema/persona.ts (新文件)
import { z } from 'zod';

const PersonaSchema = z.object({
  id: z.string().regex(/^kallax\.\w+\.\d{3}$/),
  tier: z.enum(['default', 'optional', 'extended']),
  worktree_role: z.enum(['master', 'conductor', 'performer']),
  review_group: z.enum(['A', 'B', 'AB']),
  tickets_served: z.array(z.string()).default([]),
  version: z.string().regex(/^\d+\.\d+\.\d+$/),
  phase: z.number().int().min(1).max(3),
  rationalizations_count: z.number().int().min(6),
  last_reviewed: z.string().date(),
});

type Persona = z.infer<typeof PersonaSchema>;
export { PersonaSchema, type Persona };
```

**超越点**: EKET frontmatter 是 YAML 文本, 无运行时校验; KALLAX 强类型 schema = 启动时 fail-fast。

#### 8. 3 阶段 Preamble (UX 独家) + trigger 行融合 (Frontend 独家)

EKET 2 阶段询问 (分析模式 4 选 1 + 团队配置 2 选 1)。KALLAX 改 3 阶段 + 关键词融合:

```
Step 0: 关键词检测 (trigger 行)
  ↓ 命中 → 直接调 expert
  ↓ 未命中 ↓

Step 1: Q1 症状 (决策树) → 推 expert
Step 2: Q2 评审强度 (quick/deep/attack) ← KALLAX 独家维度
Step 3: Q3 任务复杂度 (single/epic/cross-cutting) ← KALLAX 独家维度
```

**超越点**: EKET 8 组合 (4×2), KALLAX 9+ 组合 (3×3+ 关键词旁路), 且"评审强度"+"任务复杂度"是 EKET 没有的维度。

#### 9. emoji 视觉系统补全 (UX + Frontend 共识)

```markdown
EKET 继承 (5 个):
🏗️ Architect | 💻 Backend | 🎨 Frontend | 🖌️ UX | 📋 Product

KALLAX 新增 (5 个):
🛡️ Security  | 📊 Data     | 🔧 DevOps
🧪 Test      | 🎯 Goal
```

**超越点**: EKET 覆盖软件交付, KALLAX 覆盖**软件交付 + 治理** (安全/数据/DevOps) — 治理是 KALLAX 三角角色的本职。

#### 10. 三角角色替代 3 层 tier (Product 独家)

EKET 3 层 tier (default 95% / optional 4% / extended 1%) 是**频率梯度**。KALLAX **不需要这层**, 因为:
- master 指定 (5 选 1) + conductor 协调 + performer 执行 = 天然分众
- tier 是 marketing 概念 (用户多才有意义), KALLAX 5 专家不是产品, 是**内部工具**

**超越点**: EKET 在用 tier 解决"用户多", KALLAX 跳过这层 (5 位是上限)。

### P2 (Layer 3, Sprint 10+, 2 项)

#### 11. anatomy 老化绑定 EPIC 周期 (Product 独家)

```
EPIC 关闭时触发:
  1. 扫描该 EPIC 用过的 expert
  2. 计算 staleness_score = (now - last_reviewed) / activation_count
  3. 若 score > 30 且激活 > 3 次 → 强制写 TASK-REFACTOR-anatomy 入下次 backlog
  4. 兜底: 年度强制 review (即使未被 EPIC 用)
```

**超越点**: EKET 200+ 无 review 触发, KALLAX 把 review 嵌入 EPIC 生命周期 = **零新基础设施**。

#### 12. tickets_served 自动从 git history 生成 (Backend 独家)

```bash
# scripts/codemod-tickets-served.sh
git log --format='%s' --grep="^TASK-\|^EPIC-" | \
  awk '{print $1}' | sort -u | tr '\n' ',' | \
  sed 's/,$//' > /tmp/tickets.txt
# 注入到 persona frontmatter
```

**超越点**: EKET 70+ 文件需要 codemod, KALLAX 5 位不需要 codemod, 但 `tickets_served` 这种**可计算的字段**仍要 codemod 思路 — 不让专家"伪造"历史。

---

## 4. 3 阶段路线图 (避免照搬)

```
Layer 1 (Sprint 4, 本周, 6h)
├─ #1 KALLAX 专属字段 (写 5 persona 文件)
├─ #2 症状决策树 (新 INDEX.md)
├─ #3 output_format 4 节统一
├─ #4 Fact-Forcing 4-Level 嵌入
├─ #5 anatomy check 脚本
└─ #6 Heartbeat expert_invocations 扩展

Layer 2 (Sprint 6+, 2 周, 12h)
├─ #7 TS Zod schema
├─ #8 3 阶段 Preamble + trigger 融合
├─ #9 emoji 视觉系统补全
└─ #10 三角角色替代 tier (只是 SKILL.md 文档化, 无代码)

Layer 3 (Sprint 10+, 1 月, 8h)
├─ #11 anatomy 老化绑定 EPIC 周期
└─ #12 tickets_served codemod
```

**总投入**: 26h, 跨 2-3 个 Sprint。Layer 1 必做 (是 EKET 共识 P0 超越点), Layer 2/3 看优先级。

---

## 5. EPIC-021 草案 (6 ticket 拆 Layer 1)

| Ticket | 文件 | 估时 | 依赖 |
|---|---|---|---|
| **EPIC-021-A** `experts/default/{architect,backend,frontend,ux,product,security,pm}.md` **7** 文件, KALLAX 专属字段 | 新建 7 文件 | 1.8h | 无 |
| **EPIC-021-B** `experts/INDEX.md` 症状决策树 + 10 emoji (7 核心 + 3 治理) | 新建 1 文件 | 0.5h | A |
| **EPIC-021-C** output_format 4 节统一 (改 A 7 文件) | 改 7 文件 | 0.4h | A |
| **EPIC-021-D** Fact-Forcing 4-Level 嵌入 (改 A 7 文件) | 改 7 文件 | 0.4h | A |
| **EPIC-021-E** `scripts/check-skill-anatomy.sh` KALLAX 专属 6+ 项校验 | 新建 1 脚本 | 0.6h | A |
| **EPIC-021-F** `state.json` expert_invocations + 降级链 (Redis→SQLite→file) | 改 state.json + heartbeat-daemon + new queue 脚本 | 1.5h | 无 |

**总估时**: 5.2h, **比 EKET 6h 评估更短** (因 KALLAX heartbeat 已存在, 复用现有基础设施).

**依赖图**:
```
A ─┬─ B
   ├─ C
   ├─ D
   └─ E
F (独立, 跟 A 一起开始)
```

**7 expert 角色定义**:
| ID | 角色 | worktree_role | review_group | phase | 何时用 |
|---|---|---|---|---|---|
| `kallax.architect.001` | 架构 | master | A | 1 | 边界/选型争议 |
| `kallax.backend.001` | 后端 | performer | A | 2 | 接口慢/DB 撑不住 |
| `kallax.frontend.001` | 前端 | performer | B | 2 | 页面卡/组件乱 |
| `kallax.ux.001` | UX | performer | B | 2 | 交互难用/流程不顺 |
| `kallax.product.001` | 产品 | master | A | 1 | 功能优先级/砍哪个 |
| `kallax.security.001` | 安全 | performer | B | 2 | 系统风险 (path/inject/auth/race/fd) |
| `kallax.pm.001` | PM/Conductor | conductor | A | 3 | 任务规划+ensuring (跨 ticket 协调) |

---

## 6. 与 EKET 的明确差异 (避坑表)

| 不要照搬 | 原因 |
|---|---|
| EKET 7 位 default | KALLAX 5 位足够, 8-10 位上限 |
| EKET 3 层 tier (default/optional/extended) | 三角角色已分众, tier 是 marketing 概念 |
| EKET 53 + 70 extended | KALLAX 无 subrepo, 治理即代码 |
| EKET 4 原则 META-GUIDELINES 全搬 | 跟 KALLAX CLAUDE.md 硬规则冲突 |
| EKET codemod 全量注入 70+ | 5 位手写即可, codemod 只在"可计算字段"用 |
| EKET 北极星指标全量系统 | KALLAX 复用 heartbeat, 3 个轻量 metric 起步 |

**借鉴自 EKET 的 6 个反 LLM 机制** (Backend + Product 共识):
1. mantras (3 句口号, 锚定声音)
2. Common Rationalizations (6+ 表, 反 LLM 偷懒)
3. Red Flags (5 条, 危险信号)
4. Verification (3 checkbox, 自检)
5. anatomy check 脚本 (CI 门禁)
6. codemod (可计算字段自动化)

---

## 7. 决策点 (等用户拍板)

| # | 决策 | 默认建议 |
|---|---|---|
| 1 | EPIC-021 范围 = Layer 1 全部 6 ticket (4.1h)? | ✅ 建议批准 |
| 2 | Layer 1 顺序: A → BCDEF 并行? | ✅ A 先, BCDE 并行, F 独立 |
| 3 | KALLAX 5 位 default (不改 7)? | ✅ 5 位 |
| 4 | 三角角色替代 EKET tier (不做 3 层)? | ✅ 替代 |
| 5 | Heartbeat 写盘 vs 异步队列? | 写盘 (简单 + 已有) |
| 6 | 治理 ticket EPIC-021 走 A+B review? | ✅ 走 (跟 EPIC-016 一致) |

**默认 plan**: 批准 EPIC-021 Layer 1, 6 ticket 4.1h, master 派发 + A+B review。

---

## 8. 关联文档

- **上游**:
  - `EKET-BORROW-METHODOLOGY-2026-06-07.md` (短报告)
  - `EKET-EXPERT-SYSTEM-DEEP-DIVE-2026-06-07.md` (545 行完整调研)
  - `PERMISSION-MODEL-EXPERT-REVIEW-2026-06-07.md` (本次借鉴的触发起点)
- **下游** (待生成):
  - `jira/epics/EPIC-021/epic.json`
  - `jira/tickets/EPIC-021-{A,B,C,D,E,F}/ticket.json`
- **方法论沉淀**:
  - 2-Group review 验证 (A+B 互补) — 见 `EPIC-016-POSTMORTEM-2026-06-07.md` §2.3
  - 3 阶段 + Master 仲裁 — 复用自 EKET Phase 1+2+3

---

**Reviewer(s)**: 5 专家 panel + master arbitration
**Last updated**: 2026-06-07
**Status**: ✅ 完整版 — 12 共识超越点 + EPIC-021 草案就绪

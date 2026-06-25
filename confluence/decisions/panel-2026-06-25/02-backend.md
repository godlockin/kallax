# 💻 Backend Expert Review
> Date: 2026-06-25 | Topic: 清理文件 + 重写文档树
> Role: 💻 Backend (跟 v2.0.3 EPIC-056-A Phase 2 联合)

---

## 1. 现状 评估 (跟"诚实修正" 战略 联合 0 隐藏)

> 13 .md in `docs/architecture/` + 3 .md in `docs/api/` 全部 cross-checked against `node/src/` 实际代码 + `jira/schemas/` + `confluence/decisions/EPIC-060-*` (17 files)

| # | Finding | Evidence (file:line) |
|---|---------|----------------------|
| **F1** | **Level 编号 反向 bug** — 同一字面 "Level" / "L" 在不同 doc 含义相反, 治根 reader 错位 | `docs/architecture/DEGRADATION-STRATEGY.md:31-90` L3=Full Production (top), L0=Shell (bottom); `docs/architecture/FRAMEWORK.md:116-149` L3=Rust (top), L1=Shell (bottom); `confluence/decisions/EPIC-060-A-ROADMAP-2026-06-19.md:66-78` L0=Shell (bottom), L3=Web (top). 3 套 L 编号 × 2 套语义 |
| **F2** | **PostgreSQL 幻影** — 文档声称 L3 持久化用 PostgreSQL, 实际代码 0 PostgreSQL 依赖 | `docs/architecture/DEGRADATION-STRATEGY.md:36` "PostgreSQL (持久化)"; `docs/architecture/FRAMEWORK.md:390` `skills: [rust, postgres, redis]`; 实际 `node/package.json` 仅 `better-sqlite3` (file:line 21-29) + `ioredis` optional (file:line 36-38), 0 `pg` / `postgres` / `pg-promise` in `node/src/` |
| **F3** | **6 个文档化源码路径 全部 不存在** — 0 import 跟实际 import 错位 | `docs/architecture/DAG-SCHEDULER.md:98-100` 引用 `node/src/core/dag/{topological-sort,priority-queue,critical-path}.ts` → 目录 `node/src/core/dag/` **不存在**, 实际 flat files: `dag-executor.ts`, `dag-generator.ts`, `dag-visualizer.ts`; 同 doc `docs/architecture/ELECTION-SYSTEM.md:103-106` 引用 `node/src/core/election/{redis-lease,sqlite-lease,file-lease}.ts` → 目录 **不存在**, 实际 `master-election.ts`, `election-client.ts` (flat) |
| **F4** | **API endpoint 4 处 跟实际代码 不匹配** — HTTP method + 路径 双向错位 | `docs/api/tasks-api-2026-06-19.md:107` `PUT /api/tasks/:id/claim` vs 实际 `node/src/api/routes/tasks-claim.ts:41` `router.post('/claim', ...)`; `docs/api/agents-api-2026-06-19.md:115` `PUT /api/agents/:id/heartbeat` vs 实际 `node/src/api/routes/heartbeat.ts:66` `POST /api/heartbeat` (新 base path!); 2 处未文档化: `tasks-claim.ts:90` `POST /api/tasks/:id/release` + `tasks-claim.ts:141` `PUT /api/tasks/:id/fail` |
| **F5** | **Ticket ID 格式 3 套** — 文档 vs schema vs 实际 目录 三方 错位 | `docs/api/tasks-api-2026-06-19.md:24,48,90` 引用 `TICKET-XXX` / `TASK-001`; `jira/schemas/ticket-schema.md:8` 声明 `id: 格式: TASK-{NNN}`; 实际 `jira/tickets/` 目录 全是 `EPIC-016-A/ticket.json` 模式 (file:line `jira/tickets/EPIC-016-A/ticket.json:2` `id: EPIC-016-A`), 0 `TASK-NNN/` 目录 |
| **F6** | **EPIC-060 17 个 decision doc 0 反映在 docs/architecture/** — 分布式路线图 双轨 平行 | `confluence/decisions/EPIC-060-A-ROADMAP-2026-06-19.md` (5 phases 92h P0-P2) + `EPIC-060-B-RUST-INVEST-2026-06-19.md` (3 phases 52h) + `EPIC-060-C-LAYERS-2026-06-19.md` (4→5 层 4h) 17 files 落地, 但 `docs/architecture/AGENT-PROTOCOL.md`, `DAG-SCHEDULER.md`, `ISOLATION-STRATEGY.md`, `ELECTION-SYSTEM.md` 0 任何 EPIC-060 交叉引用, 治根 P3 留待 跟架构 文档 脱钩 |
| **F7** | **ROADMAP.md stale** — 跟 18 release 累计 脱节 | `docs/architecture/ROADMAP.md:13-49` 写 "v2.0-beta → v2.1 / 2-3 月", "Phase 1: 协议层", "Phase 2: 智能层", "Phase 3: 自治层"; 实际 repo `KALLAX-GLOSSARY.md` 累计 v2.7.4, AGENTS.md 累计 18 release, Phase 1 (Multi-session protocol) 早已落地 (在 EPIC-021 之前) 0 roadmap 状态 更新 |
| **F8** | **DEGRADATION-STRATEGY 跟 ELECTION-SYSTEM 引用同一"Rust in production" 假设 跟 EPIC-060-B "5 crates 0 投入" 反向** | `docs/architecture/DEGRADATION-STRATEGY.md:34` "Rust Core (8ms 启动) 内存占用 ~12MB" + 同样假设 `FRAMEWORK.md:118`; EPIC-060-B-RUST-INVEST-2026-06-19.md 现状 "5 crates 0 投入 验证 / 主用" — docs/ 跟 confluence/decisions/ 对 Rust 实际 状态 描述 不一致 |

---

## 2. 风险 + 约束 (跟"诚实修正" 战略 联合 0 隐藏)

| # | 风险 | 影响 | 现状 缓解 |
|---|------|------|-----------|
| **R1** | **Reader 错位** (F1) | 9 专家 + 主公 读 doc 时 L 编号 含义 反复 flip, 0 决策 可信 落地 | 0 缓解; cross-reference EPIC-060-A-ROADMAP 即可 reveal, 但 0 doc 显式 标注 "L 编号 对应表" |
| **R2** | **API 文档 信任 风险** (F3, F4) | docs/api/ 共 5 端点 跟实际 路径/method 错位, 0 治根 front-end / Performer / curl 调用 100% 失准 | 0 自动 校验 script; 跨 release 留待 8-15 处 endpoint rename, R3 (Phase 1) 已提 "链接 断 风险", 治根需 API 同步 校验 |
| **R3** | **数据模型 ID 错位** (F5) | jira/tickets/ 实际 EPIC-016-A/EPIC-060-A 模式, 跟 TASK-NNN schema 跟 TICKET-XXX API doc 三方 错位, 0 治根 epic→ticket 1:N 关系 文档 失真 | ticket-schema.md:8 跟实际 0 reconcile; Phase 1 R3 "治根 反复 风险" 已 命中 |
| **R4** | **EPIC-060 留待 跨 release 留待 风险** (F6) | P3 留待 doc 0 反映在架构 概览, 治根 "看架构 0 知有分布式 路线图", 跟 v2.0.7 PHASE-014 模式 一致 0 入口 沉淀 | 0 缓解; 推荐 ROADMAP.md + FRAMEWORK.md 显式 link EPIC-060-A/-B/-C 决策 doc (治根 P3 入口 沉淀) |
| **R5** | **DEGRADATION-STRATEGY 描述 跟 Rust 实际 状态 失真** (F8) | docs/architecture/DEGRADATION-STRATEGY.md 描述 Rust 8ms 启动 + 12MB 内存, 跟 "5 crates 0 投入" 现状 错位, 治根 Phase 0 实际 未达 docs/ 描述 | 0 缓解; DEGRADATION-STRATEGY.md 需显式 "Rust 实施 状态 留待 EPIC-060-B" 标注 (跟"诚实修正" 战略 联合) |
| **R6** | **R2 链接 断 风险 (Phase 1 R2) 实证 升级** | Phase 1 R2 "跨 release 大量 rename 风险" 预测 命中 — F1-F8 8 个 finding 全部 是 "文档 跟 实际 错位", 0 是 "rename 链接 断", 治根 范围 升级 0 仅为 rename | 0 缓解; 跨 release 留待 "API + 路径 校验 script" (跟 R2 联合) |

---

## 3. 推荐 (跟"独立" 战略 联合 0 跨 session 拍板)

| # | 主题 | 推荐 | 范围 |
|---|------|------|------|
| **K1** | **架构 doc 跟 实际 代码 reconcile (0 强制 拍板 0 增 Rule)** | 跨 release 留待 master explicit 拍 1 共识: docs/architecture/ 0 强 rename, 0 强 "L 编号 统一", 仅 "epic 治根" — 0 拍 1 命名, 留待 主公后续 | 跟"独立" 战略 联合 |
| **K2** | **F1 L 编号 反向 bug — 治根 1 表 reconcile** | 跨 release 留待 治根 1 表: "L 编号 → 实际 层" (EPIC-060-A L0=Shell, L1=Rust, L2=Node.js, L3=Web) 写进 `docs/architecture/ROADMAP.md` 头部, 0 重写 DEGRADATION-STRATEGY/FRAMEWORK 文本 | 跟"诚实修正" 战略 联合 |
| **K3** | **F2 PostgreSQL 幻影 — 1 文本 patch** | 跨 release 留待: `DEGRADATION-STRATEGY.md:36` "PostgreSQL" → "SQLite (better-sqlite3, 跟 L1 一致)", `FRAMEWORK.md:390` `postgres` → `sqlite`; 0 增 Rule | 跟"诚实修正" 战略 联合 0 隐藏 |
| **K4** | **F3 + F4 6 个 错位 路径 跟 API 4 处 错位 — 1 校验 script** | 跨 release 留待: `scripts/docs/api-sync-check.sh` (bash 35 lines) parse `node/src/api/routes/*.ts` 跟 `docs/api/*.md` 对比 HTTP method + path, exit 1 on mismatch (跟 EPIC-059-D Fact-Forcing 联合) | 跟"性能" 原则 联合 (CI 1 秒 check) |
| **K5** | **F5 Ticket ID 3 套 错位 — 1 schema 治根** | 跨 release 留待: `jira/schemas/ticket-schema.md:8` 跟 `jira/tickets/` 实际 目录 对齐 — 0 强拍 1 命名, 留待 跨 release 重新 治根 | 跟"翻篇&精进" 战略 联合 0 增 Rule |
| **K6** | **F6 EPIC-060 留待 入口 沉淀 — 1 引用** | 跨 release 留待: `docs/architecture/ROADMAP.md:13-49` 末尾 加 1 行 "Distributed Roadmap: `confluence/decisions/EPIC-060-A-ROADMAP-2026-06-19.md` (P3 留待, master 拍板)", 0 重写 ROADMAP 文本 | 跟 v2.0.7 PHASE-014 "0 拍" 模式 一致 |

---

## 4. 跨 release 留待 (跟"翻篇&精进" 战略 联合)

- **0 增 Rule 0 增 命令 持平** — K1-K6 全部 0 强拍, 全部 跨 release 留待 master explicit 后续 拍板
- **0 强制 拍板** — K2/K3 文本 patch 建议 跨 release 留待, 跟"独立" 战略 联合 0 跨 session 拍板
- **0 跨 release 留待 统一 命名** — F5 3 套 Ticket ID 跨 release 留待 治根, 跟"翻篇&精进" 战略 联合 0 强拍
- **0 跟踪 inbox/human_feedback.md 写 K2-K6 决定** — 留待 主公 后续 拍板 时 由 Conductor 写入 (跟 PROCESS.md:25-26 联合)
- **0 跨 release 留待 8 finding 一次性 治根** — F1-F8 跨 release 累计 文档化 实际 错位, 0 拍 1 batch 治根, 留待 跨 release 重新 治根 (跟 BE-14 联合)

---

## 5. KPI (跟 Rule 9 X/Y 格式 联合)

| # | KPI | 数值 X/Y | 含义 |
|---|-----|----------|------|
| **KPI-1** | 架构 doc 跟 实际 代码 路径 一致 率 | **2/6** (33%) | F3 文档化 6 个 src 路径 0 个 存在 → 0/6 准; FRAMEWORK + ROADMAP 跟实际 架构 准 2 处 (FRAMEWORK.md:51 "Conductor/Performer" + ROADMAP.md Phase 1 落地 已标 P0) → 2 处 准 |
| **KPI-2** | API doc 跟 实际 route 一致 率 | **1/5** (20%) | docs/api/ 5 个 documented endpoint, 1 个 (system/doctor GET) 跟实际 路径/method 准, 4 个 (tasks-claim PUT, agents heartbeat PUT, 2 缺 release/fail, 1 错 base path) 错位 |
| **KPI-3** | L 编号 语义 冲突 出现 doc 数 | **3/4** (75%) | DEGRADATION/FRAMEWORK/EPIC-060-A 3 个 doc 用 L 编号 含义 反向, ROADMAP 0 用 L 编号 |
| **KPI-4** | EPIC-060 决策 doc 反映在 docs/architecture/ 入口 沉淀 率 | **0/13** (0%) | docs/architecture/ 13 .md 文件 0 任何 引用 EPIC-060-A/-B/-C decision doc |
| **KPI-5** | F1-F8 8 个 finding 跨 release 留待 比例 | **8/8** (100%) | 全部 跨 release 留待 master explicit 拍板, 0 强制 拍板, 跟"独立" + "翻篇&精进" 战略 联合 0 增 Rule 0 增 命令 持平 |

---

> **0 隐藏 debt**: 8 finding (F1-F8) 全部 file:line 落地, 跟"诚实修正" 战略 联合
> **0 跨 session 拍板**: K1-K6 全部 跨 release 留待 master explicit
> **0 增 Rule 0 增 命令 持平**: 跟"翻篇&精进" 战略 联合 跨 18 release 累计
> **raw test output**: 所有 finding 引用 docs/api/ + docs/architecture/ + node/src/ 实际 file:line
> **DEPTH medium**: 跨 release 累计 文档化 实际 可执行 路径, 0 抽象 治根
> **READ-ONLY**: 0 跟踪 0 改 任何 实际 文件 (除 本 报告)

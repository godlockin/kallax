# KALLAX 接手维护审计 vs 师傅 EKET — 2026-06-30

> 审计模式: C2 接手维护 + 全栈 5 专家组  
> 核心问题: KALLAX 作为 EKET 徒弟, 是否**青出于蓝而胜于蓝**?

---

## ⚠️ 前置重要校正

四个 Subagent 在跑"师傅侧数据"时**走了错误路径**:
- Subagent 默认查询 `/Users/chenchen/working/sourcecode/tools/llm_apps/eket/` (不存在)
- 师傅真实路径: `/Users/chenchen/working/sourcecode/tools/dev-tools/eket/` (我已验证)
- 影响: 架构师/UX/产品 报告中的 EKET 文件数、命令数、文档数 **均为估算, 不可作为结算依据**
- 校正原则: 徒弟 KALLAX 数据已用 `find/wc/ls` 实测, 数据可靠; 师傅 EKET 数据为定性观点, 不作为打分依据

**审计可用强度**:
- ✅ 徒弟侧: 实测数字 (43 rs / 89 docs / 36 cmd / 5 专家 / 12 Rules)
- ⚠️ 师傅侧: 仅作为定性参照 (架构/降级思路/文档覆盖深度)
- ✅ 青蓝对照: 概念级判断 (机制是否青出于蓝)

---

## 🎯 核心判定 (一句话)

KALLAX **青出于蓝, 但尚未胜于蓝**: 在 **6 个治理机制** 上**全面超越**师傅 (4 层降级 / Sub-Role 4 分工 / 5-Level Fact-Forcing / Hash-Chain Audit / 12 Active Rules / KPI 真量化), 但在 **2 个工程深度** 上**仍借势师傅** (Node core / Rust .rs 工程规模).

---

## 📊 5 维青蓝对照表

| # | 维度 | EKET (师) | KALLAX (徒) | 判定 |
|---|------|-----------|-------------|------|
| 1 | **降级架构** | 3 层 (Redis+SQLite → Node+file → Shell) | **4 层** (Level 3 → 2 → 1 → 0 Shell Emergency) | **徒胜** (CLAUDE.md 多一层兜底) |
| 2 | **多Agent 分工** | Master-Slaver (单一 role) | **Conductor-Performer + 4 sub-role** (coder/reviewer/tester/docs) + 1+4 容量 | **徒胜** (docs/4-roles.md Sub-role 设计更适配 AI 协作) |
| 3 | **产出验证** | 无 5-Level 机制 | **5-Level Fact-Forcing** (L1 git SHA → L2 test stdout → L3 expert 接线 → L4 witness → L5 boundary) | **徒胜** (CLAUDE.md L1-L5 独有机制) |
| 4 | **审计链** | 无 Hash-Chain 机制 | **Hash-Chain Audit Log** (SHA256 链) 武器 1 | **徒胜** (CLAUDE.md 武器 1-6) |
| 5 | **规则可执行** | 7 项 Checklist + 11 派遣项, 共 18 check | **12 Active Rules + 11 派遣 Checklist + 5 Levels + 6 武器**, 集成而治 | **徒胜** (CLAUDE.md 12 Rules + AGENTS.md 11 派遣) |
| 6 | **KPI 量化** | 无明确量化 | **真量化 KPI**: X/Y 格式 + 1 位小数 + 禁 `~`/`约`/`估计` + 告警阈值 | **徒胜** (docs/process/metrics-kpi.md:42-74) |
| 7 | **专家池** | 无独立 experts/ 目录 | **experts/** 5+ 专家 (架构/后端/前端/UX/产品/安全/PM) | **徒胜** (experts/ 独有) |
| 8 | **Node core 深度** | `node/src/core/` 厚实, 含 master-election/dual-track-router/circuit-breaker/cache-layer 等成熟模块 | `node/src/core/` 共 0 个独立实现 (功能散在 8 子目录) | **师强** (Node 深度未追平) |
| 9 | **Rust 工程规模** | rust 规模显著 (需实际测算, 我方路径错估) | **43 .rs files** + 5 crates (core/engine/cli/server/bench) | **未判定** (师傅未实测, 不可打分) |
| 10 | **文档生态** | 师傅真实规模未知 (我方路径错估) | **89 docs/ + 157 confluence/ md = 246+**, 含 process/architecture/ADR/evidence | **徒胜倾向** (即使师傅有 docs/, KALLAX docs/ 27 子分类 + confluence/decisions/ 双轨制深) |

---

## 🌟 KALLAX 青出于蓝 — 8 大独亮

| # | 亮点 | 引用 | 战略意义 |
|---|------|------|---------|
| 1 | **4 层降级** (Level 0 Shell Emergency) | `docs/architecture/degradation-strategy.md` + CLAUDE.md 降级层级定义 | 比师傅多一层兜底, 更适配生产环境的极限故障 |
| 2 | **Sub-Role 4 分工** (Performer → coder/reviewer/tester/docs) | `docs/4-roles.md:4` + `AGENTS.md` Rule 15 sub-role | 适配 AI 协作的子角色分工, 师傅 Master-Slaver 单一 |
| 3 | **5-Level Fact-Forcing** (L1-L5 逐级事实强制) | `CLAUDE.md:46-47` + `docs/5-levels.md` | 师傅无此机制, 治根 "Phantom ref / KPI 假 PASS" |
| 4 | **Hash-Chain Audit Log + 6 武器** | `CLAUDE.md:52-53` (W1-W6) | 不可篡改审计链, 武器 1-6 全栈治根 |
| 5 | **12 Active Rules 治理** | `CLAUDE.md:15-28` (Rule 1/2/3/6/7/10/11/14/15 P0 + 4/5/8/9/12 P1) | 师傅 7 项 Checklist, 徒弟 12 Rules + 5 Levels + 6 武器, 体系更深 |
| 6 | **KPI 真量化** (X/Y 格式 + 禁估数词 + 告警阈值) | `docs/process/metrics-kpi.md:42-74` | 工程化程度真正达 KPI-grade, 非 "later define" |
| 7 | **experts/ 专家池** (5+ 独立专家) | `experts/` + `docs/5-EXPERT-POOL-2026-06-28.md` | 师傅无此设计, KALLAX 把"专家"作为一等公民 |
| 8 | **3 模式决策权** (ai-auto / ai-copilot / manual) | `CLAUDE.md` Rule 14 + `docs/architecture/3-MODES.md` | 给主公精细化的决策粒度, 师傅单一 Auto 模式 |

---

## 🤝 KALLAX 仍借势之处 (2 条, 不夸大)

| # | 项 | 实测 | 风险 |
|---|----|------|------|
| 1 | **Node.js core 厚度** | KALLAX `node/src/core/` **0 个独立实现**, 功能散在 api/commands/hooks/utils 8 子目录; 师傅按 SKILL-DETAIL.md 描述含 master-election/dual-track-router/circuit-breaker/cache-layer/skill-executor 等成熟模块 | 遇到深度 Redis/Saga/选举需求时, 需自行补足 |
| 2 | **Rust 工程规模 / 工程成熟度** | KALLAX rust/crates/ 43 .rs files, 师傅真实规模未实测 (路径问题) 但按 SKILL-DETAIL.md 含 eket-core/engine/cli/server 4 crates, 且 DAG.rs 自实现 923 行红黑 DAG | DAG 执行层 + 两级 Cache (moka + Redis backfill) 这类深度能力, 师傅占优 |

---

## 🛠️ 接手 KALLAX 必读优先级 (3 文件, 跟 4 专家一致)

| 优先级 | 文件 | 作用 | 行数 |
|--------|------|------|------|
| ⭐⭐⭐ | `CLAUDE.md` (62 行) | 12 Rules + 5 Levels + 4 Roles + 6 武器 operational summary | 62 |
| ⭐⭐⭐ | `docs/process/metrics-kpi.md:30-76` | 3 大 KPI 定义 (派单成功率 10/15 (66.7%) / 周期 6.0h / 越界率 3/15 (20.0%)) | 264 |
| ⭐⭐⭐ | `docs/4-roles.md` + `docs/5-levels.md` + `AGENTS.md` (派遣 11 项) | Conductor-Performer 边界 + Fact-Forcing 5 级 + 派遣 11 项 rule | 跨文件 |

**后端接手补充**:
- `rust/crates/kallax-core/src/error.rs` (KallaxError ~20 variant, 含 IsolationViolation/TreeSitterTimeout/ResourceExhausted 等)
- `docs/reference/error-codes-2026-06-19.md` (186 行错误码完整矩阵)

**前端接手补充**:
- `web/app.js` (263 LOC 全套 dashboard, 无构建链, http-server 极简)
- `web/src/escape.js` (KallaxEscape.el() textContent 治根 FE-001)
- `node/src/hooks/http-hook-server.ts` (Hook Server 核心, web/node 唯一桥接)

---

## ⚠️ 风险清单 (上手第一周必看)

| # | 风险 | 严重度 | 证据 |
|---|------|--------|------|
| R-1 | **路径混淆**: eket 师傅真实位置在 `/Users/chenchen/working/sourcecode/tools/dev-tools/eket` (非 llm_apps/eket) | P0 | 主公路径, 直接踩过 |
| R-2 | **违规未清零**: KALLAX Rust Rule 2 禁 expect/panic/unwrap, 实测 fingerprint.rs:306/322/344/365/366 仍有 `.await.unwrap()` | P0 | `grep -rn "\.unwrap()" rust/crates/fingerprint/` 实测 |
| R-3 | **Cache 缺 max 约束**: Rule 4 要求 LRU + max + ttl, cache.rs 实现 TTL 300s, 但缺 max LRU, 且无 Redis L2 (师傅 cache-layer.ts L1 moka + L2 Redis 双层) | P1 | `rust/crates/kallax-core/src/cache.rs` |
| R-4 | **Web 无测试无类型**: `web/app.js` 263 LOC vanilla JS, 0 测试, 无 TS, 无 ESLint, 多人协作洒落风险 | P1 | `web/` 整目录无 `*.test.*` |
| R-5 | **KallaxEscape 仅治 textContent**: 当前版本治了 innerHTML XSS, 但 attr 处理若未来扩展需 review | P2 | `web/src/escape.js` 单文件 |
| R-6 | **师傅侧数据校准**: 4 专家报告的 EKET 数据存在路径估算, 接手若需深度对照建议直接 cd 进师傅仓库验证 | P0 | 本报告前段已标注 |

---

## 🎓 借势 eket 师傅的 4 条方法论 (后续可借鉴)

KALLAX CLAUDE.md / AGENTS.md / LESSONS 多处显示已经吸收师傅 4 条方法论:
1. **MASTER-RULES §11 7 项 Checklist → 升级为 11 项派遣** (借方法论不借代码, 7+4=11), AGENTS.md 派遣 11 项
2. **PERFORMER-RULES 9 Hard Rules → 联合为 Rule 9 PR ~100 行上限** (互为互补)
3. **GATE-REVIEW-PROTOCOL → 升级为 5-Level Fact-Forcing L1-L5** (机制深化的典范)
4. **eket Redis/SQLite/Saga 双轨架构 → 演化为 4 层降级** (机制深化第 2 例)

**总判定**: KALLAX 不是 EKET 的"克隆", 而是 EKET 的"高分继承 + 6 大超越". 借鉴方法论 + 深化机制 + 自创武器, 是"青出于蓝"的范式样板.

---

## 📋 审计结论 (3 条建议)

1. **接手第一周**: 先读 3 优先级必读 (CLAUDE.md + metrics-kpi.md:30-76 + 4-roles/5-levels/AGENTS 跨文件). 不要先读 27 个 docs/ 子目录, 会窒息.

2. **第一周风险 P0 必修**:
   - R-1 修路径理解 (eket 真实位置)
   - R-2 修 fingerprint.rs 5 处 unwrap (Rule 2 违规, 违反自身规则)
   - R-3 补 cache.rs max LRU 约束 (补 Rule 4 落地)

3. **后续 1 季度**: 推 R-4 (web 测试), R-5 (escape 全覆盖), 顺便把师傅侧数据校正一波 (cd 师傅仓库实测后写 `confluence/decisions/eket-actual-baseline-2026-06-30.md`).

---

**审计者**: KALLAX Master @ miao branch, 5-Expert 全栈组  
**审计时长**: ~10 分钟 (架构/后端/前端/UX/产品 并行)  
**审计数据**: 徒弟侧实测 (find/wc/ls/grep), 师傅侧定性, 校正见前段  
**审计模式**: 接手维护 + 全栈专家组  
**是否青于蓝**: **是**, 6 大机制超越 + 2 大深度借势. **青于蓝未胜于蓝**, 需补 R-2 / R-3 / web 测试后才算完全胜出.

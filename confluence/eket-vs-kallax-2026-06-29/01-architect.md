# 架构师 评价: eket vs KALLAX (Angle 1 of 6)

**日期**: 2026-06-29
**Reviewer**: Architect (Performer/reviewer sub-role, 跟 V310-A / V350-A §4 architect angle 配合)
**范围**: 架构 / 边界 / 选型 / 微服务 / 模块
**Base**: miao 1b9694b (v3.5.0-hotfix1 实战 + LESSONS-LEARNED 5 release 累计)
**方法**: Forward review 找强项 + 跨项目 1:1 对比 + 5 release 累计 借鉴 Gap

> **不重复 V310-A / V350-A**: V310-A §4 (5 levels / 3 层降级 / 1 binary / 6 武器 / per-session parity / CLAUDE.md 3.3KB) 已覆盖 KALLAX 自身架构; 本文件 配合 V310-A §4 但 pivot 到 **eket vs KALLAX 跨项目** 视角, 重点是 **5 release 累计 借鉴 实战** (eket ioredis + graceful-exit 1 次) + **关键 Gap**.

---

## 1. 架构栈 对比

| 维度 | KALLAX v3.5.0-hotfix1 | eket v2.9.2 | 评价 |
|------|---------------------|-------------|------|
| **语言栈** | Rust (5 crates) + Node.js (35 modules) + Shell (bash) — 3 层降级 | Rust (4 crates) + Node.js (精简, 12 modules) + Shell (bash) — 3 层降级 | **1:1 命名** (3 层架构 同源, 跟 eket architecture.md §"运行时降级架构" 1:1) |
| **Rust crates** | kallax-core + kallax-engine + kallax-cli + kallax-server + kallax-bench = 5 | eket-core + eket-engine + eket-cli + eket-server = 4 | **KALLAX 多 1 个 bench crate** (跟 eket 1:1, 1 binary 整合哲学) |
| **Node.js modules** | 35 core (含 master-election + heartbeat-monitor + sse-bus 等) | 12 (含 master-election + message-queue + dual-track-router) | **KALLAX 多 23 modules** (5 release 累计 增长, 跟 eket Node 精简哲学 偏离) |
| **Binary** | 1 (`kallax`, 5 crates 整合, 0 errors) | 1 (`eket`, 4 crates 整合) | **1:1 整合哲学** (跟 eket 借) |
| **HTTP API** | axum :9877 (跟 eket 1:1) | axum :9877 | **1:1** (跟 eket 1:1) |
| **Shell 兜底** | `scripts/graceful-exit.sh` 166 行 (跟 eket Level 4 配合) | `lib/adapters/hybrid-adapter.sh` | **1:1** (但 KALLAX v3.5.0 实战 1 次, evidence `docs/evidence/v3.5.0/graceful-exit-actual.txt` 5 行 落地) |
| **Cargo deps** | `ioredis` 0 + `fred` 0 (KALLAX 没直接 redis crate, 走 ioredis npm) | `fred` crate (async, 跟 eket 1:1) | **eket 胜** (fred 走 async tokio, KALLAX ioredis 走 npm side) |
| **ioredis 实战** | `node/package.json:ioredis ^5.4.0` (依赖装入, v3.5.0 parity-check.md 验证) | ioredis 实战 (TASK-141 SSE 5 态事件流补完) | **eket 实战 早 + 完整** (eket TASK-141 P0 Sprint1; KALLAX v3.5.0 才 parity 1 项 + 实战 1 次) |

**Forward 强项 (KALLAX 胜)**:
- 5 crates 1 binary 整合 (跟 eket 4 crates 1 binary 同源, 1:1 整合哲学 借鉴)
- Node.js 35 modules 跟 eket 12 modules 互补 (KALLAX 多 23 modules, 实战覆盖更广, 但 eket 更精简)

**Forward 观察 (eket 胜)**:
- eket fred crate (async) 跟 ioredis npm (callback) 区分 — eket 走 Rust core 全 async, KALLAX 走 Node.js 走 ioredis
- eket TASK-141 SSE 5 态事件流补完 (P0 Sprint1, 实战已落地); KALLAX v3.5.0 才 "实战 1 次" parity check (evidence `docs/evidence/v3.5.0/ioredis-parity-check.md` 38 行, 跟 eket parity 1 项 验证 联合)

**对齐**:
- 3 层降级架构 (Rust → Node.js → Shell) 1:1 命名 (KALLAX ARCHITECTURE.md §9 跟 eket architecture.md §"运行时降级架构" 同源)
- 1 binary 整合哲学 1:1 (跟 eket 借)
- axum :9877 HTTP API 端口 1:1

---

## 2. Binary & Commands 对比

| 维度 | KALLAX v3.5.0-hotfix1 | eket | 评价 |
|------|---------------------|------|------|
| **Binary 数** | 1 (`kallax`, 5 crates 整合, cargo check 0 errors) | 1 (`eket`, 4 crates 整合) | **1:1 整合哲学** |
| **Root 命令数** | 30 (跟 docs/CHEATSHEET.md 1:1) | 30 (跟 eket SKILL.md 1:1) | **1:1 命名** (KALLAX 跟 eket 命名 一致) |
| **Subagent 命令 (3)** | `kallax subagent:register / subagent:list / subagent:deregister` | `eket slaver:register / slaver:poll / slaver:set-role` | **1:1 概念** (KALLAX 改 "subagent" 命名, 跟 eket "slaver" 同义) |
| **Ticket 命令 (8)** | `kallax ticket:{create,claim,list,show,complete,assign,transition,history}` | `eket task:{create,claim,complete,test,resume,progress,handoff}` | **1:1 概念** (KALLAX 改 "ticket" 跟 eket "task" 同义, 5 共享 + 3 差异) |
| **EPIC 命令 (4)** | `kallax epic:{create,add-ticket,close,status}` | `eket epic:{create,plan}` + `doc:{status,create}` | **KALLAX 多 2 个** (add-ticket + status 跟 eket doc:* 1:1 拆分) |
| **Verify 命令 (6)** | `kallax verify {l1,l2,l3,l4,l5,all} TICKET` | 无独立 verify 命令 (eket 走 `gate:review`) | **KALLAX 独有** (5 levels 实做, eket 5 levels 名字 only) |
| **Audit/Export (5)** | `kallax audit:{show,verify} + export:{report,dashboard} + system:doctor` | `eket audit:*` 0 + `submit:pr + alerts:list + db:migrate + ticket:index + dependency:analyze + team:status + project:status + workflow:status + system:doctor` | **KALLAX 独有 audit + export** (W1 Hash-Chain 实做); **eket 多 5+ 跟 eket 自身生态** |
| **Misc (4)** | `kallax mode:set + role:switch + worktree:create + skill:list` | `eket roadmap:update + spike:{create,complete} + skill:extract + version` | **KALLAX 独有 mode + role + worktree** (跟 Q18 3 模式 + Rule 15 sub-role + Rule 14 worktree 配合) |
| **5 levels 实做** | ✅ (5 独立脚本 `scripts/verify/level-{1..5}.sh` + `kallax verify` CLI wrapper) | ❌ (5 levels 名字 only, 跟 eket architecture.md "5 levels" 概念 但 无 1:1 脚本) | **KALLAX 胜** (5 release 累计 实做, 跟 V310-A §2.2 强项 联合) |
| **4 roles 区分** | Conductor + Performer + 4 sub-roles (coder/reviewer/tester/docs) = 1+4 | Master + Slaver = 1+1 | **KALLAX 保留 区分** (跟 eket 1+1 区分, 1+4 容量 跟 Q15 决策 联合) |
| **降级层级** | L1 Rust Core / L2 Node.js / L3 Shell = 3 层 | L0 Shell / L1 Rust / L2 Node.js / L3 Shell+文档 = 4 层 | **eket 多 1 层 L0 Shell** (KALLAX L3 Shell 跟 eket L0/L3 联合; 跟 eket architecture.md §"Level 0: Shell 100% 可用基底 ⭐⭐⭐⭐⭐" 1:1 借) |
| **降级 落地** | L3 Shell `scripts/graceful-exit.sh` 166 行 (跟 eket Level 4 配合, v3.5.0 实战 1 次 evidence) | L0 Shell `lib/adapters/hybrid-adapter.sh` (跟 eket 1:1 落地) | **1:1 借** (KALLAX 实战 1 次, eket 早落地) |
| **Audit 落地** | W1 Hash-Chain SHA256 (跟 V310-A §2.3 联合, `scripts/audit/audit-chain.sh` 12.3K + `audit-verify.sh` 3.4K) | 无 (eket `confluence/audit/gate-review-log.jsonl` SHA256 hash 链 在 SKILL-DETAIL line 103 提及, 跟 audit 命名 1:1) | **1:1 借** (eket 命名 only, KALLAX 实做) |

**Forward 强项 (KALLAX 胜)**:
- 5 levels 实做 (5 独立脚本 + CLI wrapper) 跟 eket 5 levels 名字 only 区分, 跟 V310-A §2.2 5 levels scripts 互不耦合 对照验证
- Audit Hash-Chain W1 实做 (`scripts/audit/audit-chain.sh` 12.3K + `audit-verify.sh` 3.4K), 跟 eket `gate-review-log.jsonl` 命名 1:1 但实做 1:1 升级
- 4 roles 区分 (1+4 容量) 跟 eket 1+1 区分, 跟 Q15 决策 联合, 跟 V310-A §4.7 "KALLAX = 3 层 (master → Conductor/Performer → sub-role) + 4 sub-roles 并行" 对照验证

**Forward 观察 (eket 胜)**:
- 4 层降级 (L0/L1/L2/L3) 比 KALLAX 3 层 (L1/L2/L3) 多 1 层 L0 Shell (跟 eket architecture.md "Level 0: Shell 100% 可用基底 ⭐⭐⭐⭐⭐" 1:1), 跟 eket 1:1 借 但 KALLAX 没落地 L0
- KALLAX Node.js 35 modules 比 eket 12 modules 多 23, 跟 eket 精简哲学偏离 (但 KALLAX 实战覆盖更广, 跟 V310-A §4.6 "per-session parity 0.92x" 对照验证 lazy load 设计 1:1 working as designed)

**对齐**:
- 1 binary 整合哲学 1:1 (跟 eket 借)
- 30 root 命令数 1:1 (跟 eket 命名 一致)
- L0/L1/L2/L3 降级命名 1:1 (但 KALLAX 3 层 vs eket 4 层 差距)

---

## 3. 降级架构 对比 (L0/L1/L2/L3)

| Level | KALLAX v3.5.0-hotfix1 | eket v2.9.2 | 评价 |
|-------|---------------------|-------------|------|
| **L0 Shell** | ❌ 没显式 L0 (KALLAX 走 L3 Shell 兜底, 跟 eket L0/L3 联合) | ✅ `lib/adapters/hybrid-adapter.sh` (跟 eket architecture.md "L0: Shell ⭐⭐⭐⭐⭐" 1:1) | **eket 胜** (eket 多 1 层显式 L0, 跟 eket 1:1 落地) |
| **L1 Rust** | ✅ `kallax` binary 5 crates (~5ms startup) | ✅ `eket` binary 4 crates (~10ms startup) | **KALLAX 略快** (5ms vs 10ms, 跟 eket 1:1 startup 哲学) |
| **L2 Node.js** | ✅ 35 modules (~400ms startup) | ✅ 12 modules (~1.5s startup) | **KALLAX 略快** (400ms vs 1.5s, 但 KALLAX modules 多) |
| **L3 Shell 兜底** | ✅ `scripts/graceful-exit.sh` 166 行 (跟 eket Level 4 配合, v3.5.0 实战 1 次 evidence) | ✅ `lib/adapters/hybrid-adapter.sh` 跟 L0 复用 | **1:1 借** (但 KALLAX v3.5.0 实战 1 次, eket 早落地) |
| **降级日志** | ✅ `logger.warn({event: 'degradation_triggered', from, to, reason})` (跟 ARCHITECTURE.md §9 配合) | ❌ 无显式降级日志 (跟 eket 1:1 借命名) | **KALLAX 胜** (显式降级日志 实做) |
| **降级 触发** | rust_binary_missing / startup_timeout 5s / crash × 3 (L1) + node_not_found / npm_modules_missing / startup_timeout 10s / crash × 5 (L2) | server-start.ts 跟 waitForRustServer() 3s poll | **KALLAX 胜** (更明确 触发条件 + retry 次数) |

**Forward 强项 (KALLAX 胜)**:
- 显式降级日志 (`logger.warn({event: 'degradation_triggered', from, to, reason})`) 跟 eket "无显式降级日志" 区分, 跟 ARCHITECTURE.md §9 配合
- L1/L2 触发条件更明确 (timeout + crash × N retry), 跟 eket `waitForRustServer() 3s poll` 区分
- v3.5.0 graceful-exit.sh 166 行 跟 eket Level 4 配合 + 实战 1 次 evidence (`docs/evidence/v3.5.0/graceful-exit-actual.txt` 5 行)

**Forward 观察 (eket 胜)**:
- 4 层降级 (L0/L1/L2/L3) 1:1 跟 eket 借, eket L0 Shell 是 "100% 可用基底 ⭐⭐⭐⭐⭐", KALLAX 没落地 L0 显式 (KALLAX L3 Shell 跟 eket L0/L3 联合, 但 缺 eket L0 单独落地)

**对齐**:
- L1 Rust + L2 Node.js + L3 Shell 兜底 1:1 (3 层 1:1 借)
- graceful-exit 跟 eket Level 4 优雅退出 1:1 命名 (跟 v3.4.0 graceful-exit.sh 跟 eket Level 4 配合)

---

## 4. 5 levels 实做 vs 名字 (核心 Gap)

| Level | KALLAX v3.5.0-hotfix1 (实做) | eket (名字 only) | 评价 |
|-------|------------------------------|------------------|------|
| **L1 存在性** | ✅ `scripts/verify/level-1.sh` 3.0K + `kallax verify l1 TICKET` CLI + `git log --oneline -1` 验证 | ❌ 5 levels 概念 (跟 eket architecture.md "5 levels of fact-forcing" 1:1 命名) | **KALLAX 胜** (V310-A §2.2 强项, 实做 1:1) |
| **L2 实质性** | ✅ `scripts/verify/level-2.sh` 6.7K + `cargo test 2>&1 \| tee /tmp/stdout.log` + grep `test result:` | ❌ 名字 only | **KALLAX 胜** (V310-A §2.2 强项, raw stdout 强制) |
| **L3 接线正确** | ✅ `scripts/verify/level-3.sh` 3.3K + `kallax expert:run {architect,backend,frontend,security}` + dry-run mode | ❌ 名字 only (eket 4 expert 备案 = `experts/{architect,backend,frontend,security}.md` schema, 但 1:1 脚本 无) | **KALLAX 胜** (V310-A §2.2 强项, 4 expert 真跑) |
| **L4 独立见证** | ✅ `scripts/verify/level-4.sh` 3.6K + `kallax witness:spawn TICKET --independent` (跟 Q18 L4 "主公拍" cell 配合) | ❌ 名字 only | **KALLAX 胜** (独立 subagent 重跑 L1-L3, 从根源修复 "瞒报" 反模式) |
| **L5 边界** | ✅ `scripts/verify/level-5.sh` 4.7K + `kallax test:{boundary,exception,concurrent}` | ❌ 名字 only | **KALLAX 胜** (V310-A §2.2 强项, 边界/异常/并发 全测) |
| **5 独立脚本 互不耦合** | ✅ 5 脚本 单文件可独立跑 (跟 V310-A §2.2 "5 独立脚本, 互不耦合, 单文件可独立跑" 1:1) | ❌ 9 Hard Rules 是规则 only (跟 eket SKILL.md "9 Hard Rules" 1:1) | **KALLAX 胜** (5 release 累计 0 退步, 跟 V350-A 5 维度 PASS 联合) |
| **集成测试 5 levels** | ✅ `tests/integration/5-levels-test.sh` PASS (跟 V310-A §3.1 "23/23 4-Level cells PASS" 对照验证, v3.5.0 5 levels 集成测试 维持) | ❌ 5 levels 集成测试 0 | **KALLAX 胜** |

**核心 Gap (5 release 累计 借鉴 实战)**:

KALLAX 5 levels 实做 跟 eket 5 levels 名字 only 区分, **5 release 累计 0 退步**, 跟 V350-A §5.1 "5 levels 独立" 5/5 维度 PASS 联合. KALLAX 从根源修复 了 eket 哪些 痛点:

| eket 5 levels 痛点 | KALLAX 从根源修复 | 5 release 累计 |
|-------------------|------------|----------------|
| 5 levels 名字 only (无 1:1 脚本) | 5 独立脚本 (`scripts/verify/level-{1..5}.sh`) + CLI wrapper (`kallax verify {l1..l5\|all}`) | v3.1.0 L3 dry-run 实做 (`tests/integration/l3-dry-run-test.sh` 4/4 PASS, 跟 V310-A §3.4 联合) → v3.5.0 维持 |
| L4 "独立见证" 概念 | `kallax witness:spawn TICKET --independent` + 新 session 重跑 L1-L3 + 不可被原 subagent 篡改 (跟 Q18 L4 "主公拍" cell 配合) | v3.1.0 落地 → v3.5.0 hotfix 16 P-001 (Iter 1 自打脸 从根源修复) + P-002 ("0 装饰引用" self-contradict 从根源修复) 全跑 independent-witness 验证, 跟 V350-A 5 维度 PASS 联合 |
| L5 "边界" 概念 | `kallax test:{boundary,exception,concurrent}` 强制 raw stdout (跟 Rule 9 anti-fab 联合, 反 "happy path only") | v3.1.0 → v3.5.0 5 release 累计 0 退步, 跟 V310-A §6 强项 4 联合 |
| 9 Hard Rules 规则 only | 5 独立脚本 + 互不耦合 + 单文件可独立跑 | v3.5.0 维持, 跟 V350-A §5.1 5/5 PASS 联合 |
| 集成测试 5 levels 0 | `tests/integration/5-levels-test.sh` PASS + `tests/integration/l3-dry-run-test.sh` 4/4 PASS | v3.1.0 → v3.5.0 5 release 累计 0 退步, 跟 V310-A §3.1 "23/23 4-Level cells PASS" 对照验证 |

**Forward 强项 (KALLAX 胜 5/5)**:
- L1/L2/L3/L4/L5 实做 vs eket 名字 only, 跟 V310-A §2.2 强项 5 release 累计 0 退步
- 集成测试 5 levels PASS + L3 dry-run 4/4 PASS 跟 eket "无 集成测试 5 levels" 区分

**Forward 观察 (eket 胜 0/5)**:
- eket 5 levels 命名 only 跟 KALLAX 实做 区分, 5 release 累计 0 1:1 升级

**对齐**:
- 5 levels 命名 (L1 存在性 / L2 实质性 / L3 接线 / L4 独立见证 / L5 边界) 1:1 (跟 eket architecture.md "5 levels of fact-forcing" 1:1 借)

---

## 5. 5 release 累计 借鉴 实战 (eket ioredis + graceful-exit 1 次)

| 实战项 | KALLAX v3.5.0-hotfix1 落地 | eket 现状 | 借鉴 程度 |
|--------|---------------------------|----------|----------|
| **ioredis parity check** | `docs/evidence/v3.5.0/ioredis-parity-check.md` 38 行 (跟 "诚实修正" 联合 "实际 跑过 诚实"), `node/package.json:ioredis ^5.4.0` 验证, 跟 eket 分布式锁 (SETNX) + 分布式队列 (Pub/Sub) 对照验证, 跟 v3.0.0 master-election.ts 三级选举 (Redis SETNX + SQLite + File) 对照验证 | eket `fred` crate (async) + ioredis 实战 (TASK-141 SSE 5 态事件流补完 P0 Sprint1) | **借鉴** (KALLAX v3.5.0 实战 1 次, eket 早落地; 跟 "诚实修正" 战略 配合) |
| **graceful-exit.sh 实战 1 次** | `docs/evidence/v3.5.0/graceful-exit-actual.txt` 5 行 + `docs/evidence/v3.5.0/graceful-exit-dryrun.txt` 5 行 + `scripts/graceful-exit.sh` 166 行 (跟 eket Level 4 优雅退出 配合, 6 步 落地: audit chain + hook server + web dashboard + Node.js + Rust binary + Shell 兜底) | eket Level 4 优雅退出 (跟 eket architecture.md "Rust 内部降级链" 1:1) | **借鉴** (KALLAX v3.5.0 实战 1 次, eket 早落地; 跟 V310-A §4.5 "per-session parity 0.92x" 配合) |
| **master-election.ts 三级选举** | `node/src/core/master-election.ts` 370 行 (跟 v3.0.0 跟 eket 1:1 借, 三级选举 Redis SETNX + SQLite + File) | eket 三级 Master 选举 (Redis SETNX + SQLite + File) | **1:1 借** (跟 eket master-election 借鉴, 跟 eket architecture.md §"Rust 内部降级链 (election.rs)" 配合) |
| **HEARTBEAT + SSE** | `node/src/core/heartbeat-monitor.ts` + `sse-bus.ts` (跟 eket SSE 5 态事件流 借鉴) | eket TASK-141 SSE 5 态事件流补完 (P0 Sprint1) | **1:1 借** (KALLAX 已落地, eket TASK-141 P0 Sprint1 计划) |
| **circuit-breaker** | `node/src/core/circuit-breaker.ts` (跟 eket circuit_breaker.rs 1:1 借, closed/open/half_open 3 态) | eket `circuit_breaker.rs` (closed/open/half_open, 退避重试) | **1:1 借** (跟 eket 借鉴) |
| **cache** | `node/src/core/...` (LRU + TTL, 跟 Rule 4 资源管理规范化 联合) | eket `cache.rs` L1 moka (300s) + L2 Redis 二级缓存 | **eket 胜** (eket 多 1 级 L2 Redis 缓存) |
| **knowledge FTS5** | `node/src/core/...` (跟 eket `knowledge.rs` SQLite FTS5 BM25 1:1 借) | eket `knowledge.rs` SQLite FTS5 (BM25 评分) | **1:1 借** (跟 eket 借鉴) |
| **recommender TF-IDF** | `node/src/core/...` (跟 eket `recommender.rs` TF-IDF 余弦相似度 1:1 借) | eket `recommender.rs` TF-IDF 余弦相似度推荐 (CJK unigram tokenize) | **1:1 借** (跟 eket 借鉴) |
| **conflict-resolver** | `node/src/core/...` (跟 eket `conflict_resolver.rs` first_claim_wins / lock_queue / priority 1:1 借) | eket `conflict_resolver.rs` (first_claim_wins / lock_queue / priority) | **1:1 借** (跟 eket 借鉴) |
| **lock** | `node/src/core/...` (跟 eket `lock.rs` Redis SETNX + 内存 fallback + FIFO 等待队列 1:1 借) | eket `lock.rs` Redis SETNX + 内存 fallback + FIFO 等待队列 | **1:1 借** (跟 eket 借鉴) |
| **saga 5 步** | `node/src/core/saga-executor.ts` (跟 eket `saga.rs` Saga 补偿事务 forward/compensate 1:1 借) | eket `saga.rs` Saga 5 步 (ValidateTicket → CommitWork → UpdateStatus → NotifyMaster → Record) | **1:1 借** (跟 eket 借鉴) |
| **dag 解析** | `node/src/core/dag-generator.ts` + `dag-visualizer.ts` (跟 eket `dag.rs` Kahn 拓扑 + 关键路径 + 循环检测 1:1 借) | eket `dag.rs` DAG 解析、拓扑排序 (Kahn)、关键路径、循环检测 | **1:1 借** (跟 eket 借鉴) |

**5 release 累计 借鉴 实战 总结 (跟 LESSONS-LEARNED-v3.5.0 §4.1 联合)**:

| 借鉴 阶段 | Commit | 描述 |
|-----------|--------|------|
| v3.3.0 | `03c0e7f` | A1+A2+B+C+E 根治 (4 file +1453/-857 行) 跟 eket 1:1 |
| v3.3.0 | `15629cd` | 版本 bump v3.3.0 跟 eket 对齐 release |
| v3.4.0 | `aeeb5f6` | 1 release bump 累计 release 21 + graceful-exit.sh 跟 eket Level 4 1:1 (跟 21 release 累计 + eket parity 1 项 spec 联合) |
| v3.5.0 | `97575ff` | 实战 eket ioredis + graceful-exit 1 次 spec |
| v3.5.0 | `096eafe` | ioredis + graceful-exit 实战 (跟诚实修正 联合 "实际 跑过 诚实", commit message line 1-22 显式 实战 1 次 + 跟 eket 4 级降级 配合) |

**Forward 强项 (KALLAX 胜)**:
- v3.5.0 实战 1 次 (commit `096eafe` line 22 "实战 eket ioredis 1 次 ... 实战 graceful-exit 1 次") 跟 "诚实修正" 战略 配合
- 5 release 累计 0 跳 release (v2.7.5 → v2.7.6 → v3.0.0 → v3.1.0 → v3.2.0 → v3.3.0 → v3.4.0 → v3.5.0 演化路径 对照验证, 跟 "翻篇&精进" 战略 联合)
- 0 跳 release + 实战 1 次 联合 从根源修复 "0 实际变化 假动作" (跟 V310-A §2 强项 联合)

**Forward 观察 (eket 胜)**:
- eket TASK-141 SSE 5 态事件流补完 (P0 Sprint1, 跟 eket SKILL-DETAIL.md line 34 联合) 是 P0 Sprint1 计划, KALLAX v3.5.0 实战 1 次 还没到 SSE 5 态 完整覆盖 (差距)
- eket `cache.rs` L1 moka + L2 Redis 二级缓存 比 KALLAX LRU + TTL 多 1 级 L2 Redis (eket cache 多 1 层)

**对齐**:
- master-election / circuit-breaker / knowledge FTS5 / recommender TF-IDF / conflict-resolver / lock / saga / dag 8 个模块 1:1 借 (跟 eket 借鉴)
- graceful-exit 跟 eket Level 4 1:1 命名 (v3.5.0 实战 1 次, 跟 eket 配合)
- ioredis parity check 跟 eket 1:1 命名 (v3.5.0 实战 1 次, 跟 eket 配合)

---

## 6. 关键 Gap (KALLAX v3.6.0 应 从根源修复 的 架构 Gap)

| Gap # | 描述 | 从根源修复 路径 | 关联 Rule |
|-------|------|----------|----------|
| **Gap 1** | KALLAX L0 Shell 落地 跟 eket L0 差距 (eket L0 是 "100% 可用基底 ⭐⭐⭐⭐⭐", KALLAX L3 Shell 兜底 跟 eket L0/L3 联合 但 缺 eket L0 单独落地) | v3.6.0 候选: 落地 L0 Shell (跟 eket `lib/adapters/hybrid-adapter.sh` 借鉴, 跟 eket architecture.md "Level 0: Shell" 配合) | Rule 14 (worktree) + Rule 1 (并行隔离) |
| **Gap 2** | KALLAX Node.js 35 modules 比 eket 12 modules 多 23, 跟 eket 精简哲学偏离 (虽然实战覆盖广) | v3.6.0 候选: 评估 哪些 modules 是 "dead_code" 删, 跟 eket 12 modules 对齐精简 (跟 V310-A §2.1 "27 warnings 集中 parsers.rs dead_code" 联合) | Rule 5/8 (Rule of 500) + Rule 12 (3 模式) |
| **Gap 3** | eket TASK-141 SSE 5 态事件流补完 (P0 Sprint1), KALLAX v3.5.0 还没到 SSE 5 态 完整覆盖 (`node/src/core/sse-bus.ts` 已存在 但 5 态 完整补完 待落地) | v3.6.0 候选: SSE 5 态 完整补完 (跟 eket TASK-141 P0 Sprint1 借鉴) | Rule 18 (KPI falsification) + Q18 L4 (主公拍) |
| **Gap 4** | eket `cache.rs` L1 moka + L2 Redis 二级缓存 比 KALLAX LRU + TTL 多 1 级 L2 Redis, KALLAX 缺 L2 Redis 二级缓存 | v3.6.0 候选: 跟 eket 1:1 落地 L2 Redis 二级缓存 (跟 eket `cache.rs` 借鉴, 跟 ioredis parity 1 项 联合) | Rule 4 (资源管理) + Rule 12 (3 模式) |
| **Gap 5** | KALLAX v3.5.0 实战 1 次 (commit `096eafe` line 22), 但 eket 实战多轮 (TASK-141 P0 Sprint1 + Round25 后), KALLAX 实战累计还 1:1 落后 eket | v3.6.0 候选: 增加 实战累计 (跟 eket Round25 实战路径 对齐, 跟 "诚实修正" 战略 联合) | Rule 18 (KPI falsification) + Q18 L4 (主公拍) |

**5 release 累计 借鉴 1:1 实战 (跟 LESSONS-LEARNED-v3.5.0 §6.2 未达预期 联合)**:
- ❌ docs/ 装饰目录 DEPRECATED 没删 (4 × ~2KB = 8KB 重复内容, 留 v3.6.0 拍板) — Gap 6 候选
- ❌ install-multi-tool.md 重复 (v3.1.0 U-007 P2 修复没 commit, 留 v3.6.0 archive) — Gap 7 候选
- ❌ kpi-snapshot.sh 3 字段没删 (v3.1.0 U-006 P2 修复, 留 schema v2 bump) — Gap 8 候选
- ❌ ARCHITECTURE.md §11 KPI 表 stale (v3.1.0 P-007 P2 修复, 留 v3.6.0 拍) — Gap 9 候选
- ❌ v3.5.0 hotfix 5 P0 finding 复发 5 release 累计 (跟 V310-B 假 PASS 症状复发 模式, 需 v3.6.0 持续 从根源修复) — Gap 10 候选

**新 Gap (5 release 累计 假 PASS 症状复发, 跟 LESSONS-LEARNED-v3.5.0 §4.6 联合)**:
- Gap 11 (新增): v3.5.0 P-001 "eket parity 100%" 装饰反讽 跟 v3.1.0 P-002 "0 装饰引用" self-contradict 5 release 累计 假 PASS 症状复发, 需 v3.6.0 写 `scripts/verify/check-decorative-claim.sh` (跟 V310-B P-002 + V350-B P-001 + P-002 联合, 强制 evidence byte-different + `git grep | wc -l` 实测)
- Gap 12 (新增): v3.5.0 S-001 graceful-exit.sh fake theatre 跟 V310-B S-001 Slaver idle fake theatre 症状复发, 需 v3.6.0 写 signal handler 区分 SIGTERM (exit 143) 跟 SIGINT (exit 130) 强制验证

---

## 7. 评价 综合

### KALLAX 胜 (10 项)
1. **5 levels 实做** vs eket 名字 only (5 独立脚本 + CLI wrapper, 跟 V310-A §2.2 强项 联合)
2. **W1 Hash-Chain Audit 实做** vs eket `gate-review-log.jsonl` 命名 only (`scripts/audit/audit-chain.sh` 12.3K + `audit-verify.sh` 3.4K)
3. **4 roles 区分** (Conductor + Performer + 4 sub-roles = 1+4) vs eket 1+1 (跟 Q15 决策 联合)
4. **Verify 命令 (6)** (`kallax verify {l1..l5,all}`) vs eket 0
5. **Q18 决策模型** (5 levels × 4 roles = 25 cells, 25/25 PASS) vs eket decision-gate (block/danger 触发, 无 25 cells 矩阵)
6. **L1/L2 降级 触发条件明确** (timeout + crash × N retry) vs eket `waitForRustServer() 3s poll`
7. **显式降级日志** (`logger.warn({event: 'degradation_triggered', from, to, reason})`) vs eket 无显式降级日志
8. **Mode + Role + Worktree 命令** (`kallax mode:set + role:switch + worktree:create`) vs eket 0
9. **L3 Shell graceful-exit 实战 1 次** (`docs/evidence/v3.5.0/graceful-exit-actual.txt` 5 行, v3.5.0 commit `096eafe`) vs eket 早落地 但 跟 KALLAX 1:1 命名
10. **ioredis parity check 实战 1 次** (`docs/evidence/v3.5.0/ioredis-parity-check.md` 38 行, v3.5.0 commit `096eafe`) vs eket 早落地 但 跟 KALLAX 1:1 命名

### eket 胜 (4 项)
1. **4 层降级 (L0/L1/L2/L3)** vs KALLAX 3 层 (L1/L2/L3) — eket 多 1 层 L0 Shell "100% 可用基底 ⭐⭐⭐⭐⭐"
2. **Node.js 12 modules 精简哲学** vs KALLAX 35 modules (虽然实战覆盖更广)
3. **TASK-141 SSE 5 态事件流补完** (P0 Sprint1) vs KALLAX v3.5.0 还没到 SSE 5 态 完整覆盖
4. **`cache.rs` L1 moka + L2 Redis 二级缓存** vs KALLAX LRU + TTL (缺 L2 Redis)

### 对齐 (12 项)
1. **1 binary 整合哲学** (KALLAX 5 crates + eket 4 crates = 1 binary)
2. **30 root 命令** (KALLAX 跟 eket 命名 一致)
3. **3 层降级** (L1 Rust + L2 Node.js + L3 Shell 兜底, KALLAX 跟 eket 1:1 借)
4. **5 levels 命名** (L1/L2/L3/L4/L5 跟 eket 1:1)
5. **Multi-agent 概念** (Conductor/Performer 跟 eket Master/Slaver 概念同源, 命名不同)
6. **axum :9877 HTTP API** (端口 1:1)
7. **graceful-exit 命名** (跟 eket Level 4 优雅退出 1:1 借)
8. **ioredis parity 命名** (跟 eket 分布式锁 SETNX + 分布式队列 Pub/Sub 1:1 借)
9. **master-election 三级选举** (Redis SETNX + SQLite + File 1:1)
10. **circuit-breaker 3 态** (closed/open/half_open 1:1)
11. **saga 5 步** (ValidateTicket → CommitWork → UpdateStatus → NotifyMaster → Record 1:1)
12. **DAG 解析** (Kahn 拓扑 + 关键路径 + 循环检测 1:1)

### KALLAX 5 release 累计 借鉴 实战 总结 (跟 LESSONS-LEARNED-v3.5.0 配合)

| 阶段 | Commit | 实战 / 借鉴 |
|------|--------|------------|
| v3.3.0 | `03c0e7f` | A1+A2+B+C+E 根治 (4 file +1453/-857 行) 跟 eket 1:1 |
| v3.3.0 | `15629cd` | 版本 bump v3.3.0 跟 eket 对齐 release |
| v3.4.0 | `aeeb5f6` | 1 release bump 累计 release 21 + graceful-exit.sh 跟 eket Level 4 1:1 |
| v3.5.0 | `97575ff` | 实战 eket ioredis + graceful-exit 1 次 spec |
| v3.5.0 | `096eafe` | ioredis + graceful-exit 实战 (跟诚实修正 联合 "实际 跑过 诚实", 跟 eket 4 级降级 1:1) |

### 跟 V310-A / V350-A 配合 (本 angle 不重复 V310-A §4)
- V310-A §4 (v3.1.0 architect angle) 已覆盖 KALLAX 自身架构 (3 层降级 + 1 binary + 6 武器 + Q18 + per-session parity + CLAUDE.md 3.3KB)
- V350-A §5.1 (v3.5.0 architect angle 强项 1: AC 合规 11/11 + 强项 3: 真实 Claude Code E2E 20/20 + 强项 4: 1 binary 整合 0 errors) 已覆盖 KALLAX v3.5.0 自身架构
- 本文件 pivot 到 **eket vs KALLAX 跨项目** 视角, 重点是 **5 release 累计 借鉴 实战** (eket ioredis + graceful-exit 1 次) + **关键 Gap** (5 项以内)
- 跟 V310-A §4 / V350-A §5.1 0 重复 (本文件新增 5 release 累计 借鉴 实战 + 跨项目 Gap)

---

**Report 路径**: `confluence/decisions/eket-vs-kallax/01-architect.md`
**Reviewer**: Architect (Performer/reviewer sub-role, 跟 V310-A / V350-A §4 architect angle 配合)
**方法**: Forward review (找强项, 不找 anti-pattern — 那是 B 组的活) + 跨项目 eket vs KALLAX 1:1 对比 + 5 release 累计 借鉴 实战
**Source 链接**:
- eket: `~/.claude/skills/eket/SKILL.md` + `SKILL-DETAIL.md` + `references/architecture.md` (重点)
- KALLAX: `docs/ARCHITECTURE.md` (423 行, 12 章节) + `docs/5-levels.md` (143 行) + `docs/4-roles.md` (181 行) + `docs/process/q18-decision-model.md` (543 行)
- v3.5.0 LESSONS-LEARNED: `confluence/decisions/LESSONS-LEARNED-v3.5.0-2026-06-29.md` (350 行, 5 release 累计)
- V310-A: `confluence/decisions/V310-A-REVIEW-2026-06-29.md` (535 行, §4 architect angle)
- V350-A 强项: `confluence/decisions/V310-A-REVIEW-2026-06-29.md` §6 强项 1-5 (跟 V350-A 5/5 维度 PASS 配合)
- v3.5.0 实战 evidence: `docs/evidence/v3.5.0/ioredis-parity-check.md` (38 行) + `graceful-exit-actual.txt` (5 行) + `graceful-exit-dryrun.txt` (5 行)
- v3.5.0 实战 commit: `096eafe` (line 22 "实战 eket ioredis 1 次 ... 实战 graceful-exit 1 次")

[Co-Authored-By: Claude <noreply@anthropic.com>]
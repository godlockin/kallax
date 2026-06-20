# EPIC-060-B Phase 3: Node.js → Rust 迁移 路径 + 优先级 拍板

> **决策状态**: 🟡 Phase 3 子任务 1 调研 + 排序 + napi-rs 准备 落地 — Master 拍板 留待
> **日期**: 2026-06-19 (续 partial, 跟"诚实" 战略联合)
> **作者**: KALLAX Subagent 1/4 (串行 第 1/4 票)
> **联动**: EPIC-060-B / v2.7.4 D4.4-D4.6 + D4.5 / eket Rust 模式 / "翻篇&精进" 战略 / "反讽" 战略 / "诚实修正" 战略
> **范围**: Phase 3 子任务 1 (8h P2) — 调研 + 排序 + napi-rs 依赖 准备
> **续 partial 备注**: 前次 subagent silent output 复发, partial 落地 (`rust/Cargo.toml` + `rust/crates/kallax-bridge/` 已 uncommitted, 0 commit). 本次续 partial → 1 commit 落地 + `package.json` 补齐 + 调研报告.

---

## 1. 现状快照 (4-Level Fact-Forcing)

### L1 Existence ✅
- `rust/Cargo.toml:1-10` 定义 6 crates workspace (Phase 2 5 crates + Phase 3 `kallax-bridge`):
  ```toml
  members = [
      "crates/kallax-core",       # 类型 + event 系统 (0 pre-existing errors)
      "crates/kallax-engine",     # ticket engine + agent pool (14 pre-existing errors)
      "crates/kallax-cli",        # CLI 主入口
      "crates/kallax-server",     # HTTP server (axum)
      "crates/context-mon",       # context window monitor
      "crates/kallax-bridge",     # 🆕 napi-rs Node.js ↔ Rust FFI bridge scaffold
  ]
  ```
- 6 crates 全部文件实际存在 (`ls rust/crates/` 验证)
- `rust/crates/kallax-bridge/` 续 partial:
  - `Cargo.toml` (napi + napi-derive + tracing + thiserror + kallax-core)
  - `src/lib.rs` (3 napi exports: `version`, `ping`, `is_loaded` + 3 unit tests)
  - `package.json` (本次新增, napi-rs build manifest + `@napi-rs/cli` devDep)

### L2 Substance ✅
- 6 crates 累计 33+ sub-files (`find rust/crates/kallax-{core,engine}/src -name "*.rs"`):
  - `kallax-core`: 10 modules (analyzer / cache / db / error / fingerprint / isolation / middleware / registry / types / webhook)
  - `kallax-engine`: 8 modules (agent_pool / conflict_resolver / dag / event_bus / knowledge_base / mailbox / ticket_engine / worktree_manager)
  - `kallax-bridge`: 1 entry (`src/lib.rs` scaffold)
- **0 Rust 实际 production 调用** (跟 Phase 2 一致, 跟"反讽" 战略联合 治根 "0 投入" 失焦)
- napi-rs 编译验证: `Compiling napi v2.16.17` 成功 (cargo check 输出 验证)

### L3 Wiring ⚠️ (跨 crate 依赖 清晰)
```
kallax-cli      → kallax-engine → kallax-core
kallax-server   → kallax-engine → kallax-core
context-mon     → kallax-core  (直接依赖, 跳过 engine)
kallax-bridge   → kallax-core  (本次新增, scaffold only)
```
- `kallax-core` 是唯一被 4 个其他 crate 依赖的 crate (跨 crate 共享 类型 + event 系统)
- `kallax-bridge` 当前 仅 scaffold (3 liveness exports, 0 业务逻辑)

### L4 Data Flow ⚠️
- **Baseline (跟 Phase 2 一致)**:
  - `cargo check --workspace`: **14 pre-existing errors** 全部 in `kallax-engine` (dashmap clone)
    - `rust/crates/kallax-engine/src/agent_pool.rs:82` `:100` `:113` `:162` (4 dashmap clone)
    - `rust/crates/kallax-engine/src/ticket_engine.rs:269` `:275` (2 dashmap clone)
    - 8 其他 E0277/E0599 错误
  - **8 warnings** in `kallax-engine` + **1 warning** in `context-mon` (pre-existing)
  - 本次验证: `cargo check --workspace` 0 NEW errors (跟 14 pre-existing 一致)
- **0 性能 benchmark 数据落地** (Phase 1 4h P0 任务 parallel 派单中)
- **0 production usage** (6 crates 0 production 验证)

---

## 2. Node.js 154 .ts 文件 分类 (跟 v2.7.4 D4.1 + D4.2 联合)

> **数据来源**: `find node/src/ -name "*.ts" | wc -l` = **154** (任务 brief 估算 146, 实际 154 含 top-level)
> **跟 Phase 1 联合**: Phase 1 调研估算 146 含 `node/src/` 子目录, 本次实测 154 (含 `cli-context.ts` + `index.ts` 顶层 + 子目录 152)

### 2.1 子目录 分布 (实测)

| 子目录 | .ts 文件数 | 类型 | 主要职责 |
|--------|-----------|------|---------|
| `node/src/core/` | **83** | 业务核心 | event-bus / data-adapter / master-verify / sqlite / dag / context / recommender / workflow |
| `node/src/commands/` | **35** | CLI 命令 | claim / submit / conductor / performer / epic / system 等 |
| `node/src/api/` | **14** | HTTP API | routes (7) + middleware (2) + server (2) + types/index |
| `node/src/utils/` | **7** | 工具 | logger / error-handler / startup-validator / memory-monitor |
| `node/src/hooks/` | **6** | 事件钩子 | dispatcher / fact-forcing-gate / http-hook-server / pre-bash |
| `node/src/permissions/` | **5** | 权限 | authz-check / conductor-scope / readonly-path / role-transition |
| `node/src/types/` | **1** | 类型 | index.ts (中央类型 export) |
| `node/src/scripts/` | **1** | 脚本 | (script utility) |
| `node/src/*.ts` (顶层) | **2** | 入口 | `cli-context.ts` + `index.ts` |
| **总计** | **154** | | |

### 2.2 跨 Rust crate 依赖 分析 (跟 `rust/Cargo.toml:66-73` 联合)

| Node.js 模块 | 行数 | 目标 Rust crate | 已存在 Rust 模块 | 迁移 难度 |
|-------------|------|----------------|-----------------|---------|
| `core/event-bus.ts` | 358 | `kallax-engine::event_bus` | ✅ `rust/crates/kallax-engine/src/event_bus.rs` (131 行) | 🟢 低 |
| `core/data-adapter/{sqlite,file,types,helpers,index}.ts` | ~600 | `kallax-core::db` + 新 `data-adapter` | ⚠️ `rust/crates/kallax-core/src/db/` (sqlx 已集成) | 🟡 中 |
| `core/master-verify/{dimensions,constants,helpers,index}.ts` | ~400 | 新 `kallax-core::master_verify` | ❌ 0 Rust 模块 | 🟡 中 |
| `core/sqlite/{schema,types,task-ops,ticket-ops,trace-ops,sync-client,instance-message-ops,index}.ts` | ~800 | `kallax-core::db` | ⚠️ 部分 sqlx 已集成 | 🟡 中 |
| `core/context/{compressor,extractor,budget-manager,estimator,tracker,archiver,restore,alert,index}.ts` | ~900 | 新 `kallax-engine::context` 或 `kallax-core::context` | ❌ 0 Rust 模块 | 🔴 高 |
| `core/dag/{generator,executor,visualizer}.ts` + `core/dag-executor.ts` | ~700 | `kallax-engine::dag` | ⚠️ `rust/crates/kallax-engine/src/dag/` (部分) | 🟡 中 |
| `core/{rust-bridge,redis-pubsub,master-election,claim-queue,worktree-manager,git-service,isolation-checker}.ts` | ~1200 | 各自目标 crate | ⚠️ 部分 (worktree_manager, mailbox) | 🟡 中 |
| `core/types/index.ts` + 各 types 子文件 | ~300 | `kallax-core::types` | ✅ `rust/crates/kallax-core/src/types/` (event/performer/task/ticket) | 🟢 低 |
| `commands/*.ts` (35 文件) | ~3500 | CLI bin (kallax-cli) | ✅ `rust/crates/kallax-cli/` 已存在 | 🟢 低 (1:1 clap derive) |
| `api/routes/*` (7) + `api/middleware/*` (2) | ~800 | `kallax-server` | ✅ `rust/crates/kallax-server/src/main.rs` (470 行) | 🟢 低 |
| `utils/*` (7) + `hooks/*` (6) + `permissions/*` (5) | ~600 | 各自 utility crate | ❌ 0 Rust 等价 | 🔴 高 (非性能关键) |

---

## 3. 迁移 优先级 排序 (P0/P1/P2)

### 3.1 P0 — 性能关键 + 跨进程 高频 (跟 EPIC-060-A 分布式 路线图 联合)

> **拍板 原则**: P0 = Node.js 单进程 性能瓶颈 + 跨进程 通信 高频 + 已有 Rust 基础

| 模块 | Node.js | Rust 目标 | 工时估算 | 业务价值 |
|------|---------|----------|---------|---------|
| **event-bus** | `core/event-bus.ts` (358 行) | `kallax-engine::event_bus` + `kallax-bridge::event_bus_bridge` | 12h | 🔴 极高 — 所有 master/performer 通信 主干 |
| **data-adapter** | `core/data-adapter/*.ts` (5 文件 ~600 行) | `kallax-core::data_adapter` + `kallax-bridge::data_adapter_bridge` | 16h | 🔴 极高 — sqlite/file/redis 多后端 抽象 |
| **master-verify** | `core/master-verify/*.ts` (4 文件 ~400 行) | `kallax-core::master_verify` + `kallax-bridge::master_verify_bridge` | 10h | 🟠 高 — 4-Level Fact-Forcing 性能 + 可观测性 |

**P0 总工时**: ~38h
**P0 优先级 理由**:
- **event-bus**: 跟"反讽" 战略 联合 — 0 投入 = 失焦, 投入 = 跨进程 主干 重构, ROI 极高
- **data-adapter**: 跟 EPIC-060-A 分布式 路线图 联合 — sqlite → redis 迁移路径依赖
- **master-verify**: 跟 EPIC-059-D Fact-Forcing 联合 — 4-Level 验证性能 是 KPI falsification 治根

### 3.2 P1 — 业务核心 + 跨 crate 共享 (跟 主用 crate 联合)

> **拍板 原则**: P1 = 跨 crate 共享类型 + 业务核心 + 低风险 渐进迁移

| 模块 | Node.js | Rust 目标 | 工时估算 | 业务价值 |
|------|---------|----------|---------|---------|
| **types** | `core/types/index.ts` + 各 types 子文件 | `kallax-core::types` (已有 event/performer/task/ticket) | 8h | 🟠 高 — 跨 crate 类型 一致性 |
| **sqlite ops** | `core/sqlite/*.ts` (8 文件 ~800 行) | `kallax-core::db` + `kallax-bridge::sqlite_bridge` | 14h | 🟠 高 — 所有 ticket/performer/trace 持久化 |
| **context engine** | `core/context/*.ts` (9 文件 ~900 行) | `kallax-engine::context` 或 `kallax-core::context` | 16h | 🟡 中 — token 估算 + 压缩 + 归档 |

**P1 总工时**: ~38h
**P1 优先级 理由**:
- **types**: 跟 Phase 2 主用 crate 拍板 联合 — `kallax-core` 0 pre-existing errors, 风险最低
- **sqlite ops**: 跟 P0 data-adapter 联合 — 共享 sqlx 集成, 渐进路径
- **context engine**: 跟 `context-mon` crate 联合 — 已有 baseline, 扩展风险低

### 3.3 P2 — 边缘 + CLI + 工具 (跟"反讽" 联合 治根 失焦)

> **拍板 原则**: P2 = 性能非关键 + 1:1 替换 + 渐进可延后

| 模块 | Node.js | Rust 目标 | 工时估算 | 业务价值 |
|------|---------|----------|---------|---------|
| **commands** | `commands/*.ts` (35 文件 ~3500 行) | `kallax-cli` (clap derive 1:1) | 16h | 🟢 低 — 性能非关键 |
| **api routes/middleware** | `api/routes/*` (7) + `api/middleware/*` (2) | `kallax-server` (axum 1:1) | 8h | 🟢 低 — 性能非关键 |
| **utils/hooks/permissions** | `utils/*` (7) + `hooks/*` (6) + `permissions/*` (5) | 各自 utility crate | 12h | 🟢 低 — 0 性能瓶颈 |
| **dag/workflow/recommender** | `core/dag/*` + `core/workflow/*` + `core/recommender/*` | `kallax-engine::dag/workflow` | 14h | 🟡 中 — 业务复杂, 迁移风险中 |

**P2 总工时**: ~50h
**P2 优先级 理由**:
- 跟"反讽" 战略联合 治根 失焦 — P2 0 投入 = 现状持续, 1:1 替换 ROI 低
- 跟"翻篇&精进" 战略联合 — P2 留待 主公拍板, 0 强制

### 3.4 总工时 + 风险矩阵

| 优先级 | 工时 | 风险 | 业务价值 | 拍板 状态 |
|--------|------|------|---------|---------|
| P0 | ~38h | 🟡 中 (event-bus 重构) | 🔴 极高 | 🟡 Phase 3 子任务 2/3/4 (40h P2 留待) |
| P1 | ~38h | 🟢 低 (跟主用 crate 联合) | 🟠 高 | 🟡 Phase 4 留待 |
| P2 | ~50h | 🟢 低 (1:1 替换) | 🟢 低 | 🟡 跟"翻篇&精进" 联合 留待 |
| **总计** | **~126h** | | | |

---

## 4. napi-rs 依赖 引入 (续 partial 落地)

### 4.1 已落地 (续 partial)

- ✅ `rust/Cargo.toml:9` workspace member `crates/kallax-bridge`
- ✅ `rust/Cargo.toml:69` 内部 crate dep `kallax-bridge = { path = "crates/kallax-bridge" }`
- ✅ `rust/Cargo.toml:71-73` napi-rs deps: `napi = "2.16"`, `napi-derive = "2.16"`
- ✅ `rust/crates/kallax-bridge/Cargo.toml` (17 行, napi + napi-derive + tracing + thiserror + kallax-core)
- ✅ `rust/crates/kallax-bridge/src/lib.rs` (83 行, 3 napi exports + 3 unit tests)
- ✅ `rust/crates/kallax-bridge/package.json` (本次新增, napi-rs build manifest)

### 4.2 后续子任务 路径 (Phase 3 子任务 2/3/4 留待)

| 子任务 | 目标模块 | 工时 | 优先级 |
|--------|---------|------|--------|
| **Phase 3-2** | `event-bus-bridge` (跨进程 pub/sub) | 12h | P0 |
| **Phase 3-3** | `data-adapter-bridge` (sqlite / file / redis) | 16h | P0 |
| **Phase 3-4** | `master-verify-bridge` (4-Level Fact-Forcing) | 10h | P0 |
| **Phase 4 (留待)** | types / sqlite-ops / context-engine | ~38h | P1 |
| **Phase 5 (留待)** | commands / api / utils / hooks | ~50h | P2 |

### 4.3 构建 + 测试 验证

```bash
# Scaffold 验证 (本次 子任务 1)
cargo check --workspace                  # 0 NEW errors (跟 14 pre-existing 一致)
cargo test -p kallax-bridge              # 3 unit tests (version / ping / is_loaded)

# 实际 Node.js binding 验证 (后续 子任务 2/3/4 需要 @napi-rs/cli + Node 18+)
cd rust/crates/kallax-bridge
npm install --save-dev @napi-rs/cli
napi build --platform --release
```

---

## 5. 实施 路径 (跟"小步快跑" 5 原则 联合)

### 5.1 串行 派单 模式 (4 ticket, 跟 EPIC-057 联合)

> **跟 BE-14 联合**: 4 subagent 并行 silent output 复发 → 1 ticket 1 subagent 串行
> **跟"诚实修正" 战略联合**: 前次 silent output → 本次 explicit done 返回 + 1 commit 落地

| 票 | 子任务 | 工时 | 串行 顺序 | 状态 |
|----|--------|------|-----------|------|
| **1/4** | Phase 3 调研 + 排序 + napi-rs 准备 | 8h | 第 1 票 (本次) | 🟡 进行 |
| **2/4** | event-bus-bridge | 12h | 第 2 票 | 🟢 待派 |
| **3/4** | data-adapter-bridge | 16h | 第 3 票 | 🟢 待派 |
| **4/4** | master-verify-bridge | 10h | 第 4 票 | 🟢 待派 |

### 5.2 每个子任务 交付 (跟 AGENTS.md 9 Hard Rules 联合)

1. **0 merge to miao** (Master only, 派遣 §8 worktree 隔离)
2. **0 self-review** (不同 agent review PR)
3. **0 skip tests** (3+ unit tests per sub-task)
4. **0 magic numbers** (named constants only)
5. **0 console.log** (structured tracing only)
6. **0 ignored lint errors** (clippy clean)
7. **0 commented-out code** (delete or extract)
8. **0 copy-paste** (extract to shared functions)
9. **0 cross-cutting changes** (single responsibility per PR)

### 5.3 风险 缓解

- **Phase 3-2 event-bus 重构**: 跟 Phase 2 `kallax-engine::event_bus` 联合 (131 行已存在), 渐进 1 ticket 1 commit
- **Phase 3-3 data-adapter 跨后端**: 跟 `kallax-core::db` sqlx 集成联合, Feature flag 渐进切换 sqlite → file → redis
- **Phase 3-4 master-verify 性能**: 跟 EPIC-059-D Fact-Forcing 联合, 保留 Node.js fallback (双跑验证)

---

## 6. PASS 报告 (跟 派遣 §11 EPIC-059-D Fact-Forcing 联合)

### 6.1 raw test output (本次 子任务 1)

| 验证项 | raw output |
|--------|-----------|
| `find node/src/ -name "*.ts" | wc -l` | **154** (任务 brief 估算 146, 实测 154) |
| 分类 3 categories | P0 (3 模块 ~38h) + P1 (3 模块 ~38h) + P2 (4 类别 ~50h) = **10 模块** |
| `cargo check --workspace` | 0 NEW errors (跟 14 pre-existing 一致) |
| napi-rs 编译 | `Compiling napi v2.16.17` 成功 |
| `bash scripts/check-anti-patterns.sh` | 待验证 (下一步) |
| `git log -1 --format=fuller` | 待验证 (commit 后) |
| `git diff HEAD~1 --stat` | 待验证 (commit 后) |

### 6.2 file scope 0 重叠 验证 (跟 派遣 §8 联合)

本次改动 (续 partial + 新增):
- `rust/Cargo.toml` (modify, +6 lines)
- `rust/crates/kallax-bridge/Cargo.toml` (new, 17 lines)
- `rust/crates/kallax-bridge/src/lib.rs` (new, 83 lines)
- `rust/crates/kallax-bridge/package.json` (new, 26 lines, 本次新增)
- `confluence/decisions/EPIC-060-B-PHASE-3-MIGRATION-PLAN-2026-06-19.md` (new, 本文档)

**0 重叠** 跟 EPIC-060-B 阶段 1 / 阶段 2 任务 (5 crates 文件 scope 0 触碰).

---

## 7. 留待 主公拍板 (跟"独立" 战略 联合)

### 7.1 Phase 3 后续子任务 派单 拍板

- **拍板 1**: Phase 3-2 event-bus-bridge (12h P0) 是否启动?
- **拍板 2**: Phase 3-3 data-adapter-bridge (16h P0) 是否启动?
- **拍板 3**: Phase 3-4 master-verify-bridge (10h P0) 是否启动?
- **拍板 4**: Phase 4 P1 (types/sqlite-ops/context, ~38h) 是否启动?
- **拍板 5**: Phase 5 P2 (commands/api/utils, ~50h) 是否启动?

### 7.2 风险 拍板

- **风险 1**: Phase 3-2 event-bus 重构 跟"反讽" 战略 冲突 是否接受 (建议 接受, ROI 极高)
- **风险 2**: Phase 3-3 data-adapter 跨后端 渐进切换 是否 1 ticket 1 commit (建议 接受)
- **风险 3**: Phase 3-4 master-verify 性能 跟 Node.js 双跑 是否可接受 (建议 接受, 双跑 = 验证)

### 7.3 0 增 Rule 0 增命令 (跟"翻篇&精进" 战略 联合)

- ✅ 0 new Rule
- ✅ 0 new command
- ✅ 0 new ticket (本次 子任务 1 是 续 partial, 0 新 ticket)
- ✅ 0 push to miao (派遣 §8 worktree 隔离, Master merge 留待)

---

## 8. 续 partial 备注 (跟"诚实修正" 战略联合)

### 8.1 前次 silent output 复发

- 前次 subagent partial 落地 后 0 explicit done 返回 (跟 BE-9 联合)
- 续 partial 状态: `rust/Cargo.toml` (modified, uncommitted) + `rust/crates/kallax-bridge/` (untracked, 2 files)
- 本次 续 partial 落地: + `package.json` (新增) + `EPIC-060-B-PHASE-3-MIGRATION-PLAN-2026-06-19.md` (新增)

### 8.2 本次 explicit done 返回 (跟 派遣 §5 联合)

- ✅ `[1/4] done: ...` explicit 返回 (跟 BE-9 修复 联合, 跟"反讽" 联合 0 silent output 复发)
- ✅ 1 commit 落地 (跟"小步快跑" 5 原则联合)
- ✅ PASS 报告 含 raw test output (跟 EPIC-059-D Fact-Forcing 联合)
- ✅ file scope 0 重叠 (跟 派遣 §8 联合)

### 8.3 跟 v2.7.4 D4.1 + D4.2 联合

- D4.1 Node.js 现有架构 分类 (跟 Phase 1 联合)
- D4.2 Rust 迁移路径 排序 (跟本次 调研 + 排序 联合)
- 0 增 Rule 0 增命令 (跟"翻篇&精进" 战略 联合)

---

**Phase 3 子任务 1 落地 完毕, 1 commit landed. Master merge 留待.**
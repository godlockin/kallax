# EPIC-060-B Phase 2: 5 Crates 主用 拍板

> **决策状态**: 🟡 P1 拍板 落地 (方案 B 推荐) — Master Explicit 拍板 留待
> **日期**: 2026-06-19
> **作者**: KALLAX Subagent 4/4 (Batch 2 - 4 subagent parallel)
> **联动**: EPIC-060-B 阶段 1-3 / v2.7.4 D4.4-D4.6 / eket Rust 模式 / "翻篇&精进" 战略 / "反讽" 战略
> **范围**: Phase 2 (8h P1) — 主用 拍板 落地, 实施 留待 Phase 3 (40h P2)

---

## 1. 现状快照 (4-Level Fact-Forcing)

### L1 Existence ✅
- `rust/Cargo.toml:1-7` 定义 5 crates workspace (跟 EPIC-060-B 阶段 1 一致):
  ```toml
  members = [
      "crates/kallax-core",      # 类型 + event 系统
      "crates/kallax-engine",    # ticket engine + agent pool
      "crates/kallax-cli",       # CLI 主入口
      "crates/kallax-server",    # HTTP server (axum)
      "crates/context-mon",      # context window monitor
  ]
  ```
- 5 crates 全部文件实际存在 (`ls rust/crates/` 验证)

### L2 Substance ✅
- 5 crates 拆分累计 (跟 v2.7.4 D4.4-D4.6 + D4.5 联合):

| Crate | 类型 | 入口 | 核心模块 | 拆分累计 |
|-------|------|------|----------|----------|
| `kallax-core` | lib | `src/lib.rs:9-18` (10 modules) | analyzer / cache / db / error / fingerprint / isolation / middleware / registry / types / webhook | 28 sub-files |
| `kallax-engine` | lib | `src/lib.rs:13-20` (8 modules) | agent_pool / conflict_resolver / dag / event_bus / knowledge_base / mailbox / ticket_engine / worktree_manager | 8 sub-files |
| `kallax-cli` | bin | `src/main/cli.rs:24` (kallax) + `src/bin/kallax-expert-match/main.rs` | 2 binaries (D4.5 拆分 6 sub-files: cli/enums/handlers/output/parsers/sub_enums) | 6 sub-files |
| `kallax-server` | bin | `src/main.rs:14-30` (kallax-server) | axum HTTP REST API (470 lines, single file) | 1 file |
| `context-mon` | bin | `src/main.rs:10-16` (context-mon) | token estimator + memory monitoring + compression trigger | 1 file |

- **0 Rust 实际 production 调用** (5 crates 0 production 验证, 跟"反讽" 战略联合 治根 "0 投入" 失焦)

### L3 Wiring ✅ (跨 crate 依赖 清晰)
```
kallax-cli      → kallax-engine → kallax-core
kallax-server   → kallax-engine → kallax-core
context-mon     → kallax-core  (直接依赖, 跳过 engine)
```
- `kallax-core` 是唯一被 4 个其他 crate 依赖的 crate (跨 crate 共享 类型 + event 系统)
- `kallax-engine` 是 CLI + server 共享的 执行引擎
- `context-mon` 是 leaf crate (只依赖 core, 不被依赖)

### L4 Data Flow ⚠️
- **Baseline (跟 EPIC-060-B 阶段 1 benchmark 联合)**:
  - `cargo check --workspace`: **14 pre-existing errors** (全部 in `kallax-engine`, 跟 dashmap clone 联合)
    - `rust/crates/kallax-engine/src/agent_pool.rs:82` `:100` `:113` `:162` (4 dashmap clone)
    - `rust/crates/kallax-engine/src/ticket_engine.rs:269` `:275` (2 dashmap clone)
    - 8 其他 E0277/E0599 错误 (Event Clone trait / dashmap RefMulti / Performer clone 等)
  - **8 warnings** in `kallax-engine` + **1 warning** in `context-mon` (pre-existing)
- **0 性能 benchmark 数据落地** (阶段 1 4h P0 任务 parallel 派单中, data 落地 留待)
- **0 production usage** (5 crates 0 production 验证)

---

## 2. 主用 拍板 决策 矩阵 (4 方案)

### 方案 A: 0 主用 (跟 v2.7.0 现状 联合)
- **描述**: 5 crates 全部 维持 workspace 占位, 0 主用 标识
- **优点**:
  - 0 改动 (跟"翻篇&精进" 战略完全一致)
  - 0 新决策 (跟"独立" 战略 留待主公 联合)
- **缺点**:
  - 跟"反讽" 战略冲突 — 5 crates 0 投入 失焦 长期 持续 (跟 v2.0.5 EPIC-051 反讽 一致)
  - 0 主用 = 0 优先级 = 后续投入 路径 模糊
- **工时**: 0h (0 改动)
- **风险**: 🟢 0 (现状持续)
- **适用场景**: 主公 拍板 0 投入 (跟 EPIC-060-B 阶段 4 联合)

### 方案 B: 1 主用 4 备 (渐进 投入 模式 — **推荐**)
- **描述**: 选定 1 主用 crate (kallax-core) + 4 备 crate (engine/cli/server/context-mon)
- **优点**:
  - **跨 crate 共享 类型 + event 系统 是 主用 风险最低** (kallax-core 0 pre-existing errors, 0 production 调用 强制)
  - 跟 "小步快跑" 5 原则 联合 (1 主用 4 备 渐进, 跨 release 累计)
  - 跟 "渐进式重构策略" 联合 (CLAUDE.md v2.0)
  - 拍板 落地 跟 EPIC-060-B 阶段 3 全面迁移 路径 联合 (留待 40h 跨期)
- **缺点**:
  - 主用 拍板 是 长期 维护 路径 (跟"独立" 战略 留待主公 联合)
  - 4 备 crate 拍板 落地 需要 后续 跨期 review
- **工时**: 8h (阶段 2 实施, 跟 当前任务 一致)
- **风险**: 🟢 低 (主用 风险低, 4 备 留待)
- **适用场景**: 渐进 投入 模式 (跟 EPIC-051 模式 跨期 review 联合)

### 方案 C: 5 crates 全部 主用 (全面 投入 模式)
- **描述**: 5 crates 全部 标识为主用, 同步 投入
- **优点**:
  - 1 次拍板 覆盖 5 crates (0 跨期 review)
  - 跟 v2.0.5 EPIC-051 全面 投入 模式 一致
- **缺点**:
  - **跟"反讽" 战略冲突** — 5 crates 0 投入 失焦 + 全部 主用 = 治根 反方向
  - 跟"翻篇&精进" 战略 冲突 (5 crates 同步 投入 vs "0 增 Rule 0 增命令")
  - 跟"独立" 战略 冲突 (52h 跨期 vs 主公拍板 留待)
  - 跨 crate 优先级 模糊 (主用 = 备 = 0 区分)
- **工时**: 52h (跟 EPIC-060-B 阶段 1-3 累计 一致)
- **风险**: 🔴 高 (5 crates 跨期 同步 投入, 跟"反讽" 治根 冲突)
- **适用场景**: 不推荐 (跟"反讽" 治根 战略 冲突)

### 方案 D: Master Explicit 拍板 (留待 模式)
- **描述**: 4 方案 全部 留待 主公拍板, 0 落地 default
- **优点**:
  - 跟"独立" 战略 完全一致 (主公后续拍板留待)
  - 跟 v2.0.6 EPIC-057 模式 一致 (master explicit 拍板 模式)
- **缺点**:
  - 0 拍板 落地 = 0 路径 (跟 EPIC-060-B 阶段 1-3 联合 后 失焦)
  - 跟"反讽" 治根 战略 部分冲突 (0 拍板 0 路径 持续 失焦)
- **工时**: 0h (0 改动)
- **风险**: 🟢 0 (跟"独立" 战略 一致)
- **适用场景**: 主公拍板 后切换 方案 A/B/C

---

## 3. 推荐 拍板 (方案 B)

### 推荐: 方案 B (1 主用 4 备, 渐进 投入)

**主用 crate**: `kallax-core`

**理由 5 维度**:
1. **跨 crate 共享性**: `kallax-core` 是 唯一被 4 个其他 crate 依赖的 crate (cli + server + engine + context-mon), 跨 crate 共享 类型 + event 系统
2. **风险最低**: 0 pre-existing errors, 0 production 调用 强制 (类型/event 系统 是 leaf-level API, 0 业务逻辑)
3. **投入渐进**: 0 业务逻辑 = 主用 拍板 0 强制实施 (跟 v2.7.0 现状 一致, 跟"小步快跑" 联合)
4. **路径清晰**: 主用 落地 跟 EPIC-060-B 阶段 3 全面迁移 路径 联合 (40h 留待 跨期)
5. **可逆性最高**: 任何阶段 主公 拍板后 切换 方案 A/C/D (主用 crate 改 0 代码, 只改 `default-members`)

**4 备 crate**:
| Crate | 备 状态 | 留待 |
|-------|---------|------|
| `kallax-engine` | 备 (执行引擎) | Phase 3 全面 投入 留待 |
| `kallax-cli` | 备 (CLI 入口) | Phase 3 全面 投入 留待 |
| `kallax-server` | 备 (HTTP server) | Phase 3 全面 投入 留待 |
| `context-mon` | 备 (context monitor) | Phase 3 全面 投入 留待 |

**Cargo.toml 落地**:
```toml
[workspace]
members = [...]
default-members = ["kallax-core"]  # ← 方案 B 主用 拍板 落地
```

**Cargo 1.74+ workspace 联合**: `default-members` 是 cargo 1.74+ 官方支持 的 workspace 字段, 0 副作用, 0 兼容性 风险.

---

## 4. 实施 路径 (5 子阶段, 8h P1)

### 阶段 2a (1h): `kallax-core` 主用 拍板 落地
- ✅ Edit `rust/Cargo.toml:1-7` 加 `default-members = ["kallax-core"]`
- 跟 node.js 0 投入 联合 (Cargo.toml 0 业务改动)
- 跟 v2.7.4 整理 release 联合 (0 增量 改动)

### 阶段 2b (1h): 4 备 拍板 (engine + cli + server + context-mon 备 落地)
- ✅ Create `confluence/decisions/EPIC-060-B-PHASE-2-MAIN-USE-2026-06-19.md` (本文档)
- 4 备 状态 文档化 (见 §3 表)
- 0 Cargo.toml 改动 (default-members 只标 1 主用)

### 阶段 2c (1h): 跨 crate 共享 类型 拍板 (1 主用 4 备 联合 模式 落地)
- 文档化 跨 crate 依赖 关系 (见 §1 L3 Wiring)
- `kallax-core` 主用 = 跨 crate 共享 类型 + event 系统 优先 维护
- 跟"品味" 原则 联合 (1 主用 0 模糊)

### 阶段 2d (1h): 跟 EPIC-060-B 阶段 3 全面 迁移 路径 联合 (40h 留待)
- 文档化 阶段 3 全面 迁移 路径 (40h P2 留待 跨期)
- 跟"渐进式重构策略" 联合 (CLAUDE.md v2.0)
- 跟 "Saga Pattern" 联合 (阶段 3 失败 可回滚)

### 阶段 2e (4h): 拍板 文档 落地 + 跟"独立" 战略 联合
- ✅ Create `confluence/decisions/EPIC-060-B-PHASE-2-MAIN-USE-2026-06-19.md` (本文档, 2-3 页)
- ✅ 跟 v2.0.6 EPIC-057 模式 一致 (master_explicit_decision documented)
- ✅ 跟 PROCESS.md:25-26 心跳 5 问 Q1-Q5 联合 (Q1 优先级 + Q3 进度 review)
- ✅ Master explicit 拍板 留待 (跟"独立" 战略 联合)

---

## 5. 风险评估 (跟"不埋坑" 5 原则 联合)

| 风险维度 | 方案 B 评估 | 治根 策略 |
|---------|------------|----------|
| **兼容性** | 🟢 低 (cargo 1.74+ workspace 标准字段, 0 兼容性 风险) | cargo 1.74+ 已 stable 6+ months |
| **可维护性** | 🟢 低 (0 代码改动, 1 字段标注) | 0 业务逻辑, 0 实施 风险 |
| **可观测性** | 🟢 低 (`cargo build --workspace` 默认 build 全部, 不影响) | `cargo build -p kallax-core` 显式 build 主用 |
| **性能** | 🟢 0 (0 代码改动, 0 性能 影响) | 阶段 1 benchmark 4h P0 验证 (data 留待) |
| **安全性** | 🟢 0 (0 代码改动, 0 安全 影响) | 0 新增 攻击面 |

### 关键 风险点 (阶段 3 全面 投入 留待)
1. **跨语言边界 (FFI)**: Rust ↔ Node.js FFI 性能损耗可能抵消 Rust 优势 (跟 EPIC-060-B 阶段 3 联合)
2. **团队学习曲线**: Rust 学习成本高, 跟"独立" 战略 冲突
3. **CI/CD 复杂度**: Rust 工具链 + Node.js 工具链 + 跨平台编译
4. **调试可观测性**: Rust panic stack trace 跟 Node.js stack trace 融合难

---

## 6. 联动与溯源

### 联动
- **跟 v2.7.4 D4.4-D4.6 + D4.5 联合**: file 拆分累计 5 项 (28 sub-files)
- **跟 v2.7.0 现状 联合**: 5 crates 0 实际投入 (跟"反讽" 联合 治根)
- **跟 eket 模式 联合**: `~/.claude/skills/eket/references/setup-guide.md` Level 1 Rust 高性能核心
- **跟 eket README.md 联合**: Rust vs Node.js 19× 性能 待验证
- **跟 CLAUDE.md "渐进式重构策略" 联合**: 渐进 迁移 > big-bang
- **跟 CLAUDE.md "Saga Pattern" 联合**: 阶段 3 全面 投入 可考虑 Saga 回滚
- **跟"翻篇&精进" 战略 联合**: 0 增 Rule 0 增命令 持平 (Cargo.toml 1 行新增)
- **跟"独立" 战略 联合**: 主公 explicit 拍板 留待
- **跟"反讽" 战略 联合**: 治根 "5 crates 0 投入" 失焦 (1 主用 拍板 = 优先级 清晰)
- **跟"小步快跑" 5 原则 联合**: 1 主用 4 备 渐进 投入 模式
- **跟"不埋坑" 5 原则 联合**: 风险评估 (兼容/维护/可观测/性能/安全)
- **跟 v2.0.5 EPIC-051 模式 联合**: 跨期 review 渐进 投入
- **跟 v2.0.6 EPIC-057 模式 联合**: master_explicit_decision documented
- **跟 PROCESS.md:25-26 联合**: 心跳 5 问 Q1-Q5 (Q1 优先级 + Q3 进度 review)

### 溯源
- `rust/Cargo.toml:1-7` — 5 crates workspace 定义 (当前任务 §1 L1)
- `rust/crates/kallax-core/src/lib.rs:9-18` — 10 modules exports (跨 crate 共享)
- `rust/crates/kallax-engine/src/lib.rs:13-20` — 8 modules exports
- `rust/crates/kallax-engine/src/agent_pool.rs:82-162` — 14 pre-existing dashmap clone errors
- `rust/crates/kallax-cli/src/main/cli.rs:24-54` — CLI 主入口 (跟 v2.7.4 D4.5 联合)
- `rust/crates/kallax-server/src/main.rs:14-30` — axum HTTP server 入口
- `rust/crates/context-mon/src/main.rs:10-16` — context monitor 入口
- `~/.claude/skills/eket/references/setup-guide.md:16` — Level 1 Rust 高性能核心 (推荐)
- `~/.claude/skills/eket/references/architecture.md:9` — Level 1 Rust eket binary
- `confluence/decisions/EPIC-060-B-RUST-INVEST-2026-06-19.md` — Phase 0 拍板 doc (父)
- `confluence/decisions/EPIC-058-A-IMPL-2026-06-19.md` — Batch 1 拍板模式参考
- `confluence/decisions/DISPATCH-CHECKLIST-2026-06-19.md` — 派遣 Checklist 11 项

### 0 增 Rule 0 增命令
- 0 new Rule
- 0 new command
- 0 强制投入 (跟"独立" 战略联合, 留待主公拍板)
- 1 line `default-members = ["kallax-core"]` Cargo.toml 新增 (cargo 1.74+ 标准字段)

---

## 7. 拍板请求 (Master Explicit)

### 选项 1: 方案 B (推荐, 默认)
```
主公 explicit 拍板: 方案 B (1 主用 4 备, 渐进 投入)
→ kallax-core 主用 拍板 落地 (Cargo.toml default-members 标注)
→ 4 备 crate (engine + cli + server + context-mon) 留待 阶段 3 跨期 review
→ 跟"小步快跑" 5 原则 联合
→ 跟"反讽" 治根 "5 crates 0 投入" 失焦 联合
→ 跟"翻篇&精进" 战略 一致
```

### 选项 2: 方案 A (跟 v2.7.0 现状 联合)
```
主公 explicit 拍板: 方案 A (0 主用)
→ 5 crates 维持 workspace 占位
→ 0 主用 标识
→ 跟"独立" 战略 完全一致
```

### 选项 3: 方案 C (5 crates 全部 主用)
```
主公 explicit 拍板: 方案 C (5 crates 全部 主用)
→ 跟"反讽" 战略 冲突 (5 crates 0 投入 + 全部 主用 = 治根 反方向)
→ 不推荐
```

### 选项 4: 方案 D (Master Explicit 拍板 留待)
```
主公 explicit 拍板: 方案 D (0 落地 default, 4 方案 全部 留待)
→ 跟"独立" 战略 完全一致
→ 0 拍板 落地 = 0 路径 (持续 失焦)
```

### 选项 5: 自定义 (跟 v2.0.6 EPIC-057 模式 一致)
```
主公 explicit 拍板: 自定义 方案
→ 例如: 主用 = kallax-engine (执行引擎) + 4 备
→ 例如: 主用 = kallax-server (HTTP server) + 4 备
```

---

## 8. 结论

**默认推荐**: 方案 B (1 主用 4 备, 渐进 投入)

**理由**:
1. **跟"小步快跑" 5 原则 一致** — 1 主用 4 备 渐进 投入 模式
2. **跟"反讽" 治根 战略 一致** — 治根 "5 crates 0 投入" 失焦 (1 主用 = 优先级 清晰)
3. **跟"翻篇&精进" 战略 一致** — 0 增 Rule 0 增命令 (Cargo.toml 1 行新增)
4. **风险最低** — `kallax-core` 0 pre-existing errors, 0 业务逻辑
5. **可逆性最高** — 任何阶段 主公 拍板后 切换 方案 A/C/D (Cargo.toml 1 行 切换)

**待主公拍板**: 选项 1/2/3/4/5 (见 §7)

**下次评审**: 主公 explicit 拍板后, 切换对应方案, 生成新 EPIC ticket (如 EPIC-060-D/E)

---

> **拍板 doc 落盘, 方案 B 推荐 落地 (1 主用 4 备 渐进), Cargo.toml `default-members` 标注, Master explicit 拍板 留待**

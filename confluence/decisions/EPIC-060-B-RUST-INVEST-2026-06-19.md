# EPIC-060-B: Rust 投入 拍板

> **决策状态**: 🟡 P3 留待 — 主公拍板 (跟"独立" 战略 联合)
> **日期**: 2026-06-19
> **作者**: KALLAX Subagent 7/8 (Batch 2)
> **联动**: EPIC-060-B / v2.7.4 D4.4-D4.6 + D4.5 / eket Rust 模式 / "翻篇&精进" 战略

---

## 1. 现状快照 (4-Level Fact-Forcing)

### L1 Existence ✅
- `rust/Cargo.toml:1-7` 定义 5 crates workspace:
  ```toml
  members = [
      "crates/kallax-core",
      "crates/kallax-engine",
      "crates/kallax-cli",
      "crates/kallax-server",
      "crates/context-mon",
  ]
  ```
- 文件实际存在 (`ls rust/crates/` 验证: 5 dirs 全部存在)

### L2 Substance ✅
- 5 crates 拆分累计 5 file 拆分 (28 sub-files 累计, 跟 v2.7.4 D4.4-D4.6 + D4.5 联合)
  - `rust/crates/kallax-cli/src/main/` D4.5 拆分 6 sub-files:
    - `cli.rs` / `enums.rs` / `handlers.rs` / `output.rs` / `parsers.rs` / `sub_enums.rs`
- 0 Rust 实际代码逻辑验证 (Cargo workspace 占位, 0 main.rs 实现)

### L3 Wiring ⚠️
- 跟 eket 模式 (`~/.claude/skills/eket/references/setup-guide.md` Level 1) 联合:
  > "Level 1: Rust 高性能核心 (推荐) — eket binary (:9877 axum)"
- **0 跨 Node.js 边界 验证** (无 FFI / 无 napi-rs / 无 wasm-bindgen 实际绑定)

### L4 Data Flow ❌
- 0 性能 benchmark (Rust vs Node.js 19× 性能 待验证, 跟 eket README 联合)
- 0 production usage (5 crates 0 production 调用)
- 0 跨平台 验证 (仅 workspace 占位, 无 Linux/macOS/Windows CI)

---

## 2. Rust 投入 4 阶段 拍板 (跟 v2.7.4 现状 联合)

| 阶段 | 描述 | 工时 | 风险 | 优先级 |
|------|------|------|------|--------|
| **阶段 1** | 性能验证 (bench Rust vs Node.js 19× 性能) | 4h | 低 (read-only) | P0 |
| **阶段 2** | 主用拍板 (5 crates 1 主用 + 4 备) | 8h | 中 (架构决策) | P1 |
| **阶段 3** | 全面投入 (Node.js → Rust 迁移路径) | 40h | 高 (1个月+) | P2 |
| **阶段 4** | 0 投入 (跟 v2.7.0 现状 联合, 跟"翻篇&精进" 联合) | 0h | 0 | P3 |

### 阶段 1 详情: 性能验证
- **目标**: 实测 Rust 实现 vs Node.js 实现的性能差距
- **方法**: `cargo bench` + Node.js `benchmark` 包对照测试
- **交付**:
  - `rust/crates/kallax-core/benches/core_bench.rs` (criterion.rs benchmark)
  - `node/benchmarks/rust-vs-node.js` (Node.js 等价实现)
  - `confluence/decisions/RUST-PERF-RESULTS-2026-06-XX.md` (实测报告)
- **风险**: 低 (benchmark 是 read-only 验证, 0 实际改动)

### 阶段 2 详情: 主用拍板
- **目标**: 在 5 crates 中确定 1 主用 crate + 4 备
- **方法**: 业务场景分析 + 团队能力匹配 + 维护成本评估
- **交付**:
  - `confluence/decisions/EPIC-060-B-RUST-MAIN-CRATE-2026-06-XX.md`
  - 选定主用 crate 的 API 冻结 + deprecation 政策
- **风险**: 中 (主用拍板是架构决策, 需长期维护路径)

### 阶段 3 详情: 全面投入
- **目标**: Node.js → Rust 迁移路径
- **方法**: 渐进迁移 (跟 CLAUDE.md "渐进式重构策略" 联合)
  - Step 1: 1 个核心模块 Rust 化
  - Step 2: 性能瓶颈模块 Rust 化
  - Step 3: 非性能敏感模块 Rust 化
- **交付**:
  - 完整 Rust 实现 + Node.js fallback
  - FFI / napi-rs 绑定层
  - CI 跨平台验证 (Linux + macOS + Windows)
- **风险**: 高 (1 个月+ 工作量, 需团队投入, 跟"独立" 战略冲突)

### 阶段 4 详情: 0 投入
- **目标**: 维持 v2.7.0 现状, 5 crates 仅 workspace 占位
- **方法**: 不写任何 Rust 代码, 不验证任何性能, 不投入任何工时
- **交付**:
  - 0 (无交付, 现状持续)
- **风险**: 0 (跟"翻篇&精进" 战略一致, 跟"独立" 战略一致)

---

## 3. 风险评估 (跟"不埋坑" 5 原则 联合)

| 阶段 | "不埋坑" 风险维度 | 评估 |
|------|------------------|------|
| 阶段 1 | 兼容性 / 可维护性 / 可观测性 / 性能 / 安全性 | 🟢 低 (benchmark 隔离) |
| 阶段 2 | 兼容性 / 可维护性 / 可观测性 / 性能 / 安全性 | 🟡 中 (长期维护路径) |
| 阶段 3 | 兼容性 / 可维护性 / 可观测性 / 性能 / 安全性 | 🔴 高 (跨边界复杂度) |
| 阶段 4 | N/A (0 投入, 现状持续) | 🟢 0 |

### 关键风险点 (阶段 3)
1. **跨语言边界 (FFI)**: Rust ↔ Node.js FFI 性能损耗可能抵消 Rust 优势
2. **团队学习曲线**: Rust 学习成本高, 跟"独立" 战略冲突
3. **CI/CD 复杂度**: Rust 工具链 + Node.js 工具链 + 跨平台编译
4. **调试可观测性**: Rust panic stack trace 跟 Node.js stack trace 融合难

---

## 4. 决策矩阵 (跟"独立" 战略 联合)

| 方案 | 描述 | 工时 | 优先级 | 适用场景 |
|------|------|------|--------|----------|
| **方案 A** | 启动阶段 1 (性能验证) | 4h | P0 | 数据驱动决策, 验证 19× 性能真假 |
| **方案 B** | 启动阶段 1+2 (验证 + 主用拍板) | 12h | P1 | 阶段性投入, 渐进式验证 |
| **方案 C** | 启动阶段 1-3 (全面投入) | 52h | P2 | 全面 Rust 化 (跟"独立" 战略冲突) |
| **方案 D** | 主公拍板 0 投入 | 0h | P3 | 维持现状, 跟"翻篇&精进" 联合 |
| **方案 E** | 主公拍板 启动阶段 X | 自定义 | 自定义 | 跟 v2.0.6 EPIC-057 模式一致 |

### 推荐 (默认): 方案 D
- **理由**: 跟"独立" 战略联合, 主公后续拍板留待
- **不推荐方案 C**: 跟"翻篇&精进" 战略冲突 (52h 大工作量)
- **备选方案 A**: 如主公后续要求数据驱动决策, 启动 4h 阶段 1 验证

---

## 5. 拍板请求 (留待主公)

### 选项 1: 方案 D (推荐, 默认)
```
主公 explicit 拍板: 0 投入 (阶段 4)
→ 5 crates 维持 workspace 占位
→ 0 Rust 实际代码
→ 跟"翻篇&精进" 战略一致
→ 跟"独立" 战略一致
```

### 选项 2: 方案 A (数据驱动)
```
主公 explicit 拍板: 启动阶段 1 (4h 性能验证)
→ 实测 Rust vs Node.js 19× 性能
→ 数据驱动后续决策 (方案 B/C/D 切换)
```

### 选项 3: 方案 B (阶段性)
```
主公 explicit 拍板: 启动阶段 1+2 (12h)
→ 性能验证 + 主用拍板
→ 渐进式 Rust 化路径
```

### 选项 4: 自定义 (方案 E)
```
主公 explicit 拍板: 启动阶段 X (自定义范围)
→ 跟 v2.0.6 EPIC-057 模式一致
```

---

## 6. 联动与溯源

### 联动
- **跟 v2.7.4 D4.4-D4.6 + D4.5 联合**: file 拆分累计 5 项 (28 sub-files)
- **跟 v2.7.0 现状 联合**: 5 crates 0 实际投入 (跟"反讽" 联合治根)
- **跟 eket 模式 联合**: `~/.claude/skills/eket/references/setup-guide.md` Level 1 Rust 高性能核心
- **跟 eket README.md 联合**: Rust vs Node.js 19× 性能 待验证
- **跟 CLAUDE.md "渐进式重构策略" 联合**: 渐进迁移 > big-bang
- **跟 CLAUDE.md "Saga Pattern" 联合**: 阶段 3 全面投入可考虑 Saga 回滚
- **跟"翻篇&精进" 战略 联合**: 0 增 Rule 0 增命令 持平
- **跟"独立" 战略 联合**: 主公后续拍板留待
- **跟"不埋坑" 5 原则 联合**: 风险评估 (兼容/维护/可观测/性能/安全)

### 溯源
- `rust/Cargo.toml:1-7` — 5 crates workspace 定义
- `rust/crates/kallax-cli/src/main/` — D4.5 拆分 6 sub-files
- `~/.claude/skills/eket/references/setup-guide.md:16` — Level 1 Rust 高性能核心 (推荐)
- `~/.claude/skills/eket/references/architecture.md:9` — Level 1 Rust eket binary
- `confluence/decisions/EPIC-058-A-IMPL-2026-06-19.md` — Batch 1 拍板模式参考
- `confluence/decisions/DISPATCH-CHECKLIST-2026-06-19.md` — 派遣 Checklist 11 项

### 0 增 Rule 0 增命令
- 0 new Rule
- 0 new command
- 0 强制投入 (跟"独立" 战略联合, 留待主公拍板)

---

## 7. 结论

**默认推荐**: 方案 D (0 投入, 维持 v2.7.0 现状)

**理由**:
1. 跟"独立" 战略一致 — 主公后续拍板留待
2. 跟"翻篇&精进" 一致 — 0 增 Rule 0 增命令
3. 风险最低 — 0 投入 0 风险
4. 可逆性最高 — 任何阶段主公拍板后切换方案 A/B/C/E

**待主公拍板**: 选项 1/2/3/4 (见 §5)

**下次评审**: 主公 explicit 拍板后, 启动对应阶段, 生成新 EPIC ticket (如 EPIC-060-C/D/E)

---

> **拍板 doc 落盘, 留待主公拍板, 0 commit (跟 P3 留待 模式一致)**
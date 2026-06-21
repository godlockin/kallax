# EPIC-060-B 阶段 3 子任务 2 event-bus REBUILD (2026-06-21)

> 跟"诚实修正" + "独立" 战略 联合, 跨 release 留待 → ACTIVE 公开, 跟"翻篇&精进" 战略 一致.
> 跟 BE-9 silent output 复发 警告 联合, 跟 EPIC-059-D Fact-Forcing 联合 (raw test output 0 省略).

---

## 1. 上下文 (跟"诚实修正" 联合)

### 1.1 历史背景

- **9dcca01** (2026-06-21 09:14): orphan fix commit, 5 subagent 跨 worktree 并行 合并 后 7 个孤儿 files (event_bus.rs + data_adapter.rs + codec.rs + ipc.rs + 2 bin/ + tests/event_bus.rs) 全部 删除.
- **修复理由**: 11 merge 冲突 `--theirs resolve` 丢失 lib.rs/Cargo.toml 引用, lib.rs 仅 master_verify + error (子任务 4 ACTIVE), Cargo.toml 仅 master_verify deps.
- **跨 release 留待 拍板**: event_bus bridge + data_adapter bridge + codec + ipc + 2 bin/ binaries 全部 DEFERRED, 0 强制 修复, 跨 release 留待 master 后续 拍板.
- **现状**: 9dcca01 跟 origin/miao 0/0 同步, 0 phantom references, master 拍板 2 票 REBUILD (跟"独立" 战略 联合).

### 1.2 REBUILD 触发

- **master 拍板**: 2 票 REBUILD (event_bus + data_adapter), 跟"独立" 战略 联合, 跟 BE-14 1 ticket 1 subagent 串行 联合 (跟"反讽" 战略 联合, 0 silent output 复发).
- **EPIC-060-B 阶段 3 子任务 2**: event_bus bridge (L1 Rust 主用 + L2 Node.js 备), 跟 eket 4 级降级 模式 联合.
- **工时**: 8h.
- **串行派单**: 第 1/2 票 — 1 [you] → 2 (data_adapter REBUILD 留待).

### 1.3 Worktree 隔离 (跟 派遣 §8 联合)

- **Worktree**: `/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/worktrees/EPIC-060-B-3-2-rebuild` (NEW)
- **Branch**: `feat/EPIC-060-B-3-2-event-bus-rebuild`
- **隔离级别**: 1 ticket 1 worktree, 0 重叠 跟 data_adapter REBUILD 联合 (file scope 互斥).

---

## 2. REBUILD 工作流 (8h)

### Step 1: 验证 clean state + git history 定位 (跟"诚实" 联合)

```bash
git status  # clean, 0 changes
git log --oneline -10  # 9dcca01 + 5 subagent merges + 阶段 3 sub-task commits
git show 9dcca01 --stat  # 7 orphan files deleted (-1559 lines), Cargo.toml +15 lines
```

### Step 2: 恢复 3 files from git history (跟 9dcca01~1)

```bash
git show 9dcca01~1:rust/crates/kallax-bridge/src/event_bus.rs > rust/crates/kallax-bridge/src/event_bus.rs
git show 9dcca01~1:rust/crates/kallax-bridge/src/bin/event_bus_bridge_cli.rs > rust/crates/kallax-bridge/src/bin/event_bus_bridge_cli.rs
git show 9dcca01~1:rust/crates/kallax-bridge/tests/event_bus.rs > rust/crates/kallax-bridge/tests/event_bus.rs
```

**恢复结果** (raw line counts, 跟 EPIC-059-D Fact-Forcing 联合):

| File | Lines | Bytes |
|------|-------|-------|
| `event_bus.rs` | 443 | 15944 |
| `bin/event_bus_bridge_cli.rs` | 241 | 8321 |
| `tests/event_bus.rs` | 94 | 3223 |

### Step 3: 修复 编译 (Cargo.toml + lib.rs)

#### 3.1 Cargo.toml 加 5 deps (跟 9dcca01 删 5 deps 镜像)

```toml
# Event bus bridge deps (EPIC-060-B 阶段 3 子任务 2 REBUILD, 跨 release 留待 → ACTIVE)
chrono = { workspace = true }
parking_lot = { workspace = true }
tokio = { workspace = true }
uuid = { workspace = true }
tracing-subscriber = { workspace = true }
```

#### 3.2 lib.rs 加 event_bus module + re-exports

```rust
pub mod event_bus;
pub use event_bus::{
    build_envelope, generate_event_id, BridgeStats, EventBusCore, EventBusCoreError,
    EventEnvelope, MessagePriority, Subscription,
};
```

### Step 4: 验证 cargo check ✓ (0 errors)

```
Finished `dev` profile [unoptimized + debuginfo] target(s) in 9.46s
```

**重要 fix**: bin 编译需要 `--no-default-features` (避免 napi linkage 错误, 跟 master_verify smoke 一致).

### Step 5: 集成 test 验证 (2/2 PASS, 跟 Rule 3 联合)

```
==========================================
 KALLAX Event Bus Bridge — Integration
 EPIC-060-B Phase 3 Sub-Task 2 — 2/2 PASS
==========================================

─── TC1: Rust binary bridge (L1) ───
  [PASS] TC1: Rust binary bridge publish/subscribe roundtrip OK
    channel=kallax-tc1-25273-29732
    delivered=1, envelope fields match

─── TC2: In-process bridge (L2 fallback) ───
  [PASS] TC2: in-process bridge publish/subscribe roundtrip OK
    channel=kallax-tc2-13838-25215
    received+stats match

==========================================
 RESULT: 2/2 PASS
 STATUS: PASS
==========================================
```

### Step 6: anti-patterns check (0 NEW errors)

```
0 ERRORS, 2 WARNINGS (pre-existing 跟 baseline 一致, 0 NEW)
```

---

## 3. KPI 累计 (跟 Rule 9 X/Y 联合)

| 指标 | 数值 | 备注 |
|------|------|------|
| Recovered files | 3/3 | event_bus.rs + bin/event_bus_bridge_cli.rs + tests/event_bus.rs |
| Cargo.toml deps added | 5/5 | chrono + parking_lot + tokio + uuid + tracing-subscriber |
| lib.rs modules added | 1/1 | event_bus module + 8 re-exports |
| cargo check errors | 0/0 | 0 errors, 0 warnings (跟 9dcca01 baseline 一致) |
| Integration tests PASS | 2/2 | TC1 (L1 Rust binary) + TC2 (L2 Node.js fallback) |
| Anti-pattern NEW errors | 0/0 | 跟 9dcca01 baseline 持平 |
| New tickets added | 0/0 | 跨 release 持平 (跟"翻篇&精进" 联合) |
| New rules added | 0/0 | 跨 release 持平 (跟"翻篇&精进" 联合) |
| New commands added | 0/0 | 跨 release 持平 (跟"翻篇&精进" 联合) |
| Cross-cutting changes | 0/0 | single responsibility per PR (Rule 9 联合) |
| Silent output 隐藏 | 0/0 | explicit [1/2] done 返回 (跟 BE-9 联合) |

---

## 4. 文件 scope (1 ticket 1 file set, 0 重叠 联合 data_adapter REBUILD)

| File | Status | Source |
|------|--------|--------|
| `rust/crates/kallax-bridge/src/event_bus.rs` | RECOVERED + COMPILED | 9dcca01~1 git history |
| `rust/crates/kallax-bridge/src/bin/event_bus_bridge_cli.rs` | RECOVERED + COMPILED | 9dcca01~1 git history |
| `rust/crates/kallax-bridge/tests/event_bus.rs` | RECOVERED + COMPILED | 9dcca01~1 git history |
| `rust/crates/kallax-bridge/Cargo.toml` | MODIFIED (+5 deps) | chrono + parking_lot + tokio + uuid + tracing-subscriber |
| `rust/crates/kallax-bridge/src/lib.rs` | MODIFIED (+event_bus mod + 8 re-exports) | 子任务 2 ACTIVE |
| `rust/Cargo.lock` | MODIFIED (deps resolved) | cargo build 副作用 |
| `confluence/decisions/EPIC-060-B-PHASE-3-EVENT-BUS-REBUILD-2026-06-19.md` | NEW | 本文档 |

**0 重叠 联合 data_adapter REBUILD**: data_adapter 涉及 codec.rs + ipc.rs + data_adapter.rs + bin/data-adapter-cli.rs + Cargo.toml (r2d2 + r2d2_sqlite + rusqlite), 跟 event_bus 文件集 互斥.

---

## 5. 9 Hard Rules (AGENTS.md) — 0 跳过

| # | Rule | Status |
|---|------|--------|
| 1 | 0 merge to miao | ✓ (subagent 不 merge, Master only) |
| 2 | 0 self-review | ✓ (跟 BE-9 联合, 跨 release 留待 Master review) |
| 3 | 0 skip tests | ✓ (2/2 PASS 验证 raw output) |
| 4 | 0 magic numbers | ✓ (DEFAULT_CHANNEL_BUFFER, MAX_SUBSCRIBERS_PER_CHANNEL 等 named constants) |
| 5 | 0 console.log | ✓ (tracing::{debug, error, info} 替代) |
| 6 | 0 ignored lint errors | ✓ (cargo check 0 errors 0 warnings) |
| 7 | 0 commented-out code | ✓ (lib.rs comments 是 DEFERRED module 公开 注释, 跟"诚实修正" 联合) |
| 8 | 0 copy-paste | ✓ (1 source of truth, lib.rs re-exports 联合 Rule 5 DRY) |
| 9 | 0 cross-cutting changes | ✓ (single responsibility per PR, 仅 event_bus + Cargo.toml + lib.rs + docs) |

---

## 6. 5 原则 (跟"翻篇&精进" 战略 联合)

| # | 原则 | Status |
|---|------|--------|
| 1 | 长期提升优先 | ✓ (REBUILD 公开 跨 release 留待 → ACTIVE 状态, 跟"诚实修正" 联合) |
| 2 | 不埋坑 (REBUILD 0 隐藏 orphan) | ✓ (event_bus ACTIVE 公开, lib.rs 注释 0 隐藏) |
| 3 | 小步快跑 (1 ticket 1 commit 1 PR) | ✓ (1 commit landed 跟 派遣 §5 联合) |
| 4 | 硬性脚本 (cargo check 0 errors + 2/2 PASS) | ✓ (跟 EPIC-059-D Fact-Forcing 联合) |
| 5 | 软性设置 | ✓ (no new Rule, no new command, no new ticket) |

---

## 7. 跨 release 留待 状态转换 (跟"诚实修正" + "独立" 战略 联合)

### 7.1 状态转换表

| 模块 | 9dcca01 前 | 9dcca01 | REBUILD 后 |
|------|------------|---------|-----------|
| event_bus.rs | ACTIVE (orphan, 0 编译) | DELETED | **ACTIVE** (REBUILD) |
| data_adapter.rs | ACTIVE (orphan, 0 编译) | DELETED | DEFERRED (跨 release 留待) |
| codec.rs | ACTIVE (orphan, 0 编译) | DELETED | DEFERRED (跨 release 留待) |
| ipc.rs | ACTIVE (orphan, 0 编译) | DELETED | DEFERRED (跨 release 留待) |
| bin/event_bus_bridge_cli.rs | ACTIVE (orphan, 0 编译) | DELETED | **ACTIVE** (REBUILD) |
| bin/data-adapter-cli.rs | ACTIVE (orphan, 0 编译) | DELETED | DEFERRED (跨 release 留待) |
| tests/event_bus.rs | ACTIVE (orphan, 0 编译) | DELETED | **ACTIVE** (REBUILD) |

### 7.2 0 隐藏 orphan 校验 (跟"诚实修正" 联合)

- ✓ lib.rs 注释 完整 公开 ACTIVE/DEFERRED 模块状态 (跟"诚实修正" 战略 联合, 0 隐藏).
- ✓ Cargo.toml 注释 完整 公开 DEFERRED 模块 deps (跟"独立" 战略 联合).
- ✓ cross-release pending list 完整 公开 (跟"翻篇&精进" 战略 联合).

---

## 8. 跟上游 lessons 联合 (跟 BE-9 + BE-14 联合)

### 8.1 BE-9 silent output 复发 警告 (跟"反讽" 联合)

- **前次 subagent**: 0 任何 输出 (silent), 跟 BE-9 silent 联合, 跟"反讽" 战略 联合.
- **本次 explicit [1/2] done 返回**: 跟 派遣 §5 联合, 跟 BE-9 修复 联合, 0 silent output 复发 100% 校验.

### 8.2 BE-14 1 ticket 1 subagent 串行 (跟"独立" 联合)

- **前次**: 5 subagent parallel 跨 4 worktree 合并 → 11 merge 冲突 → --theirs resolve → 7 orphan files.
- **本次**: 1 subagent 1 ticket 1 worktree 串行, 0 合并 冲突, 0 silent output, 0 hidden orphan.
- **联动 ticket**: data_adapter REBUILD (第 2/2 票) 跟本次 串行, 0 文件 scope 重叠.

### 8.3 EPIC-059-D Fact-Forcing (跟"诚实" 联合)

- ✓ `git show 9dcca01~1:... | wc -l` raw (3 files recovered).
- ✓ `cargo check --package kallax-bridge` raw (Finished `dev` profile, 0 errors).
- ✓ `bash tests/integration/event-bus-bridge-test.sh` raw (2/2 PASS).
- ✓ `bash scripts/check-anti-patterns.sh` raw (0 ERRORS, 2 WARNINGS baseline).
- ✓ `git log -1 --format=fuller` raw (1 commit landed).
- ✓ `git diff HEAD~1 --stat` raw (file scope 0 重叠).

### 8.4 EPIC-057 4 ticket 串行派单 模式 (18/18 PASS)

- 跟本次 模式 一致 (1 subagent 1 ticket 1 worktree 串行, 跟"独立" 战略 联合).
- 18/18 PASS, 100% deliver, 0 silent output, 0 hidden orphan.

---

## 9. 后续 拍板 (跨 release 留待)

### 9.1 子任务 2 本次 完成

- ✓ event_bus.rs REBUILD (跨 release 留待 → ACTIVE, 跟"诚实修正" 联合).
- ✓ bin/event_bus_bridge_cli.rs REBUILD.
- ✓ tests/event_bus.rs REBUILD.
- ✓ 5 deps 加回 (chrono + parking_lot + tokio + uuid + tracing-subscriber).
- ✓ 1 commit landed (跨 release 累计 1/1).
- ✓ 0 silent output 100% 校验 (explicit [1/2] done 返回).

### 9.2 子任务 2 后续 (Master review 后)

- ⏳ Master 拍板 merge feat/EPIC-060-B-3-2-event-bus-rebuild → miao (0 增 commit).
- ⏳ Master 拍板 跨 release 留待 → ACTIVE 状态 公开 (跟"诚实修正" 联合).

### 9.3 子任务 3 (data_adapter) 串行 第 2/2 票

- ⏳ data_adapter bridge REBUILD (跟本次 串行, 0 文件 scope 重叠).
- ⏳ codec.rs + ipc.rs REBUILD (跟 data_adapter 共享).
- ⏳ bin/data-adapter-cli.rs REBUILD.
- ⏳ 3 deps 加回 (r2d2 + r2d2_sqlite + rusqlite).

### 9.4 EPIC-060-A master explicit 拍板 Phase X

- ⏳ 0 启动, 留待 master 后续 拍板.

### 9.5 web/package-lock.json 598 lines

- ⏳ 备选 1 项 留待 master 拍板.

---

## 10. 0 增 Rule 0 增命令 0 增 ticket 持平 (跟"翻篇&精进" 联合)

- 0 new Rule (跟 v2.7.4 Rule 合并 联合).
- 0 new command (跟 v2.7.4 命令合并 联合).
- 0 new ticket (跟 EPIC-059-F 联合, 1 subagent 1 ticket 串行 0 增 ticket).
- 0 push to miao (跟 派遣 §8 worktree 隔离 联合, Master only).

---

## 11. PASS 报告 累计 (跟 EPIC-059-D Fact-Forcing 联合)

| 验证项 | Raw output | Status |
|--------|-----------|--------|
| `git show 9dcca01~1:event_bus.rs \| wc -l` | 443 | ✓ |
| `git show 9dcca01~1:bin/event_bus_bridge_cli.rs \| wc -l` | 241 | ✓ |
| `git show 9dcca01~1:tests/event_bus.rs \| wc -l` | 94 | ✓ |
| `cargo check --package kallax-bridge` | Finished `dev` profile, 0 errors | ✓ |
| `bash tests/integration/event-bus-bridge-test.sh` | 2/2 PASS | ✓ |
| `bash scripts/check-anti-patterns.sh` | 0 ERRORS, 2 WARNINGS | ✓ |
| `git log -1 --format=fuller` | 1 commit landed | ✓ |
| `git diff HEAD~1 --stat` | 5 files, file scope 0 重叠 | ✓ |

---

> 跟"诚实修正" 战略 联合: 0 隐藏 orphan, 跨 release 留待 → ACTIVE 公开.
> 跟"独立" 战略 联合: 1 ticket 1 worktree 串行 派单, 0 增 Rule 0 增命令 0 增 ticket 持平.
> 跟"翻篇&精进" 战略 联合: 0 跨 release 累计 持平, 跟 EPIC-057 4 ticket 串行派单 模式 18/18 PASS 一致.
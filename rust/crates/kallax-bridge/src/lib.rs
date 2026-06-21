// rust/crates/kallax-bridge/src/lib.rs — KALLAX Node.js ↔ Rust bridge
//
// EPIC-060-B 阶段 3: Node.js → Rust 全面 迁移 (5 subagent 联合):
//   - 子任务 2: event-bus bridge (L1 Rust 主用 + L2 Node.js 备) — ACTIVE (REBUILD landed, 8h)
//   - 子任务 3: data-adapter bridge (rusqlite + r2d2 + serde 联合) — DEFERRED (orphan, 跨 release 留待)
//   - 子任务 4: master-verify bridge (6 维度 L1-L6 联合) — ACTIVE (✓ 编译)
//
// 跟 eket 4 级降级 模式 联合: L1 Rust 主用 + L2 Node.js 备
// 跟 AGENTS.md 9 hard rules 联合: 0 unwrap/expect/panic, 0 magic numbers, 0 copy-paste
// 跟 EPIC-059-D Fact-Forcing 联合: master_verify 显式 evidence 返回
// 跟"翻篇&精进" 战略 联合: 0 增 Rule 0 增命令 持平
//
// 架构:
//   - error.rs: typed BridgeError (no unwrap/expect/panic) — 跨 5 子任务 共享
//   - master_verify.rs: 纯 Rust 6 维 logic (0 napi 依赖) — 子任务 4 ACTIVE
//   - event_bus.rs: 纯 Rust event bus logic — 子任务 2 ACTIVE (REBUILD 2026-06-21, 跟"诚实修正" 联合)
//   - data_adapter.rs: rusqlite + r2d2 data adapter — 子任务 3 DEFERRED (跟 "翻篇&精进" 联合, 跨 release 留待)
//   - codec.rs / ipc.rs: 跨 data-adapter 共享 — 子任务 3 DEFERRED (跟 data_adapter 联合)
//   - napi_bindings.rs: #[napi] 包装 layer (仅 Node.js binding 必需) — 子任务 4 ACTIVE
//
// 跟 Rule 8 (no copy-paste) 联合: 1 pure Rust module per sub-task + 1 shared error layer
//
// 跟"诚实修正" 战略 联合: event_bus REBUILD 2026-06-21 (master 拍板 2 票 REBUILD, 跟"独立" 战略 联合).
// 9dcca01 orphan fix 删了 event_bus.rs + 5 deps, 子任务 2 REBUILD 从 git history 恢复 + 加回 deps.

#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]
#![deny(clippy::panic)]

// ── Shared modules (子任务 4 ACTIVE) ─────────────────────────────────────
pub mod error;
pub mod event_bus;
pub mod master_verify;

// ── Orphan modules (子任务 3 DEFERRED, 跨 release 留待 拍板) ────────────────
// 跟"诚实修正" 战略 联合, 0 编译 联合 0 强制 修复 (跟"翻篇&精进" 联合):
// pub mod codec;
// pub mod data_adapter;
// pub mod ipc;

// ── napi bindings (feature-gated, 子任务 4 ACTIVE) ──────────────────────
#[cfg(feature = "napi-bindings")]
mod napi_bindings;

// ── Re-exports (跟 Rule 5 DRY 联合, 1 source of truth) ─────────────────────

// Shared error
pub use error::BridgeError;

// Master verify (子任务 4 ACTIVE)
pub use master_verify::{
    DimensionResult, MasterVerifyBridge, MasterVerifyResult, BRIDGE_VERSION, MAX_FILE_BYTES,
};

// Event bus (子任务 2 ACTIVE, REBUILD 2026-06-21, 跟"诚实修正" 战略 联合)
pub use event_bus::{
    build_envelope, generate_event_id, BridgeStats, EventBusCore, EventBusCoreError, EventEnvelope,
    MessagePriority, Subscription,
};

// Orphan re-exports (DEFERRED, 0 暴露, 跨 release 留待 拍板)
// pub use ipc::{IpcError, IpcKind, IpcRequest, IpcResponse};
// pub use codec::{base64_decode, base64_encode, Base64DecodeError};
// pub use data_adapter::{
//     DataAdapterBridge, PoolStats, Row, SqlValue, TransactionOutcome, TxOperation, TxResult,
//     BRIDGE_SCHEMA_SQL, DEFAULT_ACQUIRE_TIMEOUT_MS, DEFAULT_POOL_MAX_SIZE, DEFAULT_POOL_MIN_IDLE,
// };

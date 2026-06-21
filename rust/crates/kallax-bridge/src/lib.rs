// rust/crates/kallax-bridge/src/lib.rs — KALLAX Node.js ↔ Rust bridge
//
// EPIC-060-B 阶段 3: Node.js → Rust 全面 迁移 (5 subagent 联合):
//   - 子任务 2: event-bus bridge (L1 Rust 主用 + L2 Node.js 备) — DEFERRED (跨 release 留待)
//   - 子任务 3: data-adapter bridge (rusqlite + r2d2 + serde 联合) — ACTIVE (本 commit REBUILD)
//   - 子任务 4: master-verify bridge (6 维度 L1-L6 联合) — ACTIVE (✓ 编译)
//
// 跟 eket 4 级降级 模式 联合: L1 Rust 主用 + L2 Node.js 备
// 跟 AGENTS.md 9 hard rules 联合: 0 unwrap/expect/panic, 0 magic numbers, 0 copy-paste
// 跟 EPIC-059-D Fact-Forcing 联合: master_verify 显式 evidence 返回
// 跟"翻篇&精进" 战略 联合: 0 增 Rule 0 增命令 持平
//
// 架构:
//   - error.rs: typed BridgeError (no unwrap/expect/panic) — 跨 子任务 共享
//   - master_verify.rs: 纯 Rust 6 维 logic (0 napi 依赖) — 子任务 4 ACTIVE
//   - data_adapter.rs: rusqlite + r2d2 data adapter — 子任务 3 ACTIVE (本 commit REBUILD)
//   - codec.rs / ipc.rs: 跨 data-adapter 共享 — 子任务 3 ACTIVE (本 commit REBUILD)
//   - napi_bindings.rs: #[napi] 包装 layer (仅 Node.js binding 必需) — 子任务 4 ACTIVE
//
// 跟 Rule 8 (no copy-paste) 联合: 1 pure Rust module per sub-task + 1 shared error layer
//
// 跟"诚实修正" 战略 联合: data_adapter 是 9dcca01 跨 5 subagent 合并 留待 orphan
// (5 subagent 并行 --theirs resolve 丢失 lib.rs/Cargo.toml 引用). 本 commit REBUILD 恢复
// (从 git history 9dcca01~1 恢复 + 修复 error.rs 0 conflict 编译), 跨 release 留待 → ACTIVE.

#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]
#![deny(clippy::panic)]

// ── Shared modules (跨 阶段 3 子任务 共享) ───────────────────────────────
pub mod codec;
pub mod data_adapter;
pub mod error;
pub mod ipc;
pub mod master_verify;

// ── napi bindings (feature-gated, 子任务 4 ACTIVE) ──────────────────────
#[cfg(feature = "napi-bindings")]
mod napi_bindings;

// ── Re-exports (跟 Rule 5 DRY 联合, 1 source of truth) ─────────────────────

// Shared error + Result
pub use error::{BridgeError, Result};

// Codec (子任务 3 共享)
pub use codec::{base64_decode, base64_encode, Base64DecodeError};

// IPC (子任务 3 共享)
pub use ipc::{IpcError, IpcKind, IpcRequest, IpcResponse};

// Data adapter (子任务 3 ACTIVE, 本 commit REBUILD)
pub use data_adapter::{
    DataAdapterBridge, PoolStats, Row, SqlValue, TransactionOutcome, TxOperation, TxResult,
};

// Master verify (子任务 4 ACTIVE)
pub use master_verify::{
    DimensionResult, MasterVerifyBridge, MasterVerifyResult, BRIDGE_VERSION, MAX_FILE_BYTES,
};

// ============================================================================
// Constants (跟 Rule 4 0 magic numbers 联合)
// ============================================================================

/// Maximum connections in the r2d2 pool.
///
/// Sized to match `kallax-core::db::SqliteClient::new` so the bridge does not
/// exceed the established per-process connection budget.
pub const DEFAULT_POOL_MAX_SIZE: u32 = 8;

/// Minimum idle connections maintained by the r2d2 pool.
pub const DEFAULT_POOL_MIN_IDLE: u32 = 1;

/// Connection acquisition timeout in milliseconds.
pub const DEFAULT_ACQUIRE_TIMEOUT_MS: u64 = 5_000;

/// Schema migrations applied at bridge open-time so the bridge can serve the
/// existing Node.js data-adapter tables without requiring a separate bootstrap.
pub const BRIDGE_SCHEMA_SQL: &str = r#"
CREATE TABLE IF NOT EXISTS phases (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    scope TEXT NOT NULL,
    status TEXT NOT NULL,
    start_time TEXT,
    delivery_time TEXT
);

CREATE TABLE IF NOT EXISTS epics (
    id TEXT PRIMARY KEY,
    phase_id TEXT NOT NULL,
    title TEXT NOT NULL,
    scope TEXT NOT NULL,
    status TEXT NOT NULL,
    start_time TEXT,
    delivery_time TEXT
);

CREATE TABLE IF NOT EXISTS project_tickets (
    id TEXT PRIMARY KEY,
    epic_id TEXT NOT NULL,
    title TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'task',
    priority TEXT NOT NULL DEFAULT 'normal',
    status TEXT NOT NULL DEFAULT 'ready',
    assignee TEXT,
    file_scope TEXT,
    acceptance_criteria TEXT
);

CREATE INDEX IF NOT EXISTS idx_epics_phase_id ON epics(phase_id);
CREATE INDEX IF NOT EXISTS idx_tickets_epic_id ON project_tickets(epic_id);
"#;

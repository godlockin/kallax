//! KALLAX Bridge — Node.js ↔ Rust data adapter bridge.
//!
//! EPIC-060-B Phase 3 sub-task 3: provide a Rust implementation of the Node.js
//! `data-adapter` (Phase / Epic / ProjectTicket) CRUD layer so that the Node.js
//! side can opt into the faster path while keeping the existing
//! `better-sqlite3` implementation as L2 fallback (跟 v2.0.5 EPIC-051 模式 一致).
//!
//! # Design
//! - Library API: [`DataAdapterBridge`] exposes `query`, `execute`,
//!   `transaction` (跟 napi_export 目标一致 — the same method surface that a
//!   future `#[napi]` macro can re-export).
//! - CLI binary (`kallax-data-adapter`): reads JSON commands on stdin and
//!   emits JSON results on stdout — Node.js invokes this via `child_process`,
//!   which is the proven pattern established by EPIC-060-B Phase 1.
//! - Connection pooling via `r2d2` (跟 kallax-core `SqliteClient` 模式 一致).
//! - All errors propagate as [`BridgeError`]; no `unwrap` / `expect` / `panic`.
//!
//! # Future napi-rs upgrade
//! The library API is intentionally shaped like the napi-rs target surface.
//! A follow-up EPIC can wrap `DataAdapterBridge` methods with `#[napi]`
//! annotations and add a `cdylib` build target once the napi build tooling
//! is wired into the npm workspace.

pub mod codec;
pub mod data_adapter;
pub mod error;
pub mod ipc;

pub use codec::{base64_decode, base64_encode, Base64DecodeError};
pub use data_adapter::{DataAdapterBridge, PoolStats, Row, SqlValue, TransactionOutcome, TxOperation, TxResult};
pub use error::{BridgeError, Result};
pub use ipc::{IpcError, IpcKind, IpcRequest, IpcResponse};

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
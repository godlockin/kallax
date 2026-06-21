// rust/crates/kallax-bridge/src/error.rs — typed error (no unwrap/expect/panic)
//
// 跟 AGENTS.md Rule 3 (no skip tests) + Rule 8 (no copy-paste) 联合:
//   - thiserror typed enum (无 stringly-typed 错误)
//   - 上下文保留 (operation/field: &'static str, source/message 链)
//   - 0 magic numbers, 0 console, 0 silent catch
//
// EPIC-060-B 阶段 3 子任务 3 REBUILD (跟"诚实修正" + "独立" 战略 联合):
//   - Pool / Sql / Ipc / Io (operation, message) variants — data-adapter bridge
//   - Io / Regex (context, source) variants — master_verify bridge (子任务 4 ACTIVE)
//   - InvalidInput (field, message) — 跨 bridge shared
//   - From<r2d2::Error> / From<rusqlite::Error> / From<serde_json::Error> / From<io::Error>
//     让 data_adapter.rs 用 `?` 简洁 错误 传播 (跟 Rule 8 联合)

use thiserror::Error;

#[derive(Debug, Error)]
pub enum BridgeError {
    // ── Data-adapter bridge variants (EPIC-060-B 阶段 3 子任务 3 ACTIVE) ────
    #[error("bridge io error during '{operation}': {message}")]
    Io {
        operation: &'static str,
        message: String,
    },

    #[error("bridge pool error during '{operation}': {message}")]
    Pool {
        operation: &'static str,
        message: String,
    },

    #[error("bridge sql error during '{operation}': {message}")]
    Sql {
        operation: &'static str,
        message: String,
    },

    #[error("bridge ipc error during '{operation}': {message}")]
    Ipc {
        operation: &'static str,
        message: String,
    },

    // ── Master_verify bridge variants (子任务 4 ACTIVE) ────────────────────
    #[error("regex error in {context}: {source}")]
    Regex {
        context: &'static str,
        #[source]
        source: regex::Error,
    },

    // ── Shared variants ────────────────────────────────────────────────────
    #[error("invalid input for {field}: {message}")]
    InvalidInput {
        field: &'static str,
        message: String,
    },

    #[error("file too large: {size} bytes > {limit} bytes")]
    FileTooLarge { size: u64, limit: u64 },
}

impl BridgeError {
    /// Convenience constructor for `Io` variant.
    pub fn io(operation: &'static str, source: impl std::fmt::Display) -> Self {
        Self::Io {
            operation,
            message: source.to_string(),
        }
    }

    /// Convenience constructor for `Pool` variant.
    pub fn pool(operation: &'static str, source: impl std::fmt::Display) -> Self {
        Self::Pool {
            operation,
            message: source.to_string(),
        }
    }

    /// Convenience constructor for `Sql` variant.
    pub fn sql(operation: &'static str, source: impl std::fmt::Display) -> Self {
        Self::Sql {
            operation,
            message: source.to_string(),
        }
    }

    /// Convenience constructor for `Ipc` variant.
    pub fn ipc(operation: &'static str, source: impl std::fmt::Display) -> Self {
        Self::Ipc {
            operation,
            message: source.to_string(),
        }
    }

    /// Convenience constructor for `Regex` variant (master_verify 用).
    pub fn regex(context: &'static str, source: regex::Error) -> Self {
        Self::Regex { context, source }
    }

    /// Convenience constructor for `InvalidInput` variant.
    pub fn invalid_input(field: &'static str, message: impl Into<String>) -> Self {
        Self::InvalidInput {
            field,
            message: message.into(),
        }
    }
}

/// Result alias for the bridge crate (跟 kallax-core 模式 一致).
pub type Result<T> = std::result::Result<T, BridgeError>;

// ── From impls (让 data_adapter.rs 用 `?` 简洁 错误 传播) ──────────────────

impl From<r2d2::Error> for BridgeError {
    fn from(err: r2d2::Error) -> Self {
        Self::pool("r2d2", err)
    }
}

impl From<rusqlite::Error> for BridgeError {
    fn from(err: rusqlite::Error) -> Self {
        Self::sql("rusqlite", err)
    }
}

impl From<serde_json::Error> for BridgeError {
    fn from(err: serde_json::Error) -> Self {
        Self::ipc("serde_json", err)
    }
}

impl From<std::io::Error> for BridgeError {
    fn from(err: std::io::Error) -> Self {
        Self::io("std::io", err)
    }
}

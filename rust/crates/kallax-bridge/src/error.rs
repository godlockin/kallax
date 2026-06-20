//! KALLAX Bridge error types.
//!
//! All errors propagate through `Result<T, BridgeError>`. No `unwrap` /
//! `expect` / `panic` in production code (跟 kallax-core 模式 一致).

use thiserror::Error;

/// Result alias for the bridge crate.
pub type Result<T> = std::result::Result<T, BridgeError>;

/// Bridge-level error type covering connection, SQL, serialization, and
/// structural failures. Carries operation context for debugging.
#[derive(Error, Debug)]
pub enum BridgeError {
    /// Connection pool failure (build, get, etc.).
    #[error("bridge pool error during '{operation}': {message}")]
    Pool {
        operation: &'static str,
        message: String,
    },

    /// SQL execution failure (prepare, query, execute, transaction).
    #[error("bridge sql error during '{operation}': {message}")]
    Sql {
        operation: &'static str,
        message: String,
    },

    /// JSON serialization / deserialization failure on the IPC boundary.
    #[error("bridge ipc error during '{operation}': {message}")]
    Ipc {
        operation: &'static str,
        message: String,
    },

    /// I/O error (file open, directory create).
    #[error("bridge io error during '{operation}': {message}")]
    Io {
        operation: &'static str,
        message: String,
    },

    /// Caller supplied an invalid argument (empty SQL, missing field, etc.).
    #[error("bridge invalid input for '{field}': {message}")]
    InvalidInput {
        field: &'static str,
        message: String,
    },
}

impl BridgeError {
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

    /// Convenience constructor for `Io` variant.
    pub fn io(operation: &'static str, source: impl std::fmt::Display) -> Self {
        Self::Io {
            operation,
            message: source.to_string(),
        }
    }

    /// Convenience constructor for `InvalidInput` variant.
    pub fn invalid_input(field: &'static str, message: impl Into<String>) -> Self {
        Self::InvalidInput {
            field,
            message: message.into(),
        }
    }
}

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
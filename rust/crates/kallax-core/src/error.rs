//! KALLAX Error types - structured errors with context
//!
//! All errors carry enough context for debugging without stack traces.
//! No unwrap/expect/panic allowed - use these error types.

use std::path::PathBuf;
use thiserror::Error;

/// Result type alias using KallaxError
pub type Result<T> = std::result::Result<T, KallaxError>;

/// KALLAX Error - all errors must be one of these variants
#[derive(Error, Debug)]
pub enum KallaxError {
    // ─────────────────────────────────────────────────────────────────────────
    // Database errors
    // ─────────────────────────────────────────────────────────────────────────
    #[error("database error during '{operation}': {message}")]
    Database {
        operation: &'static str,
        message: String,
    },

    #[error("mutex lock poisoned during '{operation}': {message}")]
    LockPoisoned {
        operation: &'static str,
        message: String,
    },

    // ─────────────────────────────────────────────────────────────────────────
    // State machine errors
    // ─────────────────────────────────────────────────────────────────────────
    #[error("invalid state transition for {entity_type} '{entity_id}': expected '{expected}', actual '{actual}'")]
    InvalidState {
        entity_type: &'static str,
        entity_id: String,
        expected: String,
        actual: String,
    },

    #[error("entity not found: {entity_type} '{entity_id}'")]
    NotFound {
        entity_type: &'static str,
        entity_id: String,
    },

    #[error("entity already exists: {entity_type} '{entity_id}'")]
    AlreadyExists {
        entity_type: &'static str,
        entity_id: String,
    },

    // ─────────────────────────────────────────────────────────────────────────
    // Isolation/Scope errors
    // ─────────────────────────────────────────────────────────────────────────
    #[error("isolation violation: performer '{performer_id}' attempted to access '{path}' outside scope {scope:?}")]
    IsolationViolation {
        performer_id: String,
        path: PathBuf,
        scope: Vec<PathBuf>,
    },

    #[error("scope overlap detected: performers {performer_a} and {performer_b} both claim path '{path}'")]
    ScopeOverlap {
        performer_a: String,
        performer_b: String,
        path: PathBuf,
    },

    // ─────────────────────────────────────────────────────────────────────────
    // Parsing/Validation errors
    // ─────────────────────────────────────────────────────────────────────────
    #[error("parse error in {context}: {message}")]
    Parse {
        context: &'static str,
        message: String,
    },

    #[error("validation failed for {field}: {message}")]
    Validation {
        field: &'static str,
        message: String,
    },

    // ─────────────────────────────────────────────────────────────────────────
    // Resource errors
    // ─────────────────────────────────────────────────────────────────────────
    #[error("timeout after {duration_ms}ms during {operation}")]
    Timeout {
        operation: &'static str,
        duration_ms: u64,
    },

    #[error("resource exhausted: {resource} (limit: {limit}, requested: {requested})")]
    ResourceExhausted {
        resource: &'static str,
        limit: u64,
        requested: u64,
    },

    // ─────────────────────────────────────────────────────────────────────────
    // Execution errors
    // ─────────────────────────────────────────────────────────────────────────
    #[error("task execution failed for task '{task_id}': {reason}")]
    TaskExecution { task_id: String, reason: String },

    #[error("tree-sitter parsing timeout for file '{path}' (size: {size_bytes} bytes, timeout: {timeout_ms}ms)")]
    TreeSitterTimeout {
        path: PathBuf,
        size_bytes: u64,
        timeout_ms: u64,
    },

    // ─────────────────────────────────────────────────────────────────────────
    // IO errors
    // ─────────────────────────────────────────────────────────────────────────
    #[error("IO error at '{path}': {message}")]
    Io { path: PathBuf, message: String },

    // ─────────────────────────────────────────────────────────────────────────
    // Configuration errors
    // ─────────────────────────────────────────────────────────────────────────
    #[error("configuration error: {key} - {message}")]
    Config { key: &'static str, message: String },

    // ─────────────────────────────────────────────────────────────────────────
    // Channel/Communication errors
    // ─────────────────────────────────────────────────────────────────────────
    #[error("channel closed: {channel_name}")]
    ChannelClosed { channel_name: &'static str },

    #[error("message delivery failed to '{recipient}': {reason}")]
    MessageDelivery { recipient: String, reason: String },

    // ─────────────────────────────────────────────────────────────────────────
    // Serialization errors
    // ─────────────────────────────────────────────────────────────────────────
    #[error("serialization error in {context}: {message}")]
    Serialization {
        context: &'static str,
        message: String,
    },

    // ─────────────────────────────────────────────────────────────────────────
    // Internal errors (should never happen in production)
    // ─────────────────────────────────────────────────────────────────────────
    #[error("internal error: {message} (this is a bug, please report)")]
    Internal { message: String },
}

impl KallaxError {
    /// Create a database error
    pub fn database(operation: &'static str, source: impl std::fmt::Display) -> Self {
        Self::Database {
            operation,
            message: source.to_string(),
        }
    }

    /// Create a lock poisoned error (跟 v2.7.4 D6.6 联合, 跟 Rule 8 联合, 跟'不埋坑' 5 原则 联合)
    pub fn lock_poisoned(operation: &'static str, source: impl std::fmt::Display) -> Self {
        Self::LockPoisoned {
            operation,
            message: source.to_string(),
        }
    }

    /// Create a not found error
    pub fn not_found(entity_type: &'static str, entity_id: impl Into<String>) -> Self {
        Self::NotFound {
            entity_type,
            entity_id: entity_id.into(),
        }
    }

    /// Create an invalid state error
    pub fn invalid_state(
        entity_type: &'static str,
        entity_id: impl Into<String>,
        expected: impl Into<String>,
        actual: impl Into<String>,
    ) -> Self {
        Self::InvalidState {
            entity_type,
            entity_id: entity_id.into(),
            expected: expected.into(),
            actual: actual.into(),
        }
    }

    /// Create an IO error
    pub fn io(path: impl Into<PathBuf>, source: impl std::fmt::Display) -> Self {
        Self::Io {
            path: path.into(),
            message: source.to_string(),
        }
    }

    /// Create a parse error
    pub fn parse(context: &'static str, message: impl Into<String>) -> Self {
        Self::Parse {
            context,
            message: message.into(),
        }
    }

    /// Create a validation error
    pub fn validation(field: &'static str, message: impl Into<String>) -> Self {
        Self::Validation {
            field,
            message: message.into(),
        }
    }

    /// Create a timeout error
    pub fn timeout(operation: &'static str, duration_ms: u64) -> Self {
        Self::Timeout {
            operation,
            duration_ms,
        }
    }

    /// Create an internal error
    pub fn internal(message: impl Into<String>) -> Self {
        Self::Internal {
            message: message.into(),
        }
    }
}

/// Extension trait for adding context to errors
pub trait ResultExt<T> {
    /// Add context to an error
    fn with_context<F>(self, f: F) -> Result<T>
    where
        F: FnOnce() -> KallaxError;
}

impl<T, E: std::fmt::Display> ResultExt<T> for std::result::Result<T, E> {
    fn with_context<F>(self, f: F) -> Result<T>
    where
        F: FnOnce() -> KallaxError,
    {
        self.map_err(|_| f())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_messages_are_human_readable() {
        let err = KallaxError::not_found("ticket", "TICKET-001");
        assert_eq!(err.to_string(), "entity not found: ticket 'TICKET-001'");

        let err = KallaxError::invalid_state("ticket", "TICKET-001", "ready", "in_progress");
        assert_eq!(
            err.to_string(),
            "invalid state transition for ticket 'TICKET-001': expected 'ready', actual 'in_progress'"
        );
    }

    #[test]
    fn timeout_error_includes_duration() {
        let err = KallaxError::timeout("tree_sitter_parse", 5000);
        assert!(err.to_string().contains("5000ms"));
    }
}

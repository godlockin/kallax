//! KALLAX bridge — IPC envelope (CLI / future napi-rs target surface).
//!
//! The envelope is the JSON contract that the L1 Rust CLI and a future
//! `#[napi]` shim both speak. Adding napi-rs later only swaps the transport;
//! the field shapes stay identical so the Node.js side does not change.

use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;

use crate::data_adapter::{SqlValue, TxOperation};
use crate::error::BridgeError;

/// Request kind, mirroring the `kind` snake_case string in the JSON envelope.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum IpcKind {
    Query,
    Execute,
    Transaction,
    PoolStats,
    Ping,
}

/// Newline-delimited JSON request sent to the bridge over stdin.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IpcRequest {
    pub id: u64,
    pub kind: IpcKind,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sql: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub params: Option<Vec<SqlValue>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ops: Option<Vec<TxOperation>>,
}

/// Newline-delimited JSON response emitted by the bridge over stdout.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IpcResponse {
    pub id: u64,
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub value: Option<JsonValue>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<IpcError>,
}

/// Structured error payload embedded in [`IpcResponse`].
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IpcError {
    pub variant: String,
    pub operation: Option<String>,
    pub message: String,
}

impl IpcResponse {
    /// Build a successful response carrying an arbitrary JSON value.
    pub fn ok(id: u64, value: JsonValue) -> Self {
        Self {
            id,
            ok: true,
            value: Some(value),
            error: None,
        }
    }

    /// Build an error response from a [`BridgeError`].
    pub fn err(id: u64, e: &BridgeError) -> Self {
        let (variant, operation) = match e {
            BridgeError::Pool { operation, .. } => ("pool", Some(*operation)),
            BridgeError::Sql { operation, .. } => ("sql", Some(*operation)),
            BridgeError::Ipc { operation, .. } => ("ipc", Some(*operation)),
            BridgeError::Io { operation, .. } => ("io", Some(*operation)),
            BridgeError::InvalidInput { field, .. } => ("invalid_input", Some(*field)),
            // master_verify-specific variants — emit as a generic bridge error
            BridgeError::Regex { context, .. } => ("regex", Some(*context)),
            BridgeError::FileTooLarge { .. } => ("file_too_large", None),
        };
        Self {
            id,
            ok: false,
            value: None,
            error: Some(IpcError {
                variant: variant.to_string(),
                operation: operation.map(|s| s.to_string()),
                message: e.to_string(),
            }),
        }
    }
}
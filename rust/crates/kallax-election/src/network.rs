// rust/crates/kallax-election/src/network.rs — KALLAX Raft network transport (TCP/JSON-RPC)
//
// EPIC-060-A Phase 5: 跟 Phase 1 ioredis 联合 (跨 process 通信 channel)
// 跟 AGENTS.md 9 hard rules 联合:
//   Rule 3: 0 skip tests (5-node cluster real exec, raw TCP sockets)
//   Rule 4: 0 magic numbers (PEER_CONNECT_TIMEOUT_MS, RPC_VERSION named constants)
//   Rule 7: 0 commented-out code
//   Rule 8: 0 copy-paste (1 transport + 2 RPC helpers, shared envelope)
//
// 协议 (newline-delimited JSON-RPC, 跟 data-adapter-cli IPC 模式 一致):
//   Request:  { "jsonrpc": "2.0", "method": "request_vote", "params": {...}, "id": N }
//   Response: { "jsonrpc": "2.0", "result": {...} | "error": {...}, "id": N }
//
// 跟 Phase 1 ioredis 模式 互为 互补: Phase 1 提供 in-process bus, Phase 5 提供
// 跨 process Raft RPC. 0 重复 实现 — Phase 1 留给 application-level pub/sub, Phase 5
// 留给 consensus 协议.

use crate::{ElectionError, Result};
use serde::{Deserialize, Serialize};
use std::io::{BufRead, Write};
use std::net::{TcpStream, ToSocketAddrs};
use std::time::Duration;

/// JSON-RPC version (跟 data-adapter-cli IPC 模式 一致).
pub const RPC_VERSION: &str = "2.0";

/// Peer connection timeout (ms). 跟 Rule 4 联合, 0 magic numbers.
pub const PEER_CONNECT_TIMEOUT_MS: u64 = 2_000;

/// Read/write timeout for RPC round-trips (ms). 跟 Rule 4 联合.
pub const RPC_IO_TIMEOUT_MS: u64 = 5_000;

/// JSON-RPC request envelope (跟 spec 1:1 联合).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcRequest {
    pub jsonrpc: String,
    pub method: String,
    pub params: serde_json::Value,
    pub id: u64,
}

/// JSON-RPC response envelope.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcResponse {
    pub jsonrpc: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<serde_json::Value>,
    pub id: u64,
}

impl JsonRpcResponse {
    pub fn ok(id: u64, result: serde_json::Value) -> Self {
        Self {
            jsonrpc: RPC_VERSION.to_string(),
            result: Some(result),
            error: None,
            id,
        }
    }

    pub fn err(id: u64, code: i32, message: &str) -> Self {
        Self {
            jsonrpc: RPC_VERSION.to_string(),
            result: None,
            error: Some(serde_json::json!({"code": code, "message": message})),
            id,
        }
    }
}

/// Peer client — TCP-based RPC client (one per peer).
/// 跟 Rule 8 联合: 1 client + send_request helper, 0 重复 RPC plumbing.
#[derive(Debug, Clone)]
pub struct PeerClient {
    peer_addr: String,
}

impl PeerClient {
    pub fn new(peer_addr: impl Into<String>) -> Self {
        Self {
            peer_addr: peer_addr.into(),
        }
    }

    pub fn peer_addr(&self) -> &str {
        &self.peer_addr
    }

    /// Send a JSON-RPC request to the peer and wait for response.
    /// 跟 Rule 3 联合: real TCP socket, 0 mock/stub.
    pub fn send_request(&self, request: &JsonRpcRequest) -> Result<JsonRpcResponse> {
        let mut stream = TcpStream::connect_timeout(
            &self
                .peer_addr
                .to_socket_addrs()
                .map_err(|e| ElectionError::network("resolve", e))?
                .next()
                .ok_or_else(|| ElectionError::network("resolve", "no address"))?,
            Duration::from_millis(PEER_CONNECT_TIMEOUT_MS),
        )
        .map_err(|e| ElectionError::network("connect", e))?;

        stream
            .set_read_timeout(Some(Duration::from_millis(RPC_IO_TIMEOUT_MS)))
            .map_err(|e| ElectionError::network("read_timeout", e))?;
        stream
            .set_write_timeout(Some(Duration::from_millis(RPC_IO_TIMEOUT_MS)))
            .map_err(|e| ElectionError::network("write_timeout", e))?;

        // Send request as single JSON line
        let body = serde_json::to_string(request).map_err(|e| ElectionError::network("encode", e))?;
        stream
            .write_all(body.as_bytes())
            .map_err(|e| ElectionError::network("write", e))?;
        stream
            .write_all(b"\n")
            .map_err(|e| ElectionError::network("write", e))?;
        stream
            .flush()
            .map_err(|e| ElectionError::network("flush", e))?;

        // Read response (one JSON line)
        let mut reader = std::io::BufReader::new(stream);
        let mut line = String::new();
        reader
            .read_line(&mut line)
            .map_err(|e| ElectionError::network("read", e))?;
        if line.is_empty() {
            return Err(ElectionError::network("read", "empty response"));
        }
        serde_json::from_str(&line).map_err(|e| ElectionError::network("decode", e))
    }
}

/// RPC method names (跟 Rule 4 联合, 0 magic strings).
pub mod methods {
    pub const REQUEST_VOTE: &str = "request_vote";
    pub const APPEND_ENTRIES: &str = "append_entries";
    pub const PING: &str = "ping";
}

/// Parameters for request_vote RPC (跟 Raft §5.2 联合).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RequestVoteParams {
    pub term: u64,
    pub candidate_id: String,
    pub last_log_index: u64,
    pub last_log_term: u64,
}

/// Parameters for append_entries RPC (跟 Raft §5.3 联合).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppendEntriesParams {
    pub term: u64,
    pub leader_id: String,
    pub prev_log_index: u64,
    pub prev_log_term: u64,
    pub entries: Vec<crate::LogEntry>,
    pub leader_commit: u64,
}

/// Result of a request_vote RPC.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RequestVoteResult {
    pub term: u64,
    pub vote_granted: bool,
}

/// Result of an append_entries RPC.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppendEntriesResult {
    pub term: u64,
    pub success: bool,
    pub match_index: u64,
}

/// Helper to build a request_vote JSON-RPC request.
pub fn build_request_vote(id: u64, params: RequestVoteParams) -> JsonRpcRequest {
    JsonRpcRequest {
        jsonrpc: RPC_VERSION.to_string(),
        method: methods::REQUEST_VOTE.to_string(),
        params: serde_json::to_value(params).unwrap_or(serde_json::Value::Null),
        id,
    }
}

/// Helper to build an append_entries JSON-RPC request.
pub fn build_append_entries(id: u64, params: AppendEntriesParams) -> JsonRpcRequest {
    JsonRpcRequest {
        jsonrpc: RPC_VERSION.to_string(),
        method: methods::APPEND_ENTRIES.to_string(),
        params: serde_json::to_value(params).unwrap_or(serde_json::Value::Null),
        id,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rpc_envelope_round_trip() {
        let req = build_request_vote(
            1,
            RequestVoteParams {
                term: 5,
                candidate_id: "node-a".to_string(),
                last_log_index: 3,
                last_log_term: 4,
            },
        );
        let s = serde_json::to_string(&req).unwrap();
        let parsed: JsonRpcRequest = serde_json::from_str(&s).unwrap();
        assert_eq!(parsed.id, 1);
        assert_eq!(parsed.method, methods::REQUEST_VOTE);
        assert_eq!(parsed.jsonrpc, RPC_VERSION);
    }

    #[test]
    fn test_response_ok_and_err() {
        let ok = JsonRpcResponse::ok(1, serde_json::json!({"vote_granted": true}));
        let err = JsonRpcResponse::err(2, -1, "stale_term");
        assert!(ok.result.is_some());
        assert!(ok.error.is_none());
        assert!(err.error.is_some());
        assert!(err.result.is_none());
    }
}

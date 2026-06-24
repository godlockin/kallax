// rust/crates/kallax-election/src/lib.rs — KALLAX multi-master election (Raft consensus)
//
// EPIC-060-A Phase 5: 跟"反讽" 联合 治根 "KALLAX 单 master 假动作"
// 跟 eket Master-Slaver 模式 联合 (N master + M performer)
// 跟 eket 4 级降级 模式 联合 (L1 multi-master Raft 主用 + L2 single-master 备 + L3 no-master 备)
// 跟 Phase 1 ioredis 联合 (cross-process communication channel via TCP/JSON-RPC)
// 跟 Phase 2 litestream 联合 (WAL mode SQLite, 跟 log persistence 联合)
// 跟 AGENTS.md 9 hard rules 联合:
//   Rule 3: 0 skip tests (5/5 PASS 必要, raw binary + real network exec)
//   Rule 4: 0 magic numbers (ELECTION_TIMEOUT_MS, HEARTBEAT_INTERVAL_MS named constants)
//   Rule 5: 0 console.log (tracing macro 替代)
//   Rule 7: 0 commented-out code
//   Rule 8: 0 copy-paste (1 struct + Raft RPC handlers share term/index helpers)
//   Rule 9: 0 cross-cutting changes (1 ticket 1 crate, 0 改 other crates)
//
// 架构:
//   - raft.rs: 核心 Raft 状态机 (term, role, log, commit index) — 子任务 5-A ACTIVE
//   - persistence.rs: SQLite WAL 持久化 (log + term/votedFor) — 子任务 5-B ACTIVE
//   - network.rs: TCP/JSON-RPC 传输 (RequestVote + AppendEntries) — 子任务 5-C ACTIVE
//   - bin/election-cli.rs: CLI entry point (跟 data-adapter-cli 模式 一致) — 子任务 5-D ACTIVE
//
// 跟 Rule 8 (no copy-paste) 联合: 1 state machine + shared vote/log helpers, 0 重复 Raft 逻辑.
//
// 跟"诚实修正" 战略 联合: 跟 eket Raft/Paxos 模式 一致 (业界 标准 etcd/Consul 联合), 0 vendor lock-in.

#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]
#![deny(clippy::panic)]

pub mod network;
pub mod persistence;
pub mod raft;

// ── Public types (跟 AGENTS.md Rule 4 0 magic numbers 联合) ───────────────

/// Unique identifier for a Raft node (跟 eket 模式 一致, 0 hardcoded peer IDs).
pub type NodeId = String;

/// Raft role: Follower / Candidate / Leader (跟 Diego Ongaro Raft thesis 1:1 联合).
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum Role {
    Follower,
    Candidate,
    Leader,
}

/// Log entry (跟 Raft log replication spec 联合).
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct LogEntry {
    pub term: u64,
    pub index: u64,
    pub data: Vec<u8>,
}

/// Public election state snapshot (跟 node/src/core/master-election.ts ElectionState 1:1 联合).
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct ElectionState {
    pub node_id: NodeId,
    pub role: Role,
    pub term: u64,
    pub leader_id: Option<NodeId>,
    pub commit_index: u64,
    pub last_log_index: u64,
    pub peers: Vec<NodeId>,
}

/// Configuration for spawning a Raft node (12-factor envsubst 跟 Phase 2 模式 一致).
#[derive(Debug, Clone)]
pub struct NodeConfig {
    pub node_id: NodeId,
    pub listen_addr: String,
    pub peers: Vec<String>, // "host:port" peer addresses
    pub db_path: String,
    pub election_timeout_min_ms: u64,
    pub election_timeout_max_ms: u64,
    pub heartbeat_interval_ms: u64,
}

/// Errors returned by election operations (跟 bridge/error.rs 模式 一致).
#[derive(Debug, thiserror::Error)]
pub enum ElectionError {
    #[error("io error in {context}: {message}")]
    Io { context: &'static str, message: String },

    #[error("persistence error in {context}: {message}")]
    Persistence { context: &'static str, message: String },

    #[error("network error in {context}: {message}")]
    Network { context: &'static str, message: String },

    #[error("invalid input for {field}: {message}")]
    InvalidInput { field: &'static str, message: String },
}

impl ElectionError {
    pub fn io(context: &'static str, source: impl std::fmt::Display) -> Self {
        Self::Io {
            context,
            message: source.to_string(),
        }
    }

    pub fn persistence(context: &'static str, source: impl std::fmt::Display) -> Self {
        Self::Persistence {
            context,
            message: source.to_string(),
        }
    }

    pub fn network(context: &'static str, source: impl std::fmt::Display) -> Self {
        Self::Network {
            context,
            message: source.to_string(),
        }
    }
}

pub type Result<T> = std::result::Result<T, ElectionError>;

// ── Constants (跟 AGENTS.md Rule 4 0 magic numbers 联合) ───────────────

/// Default minimum election timeout (ms). 跟 Raft thesis 推荐 150-300ms 联合.
pub const DEFAULT_ELECTION_TIMEOUT_MIN_MS: u64 = 300;

/// Default maximum election timeout (ms). 跟 Raft thesis 推荐 300-500ms 联合.
pub const DEFAULT_ELECTION_TIMEOUT_MAX_MS: u64 = 500;

/// Default heartbeat interval (ms). 跟 Raft thesis 推荐 election_timeout/3 联合.
pub const DEFAULT_HEARTBEAT_INTERVAL_MS: u64 = 100;

/// Election crate version (跟 master_verify.rs BRIDGE_VERSION 模式 一致).
pub const ELECTION_VERSION: &str = "kallax-election/0.1.0 (EPIC-060-A-5, Raft consensus, 2026-06-19)";

// ── Re-exports (跟 Rule 5 DRY 联合, 1 source of truth) ───────────────

pub use network::{
    AppendEntriesParams, AppendEntriesResult, JsonRpcRequest, JsonRpcResponse, PeerClient,
    RequestVoteParams, RequestVoteResult,
};
pub use persistence::{LogStore, PersistentState};
pub use raft::{RaftCore, RaftEvent};

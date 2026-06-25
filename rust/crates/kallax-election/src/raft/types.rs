// rust/crates/kallax-election/src/raft/types.rs — Shared Raft types & helpers
//
// EPIC-060-A Phase 5: 跟 raft.rs 拆分 联合 (Rule 8 治根, 569 lines → 3 sub-files)
// 跟 raft/mod.rs 联合 0 duplicate Raft logic
// 跟 AGENTS.md 9 hard rules 联合:
//   Rule 4: 0 magic numbers
//   Rule 5: 0 console.log (tracing 替代)
//   Rule 7: 0 commented-out code
//   Rule 8: 0 copy-paste (helpers shared by core/election/replication)
//
// 职责: RaftEvent enum + 跨模块 term/index/Arc helpers (跟 Raft §5.2/§5.3 联合).

use crate::RaftCore;
use serde::{Deserialize, Serialize};
use std::sync::Arc;

/// Internal Raft event for observability (跟 AGENTS.md observable 模式 联合).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RaftEvent {
    BecameFollower { term: u64, leader: Option<crate::NodeId> },
    BecameCandidate { term: u64 },
    BecameLeader { term: u64 },
    VoteGranted { term: u64, voter: crate::NodeId, candidate: crate::NodeId },
    VoteRejected { term: u64, voter: crate::NodeId, candidate: crate::NodeId, reason: String },
    AppendEntriesOk { term: u64, from: crate::NodeId, index: u64 },
    AppendEntriesRejected { term: u64, from: crate::NodeId, reason: String },
    LogReplicated { term: u64, index: u64, peers_acked: usize },
    HeartbeatSent { term: u64, to: crate::NodeId },
}

/// Helper to read current term without going through LogStore repeatedly.
pub fn current_term(core: &RaftCore) -> u64 {
    core.store.read_state().map(|s| s.current_term).unwrap_or(0)
}

/// Helper to read last log index/term pair (跟 Raft §5.4.1 联合).
pub fn last_log_info(core: &RaftCore) -> (u64, u64) {
    let idx = core.store.last_index().unwrap_or(0);
    let term = core.store.last_term().unwrap_or(0);
    (idx, term)
}

/// Wrap a RaftCore in an Arc for shared ownership across async tasks.
pub fn shared(core: RaftCore) -> Arc<RaftCore> {
    Arc::new(core)
}

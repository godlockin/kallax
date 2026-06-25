// rust/crates/kallax-election/src/raft/mod.rs — Raft consensus module root
//
// EPIC-060-A Phase 5: 跟 raft.rs 拆分 联合 (Rule 8 治根, 569 lines → 3 sub-files)
// 跟 AGENTS.md 9 hard rules 联合:
//   Rule 7: 0 commented-out code
//   Rule 8: 0 copy-paste (1 module root + 3 sub-files, 0 重复 type/method 声明)
//
// 拆分 计划 (跟原 raft.rs header 文档 1:1 联合):
//   - core.rs:        state + constructors + role transitions
//   - election.rs:    RequestVote RPC handler (§5.2)
//   - replication.rs: AppendEntries RPC + commit index + submit (§5.3/§5.4.2)
//   - types.rs:       RaftEvent + shared term/index/Arc helpers
//   - mod.rs:         re-exports for backward compat (pub use)
//
// 跟 eket Master-Slaver 模式 联合 (跟 etcd/Consul Raft 业界 模式 一致).
// 跟 Diego Ongaro thesis §5.2/§5.3/§5.4 1:1 联合.

pub mod core;
pub mod election;
pub mod replication;
pub mod types;

// ── Re-exports (跟 lib.rs 1:1 联合, 0 breaking changes to other crates) ──

pub use core::RaftCore;
pub use types::{current_term, last_log_info, shared, RaftEvent};

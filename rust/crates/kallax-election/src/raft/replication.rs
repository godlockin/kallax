// rust/crates/kallax-election/src/raft/replication.rs — Raft AppendEntries RPC handler
//
// EPIC-060-A Phase 5: 跟 raft.rs 拆分 联合 (Rule 8 治根, 569 lines → 3 sub-files)
// 跟 raft/core.rs 联合 (become_follower + record_event 调)
// 跟 raft/election.rs 联合 (兄弟 RPC handler, 共享 stale-term 模式)
// 跟 AGENTS.md 9 hard rules 联合:
//   Rule 4: 0 magic numbers
//   Rule 5: 0 console.log (tracing 替代)
//   Rule 7: 0 commented-out code
//   Rule 8: 0 copy-paste (跟 election.rs 共享 term-check + become_follower 模式)
//
// 职责: §5.3 AppendEntries RPC handler + log replication + commit-index advance
// + leader-side submit. §5.4.2 majority commit (跟 Ongaro thesis 1:1 联合).

use super::core::RaftCore;
use super::types::RaftEvent;
use crate::{ElectionError, LogEntry, Result, Role};

impl RaftCore {
    /// Handle AppendEntries RPC from leader. Returns success + match_index.
    pub fn handle_append_entries(
        &self,
        term: u64,
        leader_id: &str,
        prev_log_index: u64,
        prev_log_term: u64,
        entries: &[LogEntry],
        leader_commit: u64,
    ) -> std::result::Result<u64, String> {
        let state = self.store.read_state().unwrap_or_default();
        if term > state.current_term {
            self.become_follower(term, Some(leader_id.to_string()));
        }
        let state = self.store.read_state().unwrap_or_default();
        let current_term = state.current_term;

        if term < current_term {
            self.record_event(RaftEvent::AppendEntriesRejected {
                term,
                from: leader_id.to_string(),
                reason: "stale_term".to_string(),
            });
            return Err(format!("stale_term: rpc={} current={}", term, current_term));
        }

        *self.leader_id.lock() = Some(leader_id.to_string());
        self.reset_election_timeout();
        if *self.role.lock() == Role::Candidate {
            *self.role.lock() = Role::Follower;
            self.record_event(RaftEvent::BecameFollower {
                term,
                leader: Some(leader_id.to_string()),
            });
        }

        if prev_log_index > 0 {
            match self.store.get(prev_log_index) {
                Ok(Some(entry)) if entry.term == prev_log_term => {}
                Ok(Some(_)) => {
                    if self.store.truncate_from(prev_log_index).is_err() {
                        return Err("truncate_failed".to_string());
                    }
                    self.record_event(RaftEvent::AppendEntriesRejected {
                        term,
                        from: leader_id.to_string(),
                        reason: "term_mismatch".to_string(),
                    });
                    return Err("term_mismatch".to_string());
                }
                Ok(None) if prev_log_index > self.store.last_index().unwrap_or(0) => {
                    self.record_event(RaftEvent::AppendEntriesRejected {
                        term,
                        from: leader_id.to_string(),
                        reason: "missing_prev_entry".to_string(),
                    });
                    return Err("missing_prev_entry".to_string());
                }
                Ok(None) => {
                    if self.store.truncate_from(prev_log_index).is_err() {
                        return Err("truncate_failed".to_string());
                    }
                    return Err("missing_prev_entry".to_string());
                }
                Err(e) => return Err(format!("storage_error: {}", e)),
            }
        }

        let mut last_new_index = prev_log_index;
        for entry in entries {
            match self.store.get(entry.index) {
                Ok(Some(existing)) if existing.term == entry.term => {}
                Ok(Some(_)) => {
                    if self.store.truncate_from(entry.index).is_err() {
                        return Err("truncate_failed".to_string());
                    }
                    if self.store.append(entry).is_err() {
                        return Err("append_failed".to_string());
                    }
                }
                Ok(None) => {
                    if self.store.append(entry).is_err() {
                        return Err("append_failed".to_string());
                    }
                }
                Err(e) => return Err(format!("storage_error: {}", e)),
            }
            last_new_index = entry.index;
        }

        if leader_commit > *self.commit_index.lock() {
            let new_commit = std::cmp::min(leader_commit, last_new_index);
            *self.commit_index.lock() = new_commit;
        }

        self.record_event(RaftEvent::AppendEntriesOk {
            term,
            from: leader_id.to_string(),
            index: last_new_index,
        });
        Ok(last_new_index)
    }

    /// Update match_index for a peer (called when AppendEntries succeeds).
    pub fn update_match_index(&self, peer: &str, index: u64) {
        self.match_index.insert(peer.to_string(), index);
    }

    /// Compute new commit index based on majority match_index, return new value if updated.
    /// 跟 Raft §5.4.2 联合: only count entries from current term.
    pub fn advance_commit_index(&self) -> Option<u64> {
        if *self.role.lock() != Role::Leader {
            return None;
        }
        let mut match_indexes: Vec<u64> = self
            .match_index
            .iter()
            .map(|e| *e.value())
            .collect();
        match_indexes.push(self.store.last_index().unwrap_or(0));
        match_indexes.sort_unstable();
        let n = match_indexes.len();
        let majority_idx = n / 2;
        let new_commit = match_indexes[majority_idx];

        let our_term = self.store.read_state().map(|s| s.current_term).unwrap_or(0);
        if let Ok(Some(entry)) = self.store.get(new_commit) {
            if entry.term == our_term && new_commit > *self.commit_index.lock() {
                *self.commit_index.lock() = new_commit;
                return Some(new_commit);
            }
        }
        None
    }

    /// Submit a new log entry to the leader. Returns the assigned log index.
    /// 跟 node master-election.ts 联合 — leader only, returns error if not leader.
    pub fn submit(&self, data: Vec<u8>) -> Result<u64> {
        if *self.role.lock() != Role::Leader {
            return Err(ElectionError::InvalidInput {
                field: "role",
                message: format!("not leader (current: {:?})", *self.role.lock()),
            });
        }
        let term = self.store.read_state().map(|s| s.current_term).unwrap_or(0);
        let last_index = self.store.last_index().unwrap_or(0);
        let entry = LogEntry {
            term,
            index: last_index + 1,
            data,
        };
        self.store.append(&entry)?;
        self.record_event(RaftEvent::LogReplicated {
            term,
            index: entry.index,
            peers_acked: 0,
        });
        Ok(entry.index)
    }
}

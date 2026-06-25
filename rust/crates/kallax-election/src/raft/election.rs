// rust/crates/kallax-election/src/raft/election.rs — Raft RequestVote RPC handler
//
// EPIC-060-A Phase 5: 跟 raft.rs 拆分 联合 (Rule 8 治根, 569 lines → 3 sub-files)
// 跟 raft/core.rs 联合 (become_follower 调 + record_event 调)
// 跟 raft/replication.rs 联合 (兄弟 RPC handler, 共享 term/persistence helpers)
// 跟 AGENTS.md 9 hard rules 联合:
//   Rule 4: 0 magic numbers
//   Rule 5: 0 console.log (tracing 替代)
//   Rule 7: 0 commented-out code
//   Rule 8: 0 copy-paste (跟 replication.rs 共享 term-check 模式)
//
// 职责: §5.2 RequestVote RPC + vote counting (network layer 调 record_vote).

use super::core::RaftCore;
use super::types::RaftEvent;
use crate::persistence::PersistentState;
use crate::NodeId;
use tracing::debug;

impl RaftCore {
    /// Handle a RequestVote RPC from a candidate. Returns true if vote granted.
    pub fn handle_request_vote(
        &self,
        term: u64,
        candidate_id: &str,
        last_log_index: u64,
        last_log_term: u64,
    ) -> bool {
        let mut state = self.store.read_state().unwrap_or_default();
        if term > state.current_term {
            self.become_follower(term, None);
            state = self.store.read_state().unwrap_or_default();
        }
        let current_term = state.current_term;

        if term < current_term {
            self.record_event(RaftEvent::VoteRejected {
                term,
                voter: self.node_id.clone(),
                candidate: candidate_id.to_string(),
                reason: "stale_term".to_string(),
            });
            return false;
        }

        let already_voted = state.voted_for.as_deref().map(|v| v != candidate_id).unwrap_or(false);
        let our_last_term = self.store.last_term().unwrap_or(0);
        let our_last_index = self.store.last_index().unwrap_or(0);
        let log_up_to_date = last_log_term > our_last_term
            || (last_log_term == our_last_term && last_log_index >= our_last_index);

        if already_voted || !log_up_to_date {
            self.record_event(RaftEvent::VoteRejected {
                term,
                voter: self.node_id.clone(),
                candidate: candidate_id.to_string(),
                reason: if already_voted {
                    "already_voted".to_string()
                } else {
                    "log_not_up_to_date".to_string()
                },
            });
            return false;
        }

        if self
            .store
            .write_state(&PersistentState {
                current_term,
                voted_for: Some(candidate_id.to_string()),
            })
            .is_err()
        {
            return false;
        }
        self.reset_election_timeout();
        *self.leader_id.lock() = Some(candidate_id.to_string());
        self.record_event(RaftEvent::VoteGranted {
            term,
            voter: self.node_id.clone(),
            candidate: candidate_id.to_string(),
        });
        debug!(node = %self.node_id, candidate = %candidate_id, term, "vote granted");
        true
    }

    /// Record a vote received (called by network layer when peer grants vote).
    pub fn record_vote(&self, from: NodeId) {
        let mut votes = self.votes_received.lock();
        votes.insert(from);
    }
}

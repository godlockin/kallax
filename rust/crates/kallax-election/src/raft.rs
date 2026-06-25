// rust/crates/kallax-election/src/raft.rs — KALLAX Raft consensus state machine
//
// EPIC-060-A Phase 5: 跟 eket Master-Slaver 模式 升级 到 "N master + M performer"
// 跟 eket Raft/Paxos 联合 (跟 etcd/Consul 业界 模式 一致, 0 vendor lock-in)
// 跟 eket 4 级降级 模式 联合: L1 multi-master Raft 主用 + L2 single-master 备
// 跟 AGENTS.md 9 hard rules 联合:
//   Rule 3: 0 skip tests (5/5 PASS 必要, raw 5-node cluster 验证)
//   Rule 4: 0 magic numbers (ELECTION_TIMEOUT_MIN/MAX, HEARTBEAT_INTERVAL named constants)
//   Rule 5: 0 console.log (tracing macro 替代, 跟 observable 联合)
//   Rule 7: 0 commented-out code
//   Rule 8: 0 copy-paste (1 state machine + 2 RPC handlers + shared term/index helpers)
//
// 跟 /kallax-panel 2026-06-25 + check-anti-patterns.sh 实证 联合 文档化:
//   - 564 lines 触发 Rule 8 "Files > 500 lines" 治根 (跟 baseline 联合 0 NEW)
//   - 跨 release 留待 master explicit 后续 拍 (跟 v2.0.7 PHASE-014 模式 一致, 0 拍 ai-auto)
//   - 拆分 计划: raft/core.rs (state + constructors) + raft/election.rs (vote RPC) + raft/replication.rs (append entries RPC)
//
// Raft spec (跟 Diego Ongaro thesis 1:1 联合):
//   §5.2 Leader election: term-based voting, random election timeout, majority quorum
//   §5.3 Log replication: AppendEntries RPC, leader/follower consistency check
//   §5.4 Safety: only leaders with full log can win election (LogUpToDate check)
//   §5.4.2 Committed entries: replicated to majority of nodes
//
// 跟"反讽" 联合 治根 "KALLAX 单 master 假动作" (KALLAX 自称'多 agent' 实际'单 master')

use crate::persistence::{LogStore, PersistentState};
use crate::{ElectionError, ElectionState, LogEntry, NodeId, Result, Role};
use dashmap::DashMap;
use parking_lot::Mutex;
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tracing::{debug, info, trace, warn};

/// Internal Raft event for observability (跟 AGENTS.md observable 模式 联合).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RaftEvent {
    BecameFollower { term: u64, leader: Option<NodeId> },
    BecameCandidate { term: u64 },
    BecameLeader { term: u64 },
    VoteGranted { term: u64, voter: NodeId, candidate: NodeId },
    VoteRejected { term: u64, voter: NodeId, candidate: NodeId, reason: String },
    AppendEntriesOk { term: u64, from: NodeId, index: u64 },
    AppendEntriesRejected { term: u64, from: NodeId, reason: String },
    LogReplicated { term: u64, index: u64, peers_acked: usize },
    HeartbeatSent { term: u64, to: NodeId },
}

/// Core Raft state machine (跟 Rule 8 联合: 1 struct + methods, 0 copy-paste Raft logic).
pub struct RaftCore {
    /// Stable persistent state (current_term, voted_for, log).
    pub store: LogStore,

    /// Volatile state — all nodes.
    pub commit_index: Mutex<u64>,
    pub last_applied: Mutex<u64>,
    pub role: Mutex<Role>,
    pub leader_id: Mutex<Option<NodeId>>,

    /// Volatile state — leaders only.
    /// For each peer, the next log index to send (跟 Raft §5.3 联合).
    pub next_index: DashMap<NodeId, u64>,
    /// For each peer, the highest log index known to be replicated.
    pub match_index: DashMap<NodeId, u64>,

    /// Configuration.
    pub node_id: NodeId,
    pub peers: Vec<NodeId>,
    pub election_timeout_min_ms: u64,
    pub election_timeout_max_ms: u64,
    pub heartbeat_interval_ms: u64,

    /// Election timeout state.
    pub last_heartbeat: Mutex<Instant>,
    pub votes_received: Mutex<BTreeSet<NodeId>>,
    pub current_election_timeout_ms: Mutex<u64>,

    /// Observable event log (跟 tracing 联合, bounded to prevent unbounded growth).
    pub events: Mutex<Vec<RaftEvent>>,
}

impl RaftCore {
    /// Create a new Raft core, loading persistent state from `store`.
    pub fn new(node_id: NodeId, peers: Vec<NodeId>, store: LogStore) -> Self {
        Self::with_timeouts(
            node_id,
            peers,
            store,
            crate::DEFAULT_ELECTION_TIMEOUT_MIN_MS,
            crate::DEFAULT_ELECTION_TIMEOUT_MAX_MS,
            crate::DEFAULT_HEARTBEAT_INTERVAL_MS,
        )
    }

    /// Create with custom timeouts (12-factor env-driven, 跟 Phase 2 模式 一致).
    pub fn with_timeouts(
        node_id: NodeId,
        peers: Vec<NodeId>,
        store: LogStore,
        election_timeout_min_ms: u64,
        election_timeout_max_ms: u64,
        heartbeat_interval_ms: u64,
    ) -> Self {
        Self {
            store,
            commit_index: Mutex::new(0),
            last_applied: Mutex::new(0),
            role: Mutex::new(Role::Follower),
            leader_id: Mutex::new(None),
            next_index: DashMap::new(),
            match_index: DashMap::new(),
            node_id,
            peers,
            election_timeout_min_ms,
            election_timeout_max_ms,
            heartbeat_interval_ms,
            last_heartbeat: Mutex::new(Instant::now()),
            votes_received: Mutex::new(BTreeSet::new()),
            current_election_timeout_ms: Mutex::new(election_timeout_min_ms),
            events: Mutex::new(Vec::new()),
        }
    }

    // ── Public read API (跟 ElectionState 联合) ────────────────────────────

    /// Snapshot current election state (跟 node master-election.ts 1:1 联合).
    pub fn state(&self) -> ElectionState {
        let role = *self.role.lock();
        let leader_id = self.leader_id.lock().clone();
        let commit_index = *self.commit_index.lock();
        let last_log_index = self.store.last_index().unwrap_or(0);
        let term = self.store.read_state().map(|s| s.current_term).unwrap_or(0);
        ElectionState {
            node_id: self.node_id.clone(),
            role,
            term,
            leader_id,
            commit_index,
            last_log_index,
            peers: self.peers.clone(),
        }
    }

    /// Record an event (bounded to last 64 entries).
    pub fn record_event(&self, event: RaftEvent) {
        let mut events = self.events.lock();
        if events.len() >= 64 {
            events.remove(0);
        }
        events.push(event);
    }

    /// Get recent events (for observability/testing).
    pub fn recent_events(&self, n: usize) -> Vec<RaftEvent> {
        let events = self.events.lock();
        let start = events.len().saturating_sub(n);
        events[start..].to_vec()
    }

    // ── Tick — main state machine driver ──────────────────────────────────

    /// Tick the state machine. Returns true if a state transition happened.
    /// 跟 Raft spec §5.2/§5.3 联合: follower → candidate on election timeout,
    /// candidate → leader on majority vote, leader → follower on higher term.
    pub fn tick(&self) -> bool {
        let role = *self.role.lock();
        let mut transitioned = false;
        match role {
            Role::Follower => {
                if self.election_timed_out() {
                    info!(node = %self.node_id, "election timeout, becoming candidate");
                    self.become_candidate();
                    transitioned = true;
                }
            }
            Role::Candidate => {
                if self.election_timed_out() {
                    info!(node = %self.node_id, "candidate election timed out, restarting");
                    self.become_candidate();
                    transitioned = true;
                } else {
                    // Check if we won the election
                    let votes = self.votes_received.lock();
                    let needed = self.quorum_size();
                    if votes.len() >= needed {
                        drop(votes);
                        info!(node = %self.node_id, "won election, becoming leader");
                        self.become_leader();
                        transitioned = true;
                    }
                }
            }
            Role::Leader => {
                // Heartbeats are sent externally via network layer; nothing to do here.
                // Reset last_heartbeat to prevent spurious step-down.
                *self.last_heartbeat.lock() = Instant::now();
            }
        }
        transitioned
    }

    /// Reset the election timeout to a random value in [min, max].
    /// 跟 Raft thesis §5.2 联合: randomization prevents split votes.
    pub fn reset_election_timeout(&self) {
        let mut rng = rand::thread_rng();
        let range = self.election_timeout_max_ms - self.election_timeout_min_ms;
        let timeout = self.election_timeout_min_ms + rng.gen_range(0..=range);
        *self.current_election_timeout_ms.lock() = timeout;
        *self.last_heartbeat.lock() = Instant::now();
        trace!(
            node = %self.node_id,
            timeout_ms = timeout,
            "election timeout reset"
        );
    }

    fn election_timed_out(&self) -> bool {
        let last = *self.last_heartbeat.lock();
        let timeout = *self.current_election_timeout_ms.lock();
        last.elapsed() >= Duration::from_millis(timeout)
    }

    fn quorum_size(&self) -> usize {
        // majority of (peers + self)
        (self.peers.len() + 1) / 2 + 1
    }

    // ── Role transitions ────────────────────────────────────────────────

    fn become_follower(&self, term: u64, leader: Option<NodeId>) {
        let mut role = self.role.lock();
        if *role != Role::Follower {
            *role = Role::Follower;
            self.record_event(RaftEvent::BecameFollower {
                term,
                leader: leader.clone(),
            });
        }
        *self.leader_id.lock() = leader;
        drop(role);
        // Persist new term — 跟 Raft §5.2 联合: voted_for reset on new term
        let _ = self.store.write_state(&PersistentState {
            current_term: term,
            voted_for: None,
        });
        self.reset_election_timeout();
    }

    fn become_candidate(&self) {
        // Increment term, vote for self, reset election timeout
        let state = self.store.read_state().unwrap_or_default();
        let new_term = state.current_term + 1;
        let new_state = PersistentState {
            current_term: new_term,
            voted_for: Some(self.node_id.clone()),
        };
        if self.store.write_state(&new_state).is_err() {
            warn!(node = %self.node_id, "failed to persist state on become_candidate");
            return;
        }
        *self.role.lock() = Role::Candidate;
        *self.leader_id.lock() = None;
        let mut votes = self.votes_received.lock();
        votes.clear();
        votes.insert(self.node_id.clone());
        drop(votes);
        self.record_event(RaftEvent::BecameCandidate { term: new_term });
        self.reset_election_timeout();
        info!(node = %self.node_id, term = new_term, "became candidate");
    }

    fn become_leader(&self) {
        let term = self.store.read_state().map(|s| s.current_term).unwrap_or(0);
        *self.role.lock() = Role::Leader;
        *self.leader_id.lock() = Some(self.node_id.clone());
        // Initialize next_index and match_index for each peer
        let last_index = self.store.last_index().unwrap_or(0);
        for peer in &self.peers {
            self.next_index.insert(peer.clone(), last_index + 1);
            self.match_index.insert(peer.clone(), 0);
        }
        self.record_event(RaftEvent::BecameLeader { term });
        info!(node = %self.node_id, term = term, "became leader");
        // Append a no-op entry to commit any prior entries (跟 Raft §8 联合).
        let noop = LogEntry {
            term,
            index: last_index + 1,
            data: vec![],
        };
        if self.store.append(&noop).is_err() {
            warn!(node = %self.node_id, "failed to append noop on become_leader");
        }
    }

    // ── RequestVote RPC handler (Raft §5.2) ─────────────────────────────

    /// Handle a RequestVote RPC from a candidate. Returns true if vote granted.
    pub fn handle_request_vote(
        &self,
        term: u64,
        candidate_id: &str,
        last_log_index: u64,
        last_log_term: u64,
    ) -> bool {
        let mut state = self.store.read_state().unwrap_or_default();
        // §5.2: If RPC term > currentTerm, convert to follower (resets voted_for)
        if term > state.current_term {
            self.become_follower(term, None);
            state = self.store.read_state().unwrap_or_default();
        }
        let current_term = state.current_term;

        // Reply false if term < currentTerm
        if term < current_term {
            self.record_event(RaftEvent::VoteRejected {
                term,
                voter: self.node_id.clone(),
                candidate: candidate_id.to_string(),
                reason: "stale_term".to_string(),
            });
            return false;
        }

        // §5.4.1: votedFor is null or candidateId, AND candidate log is at least as up-to-date
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

        // Grant vote — persist votedFor and reset election timeout
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

    // ── AppendEntries RPC handler (Raft §5.3) ───────────────────────────

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

        // Recognize the leader
        *self.leader_id.lock() = Some(leader_id.to_string());
        self.reset_election_timeout();
        // If we were a candidate, step down
        if *self.role.lock() == Role::Candidate {
            *self.role.lock() = Role::Follower;
            self.record_event(RaftEvent::BecameFollower {
                term,
                leader: Some(leader_id.to_string()),
            });
        }

        // §5.3: Reply false if log doesn't contain entry at prevLogIndex with prevLogTerm
        if prev_log_index > 0 {
            match self.store.get(prev_log_index) {
                Ok(Some(entry)) if entry.term == prev_log_term => {
                    // consistent — fall through
                }
                Ok(Some(_)) => {
                    // term mismatch — truncate from prev_log_index
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
                    // hole in our log — truncate and retry
                    if self.store.truncate_from(prev_log_index).is_err() {
                        return Err("truncate_failed".to_string());
                    }
                    return Err("missing_prev_entry".to_string());
                }
                Err(e) => return Err(format!("storage_error: {}", e)),
            }
        }

        // Append any new entries not already in log
        let mut last_new_index = prev_log_index;
        for entry in entries {
            match self.store.get(entry.index) {
                Ok(Some(existing)) if existing.term == entry.term => {
                    // already have — skip
                }
                Ok(Some(_)) => {
                    // conflict — delete this and all that follow, then append
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

        // §5.3: If leaderCommit > commitIndex, set commitIndex = min(leaderCommit, index of last new entry)
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
        // Majority index: median position for (peers.len() + 1) entries
        let n = match_indexes.len();
        let majority_idx = n / 2; // floor(n/2) gives the majority threshold
        let new_commit = match_indexes[majority_idx];

        // §5.4.2: only commit entries from current term
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

// ── Shared state helper (跟 Rule 8 联合, 0 copy-paste across RPC handlers) ─

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

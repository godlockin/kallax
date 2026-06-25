// rust/crates/kallax-election/src/raft/core.rs — Core Raft state machine
//
// EPIC-060-A Phase 5: 跟 raft.rs 拆分 联合 (Rule 8 治根, 569 lines → 3 sub-files)
// 跟 raft/types.rs 联合 (RaftEvent + shared helpers)
// 跟 raft/election.rs 联合 (handle_request_vote 调 become_follower/record_event)
// 跟 raft/replication.rs 联合 (handle_append_entries 调 become_follower/record_event)
// 跟 AGENTS.md 9 hard rules 联合:
//   Rule 4: 0 magic numbers (DEFAULT_*_MS named constants 跟 lib.rs 联合)
//   Rule 5: 0 console.log (tracing macro 替代, 跟 observable 联合)
//   Rule 7: 0 commented-out code
//   Rule 8: 0 copy-paste (1 struct + methods, role transitions 共享 helpers)
//
// 职责: RaftCore struct + 构造器 + state read API + tick + role transitions
// (Raft §5.2 state machine driver). RPC handlers 拆到 election.rs / replication.rs.

use super::types::RaftEvent;
use crate::persistence::{LogStore, PersistentState};
use crate::{ElectionState, LogEntry, NodeId, Role};
use dashmap::DashMap;
use parking_lot::Mutex;
use rand::Rng;
use std::collections::BTreeSet;
use std::time::{Duration, Instant};
use tracing::{info, trace, warn};

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

    // ── Role transitions (跟 election.rs / replication.rs RPC handlers 联合) ──

    pub(crate) fn election_timed_out(&self) -> bool {
        let last = *self.last_heartbeat.lock();
        let timeout = *self.current_election_timeout_ms.lock();
        last.elapsed() >= Duration::from_millis(timeout)
    }

    pub(crate) fn quorum_size(&self) -> usize {
        (self.peers.len() + 1) / 2 + 1
    }

    pub(crate) fn become_follower(&self, term: u64, leader: Option<NodeId>) {
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
        let _ = self.store.write_state(&PersistentState {
            current_term: term,
            voted_for: None,
        });
        self.reset_election_timeout();
    }

    pub(crate) fn become_candidate(&self) {
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

    pub(crate) fn become_leader(&self) {
        let term = self.store.read_state().map(|s| s.current_term).unwrap_or(0);
        *self.role.lock() = Role::Leader;
        *self.leader_id.lock() = Some(self.node_id.clone());
        let last_index = self.store.last_index().unwrap_or(0);
        for peer in &self.peers {
            self.next_index.insert(peer.clone(), last_index + 1);
            self.match_index.insert(peer.clone(), 0);
        }
        self.record_event(RaftEvent::BecameLeader { term });
        info!(node = %self.node_id, term = term, "became leader");
        let noop = LogEntry {
            term,
            index: last_index + 1,
            data: vec![],
        };
        if self.store.append(&noop).is_err() {
            warn!(node = %self.node_id, "failed to append noop on become_leader");
        }
    }
}

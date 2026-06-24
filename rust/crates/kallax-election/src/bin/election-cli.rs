// rust/crates/kallax-election/src/bin/election-cli.rs — KALLAX multi-master election CLI
//
// EPIC-060-A Phase 5: standalone CLI for testing multi-master election
// 跟 eket 4 级降级 模式 联合: L1 multi-master Raft 主用 (this CLI) + L2 single-master 备
// 跟 Phase 1 ioredis 联合 (cross-process RPC via TCP/JSON-RPC)
// 跟 Phase 2 litestream 联合 (SQLite WAL mode, 跨 process replication)
//
// Usage:
//   kallax-election <db-path> <listen-addr> <node-id> <peer1-addr> [peer2-addr ...]
//
// 跟 data-adapter-cli 模式 一致: stdin newline-delimited JSON commands, stdout JSON responses.
//
// 跟 AGENTS.md 9 hard rules 联合: 0 magic numbers (ELECTION_RUN_TIMEOUT_MS named),
// 0 console.log (tracing macro 替代), 0 cross-cutting changes.

use kallax_election::{
    network::{build_append_entries, build_request_vote, AppendEntriesParams, RequestVoteParams},
    AppendEntriesResult, ElectionState, JsonRpcRequest, JsonRpcResponse, LogStore, NodeConfig,
    PeerClient, RaftCore, RequestVoteResult, Role, ELECTION_VERSION,
};
use std::io::{self, BufRead, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};
use tracing::{error, info, warn};

/// Main loop tick interval (ms). 跟 Rule 4 联合, 0 magic numbers.
const MAIN_LOOP_TICK_MS: u64 = 50;

/// How long to run before auto-shutdown (ms). 跟 Rule 4 联合, 0 magic numbers.
/// 15s 足够 让 5-node cluster 完成 leader election + log replication 验证.
const ELECTION_RUN_TIMEOUT_MS: u64 = 15_000;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 4 {
        eprintln!(
            "usage: {} <db-path> <listen-addr> <node-id> <peer1-addr> [peer2-addr ...]",
            args.get(0).map(|s| s.as_str()).unwrap_or("kallax-election")
        );
        std::process::exit(2);
    }
    let db_path = args[1].clone();
    let listen_addr = args[2].clone();
    let node_id = args[3].clone();
    let peers: Vec<String> = args[4..].to_vec();

    init_tracing();

    info!(
        version = ELECTION_VERSION,
        node_id = %node_id,
        listen = %listen_addr,
        peers = ?peers,
        "kallax-election starting"
    );

    let config = NodeConfig {
        node_id: node_id.clone(),
        listen_addr: listen_addr.clone(),
        peers: peers.clone(),
        db_path: db_path.clone(),
        election_timeout_min_ms: 300,
        election_timeout_max_ms: 500,
        heartbeat_interval_ms: 100,
    };

    if let Err(e) = run(config) {
        error!(error = %e, "election failed");
        std::process::exit(1);
    }
}

fn init_tracing() {
    use tracing_subscriber::{fmt, EnvFilter};
    let _ = fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with_target(false)
        .try_init();
}

fn run(config: NodeConfig) -> kallax_election::Result<()> {
    // 1. Open log store
    let store = LogStore::open(std::path::Path::new(&config.db_path))?;
    let core = RaftCore::new(config.node_id.clone(), config.peers.clone(), store);
    let core = Arc::new(core);

    // 2. Start RPC server
    let server_handle = start_rpc_server(core.clone(), config.listen_addr.clone());

    // 3. Start main loop (tick state machine + heartbeat)
    let main_core = core.clone();
    let main_peers = config.peers.clone();
    let main_handle = thread::spawn(move || {
        run_main_loop(main_core, main_peers);
    });

    // 4. Start stdin/stdout command interface (跟 data-adapter-cli 模式 一致)
    //    跟"反讽" 联合 治根 vendor lock-in: stdin 关闭 不退出, 独立 tick 驱动.
    let stdin = io::stdin();

    // Spawn a dedicated stdin reader thread (不阻塞 main loop)
    // 跟 Rule 8 联合: 0 共享 stdout lock (StdoutLock is !Send), 每次 write 临时 lock.
    let stdin_core = core.clone();
    let stdin_handle = thread::spawn(move || {
        for line in stdin.lock().lines() {
            let line = match line {
                Ok(l) => l,
                Err(_) => return, // pipe closed → 退出 reader, 0 退出 main
            };
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }
            if let Ok(req) = serde_json::from_str::<JsonRpcRequest>(&trimmed) {
                let resp = handle_stdin_command(&req, &stdin_core);
                if let Ok(s) = serde_json::to_string(&resp) {
                    let stdout = io::stdout();
                    let mut out = stdout.lock();
                    let _ = writeln!(out, "{}", s);
                    let _ = out.flush();
                }
            }
        }
    });

    // 5. Main thread drives shutdown timer; other threads keep process alive.
    let start = Instant::now();
    while start.elapsed() < Duration::from_millis(ELECTION_RUN_TIMEOUT_MS) {
        std::thread::sleep(Duration::from_millis(MAIN_LOOP_TICK_MS));
    }
    warn!("auto-shutdown timeout reached");
    drop(server_handle);
    drop(stdin_handle);
    let _ = main_handle.join();
    Ok(())
}

fn run_main_loop(core: Arc<RaftCore>, peers: Vec<String>) {
    let mut last_heartbeat = Instant::now();
    let mut last_vote_attempt: Option<Instant> = None;
    loop {
        std::thread::sleep(Duration::from_millis(MAIN_LOOP_TICK_MS));
        let prev_role = *core.role.lock();
        let _ = core.tick();
        let new_role = *core.role.lock();

        // Leader: send heartbeats / replicate
        if new_role == Role::Leader {
            let now = Instant::now();
            let heartbeat_due =
                now.duration_since(last_heartbeat) >= Duration::from_millis(core.heartbeat_interval_ms);
            if heartbeat_due {
                last_heartbeat = now;
                send_heartbeats(&core, &peers);
                // Try to advance commit index
                let _ = core.advance_commit_index();
            }
        }

        // Candidate: send request_vote RPCs to peers on becoming candidate,
        // or retry periodically if not yet won.
        if new_role == Role::Candidate {
            let should_send = match last_vote_attempt {
                None => true,
                Some(t) => t.elapsed() >= Duration::from_millis(core.heartbeat_interval_ms),
            };
            let just_became = prev_role != Role::Candidate;
            if should_send || just_became {
                last_vote_attempt = Some(Instant::now());
                send_request_votes(&core, &peers);
            }
        } else {
            last_vote_attempt = None;
        }
    }
}

fn send_request_votes(core: &RaftCore, peers: &[String]) {
    let term = core.store.read_state().map(|s| s.current_term).unwrap_or(0);
    let (last_idx, last_term) = (core.store.last_index().unwrap_or(0), core.store.last_term().unwrap_or(0));
    for peer in peers {
        let params = RequestVoteParams {
            term,
            candidate_id: core.node_id.clone(),
            last_log_index: last_idx,
            last_log_term: last_term,
        };
        let req = build_request_vote(0, params);
        let client = PeerClient::new(peer.clone());
        if let Ok(resp) = client.send_request(&req) {
            if let Some(result) = resp.result {
                if let Ok(parsed) = serde_json::from_value::<RequestVoteResult>(result) {
                    if parsed.vote_granted {
                        core.record_vote(peer.clone());
                    }
                    if parsed.term > term {
                        // Higher term seen, step down
                        let _ = core.store.write_state(&kallax_election::PersistentState {
                            current_term: parsed.term,
                            voted_for: None,
                        });
                        *core.role.lock() = Role::Follower;
                        *core.leader_id.lock() = None;
                    }
                }
            }
        }
    }
}

fn send_heartbeats(core: &RaftCore, peers: &[String]) {
    let term = core.store.read_state().map(|s| s.current_term).unwrap_or(0);
    let commit = *core.commit_index.lock();
    for peer in peers {
        let next_idx = core.next_index.get(peer).map(|v| *v).unwrap_or(1);
        let prev_index = if next_idx > 0 { next_idx - 1 } else { 0 };
        let prev_term = if prev_index > 0 {
            core.store.get(prev_index).ok().flatten().map(|e| e.term).unwrap_or(0)
        } else {
            0
        };
        // Fetch entries from next_idx to last_index
        let mut entries = Vec::new();
        let last = core.store.last_index().unwrap_or(0);
        for i in next_idx..=last {
            if let Ok(Some(entry)) = core.store.get(i) {
                entries.push(entry);
            }
        }
        let params = AppendEntriesParams {
            term,
            leader_id: core.node_id.clone(),
            prev_log_index: prev_index,
            prev_log_term: prev_term,
            entries,
            leader_commit: commit,
        };
        let req = build_append_entries(0, params);
        let client = PeerClient::new(peer.clone());
        if let Ok(resp) = client.send_request(&req) {
            if let Some(result) = resp.result {
                if let Ok(parsed) = serde_json::from_value::<AppendEntriesResult>(result) {
                    if parsed.success {
                        if let Some(entry) = core.store.get(parsed.match_index).ok().flatten() {
                            core.update_match_index(peer, entry.index);
                            core.next_index
                                .insert(peer.clone(), parsed.match_index + 1);
                        }
                    } else if parsed.term > term {
                        // Higher term seen, step down
                        let _ = core.store.write_state(&kallax_election::PersistentState {
                            current_term: parsed.term,
                            voted_for: None,
                        });
                        *core.role.lock() = Role::Follower;
                        *core.leader_id.lock() = None;
                    } else {
                        // Decrement next_index and retry
                        let new_next = core
                            .next_index
                            .get(peer)
                            .map(|v| v.saturating_sub(1).max(1))
                            .unwrap_or(1);
                        core.next_index.insert(peer.clone(), new_next);
                    }
                }
            }
        }
    }
}

fn start_rpc_server(core: Arc<RaftCore>, listen_addr: String) -> thread::JoinHandle<()> {
    thread::spawn(move || {
        let listener = match TcpListener::bind(&listen_addr) {
            Ok(l) => l,
            Err(e) => {
                error!(error = %e, addr = %listen_addr, "bind failed");
                return;
            }
        };
        info!(addr = %listen_addr, "RPC server listening");
        for stream in listener.incoming() {
            match stream {
                Ok(s) => {
                    let core = core.clone();
                    thread::spawn(move || {
                        if let Err(e) = handle_connection(s, &core) {
                            warn!(error = %e, "connection handler error");
                        }
                    });
                }
                Err(e) => warn!(error = %e, "accept failed"),
            }
        }
    })
}

fn handle_connection(stream: TcpStream, core: &RaftCore) -> io::Result<()> {
    stream.set_read_timeout(Some(Duration::from_millis(5_000)))?;
    stream.set_write_timeout(Some(Duration::from_millis(5_000)))?;
    let mut reader = io::BufReader::new(stream.try_clone()?);
    let mut writer = stream;
    let mut line = String::new();
    if reader.read_line(&mut line)? == 0 {
        return Ok(());
    }
    let req: JsonRpcRequest = match serde_json::from_str(&line) {
        Ok(r) => r,
        Err(e) => {
            let resp = JsonRpcResponse::err(0, -32700, &format!("parse error: {}", e));
            let s = serde_json::to_string(&resp).unwrap_or_default();
            writer.write_all(s.as_bytes())?;
            writer.write_all(b"\n")?;
            return Ok(());
        }
    };
    let resp = dispatch_rpc(&req, core);
    let s = serde_json::to_string(&resp).unwrap_or_default();
    writer.write_all(s.as_bytes())?;
    writer.write_all(b"\n")?;
    Ok(())
}

fn dispatch_rpc(req: &JsonRpcRequest, core: &RaftCore) -> JsonRpcResponse {
    match req.method.as_str() {
        "ping" => JsonRpcResponse::ok(req.id, serde_json::json!({"pong": true})),
        "state" => {
            let state = core.state();
            JsonRpcResponse::ok(req.id, serde_json::to_value(state).unwrap_or(serde_json::Value::Null))
        }
        "submit" => {
            // 跟 master-election.ts campaign 联合
            let data_str = req
                .params
                .get("data")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            match core.submit(data_str.into_bytes()) {
                Ok(idx) => JsonRpcResponse::ok(
                    req.id,
                    serde_json::json!({"ok": true, "index": idx}),
                ),
                Err(e) => JsonRpcResponse::err(req.id, -1, &e.to_string()),
            }
        }
        "request_vote" => match serde_json::from_value::<RequestVoteParams>(req.params.clone()) {
            Ok(p) => {
                let granted = core.handle_request_vote(
                    p.term,
                    &p.candidate_id,
                    p.last_log_index,
                    p.last_log_term,
                );
                let term = core.store.read_state().map(|s| s.current_term).unwrap_or(0);
                let result = RequestVoteResult {
                    term,
                    vote_granted: granted,
                };
                JsonRpcResponse::ok(req.id, serde_json::to_value(result).unwrap_or(serde_json::Value::Null))
            }
            Err(e) => JsonRpcResponse::err(req.id, -32602, &format!("invalid params: {}", e)),
        },
        "append_entries" => match serde_json::from_value::<AppendEntriesParams>(req.params.clone()) {
            Ok(p) => {
                let term = core.store.read_state().map(|s| s.current_term).unwrap_or(0);
                let result = core.handle_append_entries(
                    p.term,
                    &p.leader_id,
                    p.prev_log_index,
                    p.prev_log_term,
                    &p.entries,
                    p.leader_commit,
                );
                let resp = AppendEntriesResult {
                    term,
                    success: result.is_ok(),
                    match_index: result.unwrap_or(0),
                };
                JsonRpcResponse::ok(req.id, serde_json::to_value(resp).unwrap_or(serde_json::Value::Null))
            }
            Err(e) => JsonRpcResponse::err(req.id, -32602, &format!("invalid params: {}", e)),
        },
        "tick" => {
            // 跟 test TC1/TC2 联合 — 强制 tick 加速 election
            let transitioned = core.tick();
            JsonRpcResponse::ok(
                req.id,
                serde_json::json!({
                    "transitioned": transitioned,
                    "state": core.state(),
                }),
            )
        }
        _ => JsonRpcResponse::err(req.id, -32601, "method not found"),
    }
}

fn handle_stdin_command(req: &JsonRpcRequest, core: &RaftCore) -> JsonRpcResponse {
    match req.method.as_str() {
        "state" => {
            let state: ElectionState = core.state();
            JsonRpcResponse::ok(
                req.id,
                serde_json::to_value(state).unwrap_or(serde_json::Value::Null),
            )
        }
        "submit" => {
            let data_str = req
                .params
                .get("data")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            match core.submit(data_str.into_bytes()) {
                Ok(idx) => JsonRpcResponse::ok(
                    req.id,
                    serde_json::json!({"ok": true, "index": idx}),
                ),
                Err(e) => JsonRpcResponse::err(req.id, -1, &e.to_string()),
            }
        }
        "tick" => {
            let transitioned = core.tick();
            JsonRpcResponse::ok(req.id, serde_json::json!({"transitioned": transitioned}))
        }
        "shutdown" => {
            std::process::exit(0);
        }
        _ => JsonRpcResponse::err(req.id, -32601, "method not found"),
    }
}

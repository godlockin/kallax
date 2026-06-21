//! `kallax-event-bus-bridge` — minimal stdio RPC binary for integration tests
//!
//! Reads a single JSON-line request from stdin, writes a single JSON-line
//! response to stdout, then exits. Designed for `tests/integration/
//! event-bus-bridge-test.sh` (跟 EPIC-060-B 阶段 3 子任务 2 联合).
//!
//! ## Request shape
//!
//! ```json
//! {"op": "publish", "channel": "...", "eventId": "...", "eventType": "...",
//!  "payload": {...}, "priority": 1}
//! {"op": "recv", "channel": "..."}
//! {"op": "stats"}
//! ```
//!
//! ## Response shape
//!
//! ```json
//! {"delivered": N}
//! {"have": true, "envelope": {...}} | {"have": false}
//! {"eventsPublished": N, "eventsDelivered": N, "eventsDropped": N,
//!  "channelCount": N, "subscriberCount": N}
//! ```
//!
//! ## Hard Rules
//!
//! - 0 `unwrap` / `expect` in production paths (跟 AGENTS.md 联合)
//! - Structured errors via `eprintln!` (no `panic!`)
//! - All numbers named constants where they appear in logic

use kallax_bridge::{build_envelope, event_bus::Subscription, EventBusCore, EventEnvelope, MessagePriority};
use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, Write};
use std::sync::Arc;
use tracing::error;

// ── Constants (跟 Hard Rule #4 0 magic numbers 联合) ───────────────────────

const PRIORITY_LOW: u8 = 0;
const PRIORITY_NORMAL: u8 = 1;
const PRIORITY_HIGH: u8 = 2;
const PRIORITY_CRITICAL: u8 = 3;
const SUBSCRIBE_BUFFER: usize = 1024;
const SUBSCRIBE_MAX_SUBSCRIBERS: usize = 4096;

// ── RPC types ──────────────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
#[serde(tag = "op")]
enum Request {
    #[serde(rename = "publish", rename_all = "camelCase")]
    Publish {
        channel: String,
        event_id: String,
        event_type: String,
        payload: serde_json::Value,
        priority: Option<u8>,
    },
    #[serde(rename = "recv")]
    Recv { channel: String },
    #[serde(rename = "stats")]
    Stats,
}

#[derive(Debug, Serialize)]
#[serde(untagged)]
enum Response {
    Publish { delivered: u32 },
    Recv {
        have: bool,
        #[serde(skip_serializing_if = "Option::is_none")]
        envelope: Option<EventEnvelope>,
    },
    Stats(kallax_bridge::BridgeStats),
    Error { error: String },
}

impl From<kallax_bridge::EventBusCoreError> for Response {
    fn from(e: kallax_bridge::EventBusCoreError) -> Self {
        Response::Error { error: e.to_string() }
    }
}

// ── Priority resolution ────────────────────────────────────────────────────

fn resolve_priority(p: Option<u8>) -> MessagePriority {
    match p {
        Some(PRIORITY_LOW) => MessagePriority::Low,
        Some(PRIORITY_NORMAL) | None => MessagePriority::Normal,
        Some(PRIORITY_HIGH) => MessagePriority::High,
        Some(PRIORITY_CRITICAL) => MessagePriority::Critical,
        Some(_) => MessagePriority::Normal,
    }
}

// ── State ──────────────────────────────────────────────────────────────────

/// Per-process subscription state (single subscriber per channel).
///
/// In the integration test, each `recv` call targets one channel and we keep a
/// long-lived subscriber on that channel. For multi-channel multi-subscriber
/// scenarios the caller spawns one process per subscriber (跟 4 级降级
/// 模型 联合, L1 Rust subprocess per consumer).
struct BridgeState {
    bus: Arc<EventBusCore>,
    subscriptions: parking_lot::Mutex<Vec<(String, Subscription)>>,
}

impl BridgeState {
    fn new() -> Self {
        Self {
            bus: EventBusCore::with_capacity(SUBSCRIBE_BUFFER, SUBSCRIBE_MAX_SUBSCRIBERS),
            subscriptions: parking_lot::Mutex::new(Vec::new()),
        }
    }

    fn ensure_subscribed(&self, channel: &str) -> Result<(), kallax_bridge::EventBusCoreError> {
        let mut subs = self.subscriptions.lock();
        if subs.iter().any(|(c, _)| c == channel) {
            return Ok(());
        }
        let sub = self.bus.subscribe(channel)?;
        subs.push((channel.to_string(), sub));
        Ok(())
    }

    fn try_pop_envelope(&self, channel: &str) -> Option<EventEnvelope> {
        let mut subs = self.subscriptions.lock();
        let entry = subs.iter_mut().find(|(c, _)| c == channel);
        match entry {
            Some((_, sub)) => sub.try_recv(),
            None => None,
        }
    }
}

// ── Main loop ──────────────────────────────────────────────────────────────

fn main() {
    let _ = tracing_subscriber_init();

    let state = BridgeState::new();
    let stdin = io::stdin();
    let mut stdout = io::stdout().lock();

    // REPL mode: read newline-delimited JSON requests, write responses.
    // Exit on EOF. Use BufRead so we can call `read_line`.
    let mut handle = io::BufReader::new(stdin.lock());
    let mut buf = String::new();
    loop {
        buf.clear();
        let read = match handle.read_line(&mut buf) {
            Ok(n) => n,
            Err(e) => {
                eprintln!("failed to read stdin: {e}");
                std::process::exit(2);
            }
        };
        if read == 0 {
            break;
        }
        let trimmed = buf.trim();
        if trimmed.is_empty() {
            continue;
        }

        let response = match serde_json::from_str::<Request>(trimmed) {
            Ok(req) => handle_request(&state, req),
            Err(e) => Response::Error {
                error: format!("invalid request JSON: {e}"),
            },
        };

        match serde_json::to_string(&response) {
            Ok(s) => {
                if let Err(e) = writeln!(stdout, "{s}") {
                    error!(error = %e, "failed to write response");
                    std::process::exit(2);
                }
                if let Err(e) = stdout.flush() {
                    error!(error = %e, "failed to flush stdout");
                    std::process::exit(2);
                }
            }
            Err(e) => {
                error!(error = %e, "failed to serialize response");
                std::process::exit(2);
            }
        }
    }
}

fn handle_request(state: &BridgeState, req: Request) -> Response {
    match req {
        Request::Publish {
            channel,
            event_id,
            event_type,
            payload,
            priority,
        } => {
            let prio = resolve_priority(priority);
            let envelope = if event_id.is_empty() {
                build_envelope(event_type, payload, prio)
            } else {
                EventEnvelope::new(event_id, event_type, payload, prio)
            };
            match state.bus.publish(&channel, envelope) {
                Ok(delivered) => Response::Publish {
                    delivered: u32::try_from(delivered).unwrap_or(u32::MAX),
                },
                Err(e) => Response::from(e),
            }
        }
        Request::Recv { channel } => match state.ensure_subscribed(&channel) {
            Ok(()) => {
                let env = state.try_pop_envelope(&channel);
                match env {
                    Some(e) => Response::Recv {
                        have: true,
                        envelope: Some(e),
                    },
                    None => Response::Recv {
                        have: false,
                        envelope: None,
                    },
                }
            }
            Err(e) => Response::from(e),
        },
        Request::Stats => Response::Stats(state.bus.stats()),
    }
}

fn tracing_subscriber_init() {
    use tracing_subscriber::EnvFilter;
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("warn"));
    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_writer(io::stderr)
        .try_init();
}
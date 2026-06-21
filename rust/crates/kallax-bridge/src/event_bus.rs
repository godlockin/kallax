//! # EventBusCore — in-process typed pub/sub, pure Rust (no Node.js dependency)
//!
//! Mirrors `node/src/core/event-bus.ts` 1:1 (typed publish/subscribe, channels,
//! delivery stats) but lives in Rust as the L1+napi path. Node.js calls this via
//! napi-rs when the `--features napi` build is active.
//!
//! ## Hard Rules
//!
//! - 0 `unwrap` / `expect` / `panic` in production code
//! - 0 magic numbers (all named constants below)
//! - All errors carry `context` for fail-fast debugging
//! - Structured logging via `tracing` (no `eprintln!` in production paths)
//!
//! ## Concurrency
//!
//! - `tokio::sync::broadcast` per channel for fan-out
//! - `parking_lot::RwLock` for the channel registry
//! - Clone-safe via `Arc<EventBusCore>`

use chrono::{DateTime, Utc};
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use thiserror::Error;
use tokio::sync::broadcast;
use tracing::{debug, error, info};
use uuid::Uuid;

// ── Constants (跟 Hard Rule #4 0 magic numbers 联合) ────────────────────────

/// Default broadcast channel buffer size (per-channel ring buffer for slow consumers).
pub const DEFAULT_CHANNEL_BUFFER: usize = 1024;

/// Maximum subscriber count (DoS guard for L1+napi path).
pub const MAX_SUBSCRIBERS_PER_CHANNEL: usize = 4096;

/// Channel buffer size for `with_capacity` builder.
pub const CHANNEL_BUFFER_FALLBACK: usize = 64;

// ── Types ──────────────────────────────────────────────────────────────────

/// Channel identifier (typed string for the L1 bridge).
pub type ChannelId = String;

/// Message priority (mirrors `MessagePriority` in event-bus.ts).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MessagePriority {
    Low = 0,
    Normal = 1,
    High = 2,
    Critical = 3,
}

impl Default for MessagePriority {
    fn default() -> Self {
        MessagePriority::Normal
    }
}

/// Event envelope crossing the bridge.
///
/// Mirrors `Envelope` in `node/src/core/event-bus.ts`:
/// `event`, `priority`, `deliveredAt`, `retryCount`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EventEnvelope {
    pub event_id: String,
    pub event_type: String,
    pub payload: serde_json::Value,
    pub priority: MessagePriority,
    pub delivered_at: DateTime<Utc>,
    pub retry_count: u32,
}

impl EventEnvelope {
    /// Build a new envelope with `retry_count = 0` and `delivered_at = now`.
    pub fn new(
        event_id: impl Into<String>,
        event_type: impl Into<String>,
        payload: serde_json::Value,
        priority: MessagePriority,
    ) -> Self {
        Self {
            event_id: event_id.into(),
            event_type: event_type.into(),
            payload,
            priority,
            delivered_at: Utc::now(),
            retry_count: 0,
        }
    }
}

/// Stats snapshot — mirrors `EventBusStats` in event-bus.ts.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BridgeStats {
    pub events_published: u64,
    pub events_delivered: u64,
    pub events_dropped: u64,
    pub channel_count: usize,
    pub subscriber_count: usize,
}

// ── Errors ─────────────────────────────────────────────────────────────────

#[derive(Debug, Error)]
pub enum EventBusCoreError {
    #[error("publish failed in {context}: {source}")]
    Publish {
        context: &'static str,
        #[source]
        source: Box<dyn std::error::Error + Send + Sync>,
    },

    #[error("subscribe failed for channel {channel}: {reason}")]
    Subscribe { channel: String, reason: String },

    #[error("channel {channel} at capacity ({max} subscribers)")]
    ChannelAtCapacity { channel: String, max: usize },

    #[error("invalid channel name (empty or contains NUL)")]
    InvalidChannelName,

    #[error("payload exceeds max size ({max_bytes} bytes), got {actual_bytes}")]
    PayloadTooLarge { max_bytes: usize, actual_bytes: usize },
}

pub type Result<T> = std::result::Result<T, EventBusCoreError>;

// ── Subscription handle ────────────────────────────────────────────────────

/// RAII guard returned from `subscribe`; drops the subscription when the
/// handle is dropped (跟 eket L1 resource mgmt 联合, 0 leak).
#[derive(Debug)]
pub struct Subscription {
    channel: ChannelId,
    // `sender` is intentionally kept alive on the subscription handle: when
    // the last `Sender` is dropped, the underlying broadcast channel closes.
    // Holding a clone here keeps the channel open for `inner_rx` until the
    // subscription is dropped.
    #[allow(dead_code)]
    sender: broadcast::Sender<EventEnvelope>,
    inner_rx: broadcast::Receiver<EventEnvelope>,
}

impl Subscription {
    /// Receive the next envelope (async, non-blocking).
    pub async fn recv(&mut self) -> Result<EventEnvelope> {
        use tokio::sync::broadcast::error::RecvError;
        match self.inner_rx.recv().await {
            Ok(env) => {
                debug!(
                    channel = %self.channel,
                    event_id = %env.event_id,
                    "subscription received envelope"
                );
                Ok(env)
            }
            Err(RecvError::Lagged(skipped)) => {
                error!(
                    channel = %self.channel,
                    skipped,
                    "subscription lagged, dropped messages"
                );
                Err(EventBusCoreError::Subscribe {
                    channel: self.channel.clone(),
                    reason: format!("lagged by {skipped} messages"),
                })
            }
            Err(RecvError::Closed) => Err(EventBusCoreError::Subscribe {
                channel: self.channel.clone(),
                reason: "channel closed".to_string(),
            }),
        }
    }

    /// Non-blocking receive: returns `Some(env)` if a message is in the buffer,
    /// `None` if the buffer is empty.
    ///
    /// Used by the stdio RPC CLI binary (`bin/event_bus_bridge_cli.rs`) for
    /// poll-based subscription draining without an async runtime.
    pub fn try_recv(&mut self) -> Option<EventEnvelope> {
        use tokio::sync::broadcast::error::TryRecvError;
        match self.inner_rx.try_recv() {
            Ok(env) => Some(env),
            Err(TryRecvError::Empty) | Err(TryRecvError::Lagged(_)) | Err(TryRecvError::Closed) => {
                None
            }
        }
    }

    pub fn channel(&self) -> &str {
        &self.channel
    }
}

// ── Core implementation ────────────────────────────────────────────────────

/// In-process typed event bus, pure Rust. Thread-safe via Arc.
///
/// Mirrors `EventBus` interface from `node/src/core/event-bus.ts`:
/// - `publish(channel, envelope)` — fan-out to all subscribers
/// - `subscribe(channel)` — returns a `Subscription` handle
/// - `unsubscribe(channel)` — drops all subscribers for a channel
/// - `stats()` — snapshot of counters
///
/// ## Standalone (no `kallax-engine` dependency)
///
/// This implementation is intentionally self-contained — it does NOT depend on
/// the pre-existing `kallax-engine::event_bus` module, which has 14 pre-existing
/// compile errors blocking that crate (verified with `cargo check --package
/// kallax-engine`). The bridge layer must be reliable independent of engine
/// rebuild status.
pub struct EventBusCore {
    /// channel name → broadcast Sender (bounded by channel_buffer)
    channels: RwLock<HashMap<ChannelId, broadcast::Sender<EventEnvelope>>>,
    /// Aggregate stats (atomics-friendly via parking_lot mutex would be heavy,
    /// so we use a dedicated small Mutex for counters only).
    stats: parking_lot::Mutex<BridgeStats>,
    /// Per-channel subscriber cap (shared with MAX_SUBSCRIBERS_PER_CHANNEL).
    max_subscribers_per_channel: usize,
    /// Per-channel broadcast buffer size (configurable via `with_capacity`).
    channel_buffer: usize,
}

impl EventBusCore {
    /// Create a new event bus core with default config.
    pub fn new() -> Arc<Self> {
        Self::with_capacity(DEFAULT_CHANNEL_BUFFER, MAX_SUBSCRIBERS_PER_CHANNEL)
    }

    /// Create a new event bus core with explicit capacity and subscriber cap.
    pub fn with_capacity(channel_buffer: usize, max_subscribers: usize) -> Arc<Self> {
        let resolved_buffer = if channel_buffer == 0 {
            CHANNEL_BUFFER_FALLBACK
        } else {
            channel_buffer
        };
        Arc::new(Self {
            channels: RwLock::new(HashMap::new()),
            stats: parking_lot::Mutex::new(BridgeStats {
                events_published: 0,
                events_delivered: 0,
                events_dropped: 0,
                channel_count: 0,
                subscriber_count: 0,
            }),
            max_subscribers_per_channel: max_subscribers,
            channel_buffer: resolved_buffer,
        })
    }

    /// Validate a channel name (non-empty, no NUL bytes).
    fn validate_channel(channel: &str) -> Result<()> {
        if channel.is_empty() || channel.contains('\0') {
            return Err(EventBusCoreError::InvalidChannelName);
        }
        Ok(())
    }

    /// Publish an envelope to a channel. Returns the number of subscribers
    /// the message was delivered to.
    pub fn publish(&self, channel: &str, envelope: EventEnvelope) -> Result<usize> {
        Self::validate_channel(channel)?;

        let sender = {
            let channels = self.channels.read();
            channels.get(channel).cloned()
        };

        let sender = match sender {
            Some(s) => s,
            None => {
                debug!(
                    channel,
                    event_id = %envelope.event_id,
                    "publish: no subscribers, dropping envelope"
                );
                self.bump_dropped();
                return Ok(0);
            }
        };

        let receiver_count = sender.receiver_count();
        match sender.send(envelope) {
            Ok(_delivered_count) => {
                debug!(
                    channel,
                    receiver_count,
                    "publish fanned out to subscribers"
                );
                self.bump_published();
                Ok(receiver_count)
            }
            Err(send_err) => {
                // All receivers dropped; this is not a hard error for publish —
                // log and bump dropped counter.
                error!(
                    channel,
                    event_id = %send_err.0.event_id,
                    "publish failed: no live receivers"
                );
                self.bump_dropped();
                Ok(0)
            }
        }
    }

    /// Subscribe to a channel. Lazily creates the broadcast channel on first
    /// subscriber.
    pub fn subscribe(self: &Arc<Self>, channel: &str) -> Result<Subscription> {
        Self::validate_channel(channel)?;

        // Acquire write lock to create the channel if missing.
        let buffer = self.channel_buffer;
        let sender = {
            let mut channels = self.channels.write();
            let sender = channels
                .entry(channel.to_string())
                .or_insert_with(|| {
                    let (tx, _rx) = broadcast::channel(buffer);
                    tx
                })
                .clone();
            sender
        };

        let receiver_count = sender.receiver_count();
        if receiver_count >= self.max_subscribers_per_channel {
            return Err(EventBusCoreError::ChannelAtCapacity {
                channel: channel.to_string(),
                max: self.max_subscribers_per_channel,
            });
        }

        let inner_rx = sender.subscribe();
        self.bump_subscriber_added();

        debug!(
            channel,
            receiver_count = receiver_count + 1,
            "new subscriber registered"
        );

        Ok(Subscription {
            channel: channel.to_string(),
            sender,
            inner_rx,
        })
    }

    /// Drop all subscribers for a channel (returns count dropped).
    pub fn unsubscribe(&self, channel: &str) -> Result<usize> {
        Self::validate_channel(channel)?;
        let mut channels = self.channels.write();
        match channels.remove(channel) {
            Some(_sender) => {
                let dropped = _sender.receiver_count();
                self.bump_channel_removed(dropped);
                info!(channel, dropped, "channel removed");
                Ok(dropped)
            }
            None => Ok(0),
        }
    }

    /// Snapshot the current stats.
    pub fn stats(&self) -> BridgeStats {
        let stats = self.stats.lock();
        let channels = self.channels.read();
        BridgeStats {
            events_published: stats.events_published,
            events_delivered: stats.events_delivered,
            events_dropped: stats.events_dropped,
            channel_count: channels.len(),
            subscriber_count: stats.subscriber_count,
        }
    }

    // ── Counter helpers (private, 0 leak) ─────────────────────────────────

    fn bump_published(&self) {
        let mut stats = self.stats.lock();
        stats.events_published = stats.events_published.saturating_add(1);
    }

    fn bump_dropped(&self) {
        let mut stats = self.stats.lock();
        stats.events_dropped = stats.events_dropped.saturating_add(1);
    }

    fn bump_subscriber_added(&self) {
        let mut stats = self.stats.lock();
        stats.subscriber_count = stats.subscriber_count.saturating_add(1);
    }

    fn bump_channel_removed(&self, dropped_subscribers: usize) {
        let mut stats = self.stats.lock();
        stats.subscriber_count = stats
            .subscriber_count
            .saturating_sub(dropped_subscribers);
    }
}

impl Default for EventBusCore {
    fn default() -> Self {
        // Direct construction (not Arc-wrapped) for `Default` compatibility;
        // callers wanting shared ownership should use `EventBusCore::new()`.
        Self {
            channels: RwLock::new(HashMap::new()),
            stats: parking_lot::Mutex::new(BridgeStats {
                events_published: 0,
                events_delivered: 0,
                events_dropped: 0,
                channel_count: 0,
                subscriber_count: 0,
            }),
            max_subscribers_per_channel: MAX_SUBSCRIBERS_PER_CHANNEL,
            channel_buffer: DEFAULT_CHANNEL_BUFFER,
        }
    }
}

// ── Helpers (跟 Rule 5 DRY 联合, 1 source of truth) ─────────────────────────

/// Generate a unique event ID (mirrors `generateId()` in event-bus.ts).
pub fn generate_event_id() -> String {
    format!("evt_{}", Uuid::new_v4().simple())
}

/// Build an envelope with a fresh ID and `delivered_at = now`.
pub fn build_envelope(
    event_type: impl Into<String>,
    payload: serde_json::Value,
    priority: MessagePriority,
) -> EventEnvelope {
    EventEnvelope::new(generate_event_id(), event_type, payload, priority)
}

// Unit tests moved to `tests/event_bus.rs` (integration-style) to keep the lib
// file focused on production logic (跟 Rule 8 ≤ 500 lines per file 联合).
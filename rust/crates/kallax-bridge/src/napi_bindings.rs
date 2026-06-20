//! # napi bindings — Node.js ↔ Rust bridge (optional, behind `napi` feature)
//!
//! This module is only compiled when the `napi` feature is enabled:
//!
//! ```bash
//! cargo build --features napi
//! ```
//!
//! In the **default build** (no `napi` feature), this file is **not compiled**,
//! keeping `cargo check` clean without the napi-rs toolchain.
//!
//! ## Design rationale
//!
//! The `event_bus.rs` core is the source of truth. The napi layer is a thin
//! wrapper exposing `EventBusBridge` to Node.js with the same shape as
//! `node/src/core/event-bus.ts` (1:1 interface parity, 0 copy-paste in the
//! JS adapter).
//!
//! ## Activation path
//!
//! ```text
//! --features napi → napi_bindings.rs compiled
//!   → calls napi_build::setup() to wire up Node-API
//!   → exports EventBusBridge JS class via #[napi] proc macros
//! ```
//!
//! When the napi-rs toolchain is unavailable (e.g., CI without node-gyp deps),
//! the default `cargo check` path passes with 0 errors and Node.js falls back
//! to the in-process L2 path (跟 eket 4 级降级 模式 联合).

#![cfg(feature = "napi")]

use crate::event_bus::{
    build_envelope, EventBusCore, EventEnvelope, MessagePriority,
};
use napi::bindgen_prelude::*;
use napi_derive::napi;
use std::sync::Arc;

/// JS-visible wrapper around `EventBusCore`. Mirrors the `EventBus` interface
/// in `node/src/core/event-bus.ts` 1:1.
#[napi]
pub struct EventBusBridge {
    inner: Arc<EventBusCore>,
}

#[napi]
impl EventBusBridge {
    /// Create a new event bus bridge. Default capacity.
    #[napi(constructor)]
    pub fn new() -> Result<Self> {
        Ok(Self {
            inner: EventBusCore::new(),
        })
    }

    /// Publish an event envelope (JSON-serializable) to a channel.
    ///
    /// Returns the number of subscribers the message was delivered to.
    #[napi]
    pub fn publish(
        &self,
        channel: String,
        event_id: String,
        event_type: String,
        payload: serde_json::Value,
        priority: Option<u8>,
    ) -> Result<u32> {
        let prio = match priority {
            Some(0) => MessagePriority::Low,
            Some(1) => MessagePriority::Normal,
            Some(2) => MessagePriority::High,
            Some(3) => MessagePriority::Critical,
            Some(_) => {
                return Err(Error::new(
                    Status::InvalidArg,
                    "priority must be 0 (Low), 1 (Normal), 2 (High), or 3 (Critical)",
                ))
            }
            None => MessagePriority::Normal,
        };
        let envelope = EventEnvelope::new(event_id, event_type, payload, prio);
        self.inner
            .publish(&channel, envelope)
            .map(u32::try_from)
            .map_err(|e| Error::new(Status::GenericFailure, format!("{e}")))?
            .map_err(|_| Error::new(Status::GenericFailure, "delivered count overflow".to_string()))
    }

    /// Subscribe to a channel. Returns a JS `EventSubscription` handle with
    /// an async `recv()` method.
    #[napi]
    pub fn subscribe(&self, channel: String) -> Result<EventSubscription> {
        let sub = self
            .inner
            .subscribe(&channel)
            .map_err(|e| Error::new(Status::GenericFailure, format!("{e}")))?;
        Ok(EventSubscription { inner: Some(sub) })
    }

    /// Drop all subscribers for a channel.
    #[napi]
    pub fn unsubscribe(&self, channel: String) -> Result<u32> {
        self.inner
            .unsubscribe(&channel)
            .map(u32::try_from)
            .map_err(|e| Error::new(Status::GenericFailure, format!("{e}")))?
            .map_err(|_| Error::new(Status::GenericFailure, "dropped count overflow".to_string()))
    }

    /// Snapshot stats (returns JS object).
    #[napi]
    pub fn stats(&self) -> BridgeStatsJs {
        let s = self.inner.stats();
        BridgeStatsJs {
            events_published: s.events_published,
            events_delivered: s.events_delivered,
            events_dropped: s.events_dropped,
            channel_count: s.channel_count as u32,
            subscriber_count: s.subscriber_count,
        }
    }

    /// Build a fresh envelope (helper for tests / Node.js glue code).
    #[napi(factory)]
    pub fn build_envelope(
        event_type: String,
        payload: serde_json::Value,
        priority: Option<u8>,
    ) -> EnvelopeJs {
        let prio = match priority {
            Some(0) => MessagePriority::Low,
            Some(1) | None => MessagePriority::Normal,
            Some(2) => MessagePriority::High,
            Some(3) => MessagePriority::Critical,
            Some(_) => MessagePriority::Normal,
        };
        let env = build_envelope(event_type, payload, prio);
        EnvelopeJs {
            event_id: env.event_id,
            event_type: env.event_type,
            payload: env.payload,
            priority: env.priority as u8,
            retry_count: env.retry_count,
        }
    }
}

/// JS-visible subscription handle. `recv()` returns a Promise<EventEnvelope>.
#[napi]
pub struct EventSubscription {
    inner: Option<crate::event_bus::Subscription>,
}

#[napi]
impl EventSubscription {
    /// Receive the next envelope (async). Returns `null` on close/lag.
    #[napi]
    pub async fn recv(&mut self) -> Result<Option<EnvelopeJs>> {
        let sub = match self.inner.as_mut() {
            Some(s) => s,
            None => return Ok(None),
        };
        match sub.recv().await {
            Ok(env) => Ok(Some(EnvelopeJs {
                event_id: env.event_id,
                event_type: env.event_type,
                payload: env.payload,
                priority: env.priority as u8,
                retry_count: env.retry_count,
            })),
            Err(_) => Ok(None),
        }
    }

    /// Channel name.
    #[napi(getter)]
    pub fn channel(&self) -> String {
        self.inner
            .as_ref()
            .map(|s| s.channel().to_string())
            .unwrap_or_default()
    }
}

/// JS-mirrored envelope shape.
#[napi(object)]
pub struct EnvelopeJs {
    pub event_id: String,
    pub event_type: String,
    pub payload: serde_json::Value,
    pub priority: u8,
    pub retry_count: u32,
}

/// JS-mirrored stats shape.
#[napi(object)]
pub struct BridgeStatsJs {
    pub events_published: u64,
    pub events_delivered: u64,
    pub events_dropped: u64,
    pub channel_count: u32,
    pub subscriber_count: u64,
}
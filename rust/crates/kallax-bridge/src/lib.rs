//! # KALLAX Bridge — Rust ↔ Node.js bridge layer
//!
//! EPIC-060-B Phase 3 Sub-Task 2: in-process typed event bus (358-line
//! `node/src/core/event-bus.ts`) → Rust napi-rs binding.
//!
//! ## 4-Level Degradation (跟 AGENTS.md 联合, 跟 eket 4 级降级 模式 联合)
//!
//! ```text
//! L1+napi  Rust native module + napi-rs exports  (primary, this crate, --features napi)
//! L1       Rust pure in-process bus              (always available, default build)
//! L2       Node.js in-process bus                (fallback, node/src/core/event-bus.ts)
//! L0       Shell                                (emergency)
//! ```
//!
//! ## Design
//!
//! - Default `cargo check`: 0 errors, no napi toolchain required.
//! - With `--features napi`: produces a Node.js native module exporting
//!   `EventBusBridge` (publish / subscribe / stats).
//! - The Rust core (`event_bus.rs`) is the source of truth; napi bindings
//!   are a thin wrapper. This keeps the L1 path testable without Node.js.
//!
//! ## Hard Rules
//!
//! - 0 `unwrap` / `expect` / `panic` in production code (跟 AGENTS.md 联合).
//! - 0 magic numbers (named constants).
//! - All log events are structured (`tracing` / `eprintln!`).

#![warn(clippy::unwrap_used)]
#![warn(clippy::expect_used)]
#![warn(clippy::panic)]

pub mod event_bus;

#[cfg(feature = "napi")]
pub mod napi_bindings;

// ── Re-exports (跟 Rule 5 DRY 联合, 1 source of truth) ─────────────────────

pub use event_bus::{
    build_envelope, generate_event_id, BridgeStats, EventBusCore, EventBusCoreError, EventEnvelope,
    MessagePriority,
};
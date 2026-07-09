//! KALLAX Core - Types and abstractions for multi-agent orchestration
//!
//! # Design Principles
//! - **No unwrap/expect/panic** - All errors use Result
//! - **Structured errors** - KallaxError with context
//! - **Type safety** - No `any` equivalents
//! - **Immutability** - Prefer owned data over mutable references

pub mod analyzer;
pub mod db;
pub mod error;
pub mod types;
pub mod cache;
pub mod middleware;
pub mod registry;
pub mod isolation;
pub mod webhook;
pub mod fingerprint;

pub use error::{KallaxError, Result};
pub use types::*;
pub use cache::Cache;
pub use middleware::MiddlewarePipeline;
pub use registry::Registry;
pub use isolation::IsolationScope;
// EPIC-095: re-export db types (跟 ticket_engine.rs EPIC-075/079 联合, 治 E0432)
pub use db::{SqliteClient, TicketFilter};

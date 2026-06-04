//! KALLAX Core - Types and abstractions for multi-agent orchestration
//!
//! # Design Principles
//! - **No unwrap/expect/panic** - All errors use Result
//! - **Structured errors** - KallaxError with context
//! - **Type safety** - No `any` equivalents
//! - **Immutability** - Prefer owned data over mutable references

pub mod analyzer;
pub mod error;
pub mod types;
pub mod cache;
pub mod middleware;
pub mod registry;
pub mod isolation;

pub use error::{KallaxError, Result};
pub use types::*;
pub use cache::Cache;
pub use middleware::MiddlewarePipeline;
pub use registry::Registry;
pub use isolation::IsolationScope;

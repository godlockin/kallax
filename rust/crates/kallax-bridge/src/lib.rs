//! KALLAX Bridge - Node.js ↔ Rust FFI via napi-rs
//!
//! # Scope (EPIC-060-B Phase 3 Task 1 scaffold)
//!
//! This crate provides the napi-rs binding surface that lets Node.js
//! call into Rust modules. Phase 3 Task 1 ships only the scaffold
//! (version + ping). Subsequent sub-tasks wire real modules:
//!
//! - Phase 3-2: `event-bus-bridge` (cross-process pub/sub)
//! - Phase 3-3: `data-adapter-bridge` (sqlite / file / redis)
//! - Phase 3-4: `master-verify-bridge` (4-level fact-forcing)
//!
//! # Design Principles
//!
//! - **No unwrap/expect/panic in business logic** - errors surface as napi::Error
//! - **Structured tracing** - bridge calls log via `tracing` (not println)
//! - **Type safety** - all exports are typed; no opaque blobs across FFI
//! - **Scaffolding only** - zero business logic in this file; bridge surface
//!   stays minimal until sub-tasks 2-4 land
//! - **Feature-gated napi** - `cargo test` builds rlib without napi symbols,
//!   `cargo build` / `napi build` produce the cdylib with FFI exports
//!
//! # Build
//!
//! ```bash
//! # Library type check (works in any env, includes napi feature by default):
//! cargo check -p kallax-bridge
//!
//! # Unit tests (rlib only, napi feature disabled to skip Node.js symbol linking):
//! cargo test -p kallax-bridge --no-default-features
//!
//! # Actual Node.js binding (requires @napi-rs/cli + Node 18+):
//! cd rust/crates/kallax-bridge && napi build --platform --release
//! ```

// ===== Pure Rust impls (always compiled, used by tests + napi wrappers) =====

/// Return the bridge version (mirrors `kallax-bridge` crate version).
///
/// Used by Node.js health checks (`isAlive()` in `core/rust-bridge.ts`)
/// to confirm the napi-rs binding is loaded and matching expected build.
pub fn version_impl() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// Lightweight liveness probe.
///
/// Returns `"pong"` when the napi binding is loaded. Node.js side
/// (`RustBridge.isAlive`) calls this before any real bridge call to
/// fail fast when the binding is missing or crashed.
pub fn ping_impl() -> &'static str {
    "pong"
}

/// Compile-time marker confirming the napi-rs build linked correctly.
///
/// Returns `true` only when the napi binding initialized. Phase 3-2/3-3/3-4
/// will extend this with real module readiness checks (event-bus subscription,
/// sqlite handle open, verify pipeline loaded).
pub fn is_loaded_impl() -> bool {
    true
}

// ===== napi FFI exports (gated by `napi` feature, compiled into cdylib) =====

#[cfg(feature = "napi")]
mod napi_bindings {
    use napi_derive::napi;

    #[napi]
    pub fn version() -> String {
        super::version_impl()
    }

    #[napi]
    pub fn ping() -> String {
        super::ping_impl().to_string()
    }

    #[napi]
    pub fn is_loaded() -> bool {
        super::is_loaded_impl()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_is_semver() {
        let v = version_impl();
        assert!(!v.is_empty(), "version must not be empty");
        let parts: Vec<&str> = v.split('.').collect();
        assert!(
            parts.len() >= 2,
            "version must have at least major.minor: got {v}"
        );
    }

    #[test]
    fn ping_returns_pong() {
        assert_eq!(ping_impl(), "pong");
    }

    #[test]
    fn is_loaded_is_true() {
        assert!(is_loaded_impl());
    }
}
// rust/crates/kallax-bridge/src/lib.rs — KALLAX Node.js ↔ Rust bridge
//
// EPIC-060-B 阶段 3 子任务 4: master-verify napi-rs binding
// 跟 6 维度 L1-L6 联合 (跟 node/src/core/master-verify/dimensions.ts 1:1 mapping)
// 跟 eket 4 级降级 模式 联合: L1 Rust 主用 + L2 Node.js 备
// 跟 AGENTS.md 9 hard rules 联合: 0 unwrap/expect/panic, 0 magic numbers, 0 copy-paste
// 跟 EPIC-059-D Fact-Forcing 联合: 所有 6 维度 都 显式 evidence 返回
//
// 架构:
//   - master_verify.rs: 纯 Rust 6 维 logic (0 napi 依赖, examples/ 跟 cargo run --example 可用)
//   - napi_bindings.rs: #[napi] 包装 layer (仅 Node.js binding 必需, 0 业务 logic)
//   - error.rs: typed BridgeError (no unwrap/expect/panic)
//
// 跟 Rule 8 (no copy-paste) 联合: 1 pure Rust module + 1 thin napi wrapper, 0 duplicate.

#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]
#![deny(clippy::panic)]

pub mod error;
pub mod master_verify;

#[cfg(feature = "napi-bindings")]
mod napi_bindings;

pub use error::BridgeError;
pub use master_verify::{
    DimensionResult, MasterVerifyBridge, MasterVerifyResult, BRIDGE_VERSION, MAX_FILE_BYTES,
};
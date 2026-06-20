// rust/crates/kallax-bridge/src/napi_bindings.rs — napi-rs thin wrapper
//
// 跟 Rule 8 (no copy-paste) 联合: 0 业务 logic, 仅 thin wrapper 把 MasterVerifyBridge
// 暴露 给 Node.js. 纯 Rust logic 在 master_verify.rs (无 napi 依赖), examples/ cargo run
// 可用 master_verify.rs 跑 0 napi linkage.
//
// 跟 Rule 3 (no skip tests) + Rule 10 (real tests) 联合: 显式 typed Result, 失败 → JsError.

#[cfg(feature = "napi-bindings")]
use napi::bindgen_prelude::Result;
#[cfg(feature = "napi-bindings")]
use napi_derive::napi;

use crate::master_verify::{DimensionResult, MasterVerifyBridge, MasterVerifyResult, BRIDGE_VERSION};

/// Bridge version string (跟 BRIDGE_VERSION 联合, 0 magic numbers).
#[cfg_attr(feature = "napi-bindings", napi)]
pub fn bridge_version() -> String {
    BRIDGE_VERSION.to_string()
}

/// L1 Existence (跟 node dimensions.ts checkL1 1:1 联合).
#[cfg_attr(feature = "napi-bindings", napi)]
pub fn verify_l1_existence(path: String) -> Result<DimensionResult> {
    MasterVerifyBridge::verify_l1_existence(&path).map_err(|e| napi::Error::from_reason(e.to_string()))
}

/// L2 Substance (跟 node dimensions.ts checkL2 1:1 联合).
#[cfg_attr(feature = "napi-bindings", napi)]
pub fn verify_l2_substance(path: String) -> Result<DimensionResult> {
    MasterVerifyBridge::verify_l2_substance(&path).map_err(|e| napi::Error::from_reason(e.to_string()))
}

/// L3 Wiring (跟 node dimensions.ts checkL3 1:1 联合).
#[cfg_attr(feature = "napi-bindings", napi)]
pub fn verify_l3_wiring(path: String) -> Result<DimensionResult> {
    MasterVerifyBridge::verify_l3_wiring(&path).map_err(|e| napi::Error::from_reason(e.to_string()))
}

/// L4 Data Flow (跟 node dimensions.ts checkL4 1:1 联合).
#[cfg_attr(feature = "napi-bindings", napi)]
pub fn verify_l4_data_flow(path: String) -> Result<DimensionResult> {
    MasterVerifyBridge::verify_l4_data_flow(&path).map_err(|e| napi::Error::from_reason(e.to_string()))
}

/// L5 Fact Forcing (跟 node dimensions.ts checkL5 1:1 联合).
#[cfg_attr(feature = "napi-bindings", napi)]
pub fn verify_l5_fact_forcing(path: String) -> Result<DimensionResult> {
    MasterVerifyBridge::verify_l5_fact_forcing(&path).map_err(|e| napi::Error::from_reason(e.to_string()))
}

/// L6 Honesty (跟 node dimensions.ts checkL6 1:1 联合).
#[cfg_attr(feature = "napi-bindings", napi)]
pub fn verify_l6_honesty(path: String) -> Result<DimensionResult> {
    MasterVerifyBridge::verify_l6_honesty(&path).map_err(|e| napi::Error::from_reason(e.to_string()))
}

/// Aggregate 6-dimension result (跟 eket L1 Rust 主用 entry 联合).
#[cfg_attr(feature = "napi-bindings", napi)]
pub fn verify_all(path: String) -> Result<MasterVerifyResult> {
    MasterVerifyBridge::verify_all(&path).map_err(|e| napi::Error::from_reason(e.to_string()))
}
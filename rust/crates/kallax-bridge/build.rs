// build.rs — napi-rs 2.x build script
// 跟 napi-build 2.3.2 联合, 0 业务 logic, 0 magic numbers
// 跟 "feature-gated napi" 模式 联合: 仅 当 napi-bindings feature 启用 时 调用 napi_build::setup()

#[cfg(feature = "napi-bindings")]
fn main() {
    napi_build::setup();
}

#[cfg(not(feature = "napi-bindings"))]
fn main() {
    // 0 napi setup 必要 — pure Rust build path
}
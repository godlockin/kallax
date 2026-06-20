// rust/crates/kallax-bridge/examples/smoke.rs — CLI smoke test for master-verify bridge
//
// EPIC-060-B 阶段 3 子任务 4: real binary smoke test (跟 Rule 10 real tests 联合)
// 跟 eket 0 magic numbers 联合: 显式 命名, 0 隐含 literal.
//
// Usage: cargo run --example smoke -- <file_path>
//   1 file_path provided → run verify_all on it, print JSON result
//   0 file_path         → run all 6 dim self-tests on this file, print summary

use kallax_bridge::{MasterVerifyBridge, BRIDGE_VERSION};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    println!("=== KALLAX Master Verify Bridge Smoke Test ===");
    println!("bridge_version: {}", BRIDGE_VERSION);
    println!();

    if args.len() > 1 {
        let path = &args[1];
        match MasterVerifyBridge::verify_all(path) {
            Ok(r) => {
                println!("verify_all({}): {}/{} passed={}",
                    path, r.total_passed, r.total_dimensions, r.passed);
                for dim in [&r.l1, &r.l2, &r.l3, &r.l4, &r.l5, &r.l6] {
                    println!("  {} {}: {}", if dim.passed { "✓" } else { "✗" }, dim.dimension, dim.description);
                }
                if r.passed {
                    std::process::exit(0);
                } else {
                    std::process::exit(1);
                }
            }
            Err(e) => {
                eprintln!("verify_all failed: {}", e);
                std::process::exit(2);
            }
        }
    }

    // Self-test: run all 6 dims on this example file
    let self_path = file!();
    println!("Self-test on: {}", self_path);
    match MasterVerifyBridge::verify_all(self_path) {
        Ok(r) => {
            println!("Self-test result: {}/{} passed={}",
                r.total_passed, r.total_dimensions, r.passed);
        }
        Err(e) => {
            eprintln!("Self-test failed: {}", e);
            std::process::exit(2);
        }
    }
}
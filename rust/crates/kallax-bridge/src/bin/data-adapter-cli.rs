//! KALLAX data-adapter CLI bridge.
//!
//! EPIC-060-B Phase 3 sub-task 3: this binary is the L1 Rust entry point that
//! the Node.js bridge (`node/src/core/data-adapter-bridge.ts`) drives via
//! `child_process.spawn`. It reads newline-delimited JSON [`IpcRequest`]s on
//! stdin and emits [`IpcResponse`]s on stdout.
//!
//! Usage:
//!   kallax-data-adapter <db-path>
//!
//! All errors are returned as structured JSON; the process never writes to
//! stderr unless there is a fatal startup failure (missing db path arg,
//! stdout pipe closed, etc.). This matches the L1 / L2 degradation contract:
//! - L1 (this CLI): primary path.
//! - L2 (Node.js better-sqlite3): fallback when the CLI fails to start.
//!
//! 跟 napi-rs future upgrade path 联合: the IPC envelope is identical to the
//! `#[napi]` shape, so a future migration to in-process napi-rs will not
//! require any Node.js-side changes.

use kallax_bridge::{BridgeError, DataAdapterBridge, IpcRequest, IpcResponse};
use std::io::{self, BufRead, Write};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("usage: kallax-data-adapter <db-path>");
        std::process::exit(2);
    }
    let db_path = &args[1];

    let bridge = match DataAdapterBridge::open(db_path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("bridge open failed: {e}");
            std::process::exit(1);
        }
    };

    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out = stdout.lock();

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break, // pipe closed
        };
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        let request: IpcRequest = match serde_json::from_str(trimmed) {
            Ok(r) => r,
            Err(e) => {
                let resp = IpcResponse::err(0, &BridgeError::ipc("parse_request", e));
                let line = serde_json::to_string(&resp).unwrap_or_else(|_| "{}".into());
                writeln!(out, "{line}").ok();
                out.flush().ok();
                continue;
            }
        };

        let response = bridge.handle(request);
        let line = serde_json::to_string(&response).unwrap_or_else(|_| "{}".into());
        writeln!(out, "{line}").ok();
        out.flush().ok();
    }
}
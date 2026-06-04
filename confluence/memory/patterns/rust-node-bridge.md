# Rust-Node HTTP Bridge

> IPC between Rust core and Node.js CLI via Axum HTTP + fetch()
> Updated: 2026-06-04

## Why HTTP Bridge?

| Approach | Startup | State | Debugging | Chosen? |
|----------|---------|-------|-----------|---------|
| napi-rs | ~0ms | In-process | Hard | No (ABI deps) |
| child_process | ~8ms/call | Stateless | Medium | No |
| HTTP bridge | ~8ms once | Persistent | Easy (curl) | **Yes** |

## Architecture

Rust Axum server on localhost:9877. Node calls via fetch(). RecoveryManager probes every 60s.

Endpoints: /health, /stats, /tasks, /performers, /bridge/status, /bridge/scheduler

## 3-Level Degradation

| Level | Engine | Startup | Memory | Features |
|-------|--------|---------|--------|----------|
| L3 | Rust | ~8ms | ~12MB | Full |
| L2 | Node | ~400ms | ~120MB | Degraded |
| L1 | Shell | ~50ms | ~2MB | Emergency |

Upgrade: 3 consecutive successful probes. Degrade: immediate on failure.

## Node DB as Single Source of Truth

Node SQLite writes, Rust reads via HTTP. No two-writer problem. Millisecond-scale staleness acceptable.

## References
- [[degradation-strategy]]
- [[framework]]
- [[election-system]]

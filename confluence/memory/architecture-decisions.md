# Architecture Decisions — KALLAX ADR Summary

> Aggregated from EKET→KALLAX rebuild. Updated: 2026-06-04

## ADR-001: Conductor-Performer Naming
Replaced Master/Slaver. Musical analogy fits: Conductor keeps time, Performer plays.

## ADR-002: Mandatory Worktree Isolation
`kallax task:claim` auto-creates `git worktree add`. File scope declarations per ticket. Result: zero conflicts.

## ADR-003: Banned Panic Patterns
CI rejects `expect()`, `unwrap()`, `panic!()` in production. All errors via `Result<T,E>`. Result: 12 violations fixed, zero crashes.

## ADR-004: Three-Level Degradation
Rust (L3) → Node (L2) → Shell (L1). RecoveryManager probes 60s, upgrades after 3 successes, degrades immediately.

## ADR-005: HTTP Bridge over napi-rs
Rust Axum on localhost:9877 + Node fetch(). Simple, debuggable, version-independent.

## ADR-006: Node SQLite as Single Source of Truth
Node writes, Rust reads via HTTP. No write conflicts.

## ADR-007: Saga Pattern for Task Completion
Multi-step completion with forward/compensate. Failed compensation logged but never crashes.

## ADR-008: Project-Scoped Data Directory
All data in `<project>/.kallax/`, never `~/.kallax/`.

## ADR-009: Foreground-Only Code Writes
Background agents hallucinate writes. Hard rule: foreground for writes, background for reads.

## ADR-010: No Cross-Performer Help
Each performer stays in its worktree. Questions through Conductor. Result: zero scope violations.

## References
- [[kallax-rebuild-lessons]]
- [[multi-agent-collab-failures]]
- [[degradation-strategy]]

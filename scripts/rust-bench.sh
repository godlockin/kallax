#!/usr/bin/env bash
# EPIC-060-B Phase 1 unified Rust benchmark runner.
# Runs all 3 tasks in `rust/crates/kallax-bench/`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUST_DIR="${REPO_ROOT}/rust"
LOG_DIR="${REPO_ROOT}/.kallax/bench-logs"
mkdir -p "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/rust-bench-$(date +%Y%m%d-%H%M%S).txt"

echo "[rust-bench] starting criterion run at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[rust-bench] log file: ${LOG_FILE}"

cd "${RUST_DIR}"
cargo bench --package kallax-bench -- --output-format bencher 2>&1 | tee "${LOG_FILE}"

echo "[rust-bench] done at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
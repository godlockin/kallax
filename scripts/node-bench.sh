#!/usr/bin/env bash
# EPIC-060-B Phase 1 unified Node.js benchmark runner.
# Runs all 3 tasks in `node/bench/`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
NODE_DIR="${REPO_ROOT}/node"
LOG_DIR="${REPO_ROOT}/.kallax/bench-logs"
mkdir -p "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/node-bench-$(date +%Y%m%d-%H%M%S).jsonl"

echo "[node-bench] starting node run at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[node-bench] log file: ${LOG_FILE}"

cd "${NODE_DIR}"

{
  echo "{\"runner\":\"node\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"nodeVersion\":\"$(node --version)\"}"
  node bench/bench-json.js
  node bench/bench-sqlite.js
  node bench/bench-hash.js
} | tee "${LOG_FILE}"

echo "[node-bench] done at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
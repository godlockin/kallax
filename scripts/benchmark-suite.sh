#!/usr/bin/env bash
# KALLAX Benchmark Suite Runner
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
echo "# KALLAX Benchmark Report"
echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""
cd "$PROJECT_ROOT"
npx tsx node/benchmarks/benchmark-suite.ts

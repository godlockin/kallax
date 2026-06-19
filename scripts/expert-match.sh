#!/usr/bin/env bash
# scripts/expert-match.sh — DEPRECATED Wrapper for KALLAX
#来源: EXPERT-EXTENSION-SCHEME §2.3
# DEPRECATED: Use kallax-expert-match (Rust binary) instead
# This wrapper exists for backward compatibility only

set -euo pipefail

REQ="${1:-}"
if [ -z "$REQ" ]; then
  echo "Usage: bash scripts/expert-match.sh \"<requirement>\""
  echo "Example: bash scripts/expert-match.sh \"接口慢怎么优化\""
  echo ""
  echo "WARNING: This script is deprecated. Use the Rust binary instead:"
  echo "  ./rust/target/release/kallax-expert-match \"<requirement>\""
  exit 1
fi

# Resolve to Rust binary
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="${REPO_ROOT}/rust/target/release/kallax-expert-match"

# Check if binary exists
if [ ! -f "$BIN" ]; then
  echo "Error: Rust binary not found at $BIN" >&2
  echo "Please run: cd rust && cargo build --release -p kallax-cli --bin kallax-expert-match" >&2
  exit 1
fi

# Delegate to Rust binary
exec "$BIN" "$@"

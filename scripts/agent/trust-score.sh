#!/bin/bash
# trust-score.sh — TrustScore 4-factor weighted calculation
# Borrowed from: Conductor §5.1 best_matching_slaver() + compute_trust()
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTANCE_DIR="${KALLAX_ROOT}/.kallax/state/instances"
# Fallback to fixture for test/CI environments (state/instances/ is gitignored)
if [[ ! -d "$INSTANCE_DIR" ]]; then
  INSTANCE_DIR="${KALLAX_ROOT}/tests/fixtures/agent/instances"
fi

# Compute TrustScore for a given instance_id
# Formula: 0.4*success_rate_7d + 0.3*uptime_30d + 0.2*(1-avg_latency_norm) + 0.1*(1-error_rate)
compute_trust() {
  local instance_id="$1"
  local instance_file="${INSTANCE_DIR}/${instance_id}.json"

  if [[ ! -f "$instance_file" ]]; then
    echo "0.5"  # default neutral when instance not found
    return
  fi

  local success_rate_7d
  local uptime_30d
  local avg_latency_norm
  local error_rate

  success_rate_7d=$(jq -r '.success_rate_7d // 0.5' "$instance_file")
  uptime_30d=$(jq -r '.uptime_30d // 0.5' "$instance_file")
  avg_latency_norm=$(jq -r '.avg_latency_norm // 0.5' "$instance_file")
  error_rate=$(jq -r '.error_rate // 0.0' "$instance_file")

  # Weights: success_rate_7d=0.4, uptime_30d=0.3, latency=0.2, error_rate=0.1
  # Using bc for floating-point math; scale=4 for precision
  echo "scale=4; 0.4 * $success_rate_7d + 0.3 * $uptime_30d + 0.2 * (1 - $avg_latency_norm) + 0.1 * (1 - $error_rate)" | bc
}

# Export for sourcing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Called as script
  INSTANCE_ID="${1:-}"
  if [[ -z "$INSTANCE_ID" ]]; then
    echo "ERROR: instance_id required" >&2
    echo "Usage: $0 <instance_id>" >&2
    exit 1
  fi
  compute_trust "$INSTANCE_ID"
else
  # Sourced: export functions
  export -f compute_trust
fi
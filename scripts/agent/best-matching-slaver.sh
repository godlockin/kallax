#!/bin/bash
# best-matching-slaver.sh — 3-layer matching with ALGO_SUGGEST output
# Layer 1: empty/any → TrustScore highest
# Layer 2: cosine ≥ 0.5 → TrustScore highest
# Layer 3: label fallback (role=2, skills=1) → TrustScore highest
# KALLAX preserves Conductor dispatch authority (主公 A decision, 3-mode A1)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTANCES_FILE="${KALLAX_ROOT}/.kallax/state/instances.json"
# Fallback to fixture for test/CI environments (state/ is gitignored)
if [[ ! -f "$INSTANCES_FILE" ]]; then
  INSTANCES_FILE="${KALLAX_ROOT}/tests/fixtures/agent/instances.json"
fi

best_matching_slaver() {
  local required_expertise="${1:-}"

  # Layer 1: empty or "any" → pick highest TrustScore
  if [[ -z "$required_expertise" ]] || [[ "$required_expertise" == "any" ]]; then
    local result
    result=$(jq -r '.instances | sort_by(-.trust_score) | .[0].id // empty' "$INSTANCES_FILE" 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
      echo "ALGO_SUGGEST: $result (Layer 1: any/empty, TrustScore highest)"
      return 0
    else
      echo "ALGO_SUGGEST: none (Layer 1: no instances found)"
      return 1
    fi
  fi

  # Layer 2: vector cosine ≥ 0.5 → pick highest TrustScore among matches
  local cosine_match
  cosine_match=$(jq -r --arg req "$required_expertise" \
    '.instances | map(select(.expertise_cosine >= 0.5)) | sort_by(-.trust_score) | .[0].id // empty' \
    "$INSTANCES_FILE" 2>/dev/null || echo "")
  if [[ -n "$cosine_match" ]]; then
    echo "ALGO_SUGGEST: $cosine_match (Layer 2: cosine ≥ 0.5, TrustScore highest)"
    return 0
  fi

  # Layer 3: label fallback scoring (role match = 2, skills contains = 1)
  local fallback
  fallback=$(jq -r --arg req "$required_expertise" \
    '.instances | map(.score = (if .role == $req then 2 else 0 end) + (if ((.skills // []) | contains([$req])) then 1 else 0 end)) | sort_by(-.score, -.trust_score) | .[0].id // empty' \
    "$INSTANCES_FILE" 2>/dev/null || echo "")
  if [[ -n "$fallback" ]]; then
    echo "ALGO_SUGGEST: $fallback (Layer 3: label fallback, score+TrustScore)"
    return 0
  fi

  echo "ALGO_SUGGEST: none (Layer 3: no fallback match)"
  return 1
}

# Export for sourcing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  REQUIRED_EXPERTISE="${1:-}"
  best_matching_slaver "$REQUIRED_EXPERTISE"
else
  export -f best_matching_slaver
fi
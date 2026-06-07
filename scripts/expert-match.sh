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

# score_expert <expert_md> <requirement>: returns score0-100
score_expert() {
  local expert_md="$1"
  local req="$2"
  local score=0

  # Extract trigger: field (P0 fix: AWK single-line miss, sed is primary)
  local trigger
  trigger=$(sed -n 's/^trigger: *//p' "$expert_md" | tr ',' '\n' | sed 's/^ *//;s/ *$//')
  if [ -z "$trigger" ]; then
    trigger=$(awk '/^trigger:/{found=1; next} found && /^[^:]+:/ {exit} found {print}' "$expert_md" | tr ',' '\n' | sed 's/^ *//;s/ *$//')
  fi
  if [ -z "$trigger" ]; then
    # fallback: single-line extraction
    trigger=$(sed -n 's/^trigger: *//p' "$expert_md" | tr ',' '\n' | sed 's/^ *//;s/ *$//')
  fi

  # w1 = 0.30: keyword match (30 pts per match, up to 3 matches = 90 max, normalized)
  local kw_score=0
  local match_count=0
  for tok in $(echo "$req" | tr ' ,;。、' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$'); do
    [ -z "$tok" ] && continue
    if echo "$trigger" | grep -q "$tok"; then
      kw_score=$((kw_score + 30))
      match_count=$((match_count + 1))
    fi
  done
  # Normalize: cap at 90 pts (3 keyword matches = full w1)
  [ "$kw_score" -gt 90 ] && kw_score=90

  # w2 = 0.25: symptom decision tree hit (25 pts if TRIGGERS.md segment matches)
  local tree_score=0
  local tree_file="${KALLAX_ROOT}/../experts/TRIGGERS.md"
  # Also check relative to repo root
  if [ ! -f "$tree_file" ]; then
    tree_file="$(cd "$(dirname "$KALLAX_ROOT")" && pwd)/experts/TRIGGERS.md"
  fi
  if [ -f "$tree_file" ]; then
    # Check if any token hits a segment keyword in TRIGGERS.md
    for tok in $(echo "$req" | tr ' ,;。、' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$'); do
      [ -z "$tok" ] && continue
      if grep -qF "$tok" "$tree_file"; then
        tree_score=25
        break
      fi
    done
  fi

  # w4 = 0.15: domain relevance baseline (15 pts)
  local domain_score=15

  score=$((kw_score + tree_score + domain_score))
  echo "$score"
}

# Find best expert (L1a keyword match)
best_id=""
best_score=0
declare -a CANDIDATES=()
for f in "${EXPERT_DIR}"/*.md; do
  [ -f "$f" ] || continue
  s=$(score_expert "$f" "$REQ")
  eid=$(basename "$f" .md)
  CANDIDATES+=("{\"id\":\"$eid\",\"score\":$s}")
  if (( s > best_score )); then
    best_score=$s
    best_id=$eid
  fi
done

END_MS=$(($(date +%s%N) / 1000000))
DURATION=$((END_MS - START_MS))

# L1b Smart Router: precision layer (only when L1 hit, to resolve ambiguity)
L1B_RESULT=""
L1B_VIA="L1"
if (( best_score >= 70 )); then
  # Build candidates JSON
  CANDIDATES_JSON="[$(IFS=','; echo "${CANDIDATES[*]}")]"

  # Call L1b router (pure bash, no LLM)
  L1B_SCRIPT="${KALLAX_ROOT}/scripts/l1b-router.sh"
  if [ -f "$L1B_SCRIPT" ]; then
    L1B_RESULT=$(l1b_route "$CANDIDATES_JSON" "$REQ" 2>/dev/null || echo "")
  fi

  if [ -n "$L1B_RESULT" ] && [ "$L1B_RESULT" != "{}" ]; then
    L1B_ID=$(echo "$L1B_RESULT" | jq -r '.best // empty')
    L1B_SCORE=$(echo "$L1B_RESULT" | jq -r '.score // empty')
    L1B_AMBIGUOUS=$(echo "$L1B_RESULT" | jq -r '.ambiguous // false')
    L1B_REASON=$(echo "$L1B_RESULT" | jq -r '.reason // empty')

    if [ "$L1B_AMBIGUOUS" = "true" ]; then
      # ambiguous → L2/L3 接
      echo "AMBIGUOUS via=L1b id=$L1B_ID score=$L1B_SCORE reason=$L1B_REASON (L2/L3 接)"
      printf '{"ts":"%s","req":"%s","via":"L1b","id":"%s","score":%s,"ambiguous":true,"reason":"%s","duration_ms":%s}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$REQ" "$L1B_ID" "$L1B_SCORE" "$L1B_REASON" "$DURATION" \
        >> "$AUDIT_LOG"
      exit 0
    else
      # resolved → L1b 输出 best
      L1B_VIA="L1b"
      best_id=$L1B_ID
      best_score=$L1B_SCORE
    fi
  fi

  echo "MATCHED via=$L1B_VIA id=$best_id score=$best_score duration=${DURATION}ms"
  printf '{"ts":"%s","req":"%s","via":"%s","id":"%s","score":%s,"duration_ms":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$REQ" "$L1B_VIA" "$best_id" "$best_score" "$DURATION" \
    >> "$AUDIT_LOG"
  exit 0
else
  via="L1 miss"
  echo "L1 MISS id=$best_id score=$best_score duration=${DURATION}ms (L2/L3 待 Sprint 2/3)"
  printf '{"ts":"%s","req":"%s","via":"%s","id":"%s","score":%s,"duration_ms":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$REQ" "$via" "$best_id" "$best_score" "$DURATION" \
    >> "$AUDIT_LOG"
  exit 1
fi
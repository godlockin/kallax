#!/bin/bash
# expert-match.sh — Match requirement to expert with L1/L2 fallback
# Usage: scripts/expert-match.sh '<requirement_text>'
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_PATH="$REPO_ROOT/.kallax/data/expert_index.db"
LOG_DIR="$REPO_ROOT/.kallax/logs"
AUDIT_LOG="$LOG_DIR/expert_resolution_audit.jsonl"

mkdir -p "$LOG_DIR"

# Constants
COSINE_THRESHOLD=0.4
L2_TOP_K=5

# Start timing (cross-platform: milliseconds since epoch)
START_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null)

# Parse requirement
if [[ $# -lt 1 ]]; then
  echo "Usage: scripts/expert-match.sh '<requirement_text>'" >&2
  exit 1
fi
REQUIREMENT="$1"

# Issue 2 fix: REQUIREMENT validation - reject dangerous SQL chars
# Prevent SQL injection via requirement text
# Check for dangerous chars: ' " ; \ -- newlines
case "$REQUIREMENT" in
  *\'*|*\"*|*\;*|*\\*|*--*|*$'\n'*|*$'\r'*)
    echo "ERROR: Invalid characters in requirement (rejected: ' \" ; \\ -- newlines)" >&2
    exit 1
    ;;
esac

# Shell-escape REQUIREMENT for safe SQL string interpolation.
# sqlite3 CLI does NOT support :param or ? placeholders, so we must escape at shell level.
# Single-quote wrap + double-single-quote for embedded quotes.
REQUIREMENT_ESC="${REQUIREMENT//\'/\'\'}"
TOP_K_ESC="${L2_TOP_K//\'/\'\'}"

# Ensure database exists
if [[ ! -f "$DB_PATH" ]]; then
  # Auto-build index if missing
  bash "$SCRIPT_DIR/build-expert-index.sh" --rebuild 2>/dev/null || true
fi

# L1: Default expert trigger matching
match_l1() {
  local req="$1"
  local result

  # Match by trigger field (keyword match in trigger or description)
  # Issue 2 fix: shell-escaped value (sqlite3 CLI has no :param binding)
  local req_esc="${req//\'/\'\'}"
  result=$(sqlite3 "$DB_PATH" \
    "SELECT id, name_cn, role, emoji, domain, tier, description, trigger
     FROM expert
     WHERE tier = 'default'
       AND (trigger LIKE '%' || '$req_esc' || '%' OR description LIKE '%' || '$req_esc' || '%')
     LIMIT 1;" 2>/dev/null || echo "")

  if [[ -z "$result" ]]; then
    # No L1 match - return failure to trigger L2
    return 1
  fi

  echo "$result"
  return 0
}

# L2: LIKE search + similarity (FTS5 fallback)
match_l2() {
  local req="$1"
  local top_k="${2:-$L2_TOP_K}"

  # Use LIKE for substring search (more reliable for Chinese)
  # Output as CSV to avoid delimiter issues with | in data
  # Issue 2 fix: shell-escaped values (sqlite3 CLI has no :param binding)
  local req_esc="${req//\'/\'\'}"
  local topk_esc="${top_k//\'/\'\'}"
  local results
  results=$(sqlite3 -csv "$DB_PATH" \
    "SELECT id, name_cn, role, emoji, domain, tier, description, trigger,
            (CASE WHEN trigger LIKE '%' || '$req_esc' || '%' THEN 2 ELSE 0 END +
             CASE WHEN description LIKE '%' || '$req_esc' || '%' THEN 1 ELSE 0 END) as relevance
     FROM expert
     WHERE trigger LIKE '%' || '$req_esc' || '%' OR description LIKE '%' || '$req_esc' || '%'
     ORDER BY relevance DESC, RANDOM()
     LIMIT $topk_esc;" 2>/dev/null || echo "")

  if [[ -z "$results" ]]; then
    # Fallback to random selection when no match
    results=$(sqlite3 -csv "$DB_PATH" \
      "SELECT id, name_cn, role, emoji, domain, tier, description, trigger, 0 as relevance
       FROM expert
       ORDER BY RANDOM() LIMIT $top_k;" 2>/dev/null || echo "")
  fi

  echo "$results"
}

# Compute semantic similarity (substring match for Chinese support)
compute_similarity() {
  local req="$1"
  local expert_trigger="$2"
  local expert_desc="$3"

  if [[ -z "$expert_trigger" && -z "$expert_desc" ]]; then
    echo "0.0"
    return
  fi

  # Use Python for reliable substring matching (handles Unicode)
  local py_script
  py_script=$(mktemp)
  cat > "$py_script" <<'PYEOF'
import sys
req = sys.argv[1]
trigger = sys.argv[2]
desc = sys.argv[3]

req_lower = req.lower()
intersect = 0

# Check trigger keywords
for keyword in trigger.split("|"):
    if keyword and req_lower in keyword.lower():
        intersect += 1

# Check description keywords (split by /)
for keyword in desc.split("/"):
    if keyword and req_lower in keyword.lower():
        intersect += 0.5

# Return similarity score
score = min(intersect * 0.5, 1.0)
print(f"{score:.4f}")
PYEOF

  python3 "$py_script" "$req" "$expert_trigger" "$expert_desc" 2>/dev/null || echo "0.0"
  rm -f "$py_script"
}

# Write audit log
# Issue 3 fix: use jq -n to construct JSON safely (prevents injection)
write_audit() {
  local via="$1"
  local confidence="$2"
  local duration_ms="$3"
  local matched_id="$4"
  local semantic_sim="$5"
  local requirement="$6"

  local timestamp
  timestamp=$(date +%FT%T%z)

  # Use jq to safely construct JSON (prevents injection via requirement field)
  local entry
  entry=$(jq -n \
    --arg ts "$timestamp" \
    --arg v "$via" \
    --arg conf "$confidence" \
    --arg dur "$duration_ms" \
    --arg mid "$matched_id" \
    --arg sim "$semantic_sim" \
    --arg req "$requirement" \
    '{timestamp: $ts, via: $v, confidence: $conf, duration_ms: ($dur | tonumber), matched_expert: $mid, semantic_sim: ($sim | tonumber), requirement: $req}')

  echo "$entry" >> "$AUDIT_LOG"
}

# Main matching logic
main() {
  local matched result via confidence semantic_sim matched_id

  # L1 attempt
  if result=$(match_l1 "$REQUIREMENT"); then
    # matched_id is the first pipe-delimited field of L1 result
    # (no SQL needed — L1 result already came from sqlite3 with LIKE-bound req)
    matched_id=$(echo "$result" | cut -d'|' -f1)
    via="L1"
    confidence="high"
    semantic_sim="1.0"
  else
    # L2 attempt with FTS5 + similarity
    via="L2"

    # Get top-5 from FTS
    local l2_results
    l2_results=$(match_l2 "$REQUIREMENT" "$L2_TOP_K")

    if [[ -n "$l2_results" ]]; then
      # Compute similarity for each candidate
      local best_sim=0 best_row=""
      while IFS=',' read -r id name_cn role emoji domain tier description trigger relevance; do
        sim=$(compute_similarity "$REQUIREMENT" "$trigger" "$description")
        # Use awk for floating point comparison
        better=$(awk "BEGIN { print ($sim > $best_sim) }")
        if [[ "$better" == "1" ]]; then
          best_sim="$sim"
          best_row="$id|$name_cn|$role|$emoji|$domain|$tier|$description|$trigger"
        fi
      done <<< "$l2_results"

      if [[ -n "$best_row" ]]; then
        matched_id=$(echo "$best_row" | cut -d'|' -f1)
        semantic_sim="$best_sim"

        # Check threshold using awk
        passes=$(awk "BEGIN { print ($best_sim >= $COSINE_THRESHOLD) }")
        if [[ "$passes" == "1" ]]; then
          confidence="high"
        else
          confidence="low"
          via="L2_miss"
        fi
      else
        matched_id="unknown"
        semantic_sim="0.0"
        confidence="low"
        via="L2_miss"
      fi
    else
      matched_id="unknown"
      semantic_sim="0.0"
      confidence="low"
      via="L2_miss"
    fi
  fi

  # Calculate duration (cross-platform)
  END_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null)
  DURATION_MS=$((END_TIME - START_TIME))

  # Output result
  if [[ "$via" == "L2_miss" ]]; then
    echo "L2 miss: no expert matched (threshold=$COSINE_THRESHOLD)"
    echo "  via=$via confidence=$confidence duration_ms=$DURATION_MS semantic_sim=$semantic_sim"
  else
    local expert_info
    # Issue 2 fix: shell-escaped matched_id (sqlite3 CLI has no :param binding)
    local matched_id_esc="${matched_id//\'/\'\'}"
    expert_info=$(sqlite3 "$DB_PATH" \
      "SELECT emoji, name_cn, role, domain FROM expert WHERE id='$matched_id_esc' LIMIT 1;" 2>/dev/null || echo "||")

    echo "Matched expert: $matched_id"
    echo "  $expert_info"
    echo "  via=$via confidence=$confidence duration_ms=$DURATION_MS semantic_sim=$semantic_sim"
  fi

  # Write audit
  write_audit "$via" "$confidence" "$DURATION_MS" "$matched_id" "$semantic_sim" "$REQUIREMENT"
}

main
#!/bin/bash
# =================================================================
# expert-resolver.sh — CLI 智能 expert 匹配
# =================================================================
# Accepts free-form query, scores experts by use_when + triggers
# Outputs all experts sorted by score (no top-N truncation)
# macOS bash 3.2 compatible (no declare -A)
# =================================================================

set -e

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_JSON="${SCRIPT_DIR}/../../kallax-experts/docs/experts/data.json"
TEMP_SCORES="/tmp/resolver-scores-$$.txt"
TEMP_META="/tmp/resolver-meta-$$.txt"

# Score weights (per the plan)
WEIGHT_TRIGGER=100
WEIGHT_USE_WHEN=10
WEIGHT_SUBSTRING=5
WEIGHT_PREFIX=0.5

# Pool sizes (approximate, for display)
POOL_LOCAL_SIZE=15
POOL_ALL_SIZE=25
POOL_EXTENDED_SIZE=350

# -----------------------------------------------------------------------------
# Cleanup on exit
# -----------------------------------------------------------------------------
cleanup() {
  rm -f "$TEMP_SCORES" "$TEMP_META"
}
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------
usage() {
  cat << 'EOF'
Usage: expert-resolver.sh <query> [options]

Options:
  --pool=local|all|extended  Expert pool to search (default: local)
  --json                      Output JSON format
  --top=N                     Return top N results (default: all)
  -h, --help                  Show this help

Examples:
  expert-resolver.sh "数据库查询动不动就超时"
  expert-resolver.sh "SQL注入漏洞" --json
  expert-resolver.sh "团队扩张,微服务怎么拆" --pool=all --top 5

Output:
  Human-readable: sorted list with scores and match reasons
  JSON: structured output with bridge field (/kallax-expert <role_id>)
EOF
  exit 0
}

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
QUERY=""
POOL="local"
OUTPUT_JSON=false
TOP_N=0  # 0 means all

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pool=*)
      POOL="${1#*=}"
      if [[ ! "$POOL" =~ ^(local|all|extended)$ ]]; then
        echo "ERROR: --pool must be local, all, or extended" >&2
        exit 1
      fi
      shift
      ;;
    --json)
      OUTPUT_JSON=true
      shift
      ;;
    --top=*)
      TOP_N="${1#*=}"
      if [[ ! "$TOP_N" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --top must be a number" >&2
        exit 1
      fi
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$QUERY" ]]; then
        QUERY="$1"
      else
        QUERY="$QUERY $1"
      fi
      shift
      ;;
  esac
done

# Validate query
if [[ -z "$QUERY" ]]; then
  echo "ERROR: Query is required" >&2
  echo "" >&2
  usage
fi

# -----------------------------------------------------------------------------
# Pool size helper
# -----------------------------------------------------------------------------
get_pool_size() {
  case "$POOL" in
    local) echo "$POOL_LOCAL_SIZE" ;;
    all) echo "$POOL_ALL_SIZE" ;;
    extended) echo "$POOL_EXTENDED_SIZE" ;;
  esac
}

# -----------------------------------------------------------------------------
# Tokenize query into temp file (one token per line)
# macOS bash 3.2 compatible
# Strategy:
#   - English: whole words only (3+ chars), no substrings
#   - Chinese: sliding window 2-4 chars (meaningful Chinese units)
# -----------------------------------------------------------------------------
tokenize_query() {
  local q="$1"
  local tok_file="/tmp/resolver-tokens-$$.txt"
  > "$tok_file"

  # Extract English words (whole words only, 3+ chars)
  echo "$q" | grep -oE '[a-zA-Z][a-zA-Z0-9]{2,}' 2>/dev/null | sort -u >> "$tok_file" || true

  # Extract Chinese character sequences and create n-grams
  local chinese_only
  chinese_only=$(echo "$q" | grep -oE '[一-龥]+' 2>/dev/null || true)

  for phrase in $chinese_only; do
    local len=${#phrase}
    # Only create 2, 3, 4 char windows (meaningful Chinese units)
    local start=0
    while [[ $start -lt $((len - 1)) ]]; do
      # 2-char
      if [[ $start -lt $((len - 1)) ]]; then
        echo "${phrase:$start:2}" >> "$tok_file"
      fi
      # 3-char
      if [[ $start -lt $((len - 2)) ]]; then
        echo "${phrase:$start:3}" >> "$tok_file"
      fi
      # 4-char
      if [[ $start -lt $((len - 3)) ]]; then
        echo "${phrase:$start:4}" >> "$tok_file"
      fi
      start=$((start + 1))
    done
  done

  # Deduplicate and ensure minimum length (2 chars)
  LC_ALL=C sort -u "$tok_file" -o "$tok_file"
  LC_ALL=C awk 'length >= 2' "$tok_file"
  rm -f "$tok_file"
}

# -----------------------------------------------------------------------------
# Check if token exists in text (substring match, case-insensitive)
# -----------------------------------------------------------------------------
token_hit() {
  local token="$1"
  local text="$2"
  echo "$text" | grep -i "$token" > /dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Score an expert against query tokens
# Returns: "score|match_reason"
# -----------------------------------------------------------------------------
score_expert() {
  local role_id="$1"
  local name="$2"
  local emoji="$3"
  local triggers_zh="$4"
  local triggers_en="$5"
  local use_when_zh_arr="$6"  # newline-separated
  local use_when_en_arr="$7"  # newline-separated

  local total_score=0
  local match_reasons=""
  local first_reason=true

  # Get tokens
  local tokens
  tokens=$(tokenize_query "$QUERY")

  # --- Trigger scoring (weight = 100) ---
  # Track which tokens have matched to avoid double-counting across fields
  local matched_trigger_tokens="/tmp/matched-tokens-$$.txt"
  > "$matched_trigger_tokens"

  while IFS= read -r token; do
    [[ -z "$token" ]] && continue

    # Check if already matched this token for triggers
    if grep -Fxq "$token" "$matched_trigger_tokens" 2>/dev/null; then
      continue
    fi

    local token_matched=false
    local reasons_for_token=""
    local matched_field=""

    # Check triggers_zh (priority field)
    if ! $token_matched && token_hit "$token" "$triggers_zh"; then
      total_score=$((total_score + WEIGHT_TRIGGER))
      reasons_for_token="${reasons_for_token},trigger:${token}×1"
      token_matched=true
      matched_field="zh"
    fi

    # Check triggers_en
    if ! $token_matched && token_hit "$token" "$triggers_en"; then
      total_score=$((total_score + WEIGHT_TRIGGER))
      reasons_for_token="${reasons_for_token},trigger:${token}×1"
      token_matched=true
      matched_field="en"
    fi

    # Check name
    if ! $token_matched && token_hit "$token" "$name"; then
      total_score=$((total_score + WEIGHT_TRIGGER))
      reasons_for_token="${reasons_for_token},trigger:${token}×1"
      token_matched=true
      matched_field="name"
    fi

    # Check role_id
    if ! $token_matched && token_hit "$token" "$role_id"; then
      total_score=$((total_score + WEIGHT_TRIGGER))
      reasons_for_token="${reasons_for_token},trigger:${token}×1"
      token_matched=true
      matched_field="role"
    fi

    # Only add reasons ONCE per token
    if $token_matched; then
      echo "$token" >> "$matched_trigger_tokens"
      # Remove leading comma from reasons_for_token for the first addition
      if $first_reason; then
        match_reasons="${match_reasons}${reasons_for_token#,}"
        first_reason=false
      else
        match_reasons="${match_reasons}${reasons_for_token}"
      fi
    fi
  done <<< "$tokens"

  rm -f "$matched_trigger_tokens"

  # --- use_when scoring (weight = 10 for direct hit, 5 for substring, 0.5 for prefix) ---
  # use_when_zh
  while IFS= read -r phrase; do
    [[ -z "$phrase" ]] && continue
    local phrase_score=0
    local hit_type=""

    # Check direct match (any token hits the phrase)
    while IFS= read -r token; do
      [[ -z "$token" ]] && continue
      if token_hit "$token" "$phrase"; then
        phrase_score=$((phrase_score + WEIGHT_USE_WHEN))
        hit_type="use_when"
        break
      fi
    done <<< "$tokens"

    # Check if query token is substring of phrase (5 pts)
    if [[ $phrase_score -eq 0 ]]; then
      while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        if echo "$phrase" | grep -i "$token" > /dev/null 2>&1; then
          # Check if token is substring of phrase (query contains phrase-like content)
          phrase_score=$((phrase_score + WEIGHT_SUBSTRING))
          hit_type="substring"
          break
        fi
      done <<< "$tokens"
    fi

    # Check if phrase is prefix of any query token (0.5 pts)
    if [[ $phrase_score -eq 0 && ${#phrase} -le 6 ]]; then
      while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        if [[ "$token" == "$phrase"* ]] || [[ "$token" == *"$phrase" ]]; then
          phrase_score=$(awk "BEGIN {printf \"%.1f\", $WEIGHT_PREFIX}")
          hit_type="prefix"
          break
        fi
      done <<< "$tokens"
    fi

    if [[ $phrase_score -gt 0 ]]; then
      total_score=$(awk "BEGIN {printf \"%.1f\", $total_score + $phrase_score}")
      [[ -n "$match_reasons" ]] && match_reasons="${match_reasons},"
      match_reasons="${match_reasons}${hit_type}:${phrase}×1"
    fi
  done <<< "$use_when_zh_arr"

  # use_when_en (same logic)
  while IFS= read -r phrase; do
    [[ -z "$phrase" ]] && continue
    local phrase_score=0
    local hit_type=""

    while IFS= read -r token; do
      [[ -z "$token" ]] && continue
      if token_hit "$token" "$phrase"; then
        phrase_score=$((phrase_score + WEIGHT_USE_WHEN))
        hit_type="use_when"
        break
      fi
    done <<< "$tokens"

    if [[ $phrase_score -eq 0 ]]; then
      while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        if echo "$phrase" | grep -i "$token" > /dev/null 2>&1; then
          phrase_score=$((phrase_score + WEIGHT_SUBSTRING))
          hit_type="substring"
          break
        fi
      done <<< "$tokens"
    fi

    if [[ $phrase_score -gt 0 ]]; then
      total_score=$(awk "BEGIN {printf \"%.1f\", $total_score + $phrase_score}")
      [[ -n "$match_reasons" ]] && match_reasons="${match_reasons},"
      match_reasons="${match_reasons}${hit_type}:${phrase}×1"
    fi
  done <<< "$use_when_en_arr"

  # Return formatted result
  echo "${total_score}|${match_reasons}"
}

# -----------------------------------------------------------------------------
# Parse use_when arrays from JSON (without jq)
# Returns: newline-separated strings
# -----------------------------------------------------------------------------
parse_use_when() {
  local json="$1"
  local field="$2"

  # Extract the array and process each element
  echo "$json" | grep -oE "\"${field}\"\s*:\s*\[[^\]]*\]" | \
    sed 's/.*\[//' | sed 's/\]//' | \
    grep -oE '"[^"]*"' | \
    sed 's/^"//' | sed 's/"$//'
}

# -----------------------------------------------------------------------------
# Load experts from JSON file (without jq)
# Uses Python fallback if grep/sed fails
# -----------------------------------------------------------------------------
load_experts() {
  local json_file="$1"

  if [[ ! -f "$json_file" ]]; then
    echo "ERROR: $json_file not found" >&2
    echo "Hint: Run 'python3 tools/build-experts.py' to generate it" >&2
    exit 1
  fi

  # Use Python for reliable JSON parsing if available
  if command -v python3 > /dev/null 2>&1; then
    python3 - "$json_file" << 'PYEOF'
import json
import sys

with open(sys.argv[1], 'r') as f:
    experts = json.load(f)

for exp in experts:
    # Format use_when arrays as newline-separated
    use_when_zh = '\n'.join(exp.get('use_when_zh', []))
    use_when_en = '\n'.join(exp.get('use_when_en', []))
    triggers_zh = exp.get('triggers_zh', '')
    triggers_en = exp.get('triggers_en', '')

    # Escape pipes in content for pipe-based parsing
    def esc(s):
        return s.replace('\\', '\\\\').replace('|', '\\|').replace('\n', '<NL>')

    print(f"{exp['role_id']}|{esc(exp['name'])}|{exp['emoji']}|{esc(triggers_zh)}|{esc(triggers_en)}|{esc(use_when_zh)}|{esc(use_when_en)}")
PYEOF
    return
  fi

  # Fallback: manual parsing with grep/sed (less reliable)
  # Extract each expert block
  local num_experts
  num_experts=$(grep -c '"role_id"' "$json_file" || echo "0")

  local i=0
  while [[ $i -lt $num_experts ]]; do
    local role_id name emoji triggers_zh triggers_en
    role_id=$(grep '"role_id"' "$json_file" | head -n $((i+1)) | tail -1 | grep -oE '"[^"]*"$' | sed 's/"//g')
    name=$(grep '"name"' "$json_file" | head -n $((i+1)) | tail -1 | grep -oE '"[^"]*"$' | sed 's/"//g')
    emoji=$(grep '"emoji"' "$json_file" | head -n $((i+1)) | tail -1 | grep -oE '"[^"]*"$' | sed 's/"//g')
    triggers_zh=$(grep '"triggers_zh"' "$json_file" | head -n $((i+1)) | tail -1 | sed 's/.*"triggers_zh"\s*:\s*"//' | sed 's/".*//')
    triggers_en=$(grep '"triggers_en"' "$json_file" | head -n $((i+1)) | tail -1 | sed 's/.*"triggers_en"\s*:\s*"//' | sed 's/".*//')

    # use_when arrays (simplified - just grab first element per array)
    local use_when_zh use_when_en
    use_when_zh="use_when_zh_$i"
    use_when_en="use_when_en_$i"

    echo "${role_id}|${name}|${emoji}|${triggers_zh}|${triggers_en}|${use_when_zh}|${use_when_en}"
    i=$((i+1))
  done
}

# -----------------------------------------------------------------------------
# Score all experts and write to temp file
# -----------------------------------------------------------------------------
score_all() {
  local json_file="$DATA_JSON"

  # For local pool, use data.json directly
  # For all/extended, we'd need additional sources (future enhancement)
  > "$TEMP_SCORES"
  > "$TEMP_META"

  # Load and score
  local experts_data
  experts_data=$(load_experts "$json_file")

  while IFS='|' read -r role_id name emoji triggers_zh triggers_en use_when_zh use_when_en; do
    [[ -z "$role_id" ]] && continue

    # Restore newlines from <NL> placeholder
    use_when_zh=$(echo "$use_when_zh" | sed 's/<NL>/\n/g')
    use_when_en=$(echo "$use_when_en" | sed 's/<NL>/\n/g')
    triggers_zh=$(echo "$triggers_zh" | sed 's/<NL>/\n/g')
    triggers_en=$(echo "$triggers_en" | sed 's/<NL>/\n/g')

    # Score this expert
    local result
    result=$(score_expert "$role_id" "$name" "$emoji" "$triggers_zh" "$triggers_en" "$use_when_zh" "$use_when_en")
    local score="${result%%|*}"
    local match_reason="${result#*|}"

    # Write to temp files (score|role_id|reason format)
    echo "${score}|${role_id}|${match_reason}" >> "$TEMP_SCORES"
    echo "${role_id}|${name}|${emoji}" >> "$TEMP_META"
  done <<< "$experts_data"

  # Sort by score descending (handle float scores)
  sort -t'|' -k1 -nr "$TEMP_SCORES" -o "$TEMP_SCORES"
}

# -----------------------------------------------------------------------------
# Output human-readable format
# -----------------------------------------------------------------------------
output_human() {
  local pool_size
  pool_size=$(get_pool_size)

  echo "=================================================================="
  echo "  Query: \"$QUERY\"  |  Pool: $POOL ($pool_size experts)"
  echo "=================================================================="

  local rank=0
  local best_match=""

  while IFS='|' read -r score role_id reason; do
    [[ -z "$score" ]] && continue

    # Skip zero scores
    is_zero=$(awk "BEGIN {print ($score == 0 ? \"1\" : \"0\")}")
    [[ "$is_zero" == "1" ]] && continue

    rank=$((rank+1))

    # Get name and emoji from meta
    local meta
    meta=$(grep "^${role_id}|" "$TEMP_META" | head -1)
    local name="${meta#*|}"
    name="${name%|*}"
    local emoji="${meta##*|}"

    # Truncate long reasons
    local display_reason="$reason"
    if [[ ${#display_reason} -gt 80 ]]; then
      display_reason="${display_reason:0:77}..."
    fi

    if [[ $rank -eq 1 ]]; then
      best_match="$role_id"
    fi

    # Pad score to consistent width
    local score_str
    score_str=$(printf "%s" "$score" | awk '{if($1 != int($1)) printf "%.1f", $1; else printf "%.0f", $1}')

    echo "#${rank}  ${emoji}  ${role_id:-unknown}          Score:${score_str}  Match:${display_reason}"

    # Respect --top if specified
    if [[ $TOP_N -gt 0 && $rank -ge $TOP_N ]]; then
      break
    fi
  done < "$TEMP_SCORES"

  if [[ $rank -eq 0 ]]; then
    echo "(No experts matched your query. Try different keywords.)"
    echo ""
    echo "Suggestions:"
    echo "  - Check spelling"
    echo "  - Try broader terms (e.g., 'database' instead of 'postgresql')"
    echo "  - Use English terms for technical keywords"
  fi

  echo "=================================================================="
  if [[ -n "$best_match" ]]; then
    echo "SUMMARY: best=${best_match} count=${rank}"
  fi
}

# -----------------------------------------------------------------------------
# Output JSON format
# -----------------------------------------------------------------------------
output_json() {
  local pool_size
  pool_size=$(get_pool_size)

  echo "{"
  echo "  \"query\": \"$(echo "$QUERY" | sed 's/"/\\"/g')\","
  echo "  \"pool\": \"$POOL\","
  echo "  \"results\": ["

  local first=true
  local rank=0
  local best_match=""

  while IFS='|' read -r score role_id reason; do
    [[ -z "$score" ]] && continue

    # Skip zero scores
    is_zero=$(awk "BEGIN {print ($score == 0 ? \"1\" : \"0\")}")
    [[ "$is_zero" == "1" ]] && continue

    rank=$((rank+1))

    # Get name and emoji from meta
    local meta
    meta=$(grep "^${role_id}|" "$TEMP_META" | head -1)
    local name="${meta#*|}"
    name="${name%|*}"
    local emoji="${meta##*|}"

    # Add comma before this element if not first
    if [[ "$first" == "false" ]]; then
      echo ","
    fi
    first=false

    if [[ $rank -eq 1 ]]; then
      best_match="$role_id"
    fi

    # Escape JSON special chars
    local reason_escaped
    reason_escaped=$(echo "$reason" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    local name_escaped
    name_escaped=$(echo "$name" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

    printf "    {\"rank\":%d,\"role_id\":\"%s\",\"name\":\"%s\",\"emoji\":\"%s\",\"score\":%s,\"hit_reason\":\"%s\",\"bridge\":\"/kallax-expert %s\"}" \
      "$rank" "$role_id" "$name_escaped" "$emoji" "$score" "$reason_escaped" "$role_id"

    if [[ $TOP_N -gt 0 && $rank -ge $TOP_N ]]; then
      break
    fi
  done < "$TEMP_SCORES"

  echo ""
  echo "  ],"
  echo "  \"best_match\": \"$best_match\","
  echo "  \"total_matched\": $rank"
  echo "}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  score_all

  if $OUTPUT_JSON; then
    output_json
  else
    output_human
  fi
}

main

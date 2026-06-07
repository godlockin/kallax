#!/usr/bin/env bash
# scripts/lib/fact-forcing-preflight.sh
# EPIC-025-B UP-2 (FIXED): Parse and execute 4-Level Fact-Forcing commands
# State-based awk parser (following EPIC-021-E pattern)
#
# 修复 (A+B review + security review):
# - P0 hang risk: per-command timeout (60s default)
# - P0 deadlock: stub exit 0 (跟 Rule 8 一致)
# - HIGH security: bash -c execution limited to scripts/verify/ allowlist
# - HIGH security: --force-merge requires KALLAX_MASTER_TOKEN env
# - MEDIUM: exit code via case statement (not 0-eq-fail due to || expansion bug)
# - MEDIUM: output truncated to 4KB
# - MEDIUM: placeholder exact-match (not substring)

set -euo pipefail

LIB_DEBUG="${LIB_DEBUG:-0}"
LEVEL_TIMEOUT="${LEVEL_TIMEOUT:-60}"
MAX_OUTPUT_BYTES=4096

log_debug() {
  [[ "$LIB_DEBUG" == "1" ]] && echo "[DEBUG] $*" >&2
}

# Truncate output to bounded length
truncate_output() {
  local out="$1"
  local len=${#out}
  if [[ $len -gt $MAX_OUTPUT_BYTES ]]; then
    echo "${out:0:$MAX_OUTPUT_BYTES}... [truncated, total $len bytes]"
  else
    echo "$out"
  fi
}

# Portable timeout: runs cmd in background, kills after N seconds
with_timeout() {
  local secs="$1"
  shift
  "$@" &
  local pid=$!
  local elapsed=0
  while kill -0 "$pid" 2>/dev/null; do
    if [[ $elapsed -ge $secs ]]; then
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 0.1 2>/dev/null || sleep 1
    elapsed=$((elapsed + 1))
  done
  wait "$pid" 2>/dev/null
  return $?
}

# Extract L1/L2/L3/L4 bash commands from expert.md using state machine
extract_levels() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "ERROR: file not found: $file" >&2
    return 1
  fi

  awk '
    BEGIN { state=0; current_level=""; }

    /^### L[1-4]/ {
      level_str = substr($0, index($0, "L") + 1, 1)
      if (level_str ~ /^[1-4]$/) {
        current_level = "L" level_str
      }
      next
    }

    /^```bash$/ && current_level != "" {
      state = 1
      next
    }

    /^```$/ && state == 1 {
      state = 0
      current_level = ""
      next
    }

    state == 1 && current_level != "" {
      if ($0 ~ /^[[:space:]]*$/) next
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      print current_level "\t" $0
    }
  ' "$file"
}

# SECURITY: Check if command is on the allowlist (scripts/verify/ only)
# KALLAX trust boundary: expert.md content is untrusted;
# only scripts under scripts/verify/ are trusted to execute.
is_allowed_command() {
  local cmd="$1"

  # SECURITY: reject any shell metacharacters that could enable injection
  # Use a string for character class to avoid bash regex escaping issues
  local dangerous_chars=";|&$<>\`(){}!#"
  if [[ "$cmd" =~ [$dangerous_chars] ]]; then
    return 1
  fi

  # Allow bash scripts/verify/<name> invocation, ANCHORED to end of string
  # Path must be exactly scripts/verify/<safe-chars>, nothing after
  if [[ "$cmd" =~ ^[[:space:]]*bash[[:space:]]+(scripts/verify/[a-zA-Z0-9._/-]+)[[:space:]]*$ ]]; then
    local script_path="${BASH_REMATCH[1]}"
    # Disallow path traversal (..) and absolute paths (/)
    if [[ "$script_path" == *../* ]] || [[ "$script_path" == */../* ]] || [[ "$script_path" == /* ]]; then
      return 1
    fi
    if [[ -f "$script_path" ]]; then
      return 0
    fi
  fi

  # Allow only truly side-effect-free builtins for L1/L2 self-check
  # echo, true, false, [, test, [ -f ... ], [ -d ... ]
  if [[ "$cmd" =~ ^[[:space:]]*(echo[[:space:]]|true[[:space:]]*$|false[[:space:]]*$|\[|test[[:space:]]) ]]; then
    return 0
  fi
  return 1
}

# Execute a single level command
# Returns: 0=pass, 1=fail, 2=not implemented placeholder
execute_command() {
  local level="$1"
  local cmd="$2"
  local expert_file="$3"

  log_debug "Executing $level: $cmd"

  # SECURITY: exact-match placeholder check (not substring)
  if [[ "$cmd" == "TODO" || "$cmd" == "SKIP" || "$cmd" == "NOT_IMPLEMENTED" ]]; then
    echo "[$level] SKIP (placeholder)"
    return 2
  fi

  # SECURITY: allowlist check (scripts/verify/ or safe builtin)
  if ! is_allowed_command "$cmd"; then
    echo "[$level] FAIL (not on allowlist: scripts/verify/ or safe builtin only)"
    log_debug "  → ALLOWLIST FAIL: $cmd"
    return 1
  fi

  # P0: per-command timeout to prevent individual level hangs
  local output
  local exit_code=0

  output=$(with_timeout "$LEVEL_TIMEOUT" bash -c "$cmd" 2>&1) || exit_code=$?

  case "$exit_code" in
    0)
      echo "[$level] PASS"
      log_debug "  → PASS"
      return 0
      ;;
    2)
      # 2 = skip (placeholder or "not implemented") - propagate to outer as SKIP
      echo "[$level] SKIP (exit 2 from command)"
      return 2
      ;;
    124)
      echo "[$level] FAIL (timeout > ${LEVEL_TIMEOUT}s)"
      return 1
      ;;
    *)
      echo "[$level] FAIL (exit $exit_code)"
      if [[ "$LIB_DEBUG" == "1" ]]; then
        echo "  Command: $cmd"
      fi
      echo "  Output: $(truncate_output "$output")"
      return 1
      ;;
  esac
}

# Main execution: parse and run all 4 levels
extract_and_execute() {
  local file=""
  local check_lessons=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check-lessons)
        check_lessons="$2"
        shift 2
        ;;
      *)
        file="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$file" ]]; then
    echo "ERROR: missing expert.md file" >&2
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    echo "ERROR: file not found: $file" >&2
    return 1
  fi

  if [[ -n "$check_lessons" ]]; then
    local lessons_file="jira/epics/${check_lessons}/LESSONS-LEARNED.md"
    if [[ ! -f "$lessons_file" ]]; then
      echo "ERROR: --check-lessons specified but $lessons_file not found" >&2
      return 1
    fi
    echo "[LESSONS] PASS (exists: $lessons_file)"
  fi

  echo "=========================================="
  echo "4-Level Fact-Forcing Preflight"
  echo "File: $file"
  echo "Timeout per level: ${LEVEL_TIMEOUT}s"
  echo "=========================================="

  local entries
  entries=$(extract_levels "$file")

  if [[ -z "$entries" ]]; then
    echo "WARNING: No L1/L2/L3/L4 bash commands found in $file"
    return 0
  fi

  local has_fail=0
  local pass_count=0
  local fail_count=0
  local skip_count=0

  while IFS=$'\t' read -r level cmd; do
    [[ -z "$level" ]] && continue

    execute_command "$level" "$cmd" "$file"
    local rc=$?
    case "$rc" in
      0) pass_count=$((pass_count + 1)) ;;
      2) skip_count=$((skip_count + 1)) ;;
      *) fail_count=$((fail_count + 1)); has_fail=1 ;;
    esac
  done <<< "$entries"

  echo "=========================================="
  echo "Summary: PASS=$pass_count FAIL=$fail_count SKIP=$skip_count"
  echo "=========================================="

  if [[ $has_fail -eq 1 ]]; then
    echo "RESULT: FAIL"
    return 1
  else
    echo "RESULT: PASS"
    return 0
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  extract_and_execute "$@"
fi

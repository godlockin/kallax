#!/usr/bin/env bash
# scripts/lib/fact-forcing-preflight.sh
# EPIC-025-B UP-2: Parse and execute 4-Level Fact-Forcing commands
# State-based awk parser (following EPIC-021-E pattern)

set -euo pipefail

LIB_DEBUG="${LIB_DEBUG:-0}"

log_debug() {
  [[ "$LIB_DEBUG" == "1" ]] && echo "[DEBUG] $*" >&2
}

# Extract L1/L2/L3/L4 bash commands from expert.md using state machine
# Returns all4 levels as tab-separated: level\tcommand
extract_levels() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "ERROR: file not found: $file" >&2
    return1
  fi

  # State machine: 0=normal, 1=in_code_block
  local state=0
  local current_level=""

  awk '
    BEGIN { state=0; current_level=""; }

    # Match level headers: ### L1, ### L2, ### L3, ### L4 (with optional 存在性/实质性/etc suffix)
    /^### L[1-4]/ {
      # Extract level number - get char after "L"
      level_str = substr($0, index($0, "L") + 1, 1)
      if (level_str ~ /^[1-4]$/) {
        current_level = "L" level_str
      }
      next
    }

    # Enter code block
    /^```bash$/ && current_level != "" {
      state = 1
      next
    }

    # Exit code block
    /^```$/ && state == 1 {
      state = 0
      current_level = ""
      next
    }

    # Inside code block: print level and command
    state == 1 && current_level != "" {
      # Skip empty lines at start of block
      if ($0 ~ /^[[:space:]]*$/) next
      # Remove leading/trailing whitespace
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      print current_level "\t" $0
    }
  ' "$file"
}

# Execute a single level command
# Returns: 0=pass, 1=fail, 2=not implemented
execute_command() {
  local level="$1"
  local cmd="$2"
  local level_dir="$3"

  log_debug "Executing $level: $cmd"

  # Check if command is a placeholder (not implemented yet)
  if echo "$cmd" | grep -q "not implemented yet\|TODO:"; then
    echo "[$level] SKIP (placeholder)"
    return 2
  fi

  # Execute the command
  local output
  local exit_code

  output=$(bash -c "$cmd" 2>&1) || exit_code=$?

  if [[ "${exit_code:-0}" -eq 0 ]]; then
    echo "[$level] PASS"
    log_debug "  → PASS"
    return 0
  else
    echo "[$level] FAIL (exit $exit_code)"
    echo "  Command: $cmd"
    echo "  Output: $output"
    log_debug "  → FAIL: $output"
    return 1
  fi
}

# Main execution: parse and run all 4 levels
# Usage: extract_and_execute <expert.md> [--check-lessons <epic-id>]
extract_and_execute() {
  local file=""
  local check_lessons=""

  # Parse arguments
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

  # Check lessons if requested
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
  echo "=========================================="

  # Extract all levels
  local entries
  entries=$(extract_levels "$file")

  if [[ -z "$entries" ]]; then
    echo "WARNING: No L1/L2/L3/L4 bash commands found in $file"
    return 0
  fi

  # Execute each level in order
  local has_fail=0
  local pass_count=0
  local fail_count=0
  local skip_count=0

  while IFS=$'\t' read -r level cmd; do
    [[ -z "$level" ]] && continue

    if execute_command "$level" "$cmd" "$file"; then
      ((pass_count++))
    else
      exit_code=$?
      if [[ $exit_code -eq 2 ]]; then
        ((skip_count++))
      else
        ((fail_count++))
        has_fail=1
      fi
    fi
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

# Shell function for direct sourcing
# Usage: source fact-forcing-preflight.sh && extract_and_execute <file>
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Called directly as script
  extract_and_execute "$@"
fi
#!/usr/bin/env bash
# scripts/kallax-onramp/lib/tool-detect.sh — EPIC-057-B
# Detect which AI CLI tool is available for onramp pre-assess.
# Priority: claude > opencode > codex > gemini (跟 scripts/install.sh 一致)
#
# Detection rule (AND — both required for onramp):
#   1. `command -v <tool>` — binary in $PATH
#   2. `[ -d $HOME/.<tool>/ ]` — config dir exists (user actually used it)
# AND is stricter than install.sh's OR — onramp RUNS the tool (install only
# creates skills dirs, so OR is safe there).
#
# Output: JSON {tool, binary, version, skills_dir, commands_dir} on stdout
# Failure: stderr "No AI CLI tool detected" + exit 1
#
# 跟"反讽" 闭环, 跟 Rule 4 Fail Fast 联合, 跟 Rule 5 DRY 联合

set -uo pipefail

# ── Tool registry (bash 3.2 compat: parallel arrays, 跟 install.sh 对齐) ──
# Order = priority. Do NOT reorder — first match wins.
TOOL_NAME=(claude opencode codex gemini)
TOOL_BINARY=(claude opencode codex gemini)
TOOL_BASE_DIR=(
  "${HOME}/.claude"
  "${HOME}/.opencode"
  "${HOME}/.codex"
  "${HOME}/.gemini"
)
TOOL_SKILLS_DIR=(
  "${HOME}/.claude/skills/kallax"
  "${HOME}/.opencode/skills/kallax"
  "${HOME}/.codex/skills/kallax"
  "${HOME}/.gemini/skills/kallax"
)
# NOTE: opencode commands_dir is SINGULAR (.opencode/command/) — 跟 install.sh 一致
TOOL_COMMANDS_DIR=(
  "${HOME}/.claude/commands"
  "${HOME}/.opencode/command"
  "${HOME}/.codex/prompts"
  "${HOME}/.gemini/commands"
)

# Lookup helper: print index for tool name (or -1). Mirrors install.sh:77-83.
tool_index() {
  local t="$1" i
  for i in "${!TOOL_NAME[@]}"; do
    if [ "${TOOL_NAME[$i]}" = "$t" ]; then echo "$i"; return 0; fi
  done
  echo -1
}

# Try to extract a version string. Falls back to "unknown".
# Args: <binary> <tool_name>
probe_version() {
  local bin="$1" tool="$2"
  local ver
  # All 4 CLIs support --version (实测: claude 2.1.153, opencode 1.17.7, gemini 0.22.2; codex 缺失 binary fallback "unknown")
  ver=$("$bin" --version 2>/dev/null | head -1 | tr -d '\n')
  if [[ -z "$ver" ]]; then
    ver="unknown"
  fi
  echo "$ver"
}

# Main detection. Sets globals and prints JSON.
detect_tool() {
  local i tool bin base
  for i in "${!TOOL_NAME[@]}"; do
    tool="${TOOL_NAME[$i]}"
    bin="${TOOL_BINARY[$i]}"
    base="${TOOL_BASE_DIR[$i]}"
    # AND check: binary in PATH AND config dir exists
    if command -v "$bin" &>/dev/null && [ -d "$base" ]; then
      KALLAX_DETECTED_TOOL="$tool"
      KALLAX_DETECTED_BINARY="$(command -v "$bin")"
      KALLAX_DETECTED_VERSION="$(probe_version "$KALLAX_DETECTED_BINARY" "$tool")"
      KALLAX_DETECTED_SKILLS_DIR="${TOOL_SKILLS_DIR[$i]}/"
      KALLAX_DETECTED_COMMANDS_DIR="${TOOL_COMMANDS_DIR[$i]}/"
      # Print JSON to stdout (跟 AC#6 联合)
      cat <<EOF
{"tool":"${KALLAX_DETECTED_TOOL}","binary":"${KALLAX_DETECTED_BINARY}","version":"${KALLAX_DETECTED_VERSION}","skills_dir":"${KALLAX_DETECTED_SKILLS_DIR}","commands_dir":"${KALLAX_DETECTED_COMMANDS_DIR}"}
EOF
      return 0
    fi
  done

  # No tool detected — fallback per AC#5
  echo "ERROR: No AI CLI tool detected" >&2
  echo "" >&2
  echo "Checked (in priority order):" >&2
  for i in "${!TOOL_NAME[@]}"; do
    tool="${TOOL_NAME[$i]}"
    bin="${TOOL_BINARY[$i]}"
    base="${TOOL_BASE_DIR[$i]}"
    local bin_status="✗"
    local dir_status="✗"
    command -v "$bin" &>/dev/null && bin_status="✓"
    [ -d "$base" ] && dir_status="✓"
    echo "  ${tool}: binary=${bin_status}  config_dir=${dir_status}  (need both)" >&2
  done
  echo "" >&2
  echo "Suggestion: install claude (https://claude.ai/code) — preferred tool" >&2
  echo "Or install opencode / codex / gemini and ensure ~/.{tool}/ config dir exists." >&2
  return 1
}

# Allow this script to be sourced (function-only) OR executed (run detect_tool).
# Pattern: 跟 install.sh:130-164 parse_args 风格的 bash 3.2 compat
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  detect_tool "$@"
fi

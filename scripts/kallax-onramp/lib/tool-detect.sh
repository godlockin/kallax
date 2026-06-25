#!/usr/bin/env bash
# scripts/kallax-onramp/lib/tool-detect.sh — EPIC-057-B (8-tool expansion)
# Detect which AI CLI tool is available for onramp pre-assess.
# Priority: claude > trae > antigravity > opencode > codex > gemini > cursor > windsurf
# (跟 scripts/install.sh:67 TOOL_NAME 数组顺序一致, v2.2.0+ 8 工具)
#
# Detection rule (AND — both required for onramp):
#   1. `command -v <tool>` — binary in $PATH
#   2. `[ -d $HOME/.<tool>/ ]` — config dir exists (user actually used it)
# AND is stricter than install.sh's OR — onramp RUNS the tool (install only
# creates skills dirs, so OR is safe there).
#
# 8 工具 CLI reality check (实测, 跟 LESSON 5 联合):
#   claude:      real CLI, `claude --print "<prompt>"`        ✅
#   trae:        real CLI, `trae chat "<prompt>"`              ✅ (VS Code fork with chat subcommand)
#   antigravity: IDE-based, no non-interactive prompt CLI      ❌ (will not detect in practice)
#   opencode:    real CLI, `opencode run "<prompt>"`           ✅
#   codex:       real CLI, `codex exec "<prompt>"`             ✅
#   gemini:      real CLI, `gemini "<prompt>"` (positional)    ✅
#   cursor:      IDE-based, no non-interactive prompt CLI      ❌ (will not detect in practice)
#   windsurf:    IDE-based, no non-interactive prompt CLI      ❌ (will not detect in practice)
#
# Output: JSON {tool, binary, version, skills_dir, commands_dir} on stdout
# Failure: stderr "No AI CLI tool detected" + exit 1
#
# 跟"反讽" 闭环, 跟 Rule 4 Fail Fast 联合, 跟 Rule 5 DRY 联合

set -uo pipefail

# ── Tool registry (bash 3.2 compat: parallel arrays, 跟 install.sh:67-128 对齐) ──
# Order = priority. Do NOT reorder — first match wins.
# 8 工具 (excludes aider/continue from install.sh: those are config-only niche tools,
# 跟 onramp "RUN the tool" 语义不符 — onramp 需要 LLM prompt invocation).
TOOL_NAME=(claude trae antigravity opencode codex gemini cursor windsurf)
TOOL_BINARY=(claude trae antigravity opencode codex gemini cursor windsurf)
TOOL_BASE_DIR=(
  "${HOME}/.claude"
  "${HOME}/.trae"
  "${HOME}/.antigravity"
  "${HOME}/.opencode"
  "${HOME}/.codex"
  "${HOME}/.gemini"
  "${HOME}/.cursor"
  "${HOME}/.codeium/windsurf"   # windsurf config 在 codeium 子目录 (跟 install.sh:77 一致)
)
TOOL_SKILLS_DIR=(
  "${HOME}/.claude/skills/kallax"
  "${HOME}/.trae/skills/kallax"
  "${HOME}/.antigravity/skills/kallax"
  "${HOME}/.opencode/skills/kallax"
  "${HOME}/.codex/skills/kallax"
  "${HOME}/.gemini/skills/kallax"
  "${HOME}/.cursor/skills/kallax"
  "${HOME}/.codeium/windsurf/skills/kallax"
)
# NOTE: opencode commands_dir is SINGULAR (.opencode/command/) — 跟 install.sh:97 一致
TOOL_COMMANDS_DIR=(
  "${HOME}/.claude/commands"
  "${HOME}/.trae/commands"
  "${HOME}/.antigravity/commands"
  "${HOME}/.opencode/command"           # singular!
  "${HOME}/.codex/prompts"
  "${HOME}/.gemini/commands"
  "${HOME}/.cursor/commands"
  "${HOME}/.codeium/windsurf/commands"
)

# Lookup helper: print index for tool name (or -1). Mirrors install.sh:145-151.
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
  # All 8 binaries may have --version (实测: claude 2.1.153, trae 1.107.1, opencode 1.17.7, gemini 0.22.2; codex 缺失 fallback; antigravity/cursor/windsurf 在本机无 $PATH binary)
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
  echo "Or install opencode / codex / gemini (real CLIs) or trae and ensure ~/.{tool}/ config dir exists." >&2
  echo "Note: antigravity/cursor/windsurf are IDE-based — they don't have non-interactive prompt CLIs," >&2
  echo "      so onramp pre-assess must use a real-CLI tool from the list above." >&2
  return 1
}

# Allow this script to be sourced (function-only) OR executed (run detect_tool).
# Pattern: 跟 install.sh:239-277 parse_args 风格的 bash 3.2 compat
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  detect_tool "$@"
fi

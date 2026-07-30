#!/usr/bin/env bash
# KALLAX Install/Upgrade — make /kallax-* available in 8 AI tools:
#   Claude Code / opencode / Codex / Gemini / Cursor / Windsurf / Aider / Continue.
# v2.1.0: 8-tool support (added cursor, windsurf, aider, continue).
# v2.2.0: 10-tool support (added trae, antigravity, codex, gemini).
# v2.3.0: --symlink is the default install method (Single Source of Truth).
# v2.1.0: full wizard with detection → select → path → diff → dry-run → confirm.
#
# Fresh install (auto-detect 10 tools):
#   ./scripts/install.sh
#   ./scripts/install.sh --target=auto
# Explicit tool(s):
#   ./scripts/install.sh --target=claude
#   ./scripts/install.sh --target=opencode,codex
# Force install all 10 (ignore detection):
#   ./scripts/install.sh --target=all
# Interactive wizard (step-by-step):
#   ./scripts/install.sh --wizard
#   ./scripts/install.sh --interactive  (alias)
# Dry-run (show what would happen, install nothing):
#   ./scripts/install.sh --dry-run
# Legacy (Claude Code only):
#   ./scripts/install.sh --skip-cli --skip-skills --skip-commands
# Upgrade:
#   ./scripts/install.sh --upgrade
# Curl install:
#   curl -fsSL <raw-url>/scripts/install.sh | bash
set -euo pipefail

VERSION="2.3.0-symlink-default-10tool"
INSTALL_MODE="install"  # install | upgrade
TARGET_MODE="auto"      # auto | all | specific-list
INSTALL_METHOD="symlink"   # symlink (DEFAULT v2.3.0) | copy (legacy)
INTERACTIVE=false
WIZARD=false
DRY_RUN=false
SKIP_CLI=false; SKIP_SKILLS=false; SKIP_COMMANDS=false

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1" >&2; }
hdr()  { echo -e "\n${BOLD}${BLUE}═══ $* ═══${NC}"; }
dim()  { echo -e "${DIM}$*${NC}"; }

# Render a single check: ✓ (detected), ✗ (not detected), or skip per-tool
check_mark() {
  local detected="$1" tool="$2"
  if [ "$detected" = "true" ]; then
    echo -e "  ${GREEN}✓${NC} ${BOLD}${tool}${NC}"
  else
    echo -e "  ${DIM}✗${NC} ${tool}"
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

BIN_DIR="${HOME}/.local/bin"

# ── Tool registry (bash 3.2 compat: parallel arrays + index lookup) ──────
# Order matters: prefer primary tools first, fall back to niche.
# 10 tools: claude / trae / antigravity / opencode / codex / gemini / cursor /
#           windsurf / aider / continue.
# Support levels: "full" (skills + commands) or "config" (config files only).
TOOL_NAME=(claude trae antigravity opencode codex gemini cursor windsurf aider continue)
TOOL_BINARY=(claude trae antigravity opencode codex gemini cursor windsurf aider "continue-cli")
TOOL_BASE_DIR=(
  "${HOME}/.claude"
  "${HOME}/.trae"
  "${HOME}/.antigravity"
  "${HOME}/.opencode"
  "${HOME}/.codex"
  "${HOME}/.gemini"
  "${HOME}/.cursor"
  "${HOME}/.codeium/windsurf"
  "${HOME}/.aider"
  "${HOME}/.continue"
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
  "${HOME}/.aider/skills/kallax"
  "${HOME}/.continue/skills/kallax"
)
TOOL_COMMANDS_DIR=(
  "${HOME}/.claude/commands"
  "${HOME}/.trae/commands"
  "${HOME}/.antigravity/commands"
  "${HOME}/.opencode/command"            # singular!
  "${HOME}/.codex/prompts"
  "${HOME}/.gemini/commands"
  "${HOME}/.cursor/commands"
  "${HOME}/.codeium/windsurf/commands"
  ""                                       # aider: no slash commands
  ""                                       # continue: no slash commands
)
TOOL_COMMANDS_SRC=(
  "$PROJECT_ROOT/.claude/commands"
  "$PROJECT_ROOT/.trae/commands"
  "$PROJECT_ROOT/.antigravity/commands"
  "$PROJECT_ROOT/.opencode/command"
  "$PROJECT_ROOT/.codex/prompts"
  "$PROJECT_ROOT/.gemini/commands"
  "$PROJECT_ROOT/.cursor/commands"
  "$PROJECT_ROOT/.codeium/windsurf/commands"
  ""                                       # aider: no slash commands
  ""                                       # continue: no slash commands
)
TOOL_COMMANDS_EXT=(sh md md md md sh md md "" "")
TOOL_SETTINGS_FILE=(
  "${HOME}/.claude/settings.json"
  "${HOME}/.trae/settings.json"
  "${HOME}/.antigravity/settings.json"
  "${HOME}/.opencode/config.json"
  "${HOME}/.codex/config.toml"
  "${HOME}/.gemini/config/settings.json"
  "${HOME}/.cursor/settings.json"
  "${HOME}/.codeium/windsurf/settings.json"
  "${HOME}/.aider.conf.yml"
  "${HOME}/.continue/config.json"
)
# Support level: "full" (skills + commands) or "config" (config files only).
# Niche tools (aider/continue) don't have slash command APIs.
# 10 tools: claude / trae / antigravity / opencode / codex / gemini / cursor /
#           windsurf / aider / continue. First 8 = full, last 2 = config.
TOOL_SUPPORT=(full full full full full full full full config config)

# ── Single source of truth (v2.2.0) ───────────────────────────────────────
# When --symlink is passed, install.sh creates a canonical source dir at
# ~/.local/share/kallax/ and symlinks each tool's user-level path to it.
# This way 4+ tools share ONE source — update once, all tools get it.
CANONICAL_DIR="${KALLAX_SHARE_DIR:-$HOME/.local/share/kallax}"
CANONICAL_SKILLS="$CANONICAL_DIR/skills/kallax"
CANONICAL_COMMANDS="$CANONICAL_DIR/commands"

# Lookup helper: print index for tool name (or -1)
tool_index() {
  local t="$1" i
  for i in "${!TOOL_NAME[@]}"; do
    if [ "${TOOL_NAME[$i]}" = "$t" ]; then echo "$i"; return 0; fi
  done
  echo -1
}

# Populated by detect_tools() / parse_target_flag() / wizard()
DETECTED_TOOLS=()
TARGET_TOOLS=()

# ── Arg parser ───────────────────────────────────────────────────────────

print_help() {
  cat <<EOF
KALLAX Install/Upgrade v${VERSION}

Usage: $0 [flags]

Target selection (EPIC-057-A, hybrid flag-controlled, 10 tools):
  --target=auto          Auto-detect 10 tools via \$HOME/.<tool>/ or which <tool>
                         (DEFAULT — equivalent to no flag in v2.0.5)
  --target=all           Force install all 10 tools (ignore detection)
  --target=claude        Install for Claude Code only
  --target=trae          Install for Trae (ByteDance AI IDE) only
  --target=antigravity   Install for Antigravity (Google AI IDE) only
  --target=opencode      Install for opencode only
  --target=codex         Install for Codex only
  --target=gemini        Install for Gemini only
  --target=cursor        Install for Cursor only
  --target=windsurf      Install for Windsurf only
  --target=aider         Install for Aider only (config only, no slash cmds)
  --target=continue      Install for Continue only (config only)
  --target=a,b,c         Install for multiple tools (comma-separated)

Install method (v2.3.0 — --symlink is now DEFAULT):
  --symlink              Single source mode: install to canonical
                         ~/.local/share/kallax/ and symlink each tool's
                         path to it. Update once, all tools get the change.
                         DEFAULT in v2.3.0+. Recommended for 4+ tools
                         (claude + trae + antigravity + opencode) — saves
                         disk + ensures consistency.
  --copy                 Copy mode (LEGACY for v2.0.x compat) — each tool
                         gets its own copy of the files. Use only if
                         --symlink doesn't work in your environment.

Wizard / Interactive:
  --wizard               Run full step-by-step wizard (5 steps):
                         detect → select → path → diff → dry-run → confirm
  --interactive          Alias for --wizard (v2.0.x compat)
  --dry-run              Show what would be installed, install nothing

Legacy (v2.0.5 compat):
  --skip-cli             Skip CLI binary
  --skip-skills          Skip skills install
  --skip-commands        Skip slash commands install
  --upgrade              Show upgrade diff then install

Other:
  --version              Show version
  -h, --help             Show this help

Installs to:
  Claude Code:  skills=~/.claude/skills/kallax/                commands=~/.claude/commands/                 (full)
  opencode:     skills=~/.opencode/skills/kallax/             commands=~/.opencode/command/  (singular!)  (full)
  Codex:        skills=~/.codex/skills/kallax/                commands=~/.codex/prompts/                  (full)
  Gemini:       skills=~/.gemini/skills/kallax/               commands=~/.gemini/commands/                (full)
  Cursor:       skills=~/.cursor/skills/kallax/               commands=~/.cursor/commands/                (full)
  Windsurf:     skills=~/.codeium/windsurf/skills/kallax/     commands=~/.codeium/windsurf/commands/      (full)
  Aider:        skills=~/.aider/skills/kallax/                commands=N/A  (no slash command API)        (config)
  Continue:     skills=~/.continue/skills/kallax/             commands=N/A  (VS Code extension)            (config)
  Trae:         skills=~/.trae/skills/kallax/                 commands=~/.trae/commands/                  (full, new v2.2.0)
  Antigravity:  skills=~/.antigravity/skills/kallax/          commands=~/.antigravity/commands/           (full, new v2.2.0)

CLI: ~/.local/bin/kallax (shared across all tools)

Single source mode (v2.3.0 — DEFAULT):
  Canonical:  ~/.local/share/kallax/   (skills + commands)
  Per tool:   ~/.claude/skills/kallax  -> ~/.local/share/kallax/skills/kallax (symlink)
              ~/.claude/commands       -> ~/.local/share/kallax/commands      (symlink)
              ~/.trae/skills/kallax    -> ~/.local/share/kallax/skills/kallax (symlink)
              ... (8 more tools, all symlinked to canonical)

  Why symlink? Update once in ~/.local/share/kallax/, all 10 tools get it.

Re-run anytime to upgrade to latest from project source.

Migrating from --copy (v2.0.x/v2.1.x/v2.2.0) to --symlink (v2.3.0+):
  ./scripts/install.sh --target=all   (auto-detects, no flags needed)
  Old copies at ~/.claude/commands/ etc. are auto-replaced by symlinks.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --skip-cli)         SKIP_CLI=true; shift ;;
      --skip-skills)      SKIP_SKILLS=true; shift ;;
      --skip-commands)    SKIP_COMMANDS=true; shift ;;
      --upgrade)          INSTALL_MODE="upgrade"; shift ;;
      --symlink)          INSTALL_METHOD="symlink"; shift ;;
      --copy)             INSTALL_METHOD="copy"; shift ;;
      --wizard)           WIZARD=true; shift ;;
      --interactive)      WIZARD=true; shift ;;  # alias for v2.0.x compat
      --dry-run)          DRY_RUN=true; shift ;;
      --target=auto)      TARGET_MODE="auto"; shift ;;
      --target=all)       TARGET_MODE="all"; shift ;;
      --target=*)
        TARGET_MODE="specific"
        # strip --target= prefix, then split by comma
        local v="${1#--target=}"
        TARGET_TOOLS=()
        IFS=',' read -ra _parts <<< "$v"
        local p
        for p in "${_parts[@]}"; do
          p="$(echo "$p" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"
          [[ -z "$p" ]] && continue
          if [ "$(tool_index "$p")" = "-1" ]; then
            err "Unknown tool: $p (valid: ${TOOL_NAME[*]})"
            exit 1
          fi
          TARGET_TOOLS+=("$p")
        done
        [[ ${#TARGET_TOOLS[@]} -eq 0 ]] && { err "Empty --target= value"; exit 1; }
        shift
        ;;
      --version) echo "kallax-install v${VERSION}"; exit 0 ;;
      -h|--help) print_help; exit 0 ;;
      *) err "Unknown: $1"; err "Run '$0 --help' for usage."; exit 1 ;;
    esac
  done
}

# ── Detection ────────────────────────────────────────────────────────────

detect_tools() {
  local i tool bin base
  DETECTED_TOOLS=()
  for i in "${!TOOL_NAME[@]}"; do
    tool="${TOOL_NAME[$i]}"
    bin="${TOOL_BINARY[$i]}"
    base="${TOOL_BASE_DIR[$i]}"
    if [ -d "$base" ] || command -v "$bin" &>/dev/null; then
      DETECTED_TOOLS+=("$tool")
    fi
  done
}

prompt_interactive() {
  # v2.0.x compat — delegate to wizard()
  wizard
}

# ── Wizard (5-step interactive installer, v2.1.0) ───────────────────────
#
# Flow:
#   Step 1/5  Tool detection summary
#   Step 2/5  Select target tools (detected / all / custom)
#   Step 3/5  Install paths confirmation
#   Step 4/5  Upgrade diff preview (if upgrading)
#   Step 5/5  Dry-run preview + final confirm
#
# All prompts have sensible defaults — just press Enter to accept.
wizard() {
  hdr "Step 1/5 — Tool Detection"
  echo ""
  local i tool
  for i in "${!TOOL_NAME[@]}"; do
    tool="${TOOL_NAME[$i]}"
    if printf '%s\n' "${DETECTED_TOOLS[@]}" | grep -qx "$tool"; then
      check_mark true "$tool"
    else
      check_mark false "$tool"
    fi
  done
  echo ""
  if [ ${#DETECTED_TOOLS[@]} -eq 0 ]; then
    warn "No tools detected. Will use --target=all path."
  else
    ok "Detected ${#DETECTED_TOOLS[@]} of 10: ${DETECTED_TOOLS[*]}"
  fi

  hdr "Step 2/5 — Select Target Tools"
  echo ""
  echo "  [1] Install for detected tools only (recommended)"
  echo "  [2] Install for all 10 tools (force)"
  echo "  [3] Custom selection (comma-separated: e.g. claude,cursor)"
  echo ""
  local mode_choice
  read -r -p "  Choose [1/2/3] (default: 1): " mode_choice
  mode_choice="${mode_choice:-1}"
  case "$mode_choice" in
    1) TARGET_MODE="auto" ;;
    2) TARGET_MODE="all" ;;
    3)
      TARGET_MODE="specific"
      TARGET_TOOLS=()
      local choice
      read -r -p "  Tool list (comma-separated): " choice
      IFS=',' read -ra _parts <<< "$choice"
      local p
      for p in "${_parts[@]}"; do
        p="$(echo "$p" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"
        [[ -z "$p" ]] && continue
        if [ "$(tool_index "$p")" = "-1" ]; then
          err "Unknown tool: $p (valid: ${TOOL_NAME[*]})"
          exit 1
        fi
        TARGET_TOOLS+=("$p")
      done
      [[ ${#TARGET_TOOLS[@]} -eq 0 ]] && { err "Empty tool list"; exit 1; }
      ;;
    *) err "Invalid choice: $mode_choice"; exit 1 ;;
  esac

  hdr "Step 3/5 — Install Paths"
  echo ""
  echo "  Default install paths:"
  echo ""
  local t idx support
  for t in "${TARGET_TOOLS[@]}"; do
    idx=$(tool_index "$t")
    support="${TOOL_SUPPORT[$idx]}"
    echo "    ${BOLD}${t}${NC} (${support}):"
    echo "      skills    → ${TOOL_SKILLS_DIR[$idx]}"
    if [ -n "${TOOL_COMMANDS_DIR[$idx]}" ]; then
      echo "      commands  → ${TOOL_COMMANDS_DIR[$idx]} (ext=.${TOOL_COMMANDS_EXT[$idx]})"
    else
      echo "      commands  → ${DIM}N/A (config only)${NC}"
    fi
    echo "      settings  → ${TOOL_SETTINGS_FILE[$idx]}"
    echo ""
  done
  echo "  CLI wrapper: ${BIN_DIR}/kallax"
  echo ""
  local path_choice
  read -r -p "  Accept defaults? [Y/n]: " path_choice
  path_choice="${path_choice:-Y}"
  case "$path_choice" in
    [Yy]*) : ;;
    [Nn]*) warn "Custom paths not yet supported — using defaults";;
    *) err "Invalid choice: $path_choice"; exit 1 ;;
  esac

  hdr "Step 4/5 — Upgrade Diff Preview"
  echo ""
  local tool idx skills_dir prev_ver new_files
  for tool in "${TARGET_TOOLS[@]}"; do
    idx=$(tool_index "$tool")
    skills_dir="${TOOL_SKILLS_DIR[$idx]}"
    if [ -f "$skills_dir/.version" ]; then
      prev_ver=$(cat "$skills_dir/.version")
      echo "  ${BOLD}${tool}${NC}: v${prev_ver} → v${VERSION}"
      INSTALL_MODE="upgrade"
    else
      echo "  ${BOLD}${tool}${NC}: fresh install → v${VERSION}"
    fi
  done
  echo ""

  hdr "Step 5/5 — Dry-Run Preview + Confirm"
  echo ""
  echo "  ${BOLD}Will install:${NC}"
  for tool in "${TARGET_TOOLS[@]}"; do
    idx=$(tool_index "$tool")
    support="${TOOL_SUPPORT[$idx]}"
    echo "    ${GREEN}✓${NC} ${tool} (${support})"
  done
  echo ""
  echo "  ${BOLD}Source files (from this repo):${NC}"
  echo "    skills:   $(find "$PROJECT_ROOT/.claude/skills/kallax" -type f 2>/dev/null | wc -l | tr -d ' ') files"
  echo "    commands: $(find "$PROJECT_ROOT/.claude/commands" -type f -name 'kallax-*' 2>/dev/null | wc -l | tr -d ' ') files (+ _kallax_common.sh)"
  echo ""
  local confirm
  read -r -p "  Proceed with install? [Y/n]: " confirm
  confirm="${confirm:-Y}"
  case "$confirm" in
    [Yy]*) : ;;
    *) echo "Aborted."; exit 0 ;;
  esac
}

resolve_targets() {
  case "$TARGET_MODE" in
    auto)
      # bash 3.2 compat: explicit copy with length check (avoid unbound var)
      TARGET_TOOLS=()
      if [ ${#DETECTED_TOOLS[@]} -gt 0 ]; then
        TARGET_TOOLS=("${DETECTED_TOOLS[@]}")
      fi
      ;;
    all)
      TARGET_TOOLS=("${TOOL_NAME[@]}")
      ;;
    specific)
      # TARGET_TOOLS already populated by parse_args / prompt_interactive
      # Validate each explicitly-named tool is detected (strict mode).
      local t idx base bin
      for t in "${TARGET_TOOLS[@]}"; do
        idx=$(tool_index "$t")
        base="${TOOL_BASE_DIR[$idx]}"
        bin="${TOOL_BINARY[$idx]}"
        if [ ! -d "$base" ] && ! command -v "$bin" &>/dev/null; then
          err "Tool '$t' not detected:"
          err "  expected base dir: $base"
          err "  expected binary:   $bin (in PATH)"
          err "Re-run with --target=auto to skip missing tools, or --target=all to force."
          exit 1
        fi
      done
      ;;
  esac

  if [ ${#TARGET_TOOLS[@]} -eq 0 ]; then
    err "No tools to install."
    err ""
    err "Detected nothing via \$HOME/.<tool>/ + which <tool>."
    err "Options:"
    err "  --target=all         Force install all 10 tools (creates dirs)"
    err "  --target=claude      Force install Claude Code only"
    err "  --target=opencode    Force install opencode only"
    err "  --target=codex       Force install Codex only"
    err "  --target=gemini      Force install Gemini only"
    err "  --target=cursor      Force install Cursor only"
    err "  --target=windsurf    Force install Windsurf only"
    err "  --target=aider       Force install Aider only"
    err "  --target=continue    Force install Continue only"
    err ""
    err "After install, run the tool to use slash commands."
    exit 1
  fi
}

# ── Per-tool install (DRY) ──────────────────────────────────────────────

# Locate skill source: prefer .claude/skills/kallax (v2.7.4 cleanup, 跟 template/ symlink 联合)
# Note: template/.claude/skills/kallax/ is now a symlink to .claude/skills/kallax/ (跟 v2.7.4 整理 release 联合),
# so we don't need a fallback chain. Just use .claude/ as canonical.
find_skills_source() {
  local src="$PROJECT_ROOT/.claude/skills/kallax"
  [ -d "$src" ] && { echo "$src"; return 0; }
  return 1
}

install_skills_for_tool() {
  local tool="$1"
  local i dst
  i=$(tool_index "$tool")
  dst="${TOOL_SKILLS_DIR[$i]}"

  local src
  if ! src=$(find_skills_source); then
    warn "[$tool] no skill source found in project, skipping skills"
    return 0
  fi

  # Symlink mode (v2.2.0): install to canonical, then symlink tool's path
  if [ "$INSTALL_METHOD" = "symlink" ]; then
    install_canonical_skills "$src"
    rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$CANONICAL_SKILLS" "$dst"
    ok "[$tool] skills → $dst (symlink → $CANONICAL_SKILLS)"
    return 0
  fi

  # Default copy mode (v2.0.x compat)
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -r "$src" "$dst"

  local count
  count=$(find "$dst" -type f 2>/dev/null | wc -l | tr -d ' ')
  ok "[$tool] skills → $dst ($count files)"

  if [ -f "$dst/SKILL.md" ]; then
    local lines
    lines=$(wc -l < "$dst/SKILL.md" | tr -d ' ')
    ok "[$tool] SKILL.md: $lines lines — auto-loaded"
  else
    warn "[$tool] SKILL.md missing — skills won't auto-load"
  fi
}

# Install skills to canonical source (single source of truth for symlink mode)
install_canonical_skills() {
  local src="$1"
  if [ -L "$CANONICAL_SKILLS" ]; then
    rm -f "$CANONICAL_SKILLS"
  fi
  rm -rf "$CANONICAL_SKILLS"
  mkdir -p "$(dirname "$CANONICAL_SKILLS")"
  cp -r "$src" "$CANONICAL_SKILLS"
  ok "[canonical] skills → $CANONICAL_SKILLS"
}

# Install commands to canonical source (single source of truth for symlink mode)
install_canonical_commands() {
  local src="$1"
  if [ -L "$CANONICAL_COMMANDS" ]; then
    rm -f "$CANONICAL_COMMANDS"
  fi
  rm -rf "$CANONICAL_COMMANDS"
  mkdir -p "$CANONICAL_COMMANDS"

  local count=0
  local md_count=0
  for f in "$src"/kallax-*; do
    [ -f "$f" ] || continue
    cp "$f" "$CANONICAL_COMMANDS/"
    count=$((count + 1))
  done

  # EPIC-127 smart router (kallax.md — bare /kallax command, no -prefix).
  # install.sh L552 only globs `kallax-*`, so this file was silently skipped —
  # new sessions without manual symlink lost the bare `/kallax` command.
  # EPIC-134: add explicit sync so future --upgrade runs guarantee /kallax works.
  if [ -f "$src/kallax.md" ]; then
    cp "$src/kallax.md" "$CANONICAL_COMMANDS/"
    md_count=$((md_count + 1))
  fi

  # Shared library
  if [ -f "$src/_kallax_common.sh" ]; then
    cp "$src/_kallax_common.sh" "$CANONICAL_COMMANDS/"
  fi

  # Heartbeat prompts (for full-support tools)
  for f in "$src"/heartbeat-*; do
    [ -f "$f" ] || continue
    cp "$f" "$CANONICAL_COMMANDS/"
  done

  # v2.3.1: Recursive copy of $src/kallax/ subdir (sub-skills: init, research, experts).
  # install.sh L552 only globs `kallax-*` (top-level files), so the subdir was
  # silently skipped — `/kallax` smart router references sub-skill docs that
  # never got installed for new sessions.
  if [ -d "$src/kallax" ]; then
    rm -rf "$CANONICAL_COMMANDS/kallax"
    cp -r "$src/kallax" "$CANONICAL_COMMANDS/"
  fi

  # v2.1.1: .md wrappers for .sh commands (Claude Code 2.1+ compat)
  # v2.3.0: Auto-extract argument-hint from USAGE: line in .sh file (跟 scripts/refresh-arg-hints.sh 模式 一致)
  for f in "$CANONICAL_COMMANDS"/kallax-*.sh; do
    [ -f "$f" ] || continue
    local name desc usage_line args md_target
    name=$(basename "$f" .sh)
    desc=$(/usr/bin/awk 'NR==2' "$f" | sed 's/^# //')
    # Extract args from USAGE: line: "/kallax-mode [conductor|...]" → "[conductor|...]"
    # Skip files without USAGE: line (e.g., takeover.md is a full doc, not a wrapper)
    usage_line=$(grep -A 1 '^USAGE:' "$f" 2>/dev/null | tail -1 | sed -E 's/^[[:space:]]+//' | sed -E "s|^/kallax-[a-z-]+[[:space:]]*||")
    args=""
    if [ -n "$usage_line" ] && [ "$usage_line" != "$(grep -A 1 '^USAGE:' "$f" 2>/dev/null | tail -1 | sed -E 's/^[[:space:]]+//')" ]; then
      args="$usage_line"
    fi
    md_target="$CANONICAL_COMMANDS/${name}.md"
    if [ -n "$args" ]; then
      cat > "$md_target" <<EOF
---
description: ${desc}
argument-hint: ${args}
---

!bash "\$(dirname "\$0")/${name}.sh" \$ARGUMENTS
EOF
    else
      cat > "$md_target" <<EOF
---
description: ${desc}
---

!bash "\$(dirname "\$0")/${name}.sh" \$ARGUMENTS
EOF
    fi
    md_count=$((md_count + 1))
  done

  ok "[canonical] commands → $CANONICAL_COMMANDS ($count .sh + $md_count .md wrappers)"
}

install_commands_for_tool() {
  local tool="$1"
  local i dst ext src
  i=$(tool_index "$tool")
  dst="${TOOL_COMMANDS_DIR[$i]}"
  ext="${TOOL_COMMANDS_EXT[$i]}"
  src="${TOOL_COMMANDS_SRC[$i]}"

  # Skip tools without slash command API (aider/continue: config only)
  if [ -z "$dst" ] || [ -z "$ext" ]; then
    dim "  [$tool] no slash command API — skipping commands install (config only)"
    return 0
  fi

  # Symlink mode (v2.2.0): install to canonical, then symlink tool's path
  if [ "$INSTALL_METHOD" = "symlink" ]; then
    install_canonical_commands "$src"
    rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$CANONICAL_COMMANDS" "$dst"
    ok "[$tool] commands → $dst (symlink → $CANONICAL_COMMANDS)"
    return 0
  fi

  # Fallback chain: tool-native → .claude (v2.7.4 cleanup, template/ now symlinks to .claude/)
  if [ ! -d "$src" ]; then src="$PROJECT_ROOT/.claude/commands"; fi
  if [ ! -d "$src" ]; then
    warn "[$tool] no commands source found, skipping"
    return 0
  fi

  mkdir -p "$dst"
  local count=0
  for f in "$src"/kallax-*; do
    [ -f "$f" ] || continue
    cp "$f" "$dst/"
    count=$((count + 1))
  done

  # Shared library (critical — all commands source this)
  if [ -f "$src/_kallax_common.sh" ]; then
    cp "$src/_kallax_common.sh" "$dst/"
    ok "[$tool] _kallax_common.sh installed"
  fi

  # Heartbeat prompts (Claude/opencode .md format)
  for f in "$src"/heartbeat-*; do
    [ -f "$f" ] || continue
    cp "$f" "$dst/"
  done

  # v2.1.1: Also generate .md wrappers for .sh commands.
  # Claude Code's slash command registry prefers .md files in some
  # versions. The .md wrapper invokes the .sh via !bash directive.
  # Only for tools that store commands as .sh (claude, gemini).
  if [ "$ext" = "sh" ]; then
    local md_count=0
    for f in "$dst"/kallax-*.sh; do
      [ -f "$f" ] || continue
      local name desc md_target
      name=$(basename "$f" .sh)
      desc=$(/usr/bin/awk 'NR==2' "$f" | sed 's/^# //')
      md_target="$dst/${name}.md"
      cat > "$md_target" <<EOF
---
description: ${desc}
---

!bash "\$(dirname "\$0")/${name}.sh" \$ARGUMENTS
EOF
      md_count=$((md_count + 1))
    done
    if [ "$md_count" -gt 0 ]; then
      ok "[$tool] .md wrappers generated: $md_count files (Claude Code 2.1+ compatibility)"
    fi
  fi

  ok "[$tool] commands → $dst ($count files, ext=.$ext)"

  if [ "$count" -gt 0 ]; then
    echo ""
    echo "  [$tool] Available globally:"
    for f in "$dst"/kallax-*; do
      [ -f "$f" ] || continue
      local name
      name=$(basename "$f" ."$ext")
      # Skip the .md wrappers in the listing (they're aliases for the .sh)
      if [ -f "$f" ] && [[ "$f" == *.md ]] && [ -f "${f%.md}.sh" ]; then continue; fi
      echo "    /$name"
    done
  fi
}

# For tools that don't have slash commands (aider/continue), install a config
# file that points to the skills/ directory so the tool can find them.
install_config_for_tool() {
  local tool="$1"
  local i dst support
  i=$(tool_index "$tool")
  dst="${TOOL_SETTINGS_FILE[$i]}"
  support="${TOOL_SUPPORT[$i]}"

  if [ "$support" != "config" ]; then return 0; fi

  # Generic config: write a stub config file with reference to skills dir
  mkdir -p "$(dirname "$dst")"
  if [ ! -f "$dst" ]; then
    cat > "$dst" <<EOF
# KALLAX skill reference (auto-generated by install.sh v${VERSION})
# This tool does not have a native slash command API.
# To use KALLAX skills, point your tool to: ${TOOL_SKILLS_DIR[$i]}

kallax:
  skills_dir: "${TOOL_SKILLS_DIR[$i]}"
  version: "${VERSION}"
EOF
    ok "[$tool] config → $dst (stub, points to skills dir)"
  else
    dim "  [$tool] config already exists at $dst — leaving alone"
  fi
}

install_for_tool() {
  local tool="$1"
  local i support
  i=$(tool_index "$tool")
  support="${TOOL_SUPPORT[$i]}"
  echo ""
  log "── Installing for: $tool (${support}) ──"
  if ! $SKIP_SKILLS;   then install_skills_for_tool "$tool"; fi
  if ! $SKIP_COMMANDS; then install_commands_for_tool "$tool"; fi
  install_config_for_tool "$tool"
}

# ── CLI wrapper (shared across tools) ────────────────────────────────────

install_cli() {
  log "Installing CLI wrapper → ${BIN_DIR}/kallax"

  mkdir -p "$BIN_DIR"

  cat > "${BIN_DIR}/kallax" << 'INNEREOF'
#!/usr/bin/env bash
# KALLAX CLI — auto-discovers project root, routes to Node.js runtime.
set -euo pipefail

KALLAX_ROOT="${KALLAX_HOME:-}"
if [ -z "$KALLAX_ROOT" ]; then
  _dir="$PWD"
  while [ "$_dir" != "/" ]; do
    if [ -f "$_dir/.kallax/IDENTITY.md" ]; then
      KALLAX_ROOT="$_dir"; break
    fi
    _dir="$(dirname "$_dir")"
  done
fi

if [ -z "$KALLAX_ROOT" ]; then
  echo "KALLAX: No .kallax/IDENTITY.md found. Run 'kallax init' or cd to a KALLAX project." >&2
  exit 1
fi

if [ -f "$KALLAX_ROOT/node_modules/.bin/tsx" ]; then
  exec "$KALLAX_ROOT/node_modules/.bin/tsx" "$KALLAX_ROOT/node/src/index.ts" "$@"
elif [ -f "$KALLAX_ROOT/node/dist/index.js" ]; then
  exec node "$KALLAX_ROOT/node/dist/index.js" "$@"
elif [ -f "$KALLAX_ROOT/rust/target/release/kallax" ]; then
  exec "$KALLAX_ROOT/rust/target/release/kallax" "$@"
else
  echo "KALLAX: No runtime found. Run 'npm install' in ${KALLAX_ROOT}." >&2
  exit 1
fi
INNEREOF

  chmod +x "${BIN_DIR}/kallax"
  ok "CLI installed → ${BIN_DIR}/kallax"

  if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    warn "${BIN_DIR} not in PATH. Add to ~/.zshrc:"
    warn "  export PATH=\"${BIN_DIR}:\$PATH\""
  fi
}

# ── Per-tool permissions (best-effort, manual hint for non-Claude) ─────

configure_claude_perms() {
  local settings="$HOME/.claude/settings.json"

  if command -v jq &>/dev/null && [ -f "$settings" ]; then
    local has_perm
    has_perm=$(jq -r '.permissions.auto // [] | map(select(. == "Bash:.claude/commands/*.sh")) | length' "$settings" 2>/dev/null || echo "0")
    if [ "$has_perm" = "0" ]; then
      local tmp
      tmp=$(mktemp)
      jq '.permissions.auto += ["Bash:.claude/commands/*.sh"]' "$settings" > "$tmp"
      mv "$tmp" "$settings"
      ok "[claude] added auto-permission: Bash:.claude/commands/*.sh"
    else
      ok "[claude] auto-permission already configured"
    fi
  elif [ ! -f "$settings" ]; then
    mkdir -p "$(dirname "$settings")"
    cat > "$settings" << 'EOF'
{
  "permissions": {
    "ask": [],
    "auto": [
      "Bash:.claude/commands/*.sh"
    ],
    "deny": []
  }
}
EOF
    ok "[claude] created $settings with auto-permissions"
  else
    warn "[claude] jq not available — add this to $settings manually:"
    warn '  "permissions": { "auto": ["Bash:.claude/commands/*.sh"] }'
  fi
}

configure_opencode_perms() {
  local cfg="$HOME/.opencode/config.json"
  if [ ! -f "$cfg" ]; then
    log "[opencode] no config.json — manual hint (TODO future EPIC):"
    log "  Add to $cfg: { \"auto_run\": \".opencode/command/*.md\" }"
  else
    log "[opencode] config.json exists — verify auto-run includes .opencode/command/*.md"
  fi
}

configure_codex_perms() {
  local cfg="$HOME/.codex/config.toml"
  if [ ! -f "$cfg" ]; then
    log "[codex] no config.toml — manual hint (TODO future EPIC):"
    log "  Add to $cfg: auto_run = [\".codex/prompts/*.md\"]"
  else
    log "[codex] config.toml exists — verify auto-run includes .codex/prompts/*.md"
  fi
}

configure_gemini_perms() {
  local cfg="$HOME/.gemini/config/settings.json"
  if [ ! -f "$cfg" ]; then
    log "[gemini] no config/settings.json — manual hint (TODO future EPIC):"
    log "  Add to $cfg: { \"auto_run\": \".gemini/commands/*.sh\" }"
  else
    log "[gemini] config/settings.json exists — verify auto-run includes .gemini/commands/*.sh"
  fi
}

configure_permissions_for_tool() {
  local tool="$1"
  case "$tool" in
    claude)   configure_claude_perms ;;
    opencode) configure_opencode_perms ;;
    codex)    configure_codex_perms ;;
    gemini)   configure_gemini_perms ;;
  esac
}

# ── Verify ──────────────────────────────────────────────────────────────

verify_install() {
  local tool
  echo ""
  echo "=== Verification (per-tool status) ==="
  for tool in "${TARGET_TOOLS[@]}"; do
    local i skills cmds
    i=$(tool_index "$tool")
    skills="${TOOL_SKILLS_DIR[$i]}"
    cmds="${TOOL_COMMANDS_DIR[$i]}"

    if [ -d "$skills" ] && [ -f "$skills/SKILL.md" ]; then
      local n
      # Use -L to follow symlinks (v2.2.0 symlink mode)
      n=$(find -L "$skills" -type f 2>/dev/null | wc -l | tr -d ' ')
      ok "[$tool] skills: $skills ($n files)"
    else
      warn "[$tool] skills: not installed"
    fi

    # Skip tools without slash command API (aider/continue: config only).
    # Without this guard, `ls "" /kallax-*` would fail under `set -euo pipefail`
    # and abort the verify phase (BE-25 联合: 0 隐藏 silent crash).
    if [ -z "$cmds" ]; then
      dim "  [$tool] no slash command API (config only — verified above)"
    else
      local cmd_count
      cmd_count=$(ls "$cmds"/kallax-* 2>/dev/null | wc -l | tr -d ' ')
      if [ "$cmd_count" -gt 0 ]; then
        ok "[$tool] commands: $cmd_count slash cmds in $cmds"
      else
        warn "[$tool] commands: not installed"
      fi
    fi
  done

  if [ -f "${BIN_DIR}/kallax" ]; then
    ok "CLI: ${BIN_DIR}/kallax"
  fi

  echo ""
  echo "Restart your AI tool (claude/opencode/codex/gemini) or open a new window."
  echo "Then type /kallax-start"
}

# ── Version stamp ───────────────────────────────────────────────────────

stamp_version() {
  local tool
  for tool in "${TARGET_TOOLS[@]}"; do
    local skills_dir
    skills_dir="${TOOL_SKILLS_DIR[$(tool_index "$tool")]}"
    mkdir -p "$skills_dir"
    echo "$VERSION" > "$skills_dir/.version"
  done
  ok "Version stamped: v${VERSION} (${#TARGET_TOOLS[@]} tool(s))"
}

# ── Upgrade check (legacy Claude diff) ──────────────────────────────────

check_upgrade() {
  if [ "$INSTALL_MODE" != "upgrade" ]; then
    # If any prior skills dir has .version, we're upgrading
    local tool i skills_dir
    for i in "${!TOOL_NAME[@]}"; do
      skills_dir="${TOOL_SKILLS_DIR[$i]}"
      if [ -f "$skills_dir/.version" ]; then
        local prev
        prev=$(cat "$skills_dir/.version")
        log "Previous install: v${prev} (${TOOL_NAME[$i]}) → upgrading to v${VERSION}"
        INSTALL_MODE="upgrade"
        return 0
      fi
    done
    return 0
  fi

  echo ""
  echo "=== Upgrade mode ==="
  log "Re-installing all ${#TARGET_TOOLS[@]} target tool(s)"
}

# ── Main ────────────────────────────────────────────────────────────────

parse_args "$@"
detect_tools
if $WIZARD; then wizard; fi
resolve_targets

# Show summary banner
echo ""
echo "========================================"
if [ "$INSTALL_MODE" = "upgrade" ]; then
  echo "  KALLAX Upgrade v${VERSION}"
else
  echo "  KALLAX Install v${VERSION}"
fi
echo "  Target mode: ${TARGET_MODE}"
echo "  Tools:       ${TARGET_TOOLS[*]}"
echo "  CLI:         ${BIN_DIR}/kallax"
if $DRY_RUN; then
  echo "  Mode:        ${YELLOW}DRY-RUN (no changes)${NC}"
fi
echo "========================================"
echo ""

# If dry-run, exit before any actual install
if $DRY_RUN; then
  ok "Dry-run complete. No files were installed."
  echo ""
  echo "  To actually install, run without --dry-run:"
  echo "    $0 --target=auto"
  echo "    $0 --wizard"
  exit 0
fi

check_upgrade

tool=""
for tool in "${TARGET_TOOLS[@]}"; do
  install_for_tool "$tool"
done

echo ""
if ! $SKIP_CLI; then install_cli; fi
echo ""

tool=""
for tool in "${TARGET_TOOLS[@]}"; do
  configure_permissions_for_tool "$tool"
done
echo ""

verify_install

stamp_version

echo ""
echo "Done. KALLAX skills + slash commands available across:"
for tool in "${TARGET_TOOLS[@]}"; do
  idx=$(tool_index "$tool")
  support="${TOOL_SUPPORT[$idx]}"
  if [ "$support" = "full" ]; then
    echo "  - $tool (full: skills + slash commands)"
  else
    echo "  - $tool (config only — points to skills dir)"
  fi
done
echo ""
echo "Upgrade hint: re-run this script anytime to upgrade."
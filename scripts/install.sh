#!/usr/bin/env bash
# KALLAX Install/Upgrade — make /kallax-* available in Claude Code / opencode /
# Codex / Gemini. EPIC-057-A: --target=auto|all|<tool>|a,b  multi-tool support.
#
# Fresh install (auto-detect 4 tools):
#   ./scripts/install.sh
#   ./scripts/install.sh --target=auto
# Explicit tool(s):
#   ./scripts/install.sh --target=claude
#   ./scripts/install.sh --target=opencode,codex
# Force install all 4 (ignore detection):
#   ./scripts/install.sh --target=all
# Interactive prompt:
#   ./scripts/install.sh --interactive
# Legacy (Claude Code only):
#   ./scripts/install.sh --skip-cli --skip-skills --skip-commands
# Upgrade:
#   ./scripts/install.sh --upgrade
# Curl install:
#   curl -fsSL <raw-url>/scripts/install.sh | bash
set -euo pipefail

VERSION="2.0.6-multi-tool"
INSTALL_MODE="install"  # install | upgrade
TARGET_MODE="auto"      # auto | all | specific-list
INTERACTIVE=false
SKIP_CLI=false; SKIP_SKILLS=false; SKIP_COMMANDS=false

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

BIN_DIR="${HOME}/.local/bin"

# ── Tool registry (bash 3.2 compat: parallel arrays + index lookup) ──────
# Order is fixed: claude → opencode → codex → gemini.
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
TOOL_COMMANDS_DIR=(
  "${HOME}/.claude/commands"
  "${HOME}/.opencode/command"      # singular!
  "${HOME}/.codex/prompts"
  "${HOME}/.gemini/commands"
)
TOOL_COMMANDS_SRC=(
  "$PROJECT_ROOT/.claude/commands"
  "$PROJECT_ROOT/.opencode/command"
  "$PROJECT_ROOT/.codex/prompts"
  "$PROJECT_ROOT/.gemini/commands"
)
TOOL_COMMANDS_EXT=(sh md md sh)
TOOL_SETTINGS_FILE=(
  "${HOME}/.claude/settings.json"
  "${HOME}/.opencode/config.json"
  "${HOME}/.codex/config.toml"
  "${HOME}/.gemini/config/settings.json"
)

# Lookup helper: print index for tool name (or -1)
tool_index() {
  local t="$1" i
  for i in "${!TOOL_NAME[@]}"; do
    if [ "${TOOL_NAME[$i]}" = "$t" ]; then echo "$i"; return 0; fi
  done
  echo -1
}

# Populated by detect_tools() / parse_target_flag()
DETECTED_TOOLS=()
TARGET_TOOLS=()

# ── Arg parser ───────────────────────────────────────────────────────────

print_help() {
  cat <<EOF
KALLAX Install/Upgrade v${VERSION}

Usage: $0 [flags]

Target selection (EPIC-057-A, hybrid flag-controlled):
  --target=auto          Auto-detect 4 tools via \$HOME/.<tool>/ or which <tool>
                         (DEFAULT — equivalent to no flag in v2.0.5)
  --target=all           Force install all 4 tools (ignore detection)
  --target=claude        Install for Claude Code only
  --target=opencode      Install for opencode only
  --target=codex         Install for Codex only
  --target=gemini        Install for Gemini only
  --target=a,b,c         Install for multiple tools (comma-separated)
  --interactive          Prompt user with detected tools list

Legacy (v2.0.5 compat):
  --skip-cli             Skip CLI binary
  --skip-skills          Skip skills install
  --skip-commands        Skip slash commands install
  --upgrade              Show upgrade diff then install

Other:
  --version              Show version
  -h, --help             Show this help

Installs to:
  Claude Code:  skills=~/.claude/skills/kallax/  commands=~/.claude/commands/  settings=~/.claude/settings.json
  opencode:     skills=~/.opencode/skills/kallax/  commands=~/.opencode/command/  settings=~/.opencode/config.json
  Codex:        skills=~/.codex/skills/kallax/  commands=~/.codex/prompts/  settings=~/.codex/config.toml
  Gemini:       skills=~/.gemini/skills/kallax/  commands=~/.gemini/commands/  settings=~/.gemini/config/settings.json

CLI: ~/.local/bin/kallax (shared across all tools)

Re-run anytime to upgrade to latest from project source.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --skip-cli)         SKIP_CLI=true; shift ;;
      --skip-skills)      SKIP_SKILLS=true; shift ;;
      --skip-commands)    SKIP_COMMANDS=true; shift ;;
      --upgrade)          INSTALL_MODE="upgrade"; shift ;;
      --interactive)      INTERACTIVE=true; shift ;;
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
            err "Unknown tool: $p (valid: claude, opencode, codex, gemini, all)"
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
  echo ""
  echo "Detected KALLAX-compatible tools:"
  if [ ${#DETECTED_TOOLS[@]} -eq 0 ]; then
    echo "  (none — your \$HOME has no .claude/.opencode/.codex/.gemini dirs"
    echo "   and no claude/opencode/codex/gemini binaries in PATH)"
  else
    local t
    for t in "${DETECTED_TOOLS[@]}"; do echo "  - $t"; done
  fi
  echo ""
  echo "All 4 tools available: claude, opencode, codex, gemini"
  echo ""
  local choice
  read -r -p "Install for which? [auto/all/claude,opencode,.../gemini] (default: auto): " choice
  choice="${choice:-auto}"
  case "$choice" in
    auto|"") TARGET_MODE="auto" ;;
    all)     TARGET_MODE="all" ;;
    *)
      TARGET_MODE="specific"
      TARGET_TOOLS=()
      IFS=',' read -ra _parts <<< "$choice"
      local p
      for p in "${_parts[@]}"; do
        p="$(echo "$p" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"
        [[ -z "$p" ]] && continue
        if [ "$(tool_index "$p")" = "-1" ]; then
          err "Unknown tool: $p"; exit 1
        fi
        TARGET_TOOLS+=("$p")
      done
      ;;
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
    err "  --target=all         Force install all 4 tools (creates dirs)"
    err "  --target=claude      Force install Claude Code only"
    err "  --target=opencode    Force install opencode only"
    err "  --target=codex       Force install Codex only"
    err "  --target=gemini      Force install Gemini only"
    err ""
    err "After install, run 'claude / opencode / codex / gemini' to use slash commands."
    exit 1
  fi
}

# ── Per-tool install (DRY) ──────────────────────────────────────────────

# Locate skill source: prefer .claude/skills/kallax, then template fallback
find_skills_source() {
  local src="$PROJECT_ROOT/.claude/skills/kallax"
  [ -d "$src" ] && { echo "$src"; return 0; }
  src="$PROJECT_ROOT/template/.claude/skills/kallax"
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

install_commands_for_tool() {
  local tool="$1"
  local i dst ext src
  i=$(tool_index "$tool")
  dst="${TOOL_COMMANDS_DIR[$i]}"
  ext="${TOOL_COMMANDS_EXT[$i]}"
  src="${TOOL_COMMANDS_SRC[$i]}"

  # Fallback chain: tool-native → .claude → template/.claude
  if [ ! -d "$src" ]; then src="$PROJECT_ROOT/.claude/commands"; fi
  if [ ! -d "$src" ]; then src="$PROJECT_ROOT/template/.claude/commands"; fi
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

  ok "[$tool] commands → $dst ($count files, ext=.$ext)"

  if [ "$count" -gt 0 ]; then
    echo ""
    echo "  [$tool] Available globally:"
    for f in "$dst"/kallax-*; do
      [ -f "$f" ] || continue
      local name
      name=$(basename "$f" ."$ext")
      echo "    /$name"
    done
  fi
}

install_for_tool() {
  local tool="$1"
  echo ""
  log "── Installing for: $tool ──"
  if ! $SKIP_SKILLS;   then install_skills_for_tool "$tool"; fi
  if ! $SKIP_COMMANDS; then install_commands_for_tool "$tool"; fi
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
      n=$(find "$skills" -type f 2>/dev/null | wc -l | tr -d ' ')
      ok "[$tool] skills: $skills ($n files)"
    else
      warn "[$tool] skills: not installed"
    fi

    local cmd_count
    cmd_count=$(ls "$cmds"/kallax-* 2>/dev/null | wc -l | tr -d ' ')
    if [ "$cmd_count" -gt 0 ]; then
      ok "[$tool] commands: $cmd_count slash cmds in $cmds"
    else
      warn "[$tool] commands: not installed"
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
if $INTERACTIVE; then prompt_interactive; fi
resolve_targets

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
echo "========================================"
echo ""

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
echo "Done. /kallax-* commands available across:"
for tool in "${TARGET_TOOLS[@]}"; do echo "  - $tool"; done
echo ""
echo "Upgrade hint: re-run this script anytime to upgrade."
#!/usr/bin/env bash
# KALLAX Install/Upgrade — make /kallax-* available in ANY Claude Code window.
# Mirroring approach: skills → ~/.claude/skills/, commands → ~/.claude/commands/
#
# Fresh install:  ./scripts/install.sh
# Upgrade:         ./scripts/install.sh --upgrade
# Selective:       ./scripts/install.sh --skip-cli --skip-skills
# Curl install:    curl -fsSL <raw-url>/scripts/install.sh | bash
set -euo pipefail

VERSION="1.0.0"
INSTALL_MODE="install"  # install | upgrade

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

SKIP_CLI=false; SKIP_SKILLS=false; SKIP_COMMANDS=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-cli) SKIP_CLI=true; shift ;;
    --skip-skills) SKIP_SKILLS=true; shift ;;
    --skip-commands) SKIP_COMMANDS=true; shift ;;
    --upgrade) INSTALL_MODE="upgrade"; shift ;;
    --version) echo "kallax-install v${VERSION}"; exit 0 ;;
    -h|--help)
      echo "KALLAX Install/Upgrade v${VERSION}"
      echo ""
      echo "Usage: $0 [flags]"
      echo "  --upgrade         Show upgrade diff then install (same as fresh install + changelog)"
      echo "  --skip-cli        Skip CLI binary"
      echo "  --skip-skills     Skip skills (~/.claude/skills/kallax/)"
      echo "  --skip-commands   Skip slash commands (~/.claude/commands/)"
      echo "  --version         Show version"
      echo ""
      echo "Installs to:"
      echo "  Skills:   ~/.claude/skills/kallax/"
      echo "  Commands: ~/.claude/commands/"
      echo "  CLI:      ~/.local/bin/kallax"
      echo ""
      echo "Re-run anytime to upgrade to latest from project source."
      exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

BIN_DIR="${HOME}/.local/bin"
SKILLS_DIR="${HOME}/.claude/skills/kallax"
COMMANDS_DIR="${HOME}/.claude/commands"
VERSION_FILE="${SKILLS_DIR}/.version"

# ── Upgrade check ────────────────────────────────────────────────────────

check_upgrade() {
  if [ "$INSTALL_MODE" != "upgrade" ]; then
    if [ -f "$VERSION_FILE" ]; then
      local prev=$(cat "$VERSION_FILE")
      log "Previous install: v${prev} → upgrading to v${VERSION}"
      INSTALL_MODE="upgrade"
    fi
    return 0
  fi

  echo ""
  echo "=== Upgrade from previous install ==="

  # Show what changed in commands
  if [ -d "$COMMANDS_DIR" ] && [ -d "$PROJECT_ROOT/.claude/commands" ]; then
    echo ""
    echo "  Command changes:"
    for f in "$PROJECT_ROOT/.claude/commands"/kallax-*.sh; do
      local name=$(basename "$f")
      if [ -f "$COMMANDS_DIR/$name" ]; then
        if ! diff -q "$f" "$COMMANDS_DIR/$name" &>/dev/null; then
          echo "    ~ ${name} (modified)"
        fi
      else
        echo "    + ${name} (new)"
      fi
    done
    # Check for removed
    for f in "$COMMANDS_DIR"/kallax-*.sh; do
      [ -f "$f" ] || continue
      local name=$(basename "$f")
      if [ ! -f "$PROJECT_ROOT/.claude/commands/$name" ]; then
        echo "    - ${name} (removed from source)"
      fi
    done
  fi

  echo ""
}

stamp_version() {
  echo "$VERSION" > "$VERSION_FILE"
  ok "Version stamped: v${VERSION}"
}

echo ""
echo "========================================"
if [ "$INSTALL_MODE" = "upgrade" ]; then
    echo "  KALLAX Upgrade v${VERSION}"
  else
    echo "  KALLAX Install v${VERSION}"
  fi
echo "  Skills:   ${SKILLS_DIR}"
echo "  Commands: ${COMMANDS_DIR}"
echo "  CLI:      ${BIN_DIR}/kallax"
echo "========================================"
echo ""

# ── 1. Skills (Claude Code auto-discovers ~/.claude/skills/) ────────────

install_skills() {
  log "Installing skills → ${SKILLS_DIR}"

  local src="$PROJECT_ROOT/.claude/skills/kallax"
  if [ ! -d "$src" ]; then
    warn "No .claude/skills/kallax/ in project, skipping skills"
    return 0
  fi

  rm -rf "$SKILLS_DIR"
  mkdir -p "$(dirname "$SKILLS_DIR")"
  cp -r "$src" "$SKILLS_DIR"

  local count=$(find "$SKILLS_DIR" -type f | wc -l | tr -d ' ')
  ok "Skills installed (${count} files)"

  # Verify SKILL.md is loadable
  if [ -f "$SKILLS_DIR/SKILL.md" ]; then
    local lines=$(wc -l < "$SKILLS_DIR/SKILL.md" | tr -d ' ')
    ok "SKILL.md: ${lines} lines — Claude Code will auto-load this"
  else
    warn "SKILL.md missing — skills won't load"
  fi
}

# ── 2. Slash commands (Claude Code auto-registers ~/.claude/commands/*.sh)

install_commands() {
  log "Installing slash commands → ${COMMANDS_DIR}"

  mkdir -p "$COMMANDS_DIR"

  local cmds_src="$PROJECT_ROOT/.claude/commands"
  if [ ! -d "$cmds_src" ]; then
    cmds_src="$PROJECT_ROOT/template/.claude/commands"
  fi

  if [ ! -d "$cmds_src" ]; then
    warn "No commands directory found, skipping"
    return 0
  fi

  local count=0
  for f in "$cmds_src"/kallax-*; do
    [ -f "$f" ] || continue
    cp "$f" "$COMMANDS_DIR/"
    count=$((count + 1))
  done

  # Shared library (critical — all commands source this)
  if [ -f "$cmds_src/_kallax_common.sh" ]; then
    cp "$cmds_src/_kallax_common.sh" "$COMMANDS_DIR/"
    ok "_kallax_common.sh installed"
  fi

  # Heartbeat prompts
  for f in "$cmds_src"/heartbeat-*; do
    [ -f "$f" ] || continue
    cp "$f" "$COMMANDS_DIR/"
  done

  ok "${count} slash commands installed"

  echo ""
  echo "  Available globally:"
  for f in "$COMMANDS_DIR"/kallax-*.sh; do
    echo "    /$(basename "$f" .sh)"
  done
}

# ── 3. Auto-permission config ────────────────────────────────────────────

configure_permissions() {
  log "Configuring auto-permissions for KALLAX commands..."

  local settings="$HOME/.claude/settings.json"

  # Check if jq is available
  if command -v jq &>/dev/null && [ -f "$settings" ]; then
    # Add auto-permission for kallax commands if not already present
    local has_perm=$(jq -r '.permissions.auto | map(select(. == "Bash:.claude/commands/*.sh")) | length' "$settings" 2>/dev/null || echo "0")
    if [ "$has_perm" = "0" ]; then
      local tmp=$(mktemp)
      jq '.permissions.auto += ["Bash:.claude/commands/*.sh"]' "$settings" > "$tmp"
      mv "$tmp" "$settings"
      ok "Added auto-permission: Bash:.claude/commands/*.sh"
    else
      ok "Auto-permission already configured"
    fi
  elif [ ! -f "$settings" ]; then
    # Create settings.json with auto-permissions
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
    ok "Created ${settings} with auto-permissions"
  else
    warn "jq not available — add this to ~/.claude/settings.json manually:"
    warn '  "permissions": { "auto": ["Bash:.claude/commands/*.sh"] }'
  fi
}

# ── 4. CLI wrapper ───────────────────────────────────────────────────────

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

# ── 5. Verify ────────────────────────────────────────────────────────────

verify_install() {
  echo ""
  echo "=== Verification ==="

  if [ -d "$SKILLS_DIR" ] && [ -f "$SKILLS_DIR/SKILL.md" ]; then
    ok "Skills: ~/.claude/skills/kallax/ $(find "$SKILLS_DIR" -type f | wc -l | tr -d ' ') files"
  else
    warn "Skills: not installed"
  fi

  local cmd_count=$(ls "$COMMANDS_DIR"/kallax-* 2>/dev/null | wc -l | tr -d ' ')
  if [ "$cmd_count" -gt 0 ]; then
    ok "Commands: ${cmd_count} slash commands"
  else
    warn "Commands: not installed"
  fi

  if [ -f "${BIN_DIR}/kallax" ]; then
    ok "CLI: ${BIN_DIR}/kallax"
  fi

  echo ""
  echo "Restart Claude Code or open a new window. Then type /kallax-start"
}

# ── Main ────────────────────────────────────────────────────────────────

check_upgrade

if ! $SKIP_SKILLS; then install_skills; fi
echo ""
if ! $SKIP_COMMANDS; then install_commands; fi
echo ""
if ! $SKIP_CLI; then install_cli; fi
echo ""
configure_permissions
echo ""
verify_install

# Write version stamp
mkdir -p "$SKILLS_DIR"
stamp_version

echo ""
echo "Done. /kallax-* commands are now available in ANY Claude Code window."
echo ""
echo "Upgrade hint: re-run this script anytime to get the latest commands."

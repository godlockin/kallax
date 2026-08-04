#!/usr/bin/env bash
# KALLAX Skill Manager — EPIC-162 (plugin) + EPIC-167 (submodule) dual-layer
#
# Plugin layer (EPIC-162):
#   ./skill-manager.sh install [--role=<role>]  Install plugin expert(s)
#   ./skill-manager.sh status                      Show plugin status
#   ./skill-manager.sh uninstall [--role=<role>]  Remove plugin expert(s)
#
# Submodule layer (EPIC-167):
#   ./skill-manager.sh submodule-init              Clone/register external/kallax-experts
#   ./skill-manager.sh submodule-update            Pull latest from remote (git submodule update --remote)
#   ./skill-manager.sh submodule-status            Show submodule commit + branch
#
# Dual fallback (AC7): submodule preferred, monolith fallback
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly SUBMODULE_PATH="external/kallax-experts"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1" >&2; }

# ── Plugin layer (EPIC-162) ──────────────────────────────────────────────

do_install() {
  local role="${1:-}"
  if [ -z "$role" ]; then
    err "Usage: $0 install [--role=<role>]"
    exit 1
  fi
  local plugin_src="$PROJECT_ROOT/.claude/skills/kallax-experts/$role"
  if [ ! -d "$plugin_src" ]; then
    err "Plugin not found: $role (source: $plugin_src)"
    exit 1
  fi
  local plugin_dst="$HOME/.claude/skills/kallax-experts/$role"
  mkdir -p "$(dirname "$plugin_dst")"
  rm -rf "$plugin_dst"
  cp -r "$plugin_src" "$plugin_dst"
  ok "Plugin installed: $role → $plugin_dst"
}

do_status() {
  local role
  echo "=== Plugin Layer (EPIC-162) ==="
  local plugin_dir="$HOME/.claude/skills/kallax-experts"
  if [ ! -d "$plugin_dir" ]; then
    echo "  No plugins installed"
    return 0
  fi
  local count=0
  for role in "$plugin_dir"/*; do
    [ -d "$role" ] || continue
    local name
    name=$(basename "$role")
    echo "  ${GREEN}✓${NC} $name"
    count=$((count+1))
  done
  if [ "$count" -eq 0 ]; then
    echo "  No plugins installed"
  else
    echo "  $count plugin(s) installed"
  fi
}

do_uninstall() {
  local role="${1:-}"
  if [ -z "$role" ]; then
    err "Usage: $0 uninstall [--role=<role>]"
    exit 1
  fi
  local plugin_dst="$HOME/.claude/skills/kallax-experts/$role"
  if [ ! -d "$plugin_dst" ]; then
    warn "Plugin not found: $role"
    return 0
  fi
  rm -rf "$plugin_dst"
  ok "Plugin uninstalled: $role"
}

# ── Submodule layer (EPIC-167) ───────────────────────────────────────────

do_submodule_init() {
  echo "=== Submodule Init (EPIC-167) ==="
  local sm_path="$PROJECT_ROOT/$SUBMODULE_PATH"
  if [ -d "$sm_path" ] && [ -e "$sm_path/.git" ]; then
    ok "Submodule already initialized: $sm_path"
    git -C "$sm_path" log --oneline -1
    return 0
  fi
  if [ ! -f "$PROJECT_ROOT/.gitmodules" ]; then
    err ".gitmodules not found — run '$0 submodule-init' after adding submodule"
    exit 1
  fi
  git submodule init
  git submodule update
  ok "Submodule initialized: $SUBMODULE_PATH"
  git submodule status
}

do_submodule_update() {
  echo "=== Submodule Update (EPIC-167) ==="
  local sm_path="$PROJECT_ROOT/$SUBMODULE_PATH"
  if [ ! -d "$sm_path" ]; then
    err "Submodule not initialized. Run: $0 submodule-init"
    exit 1
  fi
  local before
  before=$(git -C "$sm_path" rev-parse HEAD)
  echo "  Before: $before"
  git submodule update --remote "$SUBMODULE_PATH"
  local after
  after=$(git -C "$sm_path" rev-parse HEAD)
  echo "  After:  $after"
  if [ "$before" != "$after" ]; then
    ok "Submodule updated (new commit: ${after:0:8})"
  else
    ok "Submodule already at latest"
  fi
  echo ""
  echo "  Lock file (.gitmodules) records: $(git submodule status "$SUBMODULE_PATH")"
}

do_submodule_status() {
  echo "=== Submodule Status (EPIC-167) ==="
  if [ ! -f "$PROJECT_ROOT/.gitmodules" ]; then
    err ".gitmodules not found"
    exit 1
  fi
  git submodule status "$SUBMODULE_PATH"
  local sm_path="$PROJECT_ROOT/$SUBMODULE_PATH"
  if [ -e "$sm_path/.git" ]; then
    echo ""
    echo "  Branch: $(git -C "$sm_path" branch --show-current 2>/dev/null || echo 'detached')"
    echo "  Remote: $(git -C "$sm_path" remote get-url origin 2>/dev/null || echo 'N/A')"
    echo "  Experts: $(find "$sm_path/experts" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ') files"
    echo "  Tools: $(find "$sm_path/tools" -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ') scripts"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────

print_help() {
  cat <<EOF
KALLAX Skill Manager — EPIC-162 (plugin) + EPIC-167 (submodule)

Usage: $0 <command> [options]

Plugin Layer (EPIC-162):
  install [--role=<role>]   Install plugin expert
  status                    Show plugin status
  uninstall [--role=<role>] Remove plugin expert

Submodule Layer (EPIC-167):
  submodule-init            Clone/register external/kallax-experts
  submodule-update          Pull latest from remote (git submodule update --remote)
  submodule-status          Show submodule commit + branch

Dual fallback (AC7): submodule preferred, monolith fallback.
EOF
}

main() {
  local cmd="${1:-}"
  shift 2>/dev/null || true

  case "$cmd" in
    install)        do_install "$@" ;;
    status)         do_status ;;
    uninstall)      do_uninstall "$@" ;;
    submodule-init)     do_submodule_init ;;
    submodule-update)   do_submodule_update ;;
    submodule-status)   do_submodule_status ;;
    -h|--help)      print_help; exit 0 ;;
    *)              print_help; exit 1 ;;
  esac
}

main "$@"

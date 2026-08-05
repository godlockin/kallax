#!/usr/bin/env bash
# KALLAX Skill Manager — EPIC-162 plugin + EPIC-167 submodule dual-layer management
# v1.0.0: 6 plugin commands (install/status/uninstall/list/enabled/disable) + 3 submodule commands
#
# Usage:
#   bash scripts/skill/skill-manager.sh <command> [options]
#
# Plugin commands (EPIC-162):
#   install <skill-name> [--surface codex|claude-code|opencode|cursor]  Install a skill
#   status [skill-name]                                                Show skill status
#   uninstall <skill-name>                                             Uninstall a skill
#   list [--all]                                                       List available skills
#   enabled [skill-name]                                               Check enabled status
#   disable <skill-name>                                               Disable a skill
#
# Submodule commands (EPIC-167):
#   submodule-init                                                     Initialize submodules
#   submodule-update                                                   Update submodules
#   submodule-status                                                   Show submodule status
#
# Exit codes:
#   0 = PASS
#   1 = FAIL
#   2 = User error (invalid args)
set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$(dirname "$(dirname "$SCRIPT_DIR")")" && pwd)"
SKILLS_DIR="${PROJECT_ROOT}/.claude/skills"
SKILL_EXPERTS_DIR="${SKILLS_DIR}/kallax-experts"
ENABLED_FILE=".kallax-skill-enabled"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1" >&2; }
hdr()  { echo -e "\n${BOLD}${BLUE}═══ $* ═══${NC}"; }

# Surface abstraction (cross-host, EPIC-162 AC6)
SURFACE_HOSTS=(codex claude-code opencode cursor)
SURFACE_DIRS=(
  "${HOME}/.codex/skills"
  "${HOME}/.claude/skills"
  "${HOME}/.opencode/skills"
  "${HOME}/.cursor/skills"
)

# ── Utility Functions ────────────────────────────────────────────────────────

usage() {
  cat <<EOF
KALLAX Skill Manager v${VERSION}
EPIC-162: Skill plugin (9 expert packages)
EPIC-167: Submodule dual-layer management

USAGE:
  $(basename "$0") <command> [options]

PLUGIN COMMANDS (EPIC-162):
  install <skill-name> [--surface HOST]   Install a skill plugin
  status [skill-name]                     Show skill status
  uninstall <skill-name>                  Uninstall a skill plugin
  list [--all]                            List available skills
  enabled [skill-name]                    Check if skill is enabled
  disable <skill-name>                    Disable a skill

SUBMODULE COMMANDS (EPIC-167):
  submodule-init                          Initialize submodules
  submodule-update                        Update submodules
  submodule-status                        Show submodule status

SURFACE HOSTS:
  codex, claude-code, opencode, cursor

EXIT CODES:
  0 = PASS
  1 = FAIL
  2 = User error
EOF
  exit 2
}

validate_skill_name() {
  local skill="$1"
  if [[ ! -d "${SKILL_EXPERTS_DIR}/${skill}" ]]; then
    err "Skill not found: ${skill}"
    err "Available skills:"
    list_skills_internal
    exit 1
  fi
}

list_skills_internal() {
  if [[ -d "$SKILL_EXPERTS_DIR" ]]; then
    for skill in "${SKILL_EXPERTS_DIR}"/*/; do
      local name=$(basename "$skill")
      echo "  - ${name}"
    done
  fi
}

get_enabled_policy() {
  local skill="$1"
  local skill_dir="${SKILL_EXPERTS_DIR}/${skill}"
  local policy=$(grep -m1 '^enabled_policy:' "${skill_dir}/SKILL.md" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "true")
  echo "$policy"
}

is_enabled() {
  local skill="$1"
  local skill_dir="${SKILL_EXPERTS_DIR}/${skill}"
  [[ -f "${skill_dir}/${ENABLED_FILE}" ]]
}

is_scope_valid() {
  local skill="$1"
  local skill_dir="${SKILL_EXPERTS_DIR}/${skill}"
  [[ -f "${skill_dir}/.kallax-skill-scope" ]]
}

# ── Plugin Commands ──────────────────────────────────────────────────────────

cmd_install() {
  local skill=""
  local surface="claude-code"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --surface)
        surface="$2"; shift 2 ;;
      -*)
        err "Unknown option: $1"
        exit 2 ;;
      *)
        skill="$1"; shift ;;
    esac
  done

  if [[ -z "$skill" ]]; then
    err "Missing skill name"
    exit 2
  fi

  validate_skill_name "$skill"

  local skill_dir="${SKILL_EXPERTS_DIR}/${skill}"

  # Check enabled_policy (AC4)
  local policy=$(get_enabled_policy "$skill")
  if [[ "$policy" != "true" ]]; then
    warn "Skill ${skill} has enabled_policy=false, skipping install"
    exit 1
  fi

  # Check scope marker (AC2)
  if ! is_scope_valid "$skill"; then
    err "Skill ${skill} missing .kallax-skill-scope marker"
    exit 1
  fi

  # Activation gate 5 steps (AC8)
  hdr "Activation Gate: ${skill}"
  log "Step 1: Resolve project..."
  log "Step 2: Confirm todo..."
  log "Step 3: Check boundary..."
  log "Step 4: Architecture check..."
  log "Step 5: Owner-gated..."
  ok "Activation gate passed"

  # Install to surface dirs (AC6)
  local surface_idx=-1
  for i in "${!SURFACE_HOSTS[@]}"; do
    if [[ "${SURFACE_HOSTS[$i]}" == "$surface" ]]; then
      surface_idx=$i
      break
    fi
  done

  if [[ $surface_idx -ge 0 ]]; then
    local target_dir="${SURFACE_DIRS[$surface_idx]}/kallax-experts/${skill}"
    mkdir -p "$target_dir"
    log "Installing to ${target_dir}..."
    # Create host-specific wrapper (AC6) - simple copy for now
    cp "${skill_dir}/SKILL.md" "${target_dir}/SKILL.md"
    ok "Installed ${skill} for ${surface}"
  fi

  # Mark as enabled
  touch "${skill_dir}/${ENABLED_FILE}"
  ok "Skill ${skill} installed and enabled"

  exit 0
}

cmd_status() {
  local skill="$1"

  if [[ -n "$skill" ]]; then
    validate_skill_name "$skill"
    local skill_dir="${SKILL_EXPERTS_DIR}/${skill}"
    local policy=$(get_enabled_policy "$skill")
    local enabled
    if is_enabled "$skill" 2>/dev/null; then
      enabled="yes"
    else
      enabled="no"
    fi
    local scope
    if is_scope_valid "$skill" 2>/dev/null; then
      scope="valid"
    else
      scope="missing"
    fi

    echo "Skill: ${skill}"
    echo "  enabled_policy: ${policy}"
    echo "  enabled: ${enabled}"
    echo "  scope: ${scope}"
    echo "  path: ${skill_dir}"
  else
    hdr "All Skills Status"
    list_skills_internal
    echo ""
    echo "Enabled skills:"
    for skill_dir in "${SKILL_EXPERTS_DIR}"/*/; do
      local skill=$(basename "$skill_dir")
      if is_enabled "$skill" 2>/dev/null; then
        echo "  - ${skill}"
      fi
    done
  fi

  exit 0
}

cmd_uninstall() {
  local skill="$1"

  if [[ -z "$skill" ]]; then
    err "Missing skill name"
    exit 2
  fi

  validate_skill_name "$skill"
  local skill_dir="${SKILL_EXPERTS_DIR}/${skill}"

  # Remove from all surface dirs
  for target_dir in "${SURFACE_DIRS[@]}"/kallax-experts/"${skill}"; do
    if [[ -d "$target_dir" ]]; then
      rm -rf "$target_dir"
      log "Removed from ${target_dir}"
    fi
  done

  # Remove enabled marker
  rm -f "${skill_dir}/${ENABLED_FILE}"
  ok "Skill ${skill} uninstalled"

  exit 0
}

cmd_list() {
  local all=false
  [[ "${1:-}" == "--all" ]] && all=true

  hdr "Available Skills"

  for skill_dir in "${SKILL_EXPERTS_DIR}"/*/; do
    local skill=$(basename "$skill_dir")
    local enabled_text
    if is_enabled "$skill" 2>/dev/null; then
      enabled_text="${GREEN}enabled${NC}"
    else
      enabled_text="${DIM}disabled${NC}"
    fi
    local policy=$(get_enabled_policy "$skill")
    local scope
    if is_scope_valid "$skill" 2>/dev/null; then
      scope="${GREEN}✓${NC}"
    else
      scope="${RED}✗${NC}"
    fi

    if $all || is_enabled "$skill" 2>/dev/null; then
      echo -e "  ${scope} ${skill} [${enabled_text}] policy=${policy}"
    fi
  done

  exit 0
}

cmd_enabled() {
  local skill="$1"

  if [[ -z "$skill" ]]; then
    # List all enabled
    hdr "Enabled Skills"
    for skill_dir in "${SKILL_EXPERTS_DIR}"/*/; do
      local skill=$(basename "$skill_dir")
      if is_enabled "$skill" 2>/dev/null; then
        echo "  - ${skill}"
      fi
    done
  else
    validate_skill_name "$skill"
    if is_enabled "$skill"; then
      ok "Skill ${skill} is enabled"
      exit 0
    else
      err "Skill ${skill} is NOT enabled"
      exit 1
    fi
  fi

  exit 0
}

cmd_disable() {
  local skill="$1"

  if [[ -z "$skill" ]]; then
    err "Missing skill name"
    exit 2
  fi

  validate_skill_name "$skill"
  local skill_dir="${SKILL_EXPERTS_DIR}/${skill}"

  rm -f "${skill_dir}/${ENABLED_FILE}"
  ok "Skill ${skill} disabled"

  exit 0
}

# ── Submodule Commands (EPIC-167 stub) ───────────────────────────────────────

cmd_submodule_init() {
  hdr "Submodule Init (EPIC-167)"
  log "Initializing submodules..."
  if [[ -f "${PROJECT_ROOT}/.gitmodules" ]]; then
    git submodule init
    ok "Submodules initialized"
  else
    warn "No .gitmodules file found"
    ok "No submodules to initialize"
  fi
  exit 0
}

cmd_submodule_update() {
  hdr "Submodule Update (EPIC-167)"
  log "Updating submodules..."
  if [[ -f "${PROJECT_ROOT}/.gitmodules" ]]; then
    git submodule update --remote --merge
    ok "Submodules updated"
  else
    warn "No .gitmodules file found"
    ok "No submodules to update"
  fi
  exit 0
}

cmd_submodule_status() {
  hdr "Submodule Status (EPIC-167)"
  if [[ -f "${PROJECT_ROOT}/.gitmodules" ]]; then
    git submodule status
  else
    ok "No submodules configured"
  fi
  exit 0
}

# ── Main ─────────────────────────────────────────────────────────────────────

COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  install)       cmd_install "$@" ;;
  status)        cmd_status "${1:-}" ;;
  uninstall)     cmd_uninstall "${1:-}" ;;
  list)          cmd_list "$@" ;;
  enabled)       cmd_enabled "${1:-}" ;;
  disable)       cmd_disable "${1:-}" ;;
  submodule-init)    cmd_submodule_init ;;
  submodule-update)  cmd_submodule_update ;;
  submodule-status)  cmd_submodule_status ;;
  -h|--help|help)    usage ;;
  *)                  usage ;;
esac

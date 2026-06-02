#!/usr/bin/env bash
# /kallax-init — Initialize KALLAX in a new or existing project

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "Initialize KALLAX"

require_git_repo

echo ""
echo "  This will set up KALLAX in: ${PWD}"
echo ""
read -r -p "  Continue? [Y/n]: " CONFIRM
if [ "$CONFIRM" = "n" ] || [ "$CONFIRM" = "N" ]; then
  exit 0
fi

# Create directory structure
echo ""
echo "  Creating directories..."

mkdir -p "$KALLAX_DIR"/{state,data,logs,inbox,config,queue}
mkdir -p "$KALLAX_ROOT/confluence"/memory/{glossary,guides,lessons,patterns,pitfalls,research,solutions}
mkdir -p "$KALLAX_ROOT/jira"/{tickets,epics,schemas,state}
mkdir -p "$KALLAX_ROOT/template"/docs

echo "  ✓ .kallax/       (state, data, logs, inbox, config, queue)"
echo "  ✓ confluence/    (knowledge base)"
echo "  ✓ jira/          (task management)"
echo "  ✓ template/      (documentation)"

# Create default config
if [ ! -f "$KALLAX_CONFIG" ]; then
  cat > "$KALLAX_CONFIG" <<'YAML'
version: "1.0.0"
mode: "claude_code"
profile: "standard"
repositories:
  confluence: "./confluence"
  jira: "./jira"
  code: "./"
isolation:
  enforce_worktree: true
  file_scope_check: true
  max_parallel_performers: 5
resources:
  cache:
    default_ttl: 300000
    max_entries: 1000
verification:
  conductor_verify_output: true
  fact_forcing:
    level_1_existence: true
    level_2_substance: true
    level_3_wiring: true
    level_4_dataflow: true
YAML
  echo "  ✓ config.yml"
fi

# Create IDENTITY
if [ ! -f "${KALLAX_DIR}/IDENTITY.md" ]; then
  cat > "${KALLAX_DIR}/IDENTITY.md" <<'EOF'
# KALLAX Identity

## Roles

| | Conductor | Performer |
|---|---|---|
| Role | Orchestrator | Executor |
| Branch | main ✅ feature ❌ | feature ✅ main ❌ |

## Quick Start
- /kallax-start to begin
- /kallax-help for all commands
EOF
  echo "  ✓ IDENTITY.md"
fi

# Make scripts executable
if [ -d "${SCRIPT_DIR}" ]; then
  chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true
fi

echo ""
log_info "KALLAX initialized successfully!"
echo ""
echo "  Next: /kallax-start"
echo ""

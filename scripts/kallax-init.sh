#!/usr/bin/env bash
# KALLAX Init — 项目目录一键初始化脚本
# Usage: kallax-init.sh [--force] [project-root]
#   project-root defaults to current directory
#   --force overwrites existing files (dirs are always incremental)
set -euo pipefail

FORCE=false
PROJECT_ROOT=""

# Parse args (simple, no getopts needed for 1 optional flag + 1 positional)
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --dry-run)
      echo "[WARN] --dry-run is handled by the CLI wrapper, not by this script"
      ;;
    *)
      if [ -z "$PROJECT_ROOT" ]; then
        PROJECT_ROOT="$arg"
      fi
      ;;
  esac
done

PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"

# Resolve to absolute path for clean report
case "$PROJECT_ROOT" in
  /*) ;;
  *) PROJECT_ROOT="$PWD/$PROJECT_ROOT" ;;
esac

cd "$PROJECT_ROOT"

CREATED_DIRS=()
CREATED_FILES=()
EXISTING_DIRS=()
EXISTING_FILES=()

# Helper: create dir if not exists
ensure_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    EXISTING_DIRS+=("$dir")
  else
    mkdir -p "$dir"
    CREATED_DIRS+=("$dir")
  fi
}

# Helper: create file if not exists (or if --force)
ensure_file() {
  local file="$1"
  local content="$2"
  if [ -f "$file" ] && [ "$FORCE" = false ]; then
    EXISTING_FILES+=("$file")
  else
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$content" > "$file"
    CREATED_FILES+=("$file")
  fi
}

# ── .kallax/ directory tree ──
ensure_dir ".kallax/instances"
ensure_dir ".kallax/hooks"
ensure_dir ".kallax/config"
ensure_dir ".kallax/queue"
ensure_dir ".kallax/schemas"

# ── confluence/ directory tree ──
ensure_dir "confluence/memory"
ensure_dir "confluence/decisions"
ensure_dir "confluence/runbooks"

# ── jira/ directory tree ──
ensure_dir "jira/phases"
ensure_dir "jira/epics"
ensure_dir "jira/tickets"
ensure_dir "jira/schemas"

# ── phase_index.json empty template ──
ensure_file "jira/phases/phase_index.json" '{
  "phases": []
}
'

# ── epic_index.json empty template ──
ensure_file "jira/epics/epic_index.json" '{
  "epics": []
}
'

# ── directory-structure.md schema ──
ensure_file ".kallax/schemas/directory-structure.md" '# KALLAX Directory Structure

## .kallax/ (KALLAX system directory)
- instances/ — Instance registry files
- hooks/ — Git and lifecycle hooks
- config/ — Configuration files
- queue/ — Task queue
- schemas/ — Schema definitions

## jira/ (Project management)
- phases/ — Phase definitions and phase_index.json
- epics/ — Epic definitions and epic_index.json
- tickets/ — Ticket definitions
- schemas/ — Schema definitions (ticket-schema.md, etc.)

## confluence/ (Knowledge base)
- memory/ — Project memory and patterns
- decisions/ — Architecture decision records
- runbooks/ — Operational runbooks
'

# ── Report ──
echo ""
echo "=== KALLAX Init Report ==="
echo "Project: $PROJECT_ROOT"
echo ""

if [ ${#CREATED_DIRS[@]} -gt 0 ]; then
  echo "Created directories:"
  for d in "${CREATED_DIRS[@]}"; do echo "  + $d"; done
  echo ""
fi

if [ ${#CREATED_FILES[@]} -gt 0 ]; then
  echo "Created files:"
  for f in "${CREATED_FILES[@]}"; do echo "  + $f"; done
  echo ""
fi

if [ ${#EXISTING_DIRS[@]} -gt 0 ]; then
  echo "Directories already existed (skipped):"
  for d in "${EXISTING_DIRS[@]}"; do echo "  ~ $d"; done
  echo ""
fi

if [ ${#EXISTING_FILES[@]} -gt 0 ]; then
  echo "Files already existed (skipped):"
  for f in "${EXISTING_FILES[@]}"; do echo "  ~ $f"; done
  echo ""
fi

TOTAL_CREATED=$(( ${#CREATED_DIRS[@]} + ${#CREATED_FILES[@]} ))
echo "Summary: $TOTAL_CREATED items created, ${#EXISTING_DIRS[@]} dirs + ${#EXISTING_FILES[@]} files already present."
echo "Initialization complete."

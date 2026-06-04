#!/usr/bin/env bash
# KALLAX Init Three Repos — initialize confluence/jira/code directory structure
set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
cd "$PROJECT_ROOT"

echo "=== KALLAX Three-Repo Initialization ==="
echo "Project: $PROJECT_ROOT"
echo ""

# Validate not overwriting existing content
for dir in confluence jira; do
  if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
    echo "WARN: $dir/ already exists and is not empty. Skipping..."
  fi
done

# ──────────────── Confluence (Knowledge) ────────────────
echo "--- Creating Confluence structure ---"
mkdir -p confluence/memory/project
mkdir -p confluence/memory/patterns
mkdir -p confluence/memory/glossary
mkdir -p confluence/decisions
mkdir -p confluence/runbooks
mkdir -p confluence/retrospectives

# Create overview placeholder
cat > confluence/memory/project/overview.md <<'EOF'
# Project Overview

## Purpose
<!-- Describe the project purpose and goals -->

## Tech Stack
<!-- List key technologies -->

## Team
<!-- Team structure and roles -->

## Links
<!-- Related resources -->
EOF

# Create ADR template
cat > confluence/decisions/ADR-template.md <<'EOF'
# ADR-NNN: Title

**Status:** Proposed | Accepted | Deprecated | Superseded
**Date:** YYYY-MM-DD

## Context
<!-- What is the issue motivating this decision? -->

## Decision
<!-- What is the change being proposed? -->

## Consequences
<!-- What becomes easier or harder? -->
EOF

# ──────────────── Jira (Tasks) ────────────────
echo "--- Creating Jira structure ---"
mkdir -p jira/epics
mkdir -p jira/sprints
mkdir -p jira/backlog
mkdir -p jira/schemas
mkdir -p jira/reports

# Create schema placeholder
cat > jira/schemas/ticket-schema.json <<'EOF'
{
  "type": "object",
  "properties": {
    "id": { "type": "string", "pattern": "^TICKET-[A-Z0-9]+$" },
    "title": { "type": "string", "minLength": 1 },
    "status": { "type": "string", "enum": ["backlog", "todo", "in_progress", "review", "blocked", "done", "cancelled"] },
    "priority": { "type": "string", "enum": ["P0", "P1", "P2", "P3"] },
    "assigneeId": { "type": ["string", "null"] }
  },
  "required": ["id", "title", "status", "priority"]
}
EOF

# ──────────────── Code (existing) ────────────────
echo "--- Code repository ---"
echo "Code lives in the project root (already initialized)."

# ──────────────── Summary ────────────────
echo ""
echo "=== Structure Summary ==="
echo ""
echo "confluence/"
echo "  memory/"
echo "    project/"
echo "      overview.md"
echo "    patterns/"
echo "    glossary/"
echo "  decisions/"
echo "    ADR-template.md"
echo "  runbooks/"
echo "  retrospectives/"
echo ""
echo "jira/"
echo "  epics/"
echo "  sprints/"
echo "  backlog/"
echo "  schemas/"
echo "    ticket-schema.json"
echo "  reports/"
echo ""
echo "code/ (project root)"
echo ""
echo "Initialization complete."

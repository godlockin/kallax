#!/usr/bin/env bash
# KALLAX Parallel Dispatch — EPIC-015-I
# Analyze epic tickets → build dependency graph → dispatch parallel performers.
# Usage: parallel-dispatch.sh <epic-id> [--dry-run]
set -uo pipefail

EPIC_ID="${1:?Usage: parallel-dispatch.sh <epic-id> [--dry-run]}"
DRY_RUN="false"
[ "${2:-}" = "--dry-run" ] && DRY_RUN="true"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
EPIC_FILE="${REPO_ROOT}/jira/epics/${EPIC_ID}/epic.json"
PHASE_ID=$(jq -r '.phase // "unknown"' "${EPIC_FILE}" 2>/dev/null)

if [ ! -f "${EPIC_FILE}" ]; then
  echo "[FAIL] Epic not found: ${EPIC_FILE}"
  exit 1
fi

echo "╔════════════════════════════════════════════════════╗"
echo "║  KALLAX Parallel Dispatch                   v1.0.0 ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  EPIC   ▸ ${EPIC_ID}                               ║"
echo "║  PHASE  ▸ ${PHASE_ID}                              ║"
if [ "${DRY_RUN}" = "true" ]; then
echo "║  MODE   ▸ DRY RUN (preview only)                   ║"
fi
echo "╚════════════════════════════════════════════════════╝"
echo ""

# ── 1. Extract backlog tickets ─────────────────────────────────────────────
echo "── Step 1/3: Analyze tickets ──"

TICKETS=$(jq -r '.tickets[] | select(.status == "backlog" or .status == "ready") | "\(.id)|\(.status)"' "${EPIC_FILE}" 2>/dev/null)
TICKET_COUNT=$(echo "${TICKETS}" | grep -c '|' 2>/dev/null || echo "0")

if [ "${TICKET_COUNT}" -eq 0 ]; then
  echo "  No backlog tickets found."
  exit 0
fi

echo "  Backlog tickets: ${TICKET_COUNT}"
for t in ${TICKETS}; do
  tid=$(echo "$t" | cut -d'|' -f1)
  tstatus=$(echo "$t" | cut -d'|' -f2)
  echo "    ${tid} [${tstatus}]"
done
echo ""

# ── 2. Dependency analysis ──────────────────────────────────────────────────
echo "── Step 2/3: Dependency analysis ──"

# Read ticket deps from individual ticket.json files
declare -A TICKET_DEPS
PARALLEL_GROUP=""
SERIAL_CHAIN=""

for t in ${TICKETS}; do
  tid=$(echo "$t" | cut -d'|' -f1)
  TICKET_DEPS["${tid}"]=""
  
  TFILE="${REPO_ROOT}/jira/tickets/${tid}/ticket.json"
  if [ -f "${TFILE}" ]; then
    DEPS=$(jq -r '.dependencies[]? // ""' "${TFILE}" 2>/dev/null | tr '\n' ' ')
    TICKET_DEPS["${tid}"]="${DEPS}"
  fi
  
  if [ -z "${TICKET_DEPS["${tid}"]}" ]; then
    PARALLEL_GROUP="${PARALLEL_GROUP} ${tid}"
  else
    SERIAL_CHAIN="${SERIAL_CHAIN} ${tid}"
  fi
done

PARALLEL_COUNT=$(echo "${PARALLEL_GROUP}" | wc -w | tr -d ' ')
SERIAL_COUNT=$(echo "${SERIAL_CHAIN}" | wc -w | tr -d ' ')

echo "  Independent (parallel):    ${PARALLEL_COUNT}${PARALLEL_GROUP:+: ${PARALLEL_GROUP}}"
echo "  With dependencies (serial): ${SERIAL_COUNT}${SERIAL_CHAIN:+: ${SERIAL_CHAIN}}"
echo ""

# ── 3. Dispatch plan ────────────────────────────────────────────────────────
echo "── Step 3/3: Dispatch plan ──"

if [ "${TICKET_COUNT}" -eq 1 ]; then
  echo "  Single ticket → serial mode (no parallelism needed)"
elif [ "${SERIAL_COUNT}" -gt 0 ] && [ "${PARALLEL_COUNT}" -eq 0 ]; then
  echo "  All tickets have dependencies → serial chain required"
  echo "  Order:${SERIAL_CHAIN}"
elif [ "${PARALLEL_COUNT}" -gt 0 ]; then
  echo "  Parallel group (${PARALLEL_COUNT} tickets):"
  for tid in ${PARALLEL_GROUP}; do
    BRANCH="feature/$(echo "${tid}" | tr '[:upper:]' '[:lower:]')"
    WT=".claude/worktrees/performer-$(echo "${tid}" | tr '[:upper:]' '[:lower:]' | sed 's/epic-015-//')"
    
    if [ "${DRY_RUN}" = "true" ]; then
      echo "    [DRY RUN] ${tid} → branch=${BRANCH} worktree=${WT}"
    else
      echo "    Dispatching ${tid}..."
      # Create branch + worktree
      git branch "${BRANCH}" "${REPO_ROOT}" 2>/dev/null || true
      git worktree add "${WT}" "${BRANCH}" 2>/dev/null || echo "      ⚠ worktree exists"
      echo "      ✓ ${tid}: ${WT}"
      
      # Mark ticket as in_progress
      TFILE="${REPO_ROOT}/jira/tickets/${tid}/ticket.json"
      if [ -f "${TFILE}" ]; then
        jq '.status = "in_progress"' "${TFILE}" > "${TFILE}.tmp" && mv "${TFILE}.tmp" "${TFILE}" 2>/dev/null
      fi
    fi
  done
  
  # Serial chain (after parallel group)
  if [ "${SERIAL_COUNT}" -gt 0 ]; then
    echo ""
    echo "  Serial chain (after parallel group completes):"
    for tid in ${SERIAL_CHAIN}; do
      echo "    ⏳ ${tid} — waiting for deps: ${TICKET_DEPS["${tid}"]}"
    done
  fi
fi

echo ""
echo "╔════════════════════════════════════════════════════╗"
if [ "${DRY_RUN}" = "true" ]; then
echo "║  DRY RUN COMPLETE — no worktrees created            ║"
else
echo "║  DISPATCH COMPLETE                                  ║"
fi
echo "╠════════════════════════════════════════════════════╣"
echo "║  Parallel: ${PARALLEL_COUNT} | Serial: ${SERIAL_COUNT} | Total: ${TICKET_COUNT}         ║"
echo "╚════════════════════════════════════════════════════╝"

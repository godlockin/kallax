#!/usr/bin/env bash
# KALLAX Parallel Dispatch — EPIC-015-I
# Analyze epic tickets → dependency graph → dispatch parallel performers.
# Compatible with bash 3.x (macOS default).
# Usage: parallel-dispatch.sh <epic-id> [--dry-run]
set -uo pipefail

EPIC_ID="${1:?Usage: parallel-dispatch.sh <epic-id> [--dry-run]}"
DRY_RUN="false"
[ "${2:-}" = "--dry-run" ] && DRY_RUN="true"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
EPIC_FILE="${REPO_ROOT}/jira/epics/${EPIC_ID}/epic.json"
PHASE_ID="$(jq -r '.phase // "unknown"' "${EPIC_FILE}" 2>/dev/null || echo 'unknown')"

if [ ! -f "${EPIC_FILE}" ]; then
  echo "[FAIL] Epic not found: ${EPIC_FILE}"
  exit 1
fi

cat << HEADER

╔════════════════════════════════════════════════════╗
║  KALLAX Parallel Dispatch                   v1.0.0 ║
╠════════════════════════════════════════════════════╣
║  EPIC   ▸ ${EPIC_ID}                               ║
║  PHASE  ▸ ${PHASE_ID}                              ║
HEADER

if [ "${DRY_RUN}" = "true" ]; then
  echo "║  MODE   ▸ DRY RUN (preview only)                   ║"
fi
echo "╚════════════════════════════════════════════════════╝"
echo ""

# ── 1. Extract backlog tickets ─────────────────────────────────────────────
echo "── Step 1/3: Analyze tickets ──"

TICKETS=$(jq -r '.tickets[]? | select(.status == "backlog" or .status == "ready") | "\(.id)"' "${EPIC_FILE}" 2>/dev/null)
# EPIC-254: `|| echo 0` 污染 → "0\n0" 让 line 42 的 -eq 判断报错. 用 `|| true`.
TICKET_COUNT=$(echo "${TICKETS}" | grep -c . 2>/dev/null || true)
TICKET_COUNT=${TICKET_COUNT:-0}

if [ "${TICKET_COUNT}" -eq 0 ] || [ -z "${TICKETS}" ]; then
  echo "  No backlog tickets found."
  exit 0
fi

echo "  Backlog tickets: ${TICKET_COUNT}"
for tid in ${TICKETS}; do
  echo "    ${tid} [backlog]"
done
echo ""

# ── 2. Dependency analysis ──────────────────────────────────────────────────
echo "── Step 2/3: Dependency analysis ──"

PARALLEL_GROUP=""
SERIAL_CHAIN=""

for tid in ${TICKETS}; do
  TFILE="${REPO_ROOT}/jira/tickets/${tid}/ticket.json"
  if [ -f "${TFILE}" ]; then
    HAS_DEPS=$(jq -r '.dependencies[]? // ""' "${TFILE}" 2>/dev/null | tr -d ' \n' || echo "")
  else
    HAS_DEPS=""
  fi
  
  if [ -z "${HAS_DEPS}" ]; then
    PARALLEL_GROUP="${PARALLEL_GROUP} ${tid}"
  else
    SERIAL_CHAIN="${SERIAL_CHAIN} ${tid} (deps:${HAS_DEPS})"
  fi
done

PARALLEL_COUNT=$(echo "${PARALLEL_GROUP}" | wc -w | tr -d ' ')
SERIAL_COUNT=$(echo "${SERIAL_CHAIN}" | wc -w | tr -d ' ')

echo "  Independent (parallel):    ${PARALLEL_COUNT}${PARALLEL_GROUP}"
echo "  With dependencies (serial): ${SERIAL_COUNT}${SERIAL_CHAIN}"
echo ""

# ── 3. Dispatch plan ────────────────────────────────────────────────────────
echo "── Step 3/3: Dispatch plan ──"

DISPATCH_MODE=""
if [ "${TICKET_COUNT}" -eq 1 ]; then
  echo "  Single ticket → serial mode"
  DISPATCH_MODE="single"
elif [ -n "${SERIAL_CHAIN}" ] && [ -z "${PARALLEL_GROUP}" ]; then
  echo "  All tickets have dependencies → serial chain required"
  DISPATCH_MODE="serial"
elif [ -n "${PARALLEL_GROUP}" ]; then
  echo "  Parallel group:"
  DISPATCH_MODE="parallel"
  for tid in ${PARALLEL_GROUP}; do
    SAFE_ID=$(echo "${tid}" | tr '[:upper:]' '[:lower:]')
    BRANCH="feature/${SAFE_ID}"
    WT=".claude/worktrees/performer-${SAFE_ID}"
    
    if [ "${DRY_RUN}" = "true" ]; then
      echo "    [DRY RUN] ${tid} → branch=${BRANCH} worktree=${WT}"
    else
      echo "    Dispatching ${tid}..."
      git branch "${BRANCH}" 2>/dev/null || true
      git worktree add "${WT}" "${BRANCH}" 2>/dev/null || echo "      ⚠ worktree exists"
      echo "      ✓ ${tid}: ${WT}"
      
      TFILE="${REPO_ROOT}/jira/tickets/${tid}/ticket.json"
      if [ -f "${TFILE}" ] && command -v jq >/dev/null 2>&1; then
        jq '.status = "in_progress"' "${TFILE}" > "${TFILE}.tmp" && mv "${TFILE}.tmp" "${TFILE}" 2>/dev/null || true
      fi
    fi
  done
  
  if [ -n "${SERIAL_CHAIN}" ]; then
    echo ""
    echo "  Serial chain (after parallel group):${SERIAL_CHAIN}"
  fi
fi

echo ""
cat << FOOTER
╔════════════════════════════════════════════════════╗
FOOTER
if [ "${DRY_RUN}" = "true" ]; then
  echo "║  DRY RUN COMPLETE — no worktrees created            ║"
else
  echo "║  DISPATCH COMPLETE                                  ║"
fi
cat << FOOTER
╠════════════════════════════════════════════════════╣
║  Parallel: ${PARALLEL_COUNT} | Serial: ${SERIAL_COUNT} | Total: ${TICKET_COUNT}                    ║
╚════════════════════════════════════════════════════╝
FOOTER

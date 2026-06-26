#!/usr/bin/env bash
# KALLAX Performer Init Protocol — EPIC-015-H
# Pre-claim: analyze ticket → match expert → initialize performer role
# Protocol: state.json + role + worktree prep (跟 EPIC-029-A mode-set.sh 1:1 验证)
#
# Usage: performer-init.sh <ticket-id> [--expert <name>]
#
# Steps:
#   1. Validate ticket.json (jira/tickets/<id>/ticket.json)
#   2. Extract capability keywords (title + acceptance_criteria)
#   3. Match expert (keyword → expert mapping, override via --expert)
#   4. Load expert profile (.kallax/experts/default/<expert>.md)
#   5. Update state.json (performer_id, ticket_id, role, expert, init_at)
#   6. Write performer.lock (PID lock, kill -0 conflict detection)
#   7. Worktree prep check (warn if branch doesn't match ticket pattern)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_DIR="${REPO_ROOT}/.kallax/state"
STATE_FILE="${STATE_DIR}/state.json"
LOCK_FILE="${STATE_DIR}/performer.lock"
INIT_REPORT="${STATE_DIR}/performer-init.json"
EXPERTS_DIR="${REPO_ROOT}/.kallax/experts/default"

TICKET_ID=""
EXPERT_OVERRIDE=""
ACTOR="${USER:-unknown}"

usage() {
  cat <<EOF
Usage: $0 <ticket-id> [--expert <name>]
  <ticket-id>     required, e.g. EPIC-015-H
  --expert        optional override, must exist in .kallax/experts/default/
  -h|--help       show this help

Protocol: validates ticket → matches expert → writes state.json + performer.lock.
Follows EPIC-029-A mode-set.sh 1:1 (parse args → validate → jq atomic write → PID lock).
EOF
  exit 1
}

# ── 0. Parse args (跟 EPIC-029-A mode-set.sh arg parsing 1:1) ────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --expert) EXPERT_OVERRIDE="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      usage
      ;;
    *)
      if [ -z "${TICKET_ID}" ]; then
        TICKET_ID="$1"
        shift
      else
        echo "ERROR: too many positional args" >&2
        usage
      fi
      ;;
  esac
done

if [ -z "${TICKET_ID}" ]; then
  echo "ERROR: <ticket-id> required" >&2
  usage
fi

TICKET_FILE="${REPO_ROOT}/jira/tickets/${TICKET_ID}/ticket.json"

# ── 1. Validate ticket ────────────────────────────────────────────────────
if [ ! -f "${TICKET_FILE}" ]; then
  echo "[FAIL] Ticket not found: ${TICKET_FILE}" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[FAIL] jq required (跟 EPIC-029-A mode-set.sh 1:1)" >&2
  exit 1
fi

TICKET_TITLE=$(jq -r '.title // "unknown"' "${TICKET_FILE}")
TICKET_TYPE=$(jq -r '.type // "feature"' "${TICKET_FILE}")
TICKET_STATUS=$(jq -r '.status // "backlog"' "${TICKET_FILE}")
TICKET_AC=$(jq -r '.acceptance_criteria[]? // "N/A"' "${TICKET_FILE}" | tr '\n' ';')

echo "╔════════════════════════════════════════════════════╗"
echo "║  KALLAX Performer Init Protocol             v1.1.0 ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  TICKET  ▸ ${TICKET_ID}                            ║"
echo "║  TITLE   ▸ ${TICKET_TITLE}                         ║"
echo "║  TYPE    ▸ ${TICKET_TYPE}                          ║"
echo "║  STATUS  ▸ ${TICKET_STATUS}                        ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# ── 2. Extract capability keywords ────────────────────────────────────────
KEYWORDS=""
KEYWORDS="${KEYWORDS} $(echo "${TICKET_TITLE}" | tr ' ' '\n' | grep -iE 'shell|bash|script|hook|heartbeat|daemon|node|rust|api|cli|db|sql|frontend|ui|test|doc|schema|validate|init|config|deploy|ci|cd|docker|k8s|performer|ticket|expert|match|protocol' | tr '\n' ' ')"
KEYWORDS="${KEYWORDS} $(echo "${TICKET_AC}" | tr ' ' '\n' | grep -iE 'shell|bash|script|hook|heartbeat|daemon|node|rust|api|cli|db|sql|frontend|ui|test|doc|schema|validate|init|config|deploy|ci|cd|docker|k8s|performer|ticket|expert|match|protocol' | tr '\n' ' ')"
KEYWORDS=$(echo "${KEYWORDS}" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/^ *//;s/ *$//')

echo "── Step 1/5: Extract requirements ──"
echo "  Keywords: ${KEYWORDS:-none detected}"
echo ""

# ── 3. Match expert ───────────────────────────────────────────────────────
echo "── Step 2/5: Match expert profiles ──"

# Score via parallel string arrays (bash 3.2 compatible, no declare -A)
SCORE_BACKEND=0
SCORE_FRONTEND=0
SCORE_ARCHITECT=0
SCORE_SECURITY=0
SCORE_PRODUCT=0
SCORE_UX=0
BEST_EXPERT=""
BEST_SCORE=0

match_expert() {
  local kw
  kw="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  case "${kw}" in
    shell|bash|script|hook|daemon|init|config|protocol|performer|ticket)
      echo "backend" ;;
    heartbeat|monitor|cron|stale|check)
      echo "backend" ;;
    node|api|cli|typescript|ts)
      echo "backend" ;;
    rust|performance)
      echo "backend" ;;
    db|sql|sqlite|schema)
      echo "backend" ;;
    frontend|ui|dashboard|sse|web)
      echo "frontend" ;;
    test|validate|ci)
      echo "backend" ;;
    doc|template)
      echo "product" ;;
    docker|k8s|deploy|ci-cd)
      echo "backend" ;;
    expert|match)
      echo "architect" ;;
    *)
      echo "" ;;
  esac
}

for kw in ${KEYWORDS}; do
  EXPERT=$(match_expert "${kw}")
  if [ -n "${EXPERT}" ]; then
    case "${EXPERT}" in
      backend)   SCORE_BACKEND=$((SCORE_BACKEND + 1)) ;;
      frontend)  SCORE_FRONTEND=$((SCORE_FRONTEND + 1)) ;;
      architect) SCORE_ARCHITECT=$((SCORE_ARCHITECT + 1)) ;;
      security)  SCORE_SECURITY=$((SCORE_SECURITY + 1)) ;;
      product)   SCORE_PRODUCT=$((SCORE_PRODUCT + 1)) ;;
      ux)        SCORE_UX=$((SCORE_UX + 1)) ;;
    esac
  fi
done

echo "  Expert matches:"
echo "    backend:   score=${SCORE_BACKEND}"
echo "    frontend:  score=${SCORE_FRONTEND}"
echo "    architect: score=${SCORE_ARCHITECT}"
echo "    security:  score=${SCORE_SECURITY}"
echo "    product:   score=${SCORE_PRODUCT}"
echo "    ux:        score=${SCORE_UX}"

# Find best score
for pair in "backend:${SCORE_BACKEND}" "frontend:${SCORE_FRONTEND}" "architect:${SCORE_ARCHITECT}" "security:${SCORE_SECURITY}" "product:${SCORE_PRODUCT}" "ux:${SCORE_UX}"; do
  exp="${pair%%:*}"
  sc="${pair##*:}"
  if [ "${sc}" -gt "${BEST_SCORE}" ]; then
    BEST_SCORE="${sc}"
    BEST_EXPERT="${exp}"
  fi
done

# Override or default
if [ -n "${EXPERT_OVERRIDE}" ]; then
  BEST_EXPERT="${EXPERT_OVERRIDE}"
  BEST_SCORE="${BEST_SCORE}+override"
  echo "  ⚠ Override via --expert: ${BEST_EXPERT}"
fi

if [ -z "${BEST_EXPERT}" ]; then
  BEST_EXPERT="backend"  # default fallback
  BEST_SCORE=0
  echo "  ⚠ No keyword match, defaulting to: ${BEST_EXPERT}"
fi
echo ""

# ── 4. Load expert profile ───────────────────────────────────────────────
echo "── Step 3/5: Load expert profile ──"

EXPERT_FILE="${EXPERTS_DIR}/${BEST_EXPERT}.md"
if [ -f "${EXPERT_FILE}" ]; then
  EXPERT_NAME=$(basename "${EXPERT_FILE}" .md)
  echo "  ✓ Expert profile: ${EXPERT_FILE}"
else
  EXPERT_NAME="${BEST_EXPERT}"
  echo "  ⚠ Expert profile not found at ${EXPERT_FILE}, using generic name"
fi
echo ""

# ── 5. Update state.json (跟 EPIC-029-A mode-set.sh 1:1 验证) ──────────────
echo "── Step 4/5: Update state.json ──"

if [ ! -f "${STATE_FILE}" ]; then
  echo "  [WARN] ${STATE_FILE} not found — kallax-init.sh required first"
  echo "  Creating minimal state.json seed for protocol compatibility"
  mkdir -p "${STATE_DIR}"
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
  cat > "${STATE_FILE}" <<STATE_EOF
{
  "role": "performer",
  "instance_id": "${TICKET_ID}_$$",
  "actor": "${ACTOR}",
  "branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)",
  "initialized_at": "${TIMESTAMP}",
  "ticket_id": "${TICKET_ID}",
  "expert": "${BEST_EXPERT}",
  "expert_name": "${EXPERT_NAME}",
  "init_at": "${TIMESTAMP}"
}
STATE_EOF
  echo "  ✓ state.json created with performer role"
else
  # Atomic jq update (跟 mode-set.sh 1:1: . + {k:v} via tmp file + mv)
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
  TMP_STATE="${STATE_FILE}.tmp.$$"
  jq --arg tid "${TICKET_ID}" \
     --arg exp "${BEST_EXPERT}" \
     --arg ename "${EXPERT_NAME}" \
     --arg iid "${TICKET_ID}_$$" \
     --arg actor "${ACTOR}" \
     --arg ts "${TIMESTAMP}" \
     --arg role "performer" \
     '. + {role: $role, ticket_id: $tid, expert: $exp, expert_name: $ename, instance_id: $iid, actor: $actor, init_at: $ts}' \
     "${STATE_FILE}" > "${TMP_STATE}" && mv "${TMP_STATE}" "${STATE_FILE}"
  echo "  ✓ state.json updated (role=performer, ticket=${TICKET_ID}, expert=${BEST_EXPERT})"
fi

# Performer.lock conflict detection (跟 mode-set.sh mode_lock 1:1)
if [ -f "${LOCK_FILE}" ]; then
  LOCK_PID=$(cat "${LOCK_FILE}" 2>/dev/null || echo "")
  if [ -n "${LOCK_PID}" ] && kill -0 "${LOCK_PID}" 2>/dev/null; then
    echo "  [WARN] Performer locked by PID ${LOCK_PID}, overwriting"
  fi
fi
echo "$$" > "${LOCK_FILE}"
echo "  ✓ performer.lock written (PID=$$)"
echo ""

# ── 6. Worktree prep check ────────────────────────────────────────────────
echo "── Step 5/5: Worktree prep check ──"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
IS_WORKTREE="false"
GIT_DIR_PATH=$(git rev-parse --git-dir 2>/dev/null || echo "")
# Detect worktree via .git/worktrees/<name> (canonical signal, works in main repo too)
if echo "${GIT_DIR_PATH}" | grep -q "/worktrees/"; then
  IS_WORKTREE="true"
fi

# Check if branch matches ticket pattern (feature/<ticket-id>-<serial>)
TICKET_ID_LOWER=$(echo "${TICKET_ID}" | tr '[:upper:]' '[:lower:]')
EXPECTED_BRANCH="feature/${TICKET_ID_LOWER}"
if echo "${CURRENT_BRANCH}" | grep -qiE "^feature/${TICKET_ID_LOWER}(-serial[0-9]+)?$"; then
  echo "  ✓ Branch matches ticket: ${CURRENT_BRANCH}"
elif [ "${IS_WORKTREE}" = "true" ]; then
  echo "  ⚠ In worktree (${CURRENT_BRANCH}) but branch name doesn't match ticket pattern (${EXPECTED_BRANCH}*)"
else
  echo "  ⚠ Not in a worktree — recommend: git worktree add .claude/worktrees/${TICKET_ID_LOWER}-serialN feature/${TICKET_ID_LOWER}-serialN"
fi

# ── 7. Write init report (stable location) ────────────────────────────────
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
mkdir -p "${STATE_DIR}"
TMP_REPORT="${INIT_REPORT}.tmp.$$"
jq -n \
  --arg tid "${TICKET_ID}" \
  --arg ttitle "${TICKET_TITLE}" \
  --arg ttype "${TICKET_TYPE}" \
  --arg kw "${KEYWORDS}" \
  --arg exp "${BEST_EXPERT}" \
  --arg ename "${EXPERT_NAME}" \
  --argjson escore "${BEST_SCORE}" \
  --arg iid "${TICKET_ID}_$$" \
  --arg branch "${CURRENT_BRANCH}" \
  --argjson wt "${IS_WORKTREE}" \
  --arg ts "${TIMESTAMP}" \
  '{
    ticket_id: $tid,
    ticket_title: $ttitle,
    ticket_type: $ttype,
    keywords_detected: $kw,
    matched_expert: $exp,
    expert_name: $ename,
    expert_score: $escore,
    performer_id: $iid,
    branch: $branch,
    is_worktree: $wt,
    initialized_at: $ts
  }' > "${TMP_REPORT}" && mv "${TMP_REPORT}" "${INIT_REPORT}"
echo "  ✓ Init report: ${INIT_REPORT}"
echo ""

# ── 8. Summary ─────────────────────────────────────────────────────────────
echo "╔════════════════════════════════════════════════════╗"
echo "║  INIT COMPLETE                                     ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  Ticket    ▸ ${TICKET_ID}                          ║"
echo "║  Expert    ▸ ${BEST_EXPERT} (score: ${BEST_SCORE}) ║"
echo "║  Profile   ▸ ${EXPERT_NAME}                        ║"
echo "║  Branch    ▸ ${CURRENT_BRANCH}                     ║"
echo "║  Worktree  ▸ ${IS_WORKTREE}                        ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  NEXT: claim ticket → deliver → performer-complete ║"
echo "╚════════════════════════════════════════════════════╝"
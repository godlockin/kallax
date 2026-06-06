#!/usr/bin/env bash
# KALLAX Performer Init Protocol — EPIC-015-H
# Pre-claim: analyze ticket → match expert → initialize performer role.
# Usage: performer-init.sh <ticket-id>
set -euo pipefail

TICKET_ID="${1:?Usage: performer-init.sh <ticket-id>}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TICKET_FILE="${REPO_ROOT}/jira/tickets/${TICKET_ID}/ticket.json"
EXPERTS_DIR="${REPO_ROOT}/.claude/skills/kallax/experts"
SKILLS_DIR="${REPO_ROOT}/.claude/skills/kallax/skills"

if [ ! -f "${TICKET_FILE}" ]; then
  echo "[FAIL] Ticket not found: ${TICKET_FILE}"
  exit 1
fi

# ── 1. Read ticket metadata ────────────────────────────────────────────────
TICKET_TITLE=$(jq -r '.title // "unknown"' "${TICKET_FILE}" 2>/dev/null)
TICKET_TYPE=$(jq -r '.type // "feature"' "${TICKET_FILE}" 2>/dev/null)
TICKET_STATUS=$(jq -r '.status // "backlog"' "${TICKET_FILE}" 2>/dev/null)
TICKET_AC=$(jq -r '.acceptance_criteria[]? // "N/A"' "${TICKET_FILE}" 2>/dev/null | tr '\n' ';')

echo "╔════════════════════════════════════════════════════╗"
echo "║  KALLAX Performer Init Protocol             v1.0.0 ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  TICKET  ▸ ${TICKET_ID}                            ║"
echo "║  TITLE   ▸ ${TICKET_TITLE}                         ║"
echo "║  TYPE    ▸ ${TICKET_TYPE}                          ║"
echo "║  STATUS  ▸ ${TICKET_STATUS}                        ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# ── 2. Extract capability keywords from ticket ──────────────────────────────
KEYWORDS=""
# From title
KEYWORDS="${KEYWORDS} $(echo "${TICKET_TITLE}" | tr ' ' '\n' | grep -iE 'shell|bash|script|hook|heartbeat|daemon|node|rust|api|cli|db|sql|frontend|ui|test|doc|schema|validate|init|config|deploy|ci|cd|docker|k8s' | tr '\n' ' ')"

# From AC
KEYWORDS="${KEYWORDS} $(echo "${TICKET_AC}" | tr ' ' '\n' | grep -iE 'shell|bash|script|hook|heartbeat|daemon|node|rust|api|cli|db|sql|frontend|ui|test|doc|schema|validate|init|config|deploy|ci|cd|docker|k8s' | tr '\n' ' ')"

# Deduplicate
KEYWORDS=$(echo "${KEYWORDS}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

echo "── Step 1/4: Extract requirements ──"
echo "  Keywords: ${KEYWORDS:-none detected}"
echo ""

# ── 3. Match expert profiles ────────────────────────────────────────────────
echo "── Step 2/4: Match expert profiles ──"

declare -A EXPERT_SCORES
BEST_EXPERT=""
BEST_SCORE=0

# Keyword-to-expert mapping
match_expert() {
  local kw="$1"
  case "$(echo "${kw}" | tr '[:upper:]' '[:lower:]')" in
    shell|bash|script|hook|daemon|init|config)
      echo "devops infra sre" ;;
    heartbeat|monitor|cron|stale|check)
      echo "devops monitoring" ;;
    node|api|cli|typescript|ts)
      echo "backend" ;;
    rust|performance)
      echo "backend performance" ;;
    db|sql|sqlite|schema)
      echo "backend database" ;;
    frontend|ui|dashboard|sse|web)
      echo "frontend ux visual" ;;
    test|validate|bash|ci)
      echo "devops security" ;;
    doc|schema|template)
      echo "documentation knowledge-mgmt" ;;
    docker|k8s|deploy|ci-cd)
      echo "devops infra" ;;
    *)
      echo "" ;;
  esac
}

for kw in ${KEYWORDS}; do
  EXPERTS=$(match_expert "${kw}")
  for exp in ${EXPERTS}; do
    EXPERT_SCORES["${exp}"]=$((${EXPERT_SCORES["${exp}"]:-0} + 1))
  done
done

# Find best expert(s)
echo "  Expert matches:"
for exp in "${!EXPERT_SCORES[@]}"; do
  score=${EXPERT_SCORES["${exp}"]}
  echo "    ${exp}: score=${score}"
  if [ "${score}" -gt "${BEST_SCORE}" ]; then
    BEST_SCORE="${score}"
    BEST_EXPERT="${exp}"
  fi
done

if [ -z "${BEST_EXPERT}" ]; then
  BEST_EXPERT="backend"  # default fallback
  echo "  ⚠ No keyword match, defaulting to: ${BEST_EXPERT}"
fi
echo ""

# ── 4. Load expert profile ──────────────────────────────────────────────────
echo "── Step 3/4: Load expert profile ──"

EXPERT_DIR="${EXPERTS_DIR}/default"
EXPERT_FILE=""

# Search for expert config
for dir in "${EXPERTS_DIR}/default" "${EXPERTS_DIR}/extended/tech" "${EXPERTS_DIR}/extended/ops"; do
  if [ -d "${dir}" ]; then
    FOUND=$(find "${dir}" -maxdepth 1 -name "*${BEST_EXPERT}*" 2>/dev/null | head -1)
    if [ -n "${FOUND}" ]; then
      EXPERT_FILE="${FOUND}"
      break
    fi
  fi
done

if [ -n "${EXPERT_FILE}" ]; then
  echo "  ✓ Expert profile: ${EXPERT_FILE}"
  EXPERT_NAME=$(basename "${EXPERT_FILE}" | sed 's/\.[^.]*$//')
else
  echo "  ⚠ Expert profile not found, using generic"
  EXPERT_NAME="${BEST_EXPERT}"
fi
echo ""

# ── 5. Initialize and report ───────────────────────────────────────────────
echo "── Step 4/4: Initialize performer ──"

INIT_REPORT="${REPO_ROOT}/.kallax/instances/$(hostname)_$$/init_report.json"
mkdir -p "$(dirname "${INIT_REPORT}")"

cat > "${INIT_REPORT}" << REPORT
{
  "ticket_id": "${TICKET_ID}",
  "ticket_title": "${TICKET_TITLE}",
  "ticket_type": "${TICKET_TYPE}",
  "keywords_detected": "${KEYWORDS}",
  "matched_expert": "${BEST_EXPERT}",
  "expert_score": ${BEST_SCORE},
  "expert_name": "${EXPERT_NAME}",
  "recommended_skills": ["$(echo "${KEYWORDS}" | tr ' ' ',' | sed 's/,$//' | sed 's/,/", "/g')"],
  "initialized_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
REPORT

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  INIT COMPLETE                                     ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  Ticket  ▸ ${TICKET_ID}                            ║"
echo "║  Expert  ▸ ${BEST_EXPERT} (score: ${BEST_SCORE})   ║"
echo "║  Profile ▸ ${EXPERT_NAME}                          ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  NEXT: claim ticket → create worktree → deliver    ║"
echo "╚════════════════════════════════════════════════════╝"

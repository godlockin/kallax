#!/usr/bin/env bash
# KALLAX Performer Complete Protocol — EPIC-015-G
# Governance layer: enforces delivery workflow.
# Usage: performer-complete.sh <ticket-id>
set -euo pipefail

TICKET_ID="${1:?Usage: performer-complete.sh <ticket-id>}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TICKET_DIR="${REPO_ROOT}/jira/tickets/${TICKET_ID}"
TICKET_FILE="${TICKET_DIR}/ticket.json"
INBOX_DIR="${REPO_ROOT}/.kallax/queue/inbox/conductor_main"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
INSTANCE_ID="${KALLAX_INSTANCE_ID:-$(hostname)_$$}"
BRANCH="$(git branch --show-current 2>/dev/null || echo 'unknown')"

echo "╔════════════════════════════════════════════════════╗"
echo "║  KALLAX Performer Complete Protocol         v1.0.0 ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  TICKET  ▸ ${TICKET_ID}                            ║"
echo "║  BRANCH  ▸ ${BRANCH}                               ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Check ticket exists ───────────────────────────────────────────
if [ ! -f "${TICKET_FILE}" ]; then
  echo "[FAIL] Ticket file not found: ${TICKET_FILE}"
  exit 1
fi

TICKET_STATUS=$(jq -r '.status // "unknown"' "${TICKET_FILE}" 2>/dev/null || echo "unknown")
if [ "${TICKET_STATUS}" != "in_progress" ]; then
  echo "[WARN] Ticket status is '${TICKET_STATUS}', expected 'in_progress'"
fi

# ── Step 2: Detect and commit changes ─────────────────────────────────────
echo "── Step 1/5: Check uncommitted changes ──"
CHANGED=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
if [ "${CHANGED}" -gt 0 ]; then
  echo "  ${CHANGED} file(s) changed:"
  git status --short | head -10
  echo ""
  
  # Auto-commit with ticket reference
  COMMIT_MSG="feat(${TICKET_ID}): delivery — $(date +%Y-%m-%d)"
  git add -A
  git commit -m "${COMMIT_MSG}" 2>&1 || {
    echo "[FAIL] Commit failed"
    exit 1
  }
  echo "  ✓ Committed: ${COMMIT_MSG}"
else
  echo "  ✓ Working tree clean"
fi

# ── Step 3: Self-test ─────────────────────────────────────────────────────
echo ""
echo "── Step 2/5: Self-test ──"
SELF_TEST_RESULT="pass"
SELF_TEST_OUTPUT=""

# Shell script check
SH_FILES=$(git diff --name-only HEAD~1 2>/dev/null | grep '\.sh$' || true)
if [ -n "${SH_FILES}" ]; then
  echo "  Shell scripts detected, running bash -n..."
  while IFS= read -r f; do
    if ! bash -n "${REPO_ROOT}/${f}" 2>/dev/null; then
      SELF_TEST_RESULT="fail"
      SELF_TEST_OUTPUT="${SELF_TEST_OUTPUT}bash -n FAIL: ${f}\n"
    else
      SELF_TEST_OUTPUT="${SELF_TEST_OUTPUT}bash -n PASS: ${f}\n"
    fi
  done <<< "${SH_FILES}"
fi

# TypeScript check
TS_FILES=$(git diff --name-only HEAD~1 2>/dev/null | grep '\.ts$' || true)
if [ -n "${TS_FILES}" ]; then
  echo "  TypeScript files detected, running tsc --noEmit..."
  if (cd "${REPO_ROOT}/node" && npx tsc --noEmit 2>&1); then
    SELF_TEST_OUTPUT="${SELF_TEST_OUTPUT}tsc: PASS\n"
  else
    SELF_TEST_RESULT="fail"
    SELF_TEST_OUTPUT="${SELF_TEST_OUTPUT}tsc: FAIL\n"
  fi
fi

echo "  Self-test result: ${SELF_TEST_RESULT}"

# ── Step 4: Update ticket status ──────────────────────────────────────────
echo ""
echo "── Step 3/5: Update ticket ──"
if command -v jq &>/dev/null; then
  jq ".status = \"done\" | .completed_at = \"${NOW}\" | .delivery_branch = \"${BRANCH}\"" \
    "${TICKET_FILE}" > "${TICKET_FILE}.tmp" && mv "${TICKET_FILE}.tmp" "${TICKET_FILE}"
  echo "  ✓ ticket.json: status → done"
else
  echo "  [WARN] jq not available, ticket status not updated"
fi

# ── Step 5: Write review request to conductor inbox ────────────────────────
echo ""
echo "── Step 4/5: Notify conductor ──"
mkdir -p "${INBOX_DIR}"
REVIEW_FILE="${INBOX_DIR}/review_${TICKET_ID}_$(date +%s).json"

CHANGED_FILES=$(git diff --name-only HEAD~1 2>/dev/null | tr '\n' ',' | sed 's/,$//')

cat > "${REVIEW_FILE}" << REVIEW
{
  "type": "review_request",
  "ticket_id": "${TICKET_ID}",
  "performer": "${INSTANCE_ID}",
  "branch": "${BRANCH}",
  "submitted_at": "${NOW}",
  "self_test": "${SELF_TEST_RESULT}",
  "self_test_detail": "${SELF_TEST_OUTPUT}",
  "changed_files": [${CHANGED_FILES:+$(echo "${CHANGED_FILES}" | sed 's/,/\",\"/g' | sed 's/^/\"/;s/$/\"/')}],
  "message": "Performer delivery complete. Requesting conductor review."
}
REVIEW
echo "  ✓ Review request written: ${REVIEW_FILE}"

# ── Step 6: Summary ───────────────────────────────────────────────────────
echo ""
echo "── Step 5/5: Delivery Summary ──"
echo "╔════════════════════════════════════════════════════╗"
echo "║  DELIVERY COMPLETE                                 ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  Ticket    ▸ ${TICKET_ID}                          ║"
echo "║  Branch    ▸ ${BRANCH}                             ║"
echo "║  Self-test ▸ ${SELF_TEST_RESULT}                   ║"
echo "║  Review    ▸ sent to conductor inbox               ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  NEXT: Wait for conductor review & merge           ║"
echo "╚════════════════════════════════════════════════════╝"

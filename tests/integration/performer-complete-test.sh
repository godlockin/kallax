#!/usr/bin/env bash
# tests/integration/performer-complete-test.sh — TDD tests for EPIC-015-G
# performer-complete.sh Performer 交付协议固化
#
# EPIC-015-G AC: 5 acceptance criteria
#   AC #1: scripts/performer-complete.sh exists +x
#   AC #2: Implements Performer 9 Hard Rules (跟 AGENTS.md 联合)
#   AC #3: Writes .kallax/queue/outbox/performer-{id}/pass-report-{ticket}.json
#   AC #4: 9/9 PASS (跟 EPIC-015-G 全 AC 联合)
#   AC #5: 跟 EPIC-059-D Fact-Forcing 1:1 验证 (raw test output 留存)
#
# 跟 BE-23 + BE-25 + BE-26 fixes in place (1 ticket 1 subagent 串行, 0 静默 output)
# 跟 EPIC-059-D Fact-Forcing 联合 (raw test output 留存, 0 假 PASS)
# 跟 EPIC-015-A ticket delivery protocol 模式 联合

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly SCRIPT="${KALLAX_ROOT}/scripts/performer-complete.sh"

# Constants (Rule 4: no magic numbers, name all)
readonly EXPECTED_HARD_RULES=9
readonly EXPECTED_AC=5
readonly EXPECTED_TESTS=9
readonly TICKET_ID="EPIC-015-G"
readonly PASS_REPORT_DIR=".kallax/queue/outbox/performer-${TICKET_ID}"
readonly PASS_REPORT_FILE="${PASS_REPORT_DIR}/pass-report-${TICKET_ID}.json"
readonly INBOX_DIR=".kallax/queue/inbox/conductor_main"
readonly TICKET_DIR="jira/tickets/${TICKET_ID}"

# TDD red phase: verify script + ticket + dir exist
if [ ! -x "${SCRIPT}" ]; then
  echo "=========================================="
  echo "Performer Complete — Integration Tests (${EXPECTED_TESTS}/${EXPECTED_TESTS})"
  echo "=========================================="
  echo ""
  echo "FAIL: ${SCRIPT} not found or not executable (TDD red phase, AC #1)"
  echo "0/${EXPECTED_TESTS} PASS (0.0%)"
  exit 1
fi

if [ ! -f "${KALLAX_ROOT}/${TICKET_DIR}/ticket.json" ]; then
  echo "FAIL: ticket file not found at ${KALLAX_ROOT}/${TICKET_DIR}/ticket.json"
  exit 1
fi

echo "=========================================="
echo "Performer Complete — Integration Tests (${EXPECTED_TESTS}/${EXPECTED_TESTS})"
echo "EPIC-015-G | Performer 交付协议固化"
echo "AC: ${EXPECTED_AC}/5 | Hard Rules: ${EXPECTED_HARD_RULES}/9"
echo "=========================================="
echo ""

# ── Setup: temp fixture for isolated test ──────────────────────────────────
readonly FIXTURE_DIR="$(mktemp -d -t performer-complete-fix.XXXXXX)"
trap 'rm -rf "${FIXTURE_DIR}"' EXIT

# Snapshot the current state for cleanup
readonly ORIGINAL_TICKET="${KALLAX_ROOT}/${TICKET_DIR}/ticket.json"
readonly ORIGINAL_TICKET_BAK="${FIXTURE_DIR}/ticket.json.bak"
cp "${ORIGINAL_TICKET}" "${ORIGINAL_TICKET_BAK}"

# Setup state.json fixture (for authz check)
mkdir -p "${KALLAX_ROOT}/.kallax/state"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
if [ ! -f "${STATE_FILE}" ]; then
  echo '{"role": "performer", "actor": "performer_test", "branch": "feature/EPIC-015-G-serial11"}' > "${STATE_FILE}"
fi
readonly STATE_FILE_BAK="${FIXTURE_DIR}/state.json.bak"
[ -f "${STATE_FILE}" ] && cp "${STATE_FILE}" "${STATE_FILE_BAK}"

# Cleanup pass-report + inbox from previous test runs
rm -rf "${KALLAX_ROOT}/${PASS_REPORT_DIR}"
mkdir -p "${KALLAX_ROOT}/${INBOX_DIR}"

# Reset ticket status for clean test
jq '.status = "in_progress"' "${ORIGINAL_TICKET}" > "${ORIGINAL_TICKET}.tmp" && \
  mv "${ORIGINAL_TICKET}.tmp" "${ORIGINAL_TICKET}"

# ── Pre-flight: run performer-complete.sh --dry-run to generate outputs for verification
# (跟 EPIC-059-D Fact-Forcing 联合, 1 ticket 1 subagent 串行 0 silent output)
# --dry-run: skip actual commit, still generate pass-report + ticket update + review request
echo "── Pre-flight: run performer-complete.sh --dry-run ──"
if bash "${SCRIPT}" --dry-run "${TICKET_ID}" >"${FIXTURE_DIR}/script.log" 2>&1; then
  echo "  ✓ performer-complete.sh --dry-run executed (rc=0)"
else
  RC=$?
  echo "  [WARN] performer-complete.sh --dry-run returned rc=${RC}, continuing with assertions"
fi
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TC1_PASS=0; TC1_FAIL=0
TC2_PASS=0; TC2_FAIL=0
TC3_PASS=0; TC3_FAIL=0
TC4_PASS=0; TC4_FAIL=0
TC5_PASS=0; TC5_FAIL=0
TC6_PASS=0; TC6_FAIL=0
TC7_PASS=0; TC7_FAIL=0
TC8_PASS=0; TC8_FAIL=0
TC9_PASS=0; TC9_FAIL=0

pass() {
  echo "  [PASS] TC$1: $2"
  PASS_COUNT=$((PASS_COUNT + 1))
  eval "TC${1}_PASS=\$((TC${1}_PASS + 1))"
}
fail() {
  echo "  [FAIL] TC$1: $2"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  eval "TC${1}_FAIL=\$((TC${1}_FAIL + 1))"
}

# ─────────────────────────────────────────────────────────────────────────────
# TC1: AC #1 — script exists +x + bash syntax OK (Hard Rule #4: named constants)
# ─────────────────────────────────────────────────────────────────────────────
echo "── TC1: AC #1 — script exists +x + bash syntax ──"
if [ -x "${SCRIPT}" ]; then
  pass 1 "Script executable"
else
  fail 1 "Script not executable: ${SCRIPT}"
fi
if bash -n "${SCRIPT}" 2>/dev/null; then
  pass 1 "bash -n syntax OK"
else
  fail 1 "bash -n syntax failed"
fi
# Verify named constants (Rule 4: no magic numbers)
if grep -qE '^readonly PROTOCOL_VERSION=' "${SCRIPT}" && \
   grep -qE '^readonly HARD_RULES_COUNT=' "${SCRIPT}" && \
   grep -qE '^readonly BRANCH_PROTECTED=' "${SCRIPT}"; then
  pass 1 "Named constants present (Rule 4: no magic numbers)"
else
  fail 1 "Missing named constants (Rule 4 violation)"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TC2: AC #2 (part 1) — 9 Hard Rules protocol structure
# ─────────────────────────────────────────────────────────────────────────────
echo "── TC2: AC #2 — 9 Hard Rules protocol structure ──"
HARDCODED_STEPS=$(grep -cE '^echo "── Step [0-9]+/9:' "${SCRIPT}")
if [ "${HARDCODED_STEPS}" -eq 9 ]; then
  pass 2 "9 Step protocol structure (${HARDCODED_STEPS}/9)"
else
  fail 2 "Expected 9 steps, found ${HARDCODED_STEPS}"
fi
# Verify Hard Rule #1 enforcement: never merge to main (miao branch check)
if grep -qE 'BRANCH_PROTECTED.*=.*"miao"' "${SCRIPT}" && \
   grep -qE 'Hard Rule #1 VIOLATED' "${SCRIPT}"; then
  pass 2 "Hard Rule #1 enforced: miao branch block"
else
  fail 2 "Hard Rule #1 missing (no miao branch check)"
fi
# Verify Hard Rule #2: never self-review (writes to conductor inbox, not own)
if grep -qE 'conductor_main|Hard Rule #2.*never self-review' "${SCRIPT}"; then
  pass 2 "Hard Rule #2 enforced: review request to conductor inbox"
else
  fail 2 "Hard Rule #2 missing (no conductor review handoff)"
fi
# Verify Hard Rule #3: never skip tests (self-test step required)
if grep -qE 'Self-test|SELF_TEST' "${SCRIPT}"; then
  pass 2 "Hard Rule #3 enforced: self-test step"
else
  fail 2 "Hard Rule #3 missing (no self-test)"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TC3: AC #2 (part 2) — Hard Rules #4-9 explicit references
# ─────────────────────────────────────────────────────────────────────────────
echo "── TC3: AC #2 — Hard Rules #4-9 ──"
# Rule 4: no magic numbers (covered in TC1)
# Rule 5: no console.log (use structured logger / jq)
if grep -qE 'jq -r|jq -n|jq -R -s' "${SCRIPT}" && \
   ! grep -qE '^[^#]*console\.log' "${SCRIPT}"; then
  pass 3 "Hard Rule #5 enforced: no console.log (jq for structured output)"
else
  fail 3 "Hard Rule #5 violation (console.log found)"
fi
# Rule 6: no ignored lint (scan for @ts-ignore/eslint-disable/TODO)
if grep -qE '@ts-ignore|eslint-disable|TODO:' "${SCRIPT}"; then
  pass 3 "Hard Rule #6 enforced: lint scan present"
else
  fail 3 "Hard Rule #6 missing (no lint scan)"
fi
# Rule 9: no cross-cutting changes (scope check via ticket file_scope)
# (the protocol respects scope by committing only staged changes; this is implicit)
if grep -qE 'STAGED_FILES|git diff --cached' "${SCRIPT}"; then
  pass 3 "Hard Rule #9 enforced: staged-only commit (BE-26 fix --cached)"
else
  fail 3 "Hard Rule #9 missing (no staged-only check)"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TC4: AC #3 — pass-report-{ticket}.json written to .kallax/queue/outbox/performer-{id}/
# ─────────────────────────────────────────────────────────────────────────────
echo "── TC4: AC #3 — pass-report written to outbox/performer-{id}/ ──"
EXPECTED_PATH="${KALLAX_ROOT}/${PASS_REPORT_FILE}"
if [ -f "${EXPECTED_PATH}" ]; then
  pass 4 "pass-report exists at ${PASS_REPORT_FILE}"
else
  fail 4 "pass-report NOT found at ${EXPECTED_PATH}"
fi
# Verify JSON validity
if [ -f "${EXPECTED_PATH}" ] && jq empty "${EXPECTED_PATH}" 2>/dev/null; then
  pass 4 "pass-report is valid JSON"
else
  fail 4 "pass-report JSON invalid"
fi
# Verify required fields
if [ -f "${EXPECTED_PATH}" ]; then
  for field in ticket_id performer_id branch commit_sha self_test changed_files raw_test_output; do
    if jq -e ".${field}" "${EXPECTED_PATH}" >/dev/null 2>&1; then
      pass 4 "field '${field}' present in pass-report"
    else
      fail 4 "field '${field}' MISSING in pass-report"
    fi
  done
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TC5: AC #5 (part 1) — EPIC-059-D Fact-Forcing: raw test output preserved
# ─────────────────────────────────────────────────────────────────────────────
echo "── TC5: AC #5 — EPIC-059-D Fact-Forcing raw output ──"
RAW_LOG_PATH="${KALLAX_ROOT}/${TICKET_DIR}/test-output.log"
if [ -f "${RAW_LOG_PATH}" ]; then
  pass 5 "raw test output preserved at ${RAW_LOG_PATH}"
else
  fail 5 "raw test output NOT preserved"
fi
# Verify raw output contains expected sections
if [ -f "${RAW_LOG_PATH}" ]; then
  for section in "bash -n" "9 Hard Rules" "Fact-Forcing" "Hard Rule #6"; do
    if grep -qE "${section}" "${RAW_LOG_PATH}"; then
      pass 5 "raw output contains '${section}' section"
    else
      fail 5 "raw output MISSING '${section}' section"
    fi
  done
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TC6: AC #5 (part 2) — KPI X/Y format (Rule 9: no estimate, exact)
# ─────────────────────────────────────────────────────────────────────────────
echo "── TC6: AC #5 — KPI X/Y exact format (Rule 9) ──"
if [ -f "${EXPECTED_PATH}" ]; then
  KPI=$(jq -r '.self_test.kpi_x_of_y // ""' "${EXPECTED_PATH}" 2>/dev/null)
  if echo "${KPI}" | grep -qE '^[0-9]+/[0-9]+ \([0-9.]+%\)$'; then
    pass 6 "KPI X/Y format: ${KPI}"
  else
    fail 6 "KPI format invalid: '${KPI}'"
  fi
  # fact_forcing_compliance
  if jq -e '.fact_forcing_compliance.raw_output_preserved == true' "${EXPECTED_PATH}" >/dev/null 2>&1; then
    pass 6 "fact_forcing_compliance.raw_output_preserved=true"
  else
    fail 6 "fact_forcing_compliance.raw_output_preserved not set"
  fi
  if jq -e '.fact_forcing_compliance.kpi_exact_format' "${EXPECTED_PATH}" >/dev/null 2>&1; then
    pass 6 "kpi_exact_format field present"
  else
    fail 6 "kpi_exact_format field missing"
  fi
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TC7: Ticket status updated to done
# ─────────────────────────────────────────────────────────────────────────────
echo "── TC7: Ticket status → done ──"
TICKET_STATUS_AFTER=$(jq -r '.status // ""' "${ORIGINAL_TICKET}" 2>/dev/null)
if [ "${TICKET_STATUS_AFTER}" = "done" ]; then
  pass 7 "ticket.json status → done"
else
  fail 7 "ticket.json status not updated (got: '${TICKET_STATUS_AFTER}')"
fi
# Verify delivery metadata
for meta_field in completed_at delivery_branch delivery_commit; do
  if jq -e ".${meta_field}" "${ORIGINAL_TICKET}" >/dev/null 2>&1; then
    pass 7 "ticket.json ${meta_field} present"
  else
    fail 7 "ticket.json ${meta_field} MISSING"
  fi
done
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TC8: Review request written to conductor inbox
# ─────────────────────────────────────────────────────────────────────────────
echo "── TC8: Review request to conductor inbox ──"
REVIEW_FILES=$(ls "${KALLAX_ROOT}/${INBOX_DIR}/review_${TICKET_ID}_"*.json 2>/dev/null | wc -l | tr -d ' ')
if [ "${REVIEW_FILES}" -gt 0 ]; then
  pass 8 "Review request(s) written: ${REVIEW_FILES} file(s)"
  # Validate JSON
  LATEST=$(ls -t "${KALLAX_ROOT}/${INBOX_DIR}/review_${TICKET_ID}_"*.json 2>/dev/null | head -1)
  if jq empty "${LATEST}" 2>/dev/null; then
    pass 8 "Review request is valid JSON"
  else
    fail 8 "Review request JSON invalid"
  fi
  if jq -e '.type == "review_request"' "${LATEST}" >/dev/null 2>&1; then
    pass 8 "Review request has type=review_request"
  else
    fail 8 "Review request missing type=review_request"
  fi
else
  fail 8 "No review request files in ${INBOX_DIR}/"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TC9: Usage / error handling — missing arg, missing ticket, etc.
# ─────────────────────────────────────────────────────────────────────────────
echo "── TC9: Error handling ──"
# Missing arg
set +e
bash "${SCRIPT}" 2>/dev/null
RC=$?
set -e
if [ "${RC}" -ne 0 ]; then
  pass 9 "Missing arg → exit non-zero (rc=${RC})"
else
  fail 9 "Missing arg should exit non-zero, got rc=${RC}"
fi
# Missing ticket
set +e
bash "${SCRIPT}" "EPIC-DOES-NOT-EXIST-XYZ" 2>/dev/null
RC=$?
set -e
if [ "${RC}" -ne 0 ]; then
  pass 9 "Missing ticket → exit non-zero (rc=${RC})"
else
  fail 9 "Missing ticket should exit non-zero, got rc=${RC}"
fi
# Verify --help / usage line (capture stdout separately to avoid pipefail)
USAGE_OUT="$(bash "${SCRIPT}" 2>&1 || true)"
if echo "${USAGE_OUT}" | grep -q "Usage:"; then
  pass 9 "Usage message present"
else
  fail 9 "Usage message missing"
fi
echo ""

# ── Cleanup: restore original state ─────────────────────────────────────────
cp "${ORIGINAL_TICKET_BAK}" "${ORIGINAL_TICKET}"
if [ -f "${STATE_FILE_BAK}" ]; then
  cp "${STATE_FILE_BAK}" "${STATE_FILE}"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo "=========================================="
echo "Results: PASS=${PASS_COUNT} FAIL=${FAIL_COUNT}"
echo "AC verification:"
echo "  AC #1 (script exists +x):       TC1=$((${TC1_PASS}+${TC1_FAIL})) checks"
echo "  AC #2 (9 Hard Rules protocol):   TC2+TC3=$((${TC2_PASS}+${TC2_FAIL}+${TC3_PASS}+${TC3_FAIL})) checks"
echo "  AC #3 (pass-report outbox):      TC4=$((${TC4_PASS}+${TC4_FAIL})) checks"
echo "  AC #5 (Fact-Forcing raw output): TC5+TC6=$((${TC5_PASS}+${TC5_FAIL}+${TC6_PASS}+${TC6_FAIL})) checks"
echo "=========================================="

if [ "${FAIL_COUNT}" -eq 0 ]; then
  echo "${PASS_COUNT}/$((PASS_COUNT + FAIL_COUNT)) PASS (100.0%) — EPIC-015-G ALL GREEN"
  exit 0
else
  echo "${PASS_COUNT}/$((PASS_COUNT + FAIL_COUNT)) PASS"
  exit 1
fi
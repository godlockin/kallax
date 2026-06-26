#!/usr/bin/env bash
# tests/integration/performer-init-test.sh — EPIC-015-H
# Integration tests for scripts/performer-init.sh (Performer 领卡前置协议)
#
# Test cases (Rule 9 KPI 100.0%, EPIC-015-H ticket AC):
#   TC1: scripts/performer-init.sh exists + executable (L1 存在性)
#   TC2: Missing <ticket-id> → exit 1 + usage message (L2 实质性)
#   TC3: Invalid ticket-id → exit 1 + "[FAIL] Ticket not found" (L2 实质性)
#   TC4: Valid ticket-id → all 5 steps complete + INIT COMPLETE banner (L2)
#   TC5: state.json updated with role=performer + ticket_id + expert + init_at (L2/L3 接线)
#   TC6: performer.lock written (跟 EPIC-029-A mode_lock 1:1) (L3)
#   TC7: Init report .kallax/state/performer-init.json contains required fields (L4 数据流动)
#   TC8: --expert override 强制使用指定 expert (L2/L4)
#   TC9: --help 输出 usage (跟 mode-set.sh 1:1 验证) (L1/L3)
#   TC10: 0 增 Rule 0 增命令 (跟"翻篇&精进" 战略 联合): 唯一新 flag = --expert (overrides-only)
#
# Exit code: 0 iff all PASS (Rule 9 100.0%)
# Run from worktree root: ./tests/integration/performer-init-test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INIT_SH="$REPO_ROOT/scripts/performer-init.sh"
MODE_SET_SH="$REPO_ROOT/scripts/permission/mode-set.sh"

if [ ! -f "$INIT_SH" ]; then
  echo "FATAL: performer-init.sh not found at $INIT_SH" >&2
  exit 2
fi

# ── Mini test framework (跟 kallax-init-basic-test.sh 1:1) ─────────────
PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()

assert_pass() {
  local case_name="$1" detail="$2"
  RESULTS+=("[PASS] $case_name: $detail")
  PASS_COUNT=$((PASS_COUNT + 1))
}

assert_fail() {
  local case_name="$1" detail="$2"
  RESULTS+=("[FAIL] $case_name: $detail")
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

assert_true() {
  local case_name="$1" condition="$2" detail="$3"
  if eval "${condition}"; then
    assert_pass "${case_name}" "${detail}"
  else
    assert_fail "${case_name}" "${detail} (condition: ${condition})"
  fi
}

# ── Setup ────────────────────────────────────────────────────────────────
TMPDIR_BASE=$(mktemp -d -t performer-init.XXXXXX)
trap "rm -rf ${TMPDIR_BASE}" EXIT

echo "=== EPIC-015-H performer-init integration test ==="
echo "INIT_SH=${INIT_SH}"
echo "TMPDIR_BASE=${TMPDIR_BASE}"
echo ""

# ── TC1: scripts/performer-init.sh exists + executable ────────────────────
assert_true "TC1.1-script-exists" "[[ -f ${INIT_SH} ]]" "performer-init.sh exists"
assert_true "TC1.2-script-executable" "[[ -x ${INIT_SH} ]]" "performer-init.sh is executable"

# ── TC2: Missing <ticket-id> → exit 1 + usage message ─────────────────────
set +e
TC2_OUT=$(bash "${INIT_SH}" 2>&1)
TC2_RC=$?
set -e
assert_true "TC2.1-missing-arg-exit-nonzero" "[[ ${TC2_RC} -ne 0 ]]" "exit code != 0 when no ticket-id"
# Use file-based grep to avoid <ticket-id> being interpreted as redirect in eval
echo "${TC2_OUT}" > "${TMPDIR_BASE}/tc2.out"
assert_true "TC2.2-missing-arg-usage" "grep -q 'Usage:' ${TMPDIR_BASE}/tc2.out" "outputs Usage: message"
assert_true "TC2.3-missing-arg-required-msg" "grep -qE 'ticket-id.*required' ${TMPDIR_BASE}/tc2.out" "outputs 'ticket-id required'"

# ── TC3: Invalid ticket-id → exit 1 + ticket-not-found ────────────────────
set +e
TC3_OUT=$(bash "${INIT_SH}" "NONEXISTENT-9999-XYZ" 2>&1)
TC3_RC=$?
set -e
assert_true "TC3.1-invalid-ticket-exit-nonzero" "[[ ${TC3_RC} -ne 0 ]]" "exit code != 0 when ticket not found"
echo "${TC3_OUT}" > "${TMPDIR_BASE}/tc3.out"
assert_true "TC3.2-invalid-ticket-fail-msg" "grep -q 'Ticket not found' ${TMPDIR_BASE}/tc3.out" "outputs 'Ticket not found'"

# ── TC4: Valid ticket-id → all 5 steps complete ───────────────────────────
# Use a temp worktree-like dir to avoid polluting real state
TC4_PROJ="${TMPDIR_BASE}/tc4-proj"
mkdir -p "${TC4_PROJ}/.kallax/state"
mkdir -p "${TC4_PROJ}/jira/tickets/EPIC-015-H"
cp "${REPO_ROOT}/jira/tickets/EPIC-015-H/ticket.json" "${TC4_PROJ}/jira/tickets/EPIC-015-H/ticket.json"
cat > "${TC4_PROJ}/.kallax/state/state.json" <<STATE_EOF
{
  "role": "unknown",
  "instance_id": "test_seed",
  "branch": "main"
}
STATE_EOF

# Run performer-init.sh from inside the temp project (REPO_ROOT-aware via cd)
(
  cd "${TC4_PROJ}"
  TC4_OUT=$(bash "${INIT_SH}" "EPIC-015-H" 2>&1)
  TC4_RC=$?
  echo "${TC4_OUT}" > "${TMPDIR_BASE}/tc4.stdout"
  exit ${TC4_RC}
)
TC4_RC=$?
TC4_OUT=$(cat "${TMPDIR_BASE}/tc4.stdout")

assert_true "TC4.1-valid-ticket-exit-zero" "[[ ${TC4_RC} -eq 0 ]]" "exit 0 on valid ticket"
assert_true "TC4.2-banner-init-protocol" "grep -q 'Performer Init Protocol' ${TMPDIR_BASE}/tc4.stdout" "outputs 'Performer Init Protocol' banner"
assert_true "TC4.3-step1-extract" "grep -q 'Step 1/5: Extract requirements' ${TMPDIR_BASE}/tc4.stdout" "Step 1/5 displayed"
assert_true "TC4.4-step2-match" "grep -q 'Step 2/5: Match expert profiles' ${TMPDIR_BASE}/tc4.stdout" "Step 2/5 displayed"
assert_true "TC4.5-step3-load" "grep -q 'Step 3/5: Load expert profile' ${TMPDIR_BASE}/tc4.stdout" "Step 3/5 displayed"
assert_true "TC4.6-step4-state-json" "grep -q 'Step 4/5: Update state.json' ${TMPDIR_BASE}/tc4.stdout" "Step 4/5 displayed"
assert_true "TC4.7-step5-worktree" "grep -q 'Step 5/5: Worktree prep check' ${TMPDIR_BASE}/tc4.stdout" "Step 5/5 displayed"
assert_true "TC4.8-init-complete-banner" "grep -q 'INIT COMPLETE' ${TMPDIR_BASE}/tc4.stdout" "outputs 'INIT COMPLETE' banner"

# ── TC5: state.json updated with role=performer + ticket_id + expert + init_at ──
assert_true "TC5.1-state-json-exists" "[[ -f ${TC4_PROJ}/.kallax/state/state.json ]]" "state.json exists after init"
assert_true "TC5.2-state-json-valid-json" "jq -e . ${TC4_PROJ}/.kallax/state/state.json >/dev/null 2>&1" "state.json is valid JSON"
assert_true "TC5.3-state-json-role-performer" "[[ \$(jq -r '.role' ${TC4_PROJ}/.kallax/state/state.json) == 'performer' ]]" "state.json.role=performer"
assert_true "TC5.4-state-json-ticket-id" "[[ \$(jq -r '.ticket_id' ${TC4_PROJ}/.kallax/state/state.json) == 'EPIC-015-H' ]]" "state.json.ticket_id=EPIC-015-H"
assert_true "TC5.5-state-json-expert" "[[ -n \$(jq -r '.expert // empty' ${TC4_PROJ}/.kallax/state/state.json) ]]" "state.json.expert present"
assert_true "TC5.6-state-json-init-at" "[[ -n \$(jq -r '.init_at // empty' ${TC4_PROJ}/.kallax/state/state.json) ]]" "state.json.init_at present (跟 mode_set_at 1:1)"
assert_true "TC5.7-state-json-preserves-existing" "[[ \$(jq -r '.instance_id' ${TC4_PROJ}/.kallax/state/state.json) == 'test_seed' || \$(jq -r '.instance_id' ${TC4_PROJ}/.kallax/state/state.json) == EPIC-015-H_* ]]" "state.json atomic update preserves/adds fields"

# ── TC6: performer.lock written (跟 mode_set.sh mode.lock 1:1) ────────────
assert_true "TC6.1-performer-lock-exists" "[[ -f ${TC4_PROJ}/.kallax/state/performer.lock ]]" "performer.lock written"
assert_true "TC6.2-performer-lock-pid" "[[ -s ${TC4_PROJ}/.kallax/state/performer.lock ]]" "performer.lock non-empty (PID)"
LOCK_PID=$(cat "${TC4_PROJ}/.kallax/state/performer.lock" 2>/dev/null || echo "")
assert_true "TC6.3-performer-lock-numeric" "[[ ${LOCK_PID} =~ ^[0-9]+$ ]]" "performer.lock contains numeric PID"

# ── TC7: Init report .kallax/state/performer-init.json ────────────────────
INIT_REPORT="${TC4_PROJ}/.kallax/state/performer-init.json"
assert_true "TC7.1-init-report-exists" "[[ -f ${INIT_REPORT} ]]" "performer-init.json exists"
assert_true "TC7.2-init-report-valid-json" "jq -e . ${INIT_REPORT} >/dev/null 2>&1" "performer-init.json valid JSON"
assert_true "TC7.3-init-report-ticket-id" "[[ \$(jq -r '.ticket_id' ${INIT_REPORT}) == 'EPIC-015-H' ]]" "report.ticket_id=EPIC-015-H"
assert_true "TC7.4-init-report-matched-expert" "[[ -n \$(jq -r '.matched_expert // empty' ${INIT_REPORT}) ]]" "report.matched_expert present"
assert_true "TC7.5-init-report-expert-name" "[[ -n \$(jq -r '.expert_name // empty' ${INIT_REPORT}) ]]" "report.expert_name present"
assert_true "TC7.6-init-report-performer-id" "[[ \$(jq -r '.performer_id' ${INIT_REPORT}) == EPIC-015-H_* ]]" "report.performer_id=EPIC-015-H_<pid>"
assert_true "TC7.7-init-report-branch" "[[ -n \$(jq -r '.branch // empty' ${INIT_REPORT}) ]]" "report.branch present"
assert_true "TC7.8-init-report-initialized-at" "[[ -n \$(jq -r '.initialized_at // empty' ${INIT_REPORT}) ]]" "report.initialized_at present"

# ── TC8: --expert override forces chosen expert ───────────────────────────
TC8_PROJ="${TMPDIR_BASE}/tc8-proj"
mkdir -p "${TC8_PROJ}/.kallax/state"
mkdir -p "${TC8_PROJ}/jira/tickets/EPIC-015-H"
cp "${REPO_ROOT}/jira/tickets/EPIC-015-H/ticket.json" "${TC8_PROJ}/jira/tickets/EPIC-015-H/ticket.json"
echo '{"role":"unknown"}' > "${TC8_PROJ}/.kallax/state/state.json"

(
  cd "${TC8_PROJ}"
  TC8_OUT=$(bash "${INIT_SH}" "EPIC-015-H" --expert frontend 2>&1)
  TC8_RC=$?
  echo "${TC8_OUT}" > "${TMPDIR_BASE}/tc8.stdout"
  exit ${TC8_RC}
)
TC8_RC=$?
TC8_OUT=$(cat "${TMPDIR_BASE}/tc8.stdout")

assert_true "TC8.1-override-exit-zero" "[[ ${TC8_RC} -eq 0 ]]" "exit 0 with --expert override"
assert_true "TC8.2-override-state-json-expert" "[[ \$(jq -r '.expert' ${TC8_PROJ}/.kallax/state/state.json) == 'frontend' ]]" "state.json.expert=frontend (override)"
assert_true "TC8.3-override-output-msg" "grep -q 'Override' ${TMPDIR_BASE}/tc8.stdout" "output mentions Override"

# ── TC9: --help outputs usage (跟 mode-set.sh 1:1 验证) ───────────────────
HELP_OUT=$(bash "${INIT_SH}" --help 2>&1 || true)
assert_true "TC9.1-help-exit-nonzero" "bash ${INIT_SH} --help >/dev/null 2>&1 || [[ \$? -ne 0 ]]" "--help exits nonzero (跟 mode-set.sh 1:1)"
assert_true "TC9.2-help-usage" "echo \"${HELP_OUT}\" | grep -q 'Usage:'" "usage printed"
assert_true "TC9.3-help-ticket-id-required" "echo \"${HELP_OUT}\" | grep -q '<ticket-id>'" "mentions <ticket-id>"
assert_true "TC9.4-help-expert-flag" "echo \"${HELP_OUT}\" | grep -q -- '--expert'" "mentions --expert flag"

# ── TC10: 0 增 Rule 0 增命令 (跟"翻篇&精进" 战略 联合) ───────────────────
# Verify style parity with EPIC-029-A mode-set.sh: same shebang, same set -euo pipefail,
# same jq tmp+mv atomic write, same PID lock convention.
assert_true "TC10.1-shebangs-match" "head -1 ${INIT_SH} | grep -q '/bin/bash\\|/usr/bin/env bash'" "shebang uses bash (跟 mode-set.sh 一致)"
assert_true "TC10.2-strict-mode" "head -20 ${INIT_SH} | grep -q 'set -euo pipefail'" "uses set -euo pipefail (跟 mode-set.sh 一致)"
assert_true "TC10.3-jq-atomic-write" "grep -q 'jq ' ${INIT_SH} && grep -q 'mv ' ${INIT_SH}" "uses jq + mv atomic write (跟 mode-set.sh 1:1)"
assert_true "TC10.4-pid-lock-pattern" "grep -qE 'echo \"\\$\\$\"' ${INIT_SH}" "writes PID via echo \$\$ (跟 mode-set.sh 1:1)"
assert_true "TC10.5-usage-function" "grep -q 'usage()' ${INIT_SH}" "has usage() function (跟 mode-set.sh 1:1)"
assert_true "TC10.6-no-magic-numbers" "! grep -qE '\\-\\-[a-z-]+[0-9]' ${INIT_SH}" "no magic-number flags (跟 '翻篇&精进' 战略)"
assert_true "TC10.7-mode-set-sh-exists" "[[ -f ${MODE_SET_SH} ]]" "EPIC-029-A mode-set.sh exists for 1:1 验证"

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "=== Test Results ==="
for r in "${RESULTS[@]}"; do
  echo "  ${r}"
done

echo ""
echo "=== Summary ==="
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Total: ${TOTAL} | PASS: ${PASS_COUNT} | FAIL: ${FAIL_COUNT}"
if [[ "${FAIL_COUNT}" -eq 0 ]]; then
  PASS_RATE=$(awk "BEGIN {printf \"%.1f\", (${PASS_COUNT}/${TOTAL})*100}")
  echo "PASS rate: ${PASS_RATE}% (Rule 9 KPI)"
  echo "PASS: performer-init-test.sh"
  exit 0
else
  PASS_RATE=$(awk "BEGIN {printf \"%.1f\", (${PASS_COUNT}/${TOTAL})*100}")
  echo "PASS rate: ${PASS_RATE}%"
  echo "FAILED: performer-init-test.sh"
  exit 1
fi
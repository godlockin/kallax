#!/usr/bin/env bash
# tests/integration/kallax-init-basic-test.sh — EPIC-015-E
# Integration tests for scripts/kallax-init.sh (project dir init + --target multi + incremental)
#
# Test cases (Rule 9 KPI 100.0%, EPIC-015-E ticket AC):
#   TC1: Fresh project init — 3 库 + .kallax/instances + jira/{phases,epics} + confluence/ subdirs
#   TC2: phase_index.json + epic_index.json 自动生成 (含空 schema)
#   TC3: 跟 EPIC-029-F --mode 联合: --mode ai-auto 写 state.json.mode
#   TC4: 跟 EPIC-057-A --target 联合: --target=p1,p2 multi-project init
#   TC5: 增量模式: 二次 init 同项目 → created=0 skipped=N (不覆盖)
#   TC6: INIT-REPORT.md 输出 (含 类型 fresh|incremental + 创建统计)
#   TC7: 失败目标不阻塞其余: --target=valid,badpath → 1 fail 但 valid 仍 init
#   TC8: 0 增 Rule 0 增命令 (跟"翻篇&精进" 战略 联合): 用 --help 验证 usage 不引入新 flag 命名
#
# Exit code: 0 iff all PASS (Rule 9 100.0%)
# Run from worktree root: ./tests/integration/kallax-init-basic-test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INIT_SH="$REPO_ROOT/scripts/kallax-init.sh"

if [ ! -f "$INIT_SH" ]; then
  echo "FATAL: kallax-init.sh not found at $INIT_SH" >&2
  exit 2
fi

# ── Mini test framework ──────────────────────────────────────────────────
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
TMPDIR_BASE=$(mktemp -d -t kallax-init-basic.XXXXXX)
trap "rm -rf ${TMPDIR_BASE}" EXIT

echo "=== EPIC-015-E kallax-init basic integration test ==="
echo "TMPDIR_BASE=${TMPDIR_BASE}"
echo ""

# ── TC1: Fresh project init — 3 库 + .kallax/instances + jira/{phases,epics} + confluence/ subdirs ──
TC1_PROJ="${TMPDIR_BASE}/tc1-fresh"
mkdir -p "${TC1_PROJ}"
bash "${INIT_SH}" "${TC1_PROJ}" >/dev/null 2>&1

# 3 库 boundary
assert_true "TC1.1-docs" "[[ -d ${TC1_PROJ}/docs ]]" "docs/ exists"
assert_true "TC1.2-jira" "[[ -d ${TC1_PROJ}/jira ]]" "jira/ exists"
assert_true "TC1.3-scripts" "[[ -d ${TC1_PROJ}/scripts ]]" "scripts/ exists"

# .kallax subdirs
assert_true "TC1.4-kallax-queue-inbox" "[[ -d ${TC1_PROJ}/.kallax/queue/inbox ]]" ".kallax/queue/inbox/ exists"
assert_true "TC1.5-kallax-queue-outbox" "[[ -d ${TC1_PROJ}/.kallax/queue/outbox ]]" ".kallax/queue/outbox/ exists"
assert_true "TC1.6-kallax-queue-results" "[[ -d ${TC1_PROJ}/.kallax/queue/results ]]" ".kallax/queue/results/ exists"
assert_true "TC1.7-kallax-queue-dispatch" "[[ -d ${TC1_PROJ}/.kallax/queue/dispatch ]]" ".kallax/queue/dispatch/ exists"
assert_true "TC1.8-kallax-audit" "[[ -d ${TC1_PROJ}/.kallax/audit ]]" ".kallax/audit/ exists"
assert_true "TC1.9-kallax-logs" "[[ -d ${TC1_PROJ}/.kallax/logs ]]" ".kallax/logs/ exists"
assert_true "TC1.10-kallax-state" "[[ -d ${TC1_PROJ}/.kallax/state ]]" ".kallax/state/ exists"
assert_true "TC1.11-kallax-instances" "[[ -d ${TC1_PROJ}/.kallax/instances ]]" ".kallax/instances/ exists (EPIC-015-E 新增)"

# jira subdirs
assert_true "TC1.12-jira-phases" "[[ -d ${TC1_PROJ}/jira/phases ]]" "jira/phases/ exists"
assert_true "TC1.13-jira-epics" "[[ -d ${TC1_PROJ}/jira/epics ]]" "jira/epics/ exists"
assert_true "TC1.14-jira-tickets" "[[ -d ${TC1_PROJ}/jira/tickets ]]" "jira/tickets/ exists"

# confluence subdirs
assert_true "TC1.15-confluence-decisions" "[[ -d ${TC1_PROJ}/confluence/decisions ]]" "confluence/decisions/ exists"
assert_true "TC1.16-confluence-memory" "[[ -d ${TC1_PROJ}/confluence/memory ]]" "confluence/memory/ exists"
assert_true "TC1.17-confluence-runbooks" "[[ -d ${TC1_PROJ}/confluence/runbooks ]]" "confluence/runbooks/ exists"
assert_true "TC1.18-confluence-templates" "[[ -d ${TC1_PROJ}/confluence/templates ]]" "confluence/templates/ exists"
assert_true "TC1.19-confluence-architecture" "[[ -d ${TC1_PROJ}/confluence/architecture ]]" "confluence/architecture/ exists"
assert_true "TC1.20-confluence-pitfalls" "[[ -d ${TC1_PROJ}/confluence/pitfalls ]]" "confluence/pitfalls/ exists"
assert_true "TC1.21-confluence-research" "[[ -d ${TC1_PROJ}/confluence/research ]]" "confluence/research/ exists"

# CLAUDE.md + state.json seed
assert_true "TC1.22-claude-md" "[[ -f ${TC1_PROJ}/CLAUDE.md ]]" "CLAUDE.md created"
assert_true "TC1.23-state-json" "[[ -f ${TC1_PROJ}/.kallax/state/state.json ]]" "state.json seed created"

# ── TC2: phase_index.json + epic_index.json 自动生成 (含空 schema) ──
TC2_PROJ="${TMPDIR_BASE}/tc2-index"
mkdir -p "${TC2_PROJ}"
bash "${INIT_SH}" "${TC2_PROJ}" >/dev/null 2>&1

assert_true "TC2.1-phase-index-exists" "[[ -f ${TC2_PROJ}/jira/phases/phase_index.json ]]" "phase_index.json exists"
assert_true "TC2.2-phase-index-valid-json" "jq -e . ${TC2_PROJ}/jira/phases/phase_index.json >/dev/null 2>&1" "phase_index.json is valid JSON"
assert_true "TC2.3-phase-index-empty-phases" "[[ \$(jq -r '.phases | type' ${TC2_PROJ}/jira/phases/phase_index.json) == 'array' ]]" "phase_index.json has empty phases array"
assert_true "TC2.4-phase-index-meta" "[[ \$(jq -r '._meta.created_by' ${TC2_PROJ}/jira/phases/phase_index.json) == 'kallax-init' ]]" "phase_index.json _meta.created_by=kallax-init"

assert_true "TC2.5-epic-index-exists" "[[ -f ${TC2_PROJ}/jira/epics/epic_index.json ]]" "epic_index.json exists"
assert_true "TC2.6-epic-index-valid-json" "jq -e . ${TC2_PROJ}/jira/epics/epic_index.json >/dev/null 2>&1" "epic_index.json is valid JSON"
assert_true "TC2.7-epic-index-empty-epics" "[[ \$(jq -r '.epics | type' ${TC2_PROJ}/jira/epics/epic_index.json) == 'array' ]]" "epic_index.json has empty epics array"
assert_true "TC2.8-epic-index-meta" "[[ \$(jq -r '._meta.created_by' ${TC2_PROJ}/jira/epics/epic_index.json) == 'kallax-init' ]]" "epic_index.json _meta.created_by=kallax-init"

# ── TC3: 跟 EPIC-029-F --mode 联合: --mode ai-auto 写 state.json.mode ──
TC3_PROJ="${TMPDIR_BASE}/tc3-mode"
mkdir -p "${TC3_PROJ}"
bash "${INIT_SH}" "${TC3_PROJ}" --mode ai-auto --actor "tc3-test" >/dev/null 2>&1

assert_true "TC3.1-state-json-mode" "[[ \$(jq -r '.mode' ${TC3_PROJ}/.kallax/state/state.json) == 'ai-auto' ]]" "state.json.mode=ai-auto"
assert_true "TC3.2-state-json-actor" "[[ \$(jq -r '.actor' ${TC3_PROJ}/.kallax/state/state.json) == 'tc3-test' ]]" "state.json.actor=tc3-test"
assert_true "TC3.3-state-json-mode-set-at" "[[ -n \$(jq -r '.mode_set_at // empty' ${TC3_PROJ}/.kallax/state/state.json) ]]" "state.json.mode_set_at present"
assert_true "TC3.4-mode-lock" "[[ -f ${TC3_PROJ}/.kallax/state/mode.lock ]]" "mode.lock written"

# ── TC4: 跟 EPIC-057-A --target 联合: --target=p1,p2 multi-project init ──
TC4A="${TMPDIR_BASE}/tc4-multi-a"
TC4B="${TMPDIR_BASE}/tc4-multi-b"
mkdir -p "${TC4A}" "${TC4B}"
bash "${INIT_SH}" --target="${TC4A},${TC4B}" >/dev/null 2>&1

assert_true "TC4.1-multi-a-init" "[[ -f ${TC4A}/.kallax/state/state.json && -f ${TC4A}/jira/phases/phase_index.json ]]" "TC4A fully initialized via --target"
assert_true "TC4.2-multi-b-init" "[[ -f ${TC4B}/.kallax/state/state.json && -f ${TC4B}/jira/phases/phase_index.json ]]" "TC4B fully initialized via --target"
assert_true "TC4.3-multi-a-instances" "[[ -d ${TC4A}/.kallax/instances ]]" "TC4A has .kallax/instances/"
assert_true "TC4.4-multi-b-instances" "[[ -d ${TC4B}/.kallax/instances ]]" "TC4B has .kallax/instances/"

# ── TC5: 增量模式: 二次 init 同项目 → created=0 skipped=N (不覆盖) ──
TC5_PROJ="${TMPDIR_BASE}/tc5-incremental"
mkdir -p "${TC5_PROJ}"
# 1st run: fresh
OUT1=$(bash "${INIT_SH}" "${TC5_PROJ}" 2>&1)
# Modify state.json to verify NO overwrite on 2nd run
echo '{"custom_field": "preserve_me"}' > "${TC5_PROJ}/.kallax/state/state.json.tampered"
mv "${TC5_PROJ}/.kallax/state/state.json.tampered" "${TC5_PROJ}/.kallax/state/state.json"
# 2nd run: incremental
OUT2=$(bash "${INIT_SH}" "${TC5_PROJ}" 2>&1)

assert_true "TC5.1-second-run-incremental" "echo \"${OUT2}\" | grep -q 'incremental'" "2nd run output marked [incremental]"
assert_true "TC5.2-second-run-no-overwrite" "[[ \$(jq -r '.custom_field' ${TC5_PROJ}/.kallax/state/state.json) == 'preserve_me' ]]" "state.json NOT overwritten (custom_field preserved)"
assert_true "TC5.3-second-run-skipped-gte1" "echo \"${OUT2}\" | grep -qE 'skipped=[1-9][0-9]*'" "2nd run reports skipped>=1"

# ── TC6: INIT-REPORT.md 输出 (含 类型 fresh|incremental + 创建统计) ──
assert_true "TC6.1-init-report-fresh-exists" "[[ -f ${TC1_PROJ}/docs/INIT-REPORT.md ]]" "INIT-REPORT.md created (TC1 fresh)"
assert_true "TC6.2-init-report-fresh-type" "grep -q '类型.*全新初始化' ${TC1_PROJ}/docs/INIT-REPORT.md" "INIT-REPORT.md marks 全新初始化"
assert_true "TC6.3-init-report-fresh-stats" "grep -qE '\*\*创建\*\*:.*[0-9]+' ${TC1_PROJ}/docs/INIT-REPORT.md" "INIT-REPORT.md contains **创建**: N 项"
assert_true "TC6.4-init-report-incremental-type" "grep -q '类型.*增量初始化' ${TC5_PROJ}/docs/INIT-REPORT.md" "INIT-REPORT.md (2nd run) marks 增量初始化"
assert_true "TC6.5-init-report-incremental-skipped" "grep -q '跳过' ${TC5_PROJ}/docs/INIT-REPORT.md" "INIT-REPORT.md (2nd run) reports 跳过"

# ── TC7: 失败目标不阻塞其余: --target=valid,badpath → 1 fail 但 valid 仍 init ──
TC7_VALID="${TMPDIR_BASE}/tc7-valid"
mkdir -p "${TC7_VALID}"
TC7_BADPATH="${TMPDIR_BASE}/tc7-does-not-exist"  # NOT created
set +e
bash "${INIT_SH}" --target="${TC7_VALID},${TC7_BADPATH}" >/dev/null 2>&1
RC=$?
set -e

assert_true "TC7.1-valid-still-initialized" "[[ -f ${TC7_VALID}/.kallax/state/state.json && -f ${TC7_VALID}/jira/phases/phase_index.json ]]" "TC7 valid target fully initialized despite sibling failure"
assert_true "TC7.2-badpath-not-created" "[[ ! -d ${TC7_BADPATH} ]]" "TC7 badpath NOT created (strict mode preserved)"
assert_true "TC7.3-exit-nonzero-on-partial-fail" "[[ ${RC} -ne 0 ]]" "TC7 exit nonzero on partial failure"

# ── TC8: 0 增 Rule 0 增命令 (跟"翻篇&精进" 战略 联合) ──
# Verify usage docs mention all 3 flags (--mode / --actor / --target) without any new flag naming
HELP_OUT=$(bash "${INIT_SH}" --help 2>&1 || true)
assert_true "TC8.1-help-mentions-mode" "echo \"${HELP_OUT}\" | grep -q -- '--mode'" "usage mentions --mode (existing)"
assert_true "TC8.2-help-mentions-target" "echo \"${HELP_OUT}\" | grep -q -- '--target'" "usage mentions --target (EPIC-015-E new)"
assert_true "TC8.3-help-no-magic" "! echo \"${HELP_OUT}\" | grep -qE '\\-\\-[a-z-]+[0-9]'" "usage contains no magic-number flags"

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
  echo "PASS: kallax-init-basic-test.sh"
  exit 0
else
  PASS_RATE=$(awk "BEGIN {printf \"%.1f\", (${PASS_COUNT}/${TOTAL})*100}")
  echo "PASS rate: ${PASS_RATE}%"
  echo "FAILED: kallax-init-basic-test.sh"
  exit 1
fi

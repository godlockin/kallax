#!/usr/bin/env bash
# tests/integration/kallax-db-init-test.sh — EPIC-015-F
# Integration tests for scripts/kallax-db-init.sh (team-collab SQLite init)
#
# Test cases (Rule 9 KPI 100.0%, EPIC-015-F ticket AC):
#   TC1: scripts/kallax-db-init.sh exists +x + shebang + set -uo pipefail
#   TC2: Fresh init creates .kallax/data/kallax.db + 8 tables (phases, epics, tickets,
#        team_instances, heartbeat_log, audit_log, expert_invocations, experts)
#   TC3: jira/schemas/db-schema.json exists + valid JSON + has all 8 tables declared
#   TC4: 跟 EPIC-030-G AuditMiddleware 1:1 验证: audit_log columns = 6 (id, command,
#        ticket_id, slaver_id, elapsed_ms, created_at)
#   TC5: 跟 EPIC-015-D 1:1 验证: phases/epics/tickets/team_instances/heartbeat_log
#        columns cover required schema fields
#   TC6: Idempotent: 2nd run on same project → skipped (no overwrite)
#   TC7: --target multi-project: comma-separated paths both initialized
#   TC8: --force: re-init overwrites existing DB
#   TC9: INIT-REPORT written to .kallax/state/db-init-report.md
#   TC10: --help usage shows 3 modes (fresh, skipped, force)
#
# Exit code: 0 iff all PASS (Rule 9 100.0%)
# Run from worktree root: ./tests/integration/kallax-db-init-test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INIT_SH="${REPO_ROOT}/scripts/kallax-db-init.sh"
SCHEMA_JSON="${REPO_ROOT}/jira/schemas/db-schema.json"

if [ ! -f "$INIT_SH" ]; then
  echo "FATAL: kallax-db-init.sh not found at $INIT_SH" >&2
  exit 2
fi
if [ ! -x "$INIT_SH" ]; then
  echo "FATAL: kallax-db-init.sh not executable" >&2
  exit 2
fi
if [ ! -f "$SCHEMA_JSON" ]; then
  echo "FATAL: db-schema.json not found at $SCHEMA_JSON" >&2
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
TMPDIR_BASE=$(mktemp -d -t kallax-db-init.XXXXXX)
trap "rm -rf ${TMPDIR_BASE}" EXIT

echo "=== EPIC-015-F kallax-db-init integration test ==="
echo "TMPDIR_BASE=${TMPDIR_BASE}"
echo "INIT_SH=${INIT_SH}"
echo "SCHEMA_JSON=${SCHEMA_JSON}"
echo ""

# 8 expected tables (跟 db-schema.json 1:1)
EXPECTED_TABLES=(phases epics tickets team_instances heartbeat_log audit_log expert_invocations experts)

# ── TC1: script exists +x + shebang + set -uo pipefail ──────────────────
assert_true "TC1.1-script-exists" "[[ -f ${INIT_SH} ]]" "scripts/kallax-db-init.sh exists"
assert_true "TC1.2-script-executable" "[[ -x ${INIT_SH} ]]" "scripts/kallax-db-init.sh is +x"
assert_true "TC1.3-script-shebang" "head -1 ${INIT_SH} | grep -q '^#!/usr/bin/env bash'" "shebang present"
assert_true "TC1.4-script-strict" "head -10 ${INIT_SH} | grep -q 'set -euo pipefail'" "set -euo pipefail present"

# ── TC2: fresh init creates .kallax/data/kallax.db + 8 tables ──────────
TC2_PROJ="${TMPDIR_BASE}/tc2-fresh"
mkdir -p "${TC2_PROJ}"
bash "${INIT_SH}" "${TC2_PROJ}" >/dev/null 2>&1

assert_true "TC2.1-db-dir-created" "[[ -d ${TC2_PROJ}/.kallax/data ]]" ".kallax/data/ created"
assert_true "TC2.2-db-file-created" "[[ -f ${TC2_PROJ}/.kallax/data/kallax.db ]]" ".kallax/data/kallax.db created"

# Verify 8 tables exist (use sqlite_master count)
ACTUAL_TABLE_COUNT=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" 2>/dev/null || echo 0)
assert_true "TC2.3-table-count-8" "[[ ${ACTUAL_TABLE_COUNT} -eq 8 ]]" "8 tables created (got ${ACTUAL_TABLE_COUNT})"

# Verify each expected table exists
for t in "${EXPECTED_TABLES[@]}"; do
  PRESENT=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='${t}';" 2>/dev/null || echo 0)
  assert_true "TC2.4-table-${t}" "[[ ${PRESENT} -eq 1 ]]" "table ${t} exists"
done

# ── TC3: jira/schemas/db-schema.json valid + has 8 tables ──────────────
assert_true "TC3.1-schema-valid-json" "jq -e . ${SCHEMA_JSON} >/dev/null 2>&1" "db-schema.json is valid JSON"
SCHEMA_TABLE_COUNT=$(jq '.tables | keys | length' "${SCHEMA_JSON}")
assert_true "TC3.2-schema-8-tables" "[[ ${SCHEMA_TABLE_COUNT} -eq 8 ]]" "db-schema.json declares 8 tables (got ${SCHEMA_TABLE_COUNT})"

# Verify all 8 expected tables are declared in db-schema.json
for t in "${EXPECTED_TABLES[@]}"; do
  assert_true "TC3.3-schema-declares-${t}" "jq -e '.tables.${t}' ${SCHEMA_JSON} >/dev/null 2>&1" "db-schema.json declares table ${t}"
done

# ── TC4: 跟 EPIC-030-G AuditMiddleware 1:1 验证 ─────────────────────────
# EPIC-030-G audit_log columns: id / command / ticket_id / slaver_id / elapsed_ms / created_at (6 cols)
EPIC_030G_AUDIT_COLS="id,command,ticket_id,slaver_id,elapsed_ms,created_at"
ACTUAL_AUDIT_COLS=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT name FROM pragma_table_info('audit_log') ORDER BY cid;" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

assert_true "TC4.1-audit-cols-6" "[[ \$(sqlite3 ${TC2_PROJ}/.kallax/data/kallax.db 'PRAGMA table_info(audit_log);' | wc -l | tr -d ' ') -eq 6 ]]" "audit_log has 6 columns (1:1 with EPIC-030-G)"
assert_true "TC4.2-audit-cols-match-epic-030g" "[[ '${ACTUAL_AUDIT_COLS}' == '${EPIC_030G_AUDIT_COLS}' ]]" "audit_log column names 1:1 with EPIC-030-G: ${ACTUAL_AUDIT_COLS}"

# Verify each audit_log column type 1:1 with EPIC-030-G
ACTUAL_AUDIT_ID_TYPE=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT type FROM pragma_table_info('audit_log') WHERE name='id';" 2>/dev/null)
ACTUAL_AUDIT_CMD_TYPE=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT type FROM pragma_table_info('audit_log') WHERE name='command';" 2>/dev/null)
ACTUAL_AUDIT_ELAPSED_TYPE=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT type FROM pragma_table_info('audit_log') WHERE name='elapsed_ms';" 2>/dev/null)
assert_true "TC4.3-audit-id-integer" "[[ '${ACTUAL_AUDIT_ID_TYPE}' == 'INTEGER' ]]" "audit_log.id is INTEGER (1:1 with EPIC-030-G)"
assert_true "TC4.4-audit-cmd-text" "[[ '${ACTUAL_AUDIT_CMD_TYPE}' == 'TEXT' ]]" "audit_log.command is TEXT (1:1 with EPIC-030-G)"
assert_true "TC4.5-audit-elapsed-integer" "[[ '${ACTUAL_AUDIT_ELAPSED_TYPE}' == 'INTEGER' ]]" "audit_log.elapsed_ms is INTEGER (1:1 with EPIC-030-G)"

# Write+query test: simulate audit-middleware behavior on the new DB
sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "INSERT INTO audit_log (command, ticket_id, slaver_id, elapsed_ms, created_at) VALUES ('check-fact-forcing-preflight', 'EPIC-030-G', 'slaver-perf-001', 1234, '2026-06-26T10:00:00+00:00');"
AUDIT_ROW=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT command, ticket_id, slaver_id, elapsed_ms FROM audit_log WHERE ticket_id='EPIC-030-G';" 2>/dev/null)
assert_true "TC4.6-audit-write-and-query" "echo '${AUDIT_ROW}' | grep -q 'check-fact-forcing-preflight.*EPIC-030-G.*slaver-perf-001.*1234'" "audit_log write + query works (1:1 with EPIC-030-G contract)"

# ── TC5: 跟 EPIC-015-D JSON schemas 1:1 验证 ──────────────────────────
# phases: must have id, title, status
PHASES_COLS=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT name FROM pragma_table_info('phases');" 2>/dev/null | sort | tr '\n' ',' | sed 's/,$//')
for col in id title status; do
  HAS=$(echo "${PHASES_COLS}" | grep -q "${col}" && echo 1 || echo 0)
  assert_true "TC5.1-phases-has-${col}" "[[ ${HAS} -eq 1 ]]" "phases.${col} present (1:1 with phase-schema.json)"
done

# epics: must have id, phase_id, title, status, tickets_total, tickets_done
EPICS_COLS=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT name FROM pragma_table_info('epics');" 2>/dev/null | sort | tr '\n' ',' | sed 's/,$//')
for col in id phase_id title status tickets_total tickets_done tickets_ready tickets_deferred; do
  HAS=$(echo "${EPICS_COLS}" | grep -q "${col}" && echo 1 || echo 0)
  assert_true "TC5.2-epics-has-${col}" "[[ ${HAS} -eq 1 ]]" "epics.${col} present (1:1 with epic-schema.json)"
done

# tickets: must have id, epic_id, title, type, priority, status, created_by, created_at, acceptance_criteria
TICKETS_COLS=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT name FROM pragma_table_info('tickets');" 2>/dev/null | sort | tr '\n' ',' | sed 's/,$//')
for col in id epic_id title type priority status created_by created_at acceptance_criteria; do
  HAS=$(echo "${TICKETS_COLS}" | grep -q "${col}" && echo 1 || echo 0)
  assert_true "TC5.3-tickets-has-${col}" "[[ ${HAS} -eq 1 ]]" "tickets.${col} present (1:1 with ticket-schema.json)"
done

# State machine: status CHECK constraint on tickets (12 states per v2.7.4 D5)
TICKETS_STATUS_CHECK=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT sql FROM sqlite_master WHERE type='table' AND name='tickets';" 2>/dev/null | grep -o "status IN ('[^']*'" | head -1)
assert_true "TC5.4-tickets-status-check" "echo '${TICKETS_STATUS_CHECK}' | grep -q 'status IN'" "tickets.status has CHECK constraint (1:1 with state-schema.json ticketStatus enum)"

# 12 ticketStatus states per ticket-schema.md (8 primary + 4 secondary per v2.7.4 D5)
for st in backlog analysis ready gate_review in_progress test pr_review done blocked pending deferred failed; do
  IN_CHECK=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT sql FROM sqlite_master WHERE type='table' AND name='tickets';" 2>/dev/null | grep -c "'${st}'" || echo 0)
  assert_true "TC5.5-tickets-state-${st}" "[[ ${IN_CHECK} -ge 1 ]]" "tickets.status CHECK includes state '${st}' (1:1 with state-schema.json ticketStatus enum)"
done

# team_instances + heartbeat_log heartbeat tracking
for col in instance_id role status pid heartbeat_at; do
  HAS=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM pragma_table_info('team_instances') WHERE name='${col}';" 2>/dev/null)
  assert_true "TC5.6-team_instances-has-${col}" "[[ ${HAS} -eq 1 ]]" "team_instances.${col} present"
done
for col in instance_id tick_at status; do
  HAS=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM pragma_table_info('heartbeat_log') WHERE name='${col}';" 2>/dev/null)
  assert_true "TC5.7-heartbeat_log-has-${col}" "[[ ${HAS} -eq 1 ]]" "heartbeat_log.${col} present"
done

# expert_invocations + experts
for col in ticket_id expert_role phase verdict; do
  HAS=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM pragma_table_info('expert_invocations') WHERE name='${col}';" 2>/dev/null)
  assert_true "TC5.8-expert_invocations-has-${col}" "[[ ${HAS} -eq 1 ]]" "expert_invocations.${col} present"
done
for col in name tier skill_path; do
  HAS=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM pragma_table_info('experts') WHERE name='${col}';" 2>/dev/null)
  assert_true "TC5.9-experts-has-${col}" "[[ ${HAS} -eq 1 ]]" "experts.${col} present"
done

# ── TC6: idempotent (2nd run skipped) ──────────────────────────────────
OUT2=$(bash "${INIT_SH}" "${TC2_PROJ}" 2>&1)
assert_true "TC6.1-second-run-skipped" "echo '${OUT2}' | grep -q 'DB already exists'" "2nd run on existing DB → skipped"
assert_true "TC6.2-second-run-suggests-force" "echo '${OUT2}' | grep -q -- '--force'" "2nd run message suggests --force"

# Verify DB not overwritten (still 8 tables, audit_log row still there)
TC6_TABLE_COUNT=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" 2>/dev/null || echo 0)
assert_true "TC6.3-db-not-overwritten" "[[ ${TC6_TABLE_COUNT} -eq 8 ]]" "DB tables count preserved (8) after 2nd run"

TC6_AUDIT_COUNT=$(sqlite3 "${TC2_PROJ}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM audit_log;" 2>/dev/null || echo 0)
assert_true "TC6.4-audit-data-preserved" "[[ ${TC6_AUDIT_COUNT} -eq 1 ]]" "audit_log data preserved (1 row) after 2nd run"

# ── TC7: --target multi-project ────────────────────────────────────────
TC7A="${TMPDIR_BASE}/tc7-multi-a"
TC7B="${TMPDIR_BASE}/tc7-multi-b"
mkdir -p "${TC7A}" "${TC7B}"
bash "${INIT_SH}" --target="${TC7A},${TC7B}" >/dev/null 2>&1

assert_true "TC7.1-multi-a-db" "[[ -f ${TC7A}/.kallax/data/kallax.db ]]" "TC7A .kallax/data/kallax.db created"
assert_true "TC7.2-multi-b-db" "[[ -f ${TC7B}/.kallax/data/kallax.db ]]" "TC7B .kallax/data/kallax.db created"
TC7A_TABLES=$(sqlite3 "${TC7A}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" 2>/dev/null || echo 0)
TC7B_TABLES=$(sqlite3 "${TC7B}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" 2>/dev/null || echo 0)
assert_true "TC7.3-multi-a-8-tables" "[[ ${TC7A_TABLES} -eq 8 ]]" "TC7A has 8 tables"
assert_true "TC7.4-multi-b-8-tables" "[[ ${TC7B_TABLES} -eq 8 ]]" "TC7B has 8 tables"

# ── TC8: --force re-init ─────────────────────────────────────────────
TC8_PROJ="${TMPDIR_BASE}/tc8-force"
mkdir -p "${TC8_PROJ}"
bash "${INIT_SH}" "${TC8_PROJ}" >/dev/null 2>&1
# write a row
sqlite3 "${TC8_PROJ}/.kallax/data/kallax.db" "INSERT INTO audit_log (command, ticket_id, slaver_id, elapsed_ms, created_at) VALUES ('test-row', 'EPIC-015-F', 'test', 999, '2026-06-26T00:00:00+00:00');"
BEFORE_COUNT=$(sqlite3 "${TC8_PROJ}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM audit_log;" 2>/dev/null)
assert_true "TC8.1-precondition-row-present" "[[ ${BEFORE_COUNT} -eq 1 ]]" "TC8 precondition: 1 row exists"

# --force re-init
bash "${INIT_SH}" --force "${TC8_PROJ}" >/dev/null 2>&1
TC8_TABLES=$(sqlite3 "${TC8_PROJ}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" 2>/dev/null || echo 0)
assert_true "TC8.2-force-recreate-8-tables" "[[ ${TC8_TABLES} -eq 8 ]]" "TC8 --force: 8 tables recreated"
AFTER_COUNT=$(sqlite3 "${TC8_PROJ}/.kallax/data/kallax.db" "SELECT COUNT(*) FROM audit_log;" 2>/dev/null)
assert_true "TC8.3-force-cleared-data" "[[ ${AFTER_COUNT} -eq 0 ]]" "TC8 --force: previous rows cleared (audit_log count=0)"

# ── TC9: INIT-REPORT written ────────────────────────────────────────
assert_true "TC9.1-report-exists" "[[ -f ${TC2_PROJ}/.kallax/state/db-init-report.md ]]" "db-init-report.md exists"
assert_true "TC9.2-report-mentions-EPIC-015-F" "grep -q 'EPIC-015-F' ${TC2_PROJ}/.kallax/state/db-init-report.md" "report mentions EPIC-015-F"
assert_true "TC9.3-report-mentions-EPIC-030-G" "grep -q 'EPIC-030-G' ${TC2_PROJ}/.kallax/state/db-init-report.md" "report mentions EPIC-030-G (1:1 audit_log)"
assert_true "TC9.4-report-table-count-8" "grep -qE '8 张|8/${#EXPECTED_TABLES[@]}|创建表.*8' ${TC2_PROJ}/.kallax/state/db-init-report.md" "report mentions 8 tables"
assert_true "TC9.5-report-schema-version" "grep -q 'v1' ${TC2_PROJ}/.kallax/state/db-init-report.md" "report references schema v1"

# ── TC10: --help shows usage ─────────────────────────────────────────
HELP_OUT=$(bash "${INIT_SH}" --help 2>&1 || true)
assert_true "TC10.1-help-shows-usage" "echo '${HELP_OUT}' | grep -q 'Usage:'" "usage line present"
assert_true "TC10.2-help-shows-target" "echo '${HELP_OUT}' | grep -q -- '--target'" "usage mentions --target"
assert_true "TC10.3-help-shows-force" "echo '${HELP_OUT}' | grep -q -- '--force'" "usage mentions --force"
assert_true "TC10.4-help-shows-8-tables" "echo '${HELP_OUT}' | grep -qE '8|phases|epics|audit_log'" "usage mentions tables"
assert_true "TC10.5-help-no-magic-numbers" "! echo '${HELP_OUT}' | grep -qE '\\-\\-[a-z-]+[0-9]'" "no magic-number flags (跟'翻篇&精进' 战略 联合)"

# ── Summary ────────────────────────────────────────────────────────────
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
  echo "PASS: kallax-db-init-test.sh"
  exit 0
else
  PASS_RATE=$(awk "BEGIN {printf \"%.1f\", (${PASS_COUNT}/${TOTAL})*100}")
  echo "PASS rate: ${PASS_RATE}%"
  echo "FAILED: kallax-db-init-test.sh"
  exit 1
fi

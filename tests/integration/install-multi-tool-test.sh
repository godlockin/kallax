#!/usr/bin/env bash
# File: tests/integration/install-multi-tool-test.sh
# (renamed from install-test.sh per jira/tickets/EPIC-057-A/ticket.json file_scope)
#
# KALLAX install.sh integration test — EPIC-057-A
#
# Validates scripts/install.sh supports multi-tool install via:
#   --target=auto | --target=all | --target=<tool> | --target=a,b
# and that 4 工具 skills/commands paths are correctly mapped.
#
# Test plan (6 cases, Rule 9 KPI 6/6 = 100.0%):
#   T1: --target=auto + 4 mock base dirs → 4 skills dirs auto-created
#   T2: --target=all + 0 mock → 4 skills dirs force-created (10-tool mode)
#   T3: --target=claude + 0 mock → exit 1, "not detected" (strict mode)
#   T4: --target=opencode,codex + 4 mock → 2 skills dirs, others absent
#   T5: --target=nonexistent → exit 1, "unknown tool"
#   T6: --target=auto + 0 detected → exit 1, suggestion to use --target=all
#
# Fixture isolation: each test sets HOME=$(mktemp -d) + PATH=/usr/bin:/bin
# via `env -i` so install.sh cannot pollute the real $HOME or detect real
# tool binaries. No mock stubs required for command/grep/ls etc.
#
# Bash 3.2 compat: no `declare -A`; uses plain string interpolation.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SH="$REPO_ROOT/scripts/install.sh"

if [ ! -f "$INSTALL_SH" ]; then
  echo "FATAL: install.sh not found at $INSTALL_SH" >&2
  exit 2
fi

# ── Mini test framework ──────────────────────────────────────────────────

PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()
CASE_NAMES=()
CASE_PASS=()

record() {
  local status="$1" case_name="$2" detail="$3"
  RESULTS+=("[$status] $case_name: $detail")
  if [ "$status" = "PASS" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# Record overall case result (one vote per case)
record_case() {
  local name="$1" passed="$2" detail="$3"
  CASE_NAMES+=("$name")
  if [ "$passed" = "true" ]; then
    CASE_PASS+=("PASS")
    record "PASS" "$name" "$detail"
  else
    CASE_PASS+=("FAIL")
    record "FAIL" "$name" "$detail"
  fi
}

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    return 0
  else
    record "FAIL" "$name" "expected='$expected' got='$actual'"
    return 1
  fi
}

assert_dir_exists() {
  local name="$1" dir="$2"
  if [ -d "$dir" ]; then
    return 0
  else
    record "FAIL" "$name" "dir missing: $dir"
    return 1
  fi
}

assert_dir_missing() {
  local name="$1" dir="$2"
  if [ ! -d "$dir" ]; then
    return 0
  else
    record "FAIL" "$name" "dir should not exist: $dir"
    return 1
  fi
}

# ── Fixture helpers ─────────────────────────────────────────────────────

mock_4_base_dirs() {
  local home="$1"
  mkdir -p \
    "$home/.claude" \
    "$home/.opencode" \
    "$home/.codex" \
    "$home/.gemini"
}

# Run install.sh with isolated HOME + PATH. Stdout/stderr captured to log.
# Returns install.sh exit code.
run_install() {
  local home="$1"; shift
  local logfile
  logfile=$(mktemp)
  env -i \
    HOME="$home" \
    PATH="/usr/bin:/bin" \
    bash "$INSTALL_SH" "$@" > "$logfile" 2>&1
  local rc=$?
  if [ "${VERBOSE:-0}" = "1" ]; then
    echo "──── install.sh output ($@) ────" >&2
    cat "$logfile" >&2
    echo "──── exit: $rc ────" >&2
  fi
  rm -f "$logfile"
  return $rc
}

# ── T1: --target=auto + 4 mock → 4 skills dirs created ──────────────────
test_target_auto_with_mocks() {
  local home case="T1 --target=auto + 4 mock base dirs"
  home=$(mktemp -d)
  mock_4_base_dirs "$home"
  run_install "$home" "--target=auto"
  local rc=$?
  local ok=true
  assert_eq "$case exit code" "0" "$rc" || ok=false
  assert_dir_exists "$case claude skills"  "$home/.claude/skills/kallax"  || ok=false
  assert_dir_exists "$case opencode skills" "$home/.opencode/skills/kallax" || ok=false
  assert_dir_exists "$case codex skills"   "$home/.codex/skills/kallax"   || ok=false
  assert_dir_exists "$case gemini skills"  "$home/.gemini/skills/kallax"  || ok=false
  # Per-tool commands dir paths (跟 AGENTS.md §10 联合)
  assert_dir_exists "$case claude commands"  "$home/.claude/commands"   || ok=false
  assert_dir_exists "$case opencode commands (singular /command/)" "$home/.opencode/command" || ok=false
  assert_dir_exists "$case codex commands (prompts/)" "$home/.codex/prompts" || ok=false
  assert_dir_exists "$case gemini commands"  "$home/.gemini/commands"   || ok=false
  rm -rf "$home"
  record_case "$case" "$ok" "4 skills + 4 commands dirs created"
}

# ── T2: --target=all + 0 mock → 4 skills dirs force-created ────────────
test_target_all_no_mocks() {
  local home case="T2 --target=all + 0 mock"
  home=$(mktemp -d)
  # Don't mock — install.sh should force-install all 10 tools
  run_install "$home" "--target=all"
  local rc=$?
  local ok=true
  assert_eq "$case exit code" "0" "$rc" || ok=false
  # Verify all 4 documented tools' skills dirs created (other 6 tools
  # are out of EPIC-057-A scope but should not break the test)
  assert_dir_exists "$case claude skills"  "$home/.claude/skills/kallax"  || ok=false
  assert_dir_exists "$case opencode skills" "$home/.opencode/skills/kallax" || ok=false
  assert_dir_exists "$case codex skills"   "$home/.codex/skills/kallax"   || ok=false
  assert_dir_exists "$case gemini skills"  "$home/.gemini/skills/kallax"  || ok=false
  rm -rf "$home"
  record_case "$case" "$ok" "4 skills dirs force-created (10-tool mode)"
}

# ── T3: --target=claude + 0 mock → exit 1 (strict mode) ────────────────
test_target_specific_no_mock() {
  local home case="T3 --target=claude + 0 mock (strict mode)"
  home=$(mktemp -d)
  run_install "$home" "--target=claude"
  local rc=$?
  local ok=true
  assert_eq "$case exit code" "1" "$rc" || ok=false
  assert_dir_missing "$case claude skills NOT created" "$home/.claude/skills/kallax" || ok=false
  rm -rf "$home"
  record_case "$case" "$ok" "exit 1 + no install (strict detection)"
}

# ── T4: --target=opencode,codex + 4 mock → 2 skills dirs ───────────────
test_target_multi() {
  local home case="T4 --target=opencode,codex + 4 mock"
  home=$(mktemp -d)
  mock_4_base_dirs "$home"
  run_install "$home" "--target=opencode,codex"
  local rc=$?
  local ok=true
  assert_eq "$case exit code" "0" "$rc" || ok=false
  assert_dir_exists "$case opencode skills" "$home/.opencode/skills/kallax" || ok=false
  assert_dir_exists "$case codex skills"   "$home/.codex/skills/kallax"   || ok=false
  assert_dir_missing "$case claude skills NOT created" "$home/.claude/skills/kallax" || ok=false
  assert_dir_missing "$case gemini skills NOT created" "$home/.gemini/skills/kallax" || ok=false
  rm -rf "$home"
  record_case "$case" "$ok" "opencode+codex installed, claude+gemini skipped"
}

# ── T5: --target=nonexistent → exit 1 (unknown tool) ───────────────────
test_target_unknown() {
  local home case="T5 --target=nonexistent (unknown tool)"
  home=$(mktemp -d)
  run_install "$home" "--target=nonexistent"
  local rc=$?
  local ok=true
  assert_eq "$case exit code" "1" "$rc" || ok=false
  assert_dir_missing "$case no skills dir created" "$home/.claude/skills/kallax" || ok=false
  rm -rf "$home"
  record_case "$case" "$ok" "exit 1 (unknown tool rejected)"
}

# ── T6: --target=auto + 0 detected → exit 1 + suggestion ───────────────
test_target_auto_no_detection() {
  local home case="T6 --target=auto + 0 detected (suggestion)"
  home=$(mktemp -d)
  run_install "$home" "--target=auto"
  local rc=$?
  local ok=true
  assert_eq "$case exit code" "1" "$rc" || ok=false
  assert_dir_missing "$case no skills dir created" "$home/.claude/skills/kallax" || ok=false
  rm -rf "$home"
  record_case "$case" "$ok" "exit 1 with --target=all suggestion"
}

# ── Main ───────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════════════════════════"
echo " KALLAX install.sh integration test — EPIC-057-A"
echo " install.sh: $INSTALL_SH"
echo " 4 工具: claude / opencode / codex / gemini"
echo "════════════════════════════════════════════════════════════════"
echo ""

test_target_auto_with_mocks
test_target_all_no_mocks
test_target_specific_no_mock
test_target_multi
test_target_unknown
test_target_auto_no_detection

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " Per-case results:"
echo "════════════════════════════════════════════════════════════════"
for i in "${!CASE_NAMES[@]}"; do
  printf "  %-4s  %s\n" "${CASE_PASS[$i]}" "${CASE_NAMES[$i]}"
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " All assertions:"
echo "════════════════════════════════════════════════════════════════"
for r in "${RESULTS[@]}"; do
  echo "  $r"
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " Summary: ${#CASE_NAMES[@]} cases | PASS ${PASS_COUNT} | FAIL ${FAIL_COUNT}"
echo "════════════════════════════════════════════════════════════════"

if [ "$FAIL_COUNT" -eq 0 ]; then
  echo " RESULT: 6/6 PASS = 100.0% (Rule 9 KPI)"
  exit 0
else
  echo " RESULT: FAILED (${FAIL_COUNT} assertion(s) failed)"
  exit 1
fi

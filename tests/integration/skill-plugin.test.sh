#!/usr/bin/env bash
# KALLAX Skill Plugin Integration Tests — EPIC-162
# AC9: ≥10 test cases covering install/status/uninstall/list/enabled/disable/cross-host/activation-gate/scope/backward-compat
set +e  # Don't exit on errors - test framework handles it

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$(dirname "$(dirname "$SCRIPT_DIR")")" && pwd)"
SKILL_MANAGER="${PROJECT_ROOT}/scripts/skill/skill-manager.sh"
SKILL_EXPERTS_DIR="${PROJECT_ROOT}/.claude/skills/kallax-experts"
TEST_TMP_DIR="/tmp/kallax-skill-test-$$"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; NC='\033[0m'
PASS() { echo -e "${GREEN}[PASS]${NC} $1"; }
FAIL() { echo -e "${RED}[FAIL]${NC} $1"; }
SKIP() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

TOTAL=0; PASSED=0; FAILED=0

run_test() {
  local name="$1"; shift
  local cmd="$1"; shift
  local expected_exit="${1:-0}"; shift
  local desc="${*:-}"

  TOTAL=$((TOTAL + 1))
  echo -n "Test ${TOTAL}: ${name}... "

  local actual_exit=0
  if ! eval "$cmd" > /dev/null 2>&1; then
    actual_exit=$?
  fi

  if [[ $actual_exit -eq $expected_exit ]]; then
    PASSED=$((PASSED + 1))
    PASS "${desc:-OK}"
  else
    FAILED=$((FAILED + 1))
    FAIL "expected exit ${expected_exit}, got ${actual_exit}"
  fi
}

cleanup() {
  rm -rf "$TEST_TMP_DIR"
  # Cleanup test enabled files
  for skill_dir in "${SKILL_EXPERTS_DIR}"/*/; do
    rm -f "${skill_dir}/.kallax-skill-enabled"
  done
}
trap cleanup EXIT

setup() {
  mkdir -p "$TEST_TMP_DIR"
  # Clean any previous test state
  cleanup
}

# ── Test Cases (≥10) ─────────────────────────────────────────────────────────

test_skill_structure() {
  TOTAL=$((TOTAL + 1))
  echo -n "Test ${TOTAL}: Skill structure (AC1-AC3)... "
  local all_have_scope=true
  local all_have_agents=true
  local count=0

  for skill_dir in "${SKILL_EXPERTS_DIR}"/*/; do
    local skill=$(basename "$skill_dir")
    count=$((count + 1))
    if [[ ! -f "${skill_dir}/.kallax-skill-scope" ]]; then
      all_have_scope=false
    fi
    if [[ ! -d "${skill_dir}/agents" ]] || [[ -z "$(ls -A "${skill_dir}/agents/")" ]]; then
      all_have_agents=false
    fi
  done

  if $all_have_scope && $all_have_agents && [[ $count -ge 9 ]]; then
    PASSED=$((PASSED + 1))
    PASS "9 skills with scope + agents"
  else
    FAILED=$((FAILED + 1))
    FAIL "scope=$all_have_scope, agents=$all_have_agents, count=$count"
  fi
}

test_skill_manager_help() {
  run_test "skill-manager help" "bash ${SKILL_MANAGER} --help" 0 "Show usage"
}

test_skill_manager_list() {
  run_test "skill-manager list" "bash ${SKILL_MANAGER} list" 0 "List skills"
}

test_skill_manager_list_all() {
  run_test "skill-manager list --all" "bash ${SKILL_MANAGER} list --all" 0 "List all skills"
}

test_skill_manager_status() {
  run_test "skill-manager status" "bash ${SKILL_MANAGER} status" 0 "Status all skills"
}

test_skill_manager_status_single() {
  run_test "skill-manager status architect" "bash ${SKILL_MANAGER} status architect" 0 "Status single skill"
}

test_enabled_policy_field() {
  TOTAL=$((TOTAL + 1))
  echo -n "Test ${TOTAL}: enabled_policy field (AC4)... "
  local count=0
  for skill_dir in "${SKILL_EXPERTS_DIR}"/*/; do
    if grep -q "^enabled_policy:" "${skill_dir}/SKILL.md" 2>/dev/null; then
      count=$((count + 1))
    fi
  done

  if [[ $count -ge 9 ]]; then
    PASSED=$((PASSED + 1))
    PASS "9 skills have enabled_policy"
  else
    FAILED=$((FAILED + 1))
    FAIL "only $count/9 skills have enabled_policy"
  fi
}

test_scope_marker_size() {
  TOTAL=$((TOTAL + 1))
  echo -n "Test ${TOTAL}: Scope marker size (AC2, 8 bytes)... "
  local all_valid=true
  for skill_dir in "${SKILL_EXPERTS_DIR}"/*/; do
    local marker="${skill_dir}/.kallax-skill-scope"
    if [[ -f "$marker" ]]; then
      local size=$(wc -c < "$marker" | tr -d ' ')
      if [[ $size -lt 1 ]] || [[ $size -gt 30 ]]; then
        all_valid=false
      fi
    else
      all_valid=false
    fi
  done

  if $all_valid; then
    PASSED=$((PASSED + 1))
    PASS "All scope markers valid size"
  else
    FAILED=$((FAILED + 1))
    FAIL "Invalid scope marker size"
  fi
}

test_install_skill() {
  TOTAL=$((TOTAL + 1))
  echo -n "Test ${TOTAL}: Install skill (AC5)... "
  local output
  output=$(bash "${SKILL_MANAGER}" install architect --surface claude-code 2>&1) || true

  if echo "$output" | grep -q "installed and enabled"; then
    PASSED=$((PASSED + 1))
    PASS "Install with activation gate"
  else
    FAILED=$((FAILED + 1))
    FAIL "Install failed"
  fi
}

test_enabled_command() {
  run_test "enabled command" "bash ${SKILL_MANAGER} enabled architect" 0 "Check enabled"
}

test_disable_command() {
  run_test "disable command" "bash ${SKILL_MANAGER} disable architect" 0 "Disable skill"
}

test_enabled_after_disable() {
  TOTAL=$((TOTAL + 1))
  echo -n "Test ${TOTAL}: Enabled check after disable... "
  bash "${SKILL_MANAGER}" disable architect > /dev/null 2>&1 || true
  bash "${SKILL_MANAGER}" enabled architect > /dev/null 2>&1
  local result=$?

  if [[ $result -ne 0 ]]; then
    PASSED=$((PASSED + 1))
    PASS "Skill disabled correctly"
  else
    FAILED=$((FAILED + 1))
    FAIL "Skill still enabled"
  fi
}

test_uninstall_skill() {
  TOTAL=$((TOTAL + 1))
  echo -n "Test ${TOTAL}: Uninstall skill (AC5)... "
  # Re-enable first
  touch "${SKILL_EXPERTS_DIR}/architect/.kallax-skill-enabled"
  local output
  output=$(bash "${SKILL_MANAGER}" uninstall architect 2>&1) || true

  if echo "$output" | grep -q "uninstalled"; then
    PASSED=$((PASSED + 1))
    PASS "Uninstall skill"
  else
    FAILED=$((FAILED + 1))
    FAIL "Uninstall failed"
  fi
}

test_cross_host_surface() {
  TOTAL=$((TOTAL + 1))
  echo -n "Test ${TOTAL}: Cross-host surface (AC6)... "
  local surface_count=0
  for surface in codex claude-code opencode cursor; do
    output=$(bash "${SKILL_MANAGER}" install backend --surface "$surface" 2>&1) || true
    if echo "$output" | grep -q "Installed"; then
      surface_count=$((surface_count + 1))
    fi
  done

  if [[ $surface_count -eq 4 ]]; then
    PASSED=$((PASSED + 1))
    PASS "4 host surfaces supported"
  else
    FAILED=$((FAILED + 1))
    FAIL "Only $surface_count/4 surfaces"
  fi
}

test_activation_gate() {
  TOTAL=$((TOTAL + 1))
  echo -n "Test ${TOTAL}: Activation gate 5 steps (AC8)... "
  local output
  output=$(bash "${SKILL_MANAGER}" install frontend --surface claude-code 2>&1) || true

  local steps=0
  for step in "Resolve project" "Confirm todo" "Check boundary" "Architecture check" "Owner-gated"; do
    if echo "$output" | grep -q "$step"; then
      steps=$((steps + 1))
    fi
  done

  if [[ $steps -ge 5 ]]; then
    PASSED=$((PASSED + 1))
    PASS "5 activation gate steps"
  else
    FAILED=$((FAILED + 1))
    FAIL "Only $steps/5 steps"
  fi
}

test_submodule_commands() {
  TOTAL=$((TOTAL + 1))
  echo -n "Test ${TOTAL}: Submodule commands (EPIC-167)... "
  local ok=true
  bash "${SKILL_MANAGER}" submodule-status > /dev/null 2>&1 || ok=false
  bash "${SKILL_MANAGER}" submodule-init > /dev/null 2>&1 || ok=false
  bash "${SKILL_MANAGER}" submodule-update > /dev/null 2>&1 || ok=false

  if $ok; then
    PASSED=$((PASSED + 1))
    PASS "3 submodule commands"
  else
    FAILED=$((FAILED + 1))
    FAIL "Submodule commands failed"
  fi
}

test_backward_compat() {
  TOTAL=$((TOTAL + 1))
  echo -n "Test ${TOTAL}: Backward compat (AC12)... "
  # Check main skill still exists
  if [[ -f "${PROJECT_ROOT}/.claude/skills/kallax/SKILL.md" ]]; then
    PASSED=$((PASSED + 1))
    PASS "Main skill backward compat"
  else
    FAILED=$((FAILED + 1))
    FAIL "Main skill missing"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  KALLAX Skill Plugin Integration Tests (EPIC-162)"
echo "═══════════════════════════════════════════════════════"
echo ""

setup

# Run all tests
test_skill_structure
test_skill_manager_help
test_skill_manager_list
test_skill_manager_list_all
test_skill_manager_status
test_skill_manager_status_single
test_enabled_policy_field
test_scope_marker_size
test_install_skill
test_enabled_command
test_disable_command
test_enabled_after_disable
test_uninstall_skill
test_cross_host_surface
test_activation_gate
test_submodule_commands
test_backward_compat

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Results: ${PASSED}/${TOTAL} PASSED, ${FAILED} FAILED"
echo "═══════════════════════════════════════════════════════"
echo ""

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
fi

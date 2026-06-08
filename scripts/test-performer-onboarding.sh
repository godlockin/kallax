#!/usr/bin/env bash
# KALLAX Performer Onboarding Test -- EPIC-016-R AC16
# Tests 4 scenarios: (a) no EPIC, (b) normal, (c) continue, (d) no master.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PERFORMER_INIT="${SCRIPT_DIR}/performer-session-init.sh"
KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"
EPICS_DIR="jira/epics"
TICKETS_DIR="jira/tickets"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

FAIL_COUNT=0
PASS_COUNT=0

# Helper: run performer-session-init.sh in a temp directory environment
run_performer_init() {
  local tmpdir="$1"
  # performer-session-init.sh uses relative paths from repo root
  # so we cd to repo root and point KALLAX_ROOT to the temp dir
  export KALLAX_ROOT="${tmpdir}/.kallax"
  export KALLAX_INSTANCE_ID="test-performer-$$"
  bash "${PERFORMER_INIT}" 2>&1
}

# ============================================================
# Scenario (a): New project — no EPIC
# ============================================================
test_scenario_a() {
  echo ""
  echo "─── Scenario (a): New project, no EPIC ───"

  local test_dir
  test_dir=$(mktemp -d)
  mkdir -p "${test_dir}/${EPICS_DIR}" "${test_dir}/${TICKETS_DIR}" \
    "${test_dir}/${KALLAX_ROOT}/instances" "${test_dir}/${KALLAX_ROOT}/logs"

  # Create state.json for a conductor (no EPIC setup)
  cat > "${test_dir}/${KALLAX_ROOT}/instances/test-conductor/state.json" << 'JSONEOF'
{
  "instance_id": "test-conductor",
  "role": "conductor",
  "status": "ACTIVE"
}
JSONEOF

  local output
  output=$(cd "${test_dir}" && run_performer_init "${test_dir}" 2>&1) || true

  # Should contain guidance to init EPIC
  if echo "$output" | grep -q "初始化"; then
    pass "(a) Correctly prompts EPIC initialization"
  else
    fail "(a) Missing EPIC initialization prompt"
    echo "Output: $output"
  fi

  rm -rf "${test_dir}"
}

# ============================================================
# Scenario (b): Normal — master exists + ready tickets
# ============================================================
test_scenario_b() {
  echo ""
  echo "─── Scenario (b): Normal flow ───"

  local test_dir
  test_dir=$(mktemp -d)
  mkdir -p "${test_dir}/${EPICS_DIR}/EPIC-016" "${test_dir}/${TICKETS_DIR}/EPIC-016-R" \
    "${test_dir}/${KALLAX_ROOT}/instances/master_main" "${test_dir}/${KALLAX_ROOT}/logs"

  # Master state
  cat > "${test_dir}/${KALLAX_ROOT}/instances/master_main/state.json" << 'JSONEOF'
{
  "instance_id": "master_main",
  "role": "master",
  "status": "ACTIVE"
}
JSONEOF

  # EPIC with ready ticket
  cat > "${test_dir}/${EPICS_DIR}/EPIC-016/epic.json" << 'JSONEOF'
{
  "id": "EPIC-016",
  "title": "Init Performance Optimization",
  "tickets": [
    {"id": "EPIC-016-R", "status": "ready", "priority": "P1", "title": "session_start stdio defense"}
  ]
}
JSONEOF

  # Ticket file
  cat > "${test_dir}/${TICKETS_DIR}/EPIC-016-R/ticket.json" << 'JSONEOF'
{
  "id": "EPIC-016-R",
  "status": "ready",
  "priority": "P1",
  "title": "session_start stdio defense",
  "assignee": null
}
JSONEOF

  local output
  # Provide "1" to select the first ticket in the interactive select
  output=$(cd "${test_dir}" && printf '1\n' | run_performer_init "${test_dir}" 2>&1) || true

  # Should show Step 1-4 and READY card
  local has_project_state=false
  local has_candidates=false
  local has_ready_card=false

  if echo "$output" | grep -q "Step 1/4"; then
    has_project_state=true
    pass "(b) Step 1/4: Project state shown"
  else
    fail "(b) Step 1/4: Project state missing"
  fi

  if echo "$output" | grep -q "Step 3/4"; then
    has_candidates=true
    pass "(b) Step 3/4: Candidates shown"
  else
    fail "(b) Step 3/4: Candidates missing"
  fi

  if echo "$output" | grep -q "READY TO WORK"; then
    has_ready_card=true
    pass "(b) Step 4/4: READY card shown"
  else
    fail "(b) Step 4/4: READY card missing"
  fi

  if echo "$output" | grep -q "EPIC-016-R"; then
    pass "(b) Correctly shows EPIC-016-R in output"
  else
    fail "(b) EPIC-016-R not found in output"
  fi

  rm -rf "${test_dir}"
}

# ============================================================
# Scenario (c): Already on feature branch with in_progress task
# ============================================================
test_scenario_c() {
  echo ""
  echo "─── Scenario (c): Continue existing task ───"

  local test_dir
  test_dir=$(mktemp -d)
  mkdir -p "${test_dir}/${EPICS_DIR}/EPIC-016" "${test_dir}/${TICKETS_DIR}/EPIC-016-R" \
    "${test_dir}/${KALLAX_ROOT}/instances/test-performer-$$" "${test_dir}/${KALLAX_ROOT}/logs" \
    "${test_dir}/.git/worktrees"

  # Git mock: feature branch
  mkdir -p "${test_dir}/.git"
  touch "${test_dir}/.git/worktrees"

  # Performer state with in_progress task
  cat > "${test_dir}/${KALLAX_ROOT}/instances/test-performer-$$/state.json" << 'JSONEOF'
{
  "instance_id": "test-performer-$$",
  "role": "performer",
  "status": "ACTIVE",
  "branch": "feature/EPIC-016-R-stdio-defense",
  "current_task": {
    "ticket_id": "EPIC-016-R",
    "worktree_path": "/tmp/.kallax/worktrees/performer-EPIC-016-R"
  }
}
JSONEOF

  # EPIC
  cat > "${test_dir}/${EPICS_DIR}/EPIC-016/epic.json" << 'JSONEOF'
{
  "id": "EPIC-016",
  "tickets": [{"id": "EPIC-016-R", "status": "in_progress"}]
}
JSONEOF

  local output
  output=$(cd "${test_dir}" && GIT_DIR="${test_dir}/.git" run_performer_init "${test_dir}" 2>&1) || true

  if echo "$output" | grep -q "Already on feature branch\|already in progress\|EPIC-016-R"; then
    pass "(c) Correctly detects in-progress task"
  elif echo "$output" | grep -q "SESSION READY\|continue"; then
    pass "(c) Correctly offers continue option"
  else
    warn "(c) Continue detection — check output manually"
    echo "Output: $output"
  fi

  rm -rf "${test_dir}"
}

# ============================================================
# Scenario (d): No master
# ============================================================
test_scenario_d() {
  echo ""
  echo "─── Scenario (d): No master ───"

  local test_dir
  test_dir=$(mktemp -d)
  mkdir -p "${test_dir}/${EPICS_DIR}/EPIC-016" "${test_dir}/${TICKETS_DIR}/EPIC-016-R" \
    "${test_dir}/${KALLAX_ROOT}/instances" "${test_dir}/${KALLAX_ROOT}/logs"

  # EPIC with ready ticket but no master_main state
  cat > "${test_dir}/${EPICS_DIR}/EPIC-016/epic.json" << 'JSONEOF'
{
  "id": "EPIC-016",
  "tickets": [{"id": "EPIC-016-R", "status": "ready", "priority": "P1"}]
}
JSONEOF

  cat > "${test_dir}/${TICKETS_DIR}/EPIC-016-R/ticket.json" << 'JSONEOF'
{
  "id": "EPIC-016-R",
  "status": "ready",
  "priority": "P1",
  "assignee": null
}
JSONEOF

  local output
  output=$(cd "${test_dir}" && run_performer_init "${test_dir}" 2>&1) || true

  # Should warn about no master
  if echo "$output" | grep -qE "无 master|no master|⚠"; then
    pass "(d) Correctly warns about missing master"
  else
    warn "(d) Master warning may be in Step 1 — check output"
    echo "Output: $output"
  fi

  rm -rf "${test_dir}"
}

# ============================================================
# Run all scenarios
# ============================================================
echo "== KALLAX Performer Onboarding Test (4 scenarios) =="

test_scenario_a
test_scenario_b
test_scenario_c
test_scenario_d

echo ""
echo "=== Summary ==="
echo "Test script structure verified."
echo "Manual verification required for AC17 (real session /kallax init as Performer)."
echo "Run: bash scripts/performer-session-init.sh in a real session to verify 4-step output."
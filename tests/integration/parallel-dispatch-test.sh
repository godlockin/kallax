#!/bin/bash
# parallel-dispatch-test.sh — Integration test for parallel-dispatch.sh
#
# Tests AC (EPIC-015-I ticket.json):
#   1. 读取 epic.json → 分析 ticket 依赖关系
#   2. 无依赖的 tickets → 默认并行
#   3. 有依赖的 tickets → 串行链
#   4. 输出调度计划: 并行组 + 串行链
#   5. dry-run 模式预览
#   6. 1 张卡或无依赖冲突 → 串行
#
# Source: EPIC-015-I ticket.json AC (跟 1 ticket 1 subagent 串行 联合)

set -uo pipefail

readonly TEST_ID="$$"
readonly TEST_DIR="/tmp/kallax-parallel-dispatch-test-${TEST_ID}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly DISPATCH="${KALLAX_ROOT}/scripts/parallel-dispatch.sh"

PASS=0
FAIL=0

log_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
log_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

cleanup() {
  if [[ -d "$TEST_DIR" ]]; then
    # Remove worktrees inside temp repo first (if any)
    if [[ -d "$TEST_DIR/repo" ]]; then
      (cd "$TEST_DIR/repo" && git worktree prune 2>/dev/null || true)
    fi
    rm -rf "$TEST_DIR"
  fi
}
trap cleanup EXIT

#===============================================================================
# Setup: build temp git repo + 3 synthetic epics
#   - EPIC-PARALLEL-3: 3 tickets, no deps → expect parallel group
#   - EPIC-SINGLE-1:   1 ticket, no deps  → expect serial/single mode
#   - EPIC-DEPS-3:     3 tickets, T2 deps T1, T3 deps T2 → expect serial chain
#===============================================================================
setup_test_repo() {
  mkdir -p "$TEST_DIR/repo"
  cd "$TEST_DIR/repo"

  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "test" > README.md
  git add .
  git commit -q -m "initial" >/dev/null

  # --- EPIC-PARALLEL-3: 3 independent tickets ---
  local EPIC_DIR="$TEST_DIR/repo/jira/epics/EPIC-PARALLEL-3"
  mkdir -p "$EPIC_DIR"
  for tid in EPIC-PARALLEL-3-A EPIC-PARALLEL-3-B EPIC-PARALLEL-3-C; do
    local TDIR="$TEST_DIR/repo/jira/tickets/${tid}"
    mkdir -p "$TDIR"
    cat > "${TDIR}/ticket.json" <<EOF
{
  "id": "${tid}",
  "epicId": "EPIC-PARALLEL-3",
  "status": "backlog",
  "title": "ticket ${tid}",
  "priority": "P1"
}
EOF
  done
  cat > "${EPIC_DIR}/epic.json" <<EOF
{
  "id": "EPIC-PARALLEL-3",
  "phase": "PHASE-TEST",
  "title": "parallel test epic",
  "status": "active",
  "tickets": [
    { "id": "EPIC-PARALLEL-3-A", "status": "backlog" },
    { "id": "EPIC-PARALLEL-3-B", "status": "backlog" },
    { "id": "EPIC-PARALLEL-3-C", "status": "backlog" }
  ]
}
EOF

  # --- EPIC-SINGLE-1: 1 ticket → single mode ---
  EPIC_DIR="$TEST_DIR/repo/jira/epics/EPIC-SINGLE-1"
  mkdir -p "$EPIC_DIR"
  TDIR="$TEST_DIR/repo/jira/tickets/EPIC-SINGLE-1-A"
  mkdir -p "$TDIR"
  cat > "${TDIR}/ticket.json" <<'EOF'
{
  "id": "EPIC-SINGLE-1-A",
  "epicId": "EPIC-SINGLE-1",
  "status": "backlog",
  "title": "single ticket",
  "priority": "P0"
}
EOF
  cat > "${EPIC_DIR}/epic.json" <<'EOF'
{
  "id": "EPIC-SINGLE-1",
  "phase": "PHASE-TEST",
  "title": "single test epic",
  "status": "active",
  "tickets": [
    { "id": "EPIC-SINGLE-1-A", "status": "backlog" }
  ]
}
EOF

  # --- EPIC-DEPS-3: 3 tickets with chained deps ---
  EPIC_DIR="$TEST_DIR/repo/jira/epics/EPIC-DEPS-3"
  mkdir -p "$EPIC_DIR"
  TDIR="$TEST_DIR/repo/jira/tickets/EPIC-DEPS-3-A"
  mkdir -p "$TDIR"
  cat > "${TDIR}/ticket.json" <<'EOF'
{
  "id": "EPIC-DEPS-3-A",
  "epicId": "EPIC-DEPS-3",
  "status": "backlog",
  "title": "first dep ticket",
  "priority": "P1"
}
EOF
  TDIR="$TEST_DIR/repo/jira/tickets/EPIC-DEPS-3-B"
  mkdir -p "$TDIR"
  cat > "${TDIR}/ticket.json" <<'EOF'
{
  "id": "EPIC-DEPS-3-B",
  "epicId": "EPIC-DEPS-3",
  "status": "backlog",
  "title": "second dep ticket",
  "priority": "P1",
  "dependencies": ["EPIC-DEPS-3-A"]
}
EOF
  TDIR="$TEST_DIR/repo/jira/tickets/EPIC-DEPS-3-C"
  mkdir -p "$TDIR"
  cat > "${TDIR}/ticket.json" <<'EOF'
{
  "id": "EPIC-DEPS-3-C",
  "epicId": "EPIC-DEPS-3",
  "status": "backlog",
  "title": "third dep ticket",
  "priority": "P1",
  "dependencies": ["EPIC-DEPS-3-B"]
}
EOF
  cat > "${EPIC_DIR}/epic.json" <<'EOF'
{
  "id": "EPIC-DEPS-3",
  "phase": "PHASE-TEST",
  "title": "deps test epic",
  "status": "active",
  "tickets": [
    { "id": "EPIC-DEPS-3-A", "status": "backlog" },
    { "id": "EPIC-DEPS-3-B", "status": "backlog" },
    { "id": "EPIC-DEPS-3-C", "status": "backlog" }
  ]
}
EOF
}

#===============================================================================
# Test 1: script exists + is executable
#===============================================================================
test_script_exists() {
  echo ""
  echo "=== Test 1: script exists + executable ==="
  if [[ -f "$DISPATCH" ]] && [[ -x "$DISPATCH" ]]; then
    log_pass "script exists at $DISPATCH and is executable"
  else
    log_fail "script missing or not executable at $DISPATCH"
  fi
}

#===============================================================================
# Test 2: no args → fail (exit != 0)
#===============================================================================
test_no_args_fails() {
  echo ""
  echo "=== Test 2: no args → exit != 0 ==="
  local rc
  bash "$DISPATCH" >/dev/null 2>&1
  rc=$?
  if [[ $rc -ne 0 ]]; then
    log_pass "no args → exit=$rc (expected non-zero)"
  else
    log_fail "no args → exit=$rc (expected non-zero)"
  fi
}

#===============================================================================
# Test 3: missing epic → fail (exit != 0)
#===============================================================================
test_missing_epic_fails() {
  echo ""
  echo "=== Test 3: missing epic → exit != 0 ==="
  local rc
  bash "$DISPATCH" "EPIC-DOES-NOT-EXIST-XYZ" --dry-run >/dev/null 2>&1
  rc=$?
  if [[ $rc -ne 0 ]]; then
    log_pass "missing epic → exit=$rc (expected non-zero)"
  else
    log_fail "missing epic → exit=$rc (expected non-zero)"
  fi
}

#===============================================================================
# Test 4: AC1+AC2 — read epic, parallel group for 3 independent tickets
#===============================================================================
test_parallel_group() {
  echo ""
  echo "=== Test 4: AC1+AC2 — 3 independent tickets → parallel group ==="
  local output
  output=$(bash "$DISPATCH" "EPIC-PARALLEL-3" --dry-run 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log_fail "dry-run exit=$rc (expected 0)"
    echo "    output: $output"
    return 1
  fi
  # Expect "Parallel: 3 | Serial: 0 | Total: 3" in footer
  if echo "$output" | grep -qE "Parallel:[[:space:]]*3[[:space:]]*\|.*Serial:[[:space:]]*0"; then
    log_pass "AC4: footer reports Parallel: 3 | Serial: 0"
  else
    log_fail "AC4: footer missing Parallel: 3 | Serial: 0"
    echo "    output: $output"
  fi
  # Expect all 3 ticket IDs in parallel list
  local missing=0
  for tid in EPIC-PARALLEL-3-A EPIC-PARALLEL-3-B EPIC-PARALLEL-3-C; do
    if ! echo "$output" | grep -q "${tid}"; then
      log_fail "AC2: ticket ${tid} missing from output"
      missing=1
    fi
  done
  if [[ $missing -eq 0 ]]; then
    log_pass "AC2: all 3 independent tickets listed as parallel"
  fi
}

#===============================================================================
# Test 5: AC6 — single ticket → serial mode
#===============================================================================
test_single_ticket_serial() {
  echo ""
  echo "=== Test 5: AC6 — single ticket → serial mode ==="
  local output
  output=$(bash "$DISPATCH" "EPIC-SINGLE-1" --dry-run 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log_fail "dry-run exit=$rc (expected 0)"
    return 1
  fi
  if echo "$output" | grep -q "Single ticket → serial mode"; then
    log_pass "AC6: single ticket → serial mode marker"
  else
    log_fail "AC6: missing 'Single ticket → serial mode' marker"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 6: AC3 — deps → serial chain
#===============================================================================
test_deps_serial_chain() {
  echo ""
  echo "=== Test 6: AC3 — deps → serial chain ==="
  local output
  output=$(bash "$DISPATCH" "EPIC-DEPS-3" --dry-run 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log_fail "dry-run exit=$rc (expected 0)"
    return 1
  fi
  # B has dep A → "With dependencies (serial): 2 EPIC-DEPS-3-B EPIC-DEPS-3-C"
  if echo "$output" | grep -qE "With dependencies.*EPIC-DEPS-3-B"; then
    log_pass "AC3: B (with dep A) listed in serial chain"
  else
    log_fail "AC3: B not found in serial chain"
    echo "    output: $output"
  fi
  if echo "$output" | grep -qE "With dependencies.*EPIC-DEPS-3-C"; then
    log_pass "AC3: C (with dep B) listed in serial chain"
  else
    log_fail "AC3: C not found in serial chain"
    echo "    output: $output"
  fi
  # A has no deps → parallel group (1 ticket)
  if echo "$output" | grep -qE "Independent.*EPIC-DEPS-3-A"; then
    log_pass "AC2+AC3: A (no deps) listed as independent"
  else
    log_fail "AC2+AC3: A not found in independent group"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 7: AC5 — dry-run doesn't create worktrees / branches
#===============================================================================
test_dry_run_no_side_effects() {
  echo ""
  echo "=== Test 7: AC5 — dry-run no side effects ==="
  # Snapshot worktree + branch list before
  local wt_before br_before
  wt_before=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
  br_before=$(git branch --list | wc -l | tr -d ' ')

  bash "$DISPATCH" "EPIC-PARALLEL-3" --dry-run >/dev/null 2>&1

  local wt_after br_after
  wt_after=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
  br_after=$(git branch --list | wc -l | tr -d ' ')

  if [[ "$wt_before" == "$wt_after" ]]; then
    log_pass "AC5: dry-run did not create worktree (count $wt_before → $wt_after)"
  else
    log_fail "AC5: dry-run created worktree (count $wt_before → $wt_after)"
  fi
  if [[ "$br_before" == "$br_after" ]]; then
    log_pass "AC5: dry-run did not create branch (count $br_before → $br_after)"
  else
    log_fail "AC5: dry-run created branch (count $br_before → $br_after)"
  fi
}

#===============================================================================
# Test 8: real dispatch creates worktrees for parallel group (cleanup after)
#===============================================================================
test_real_dispatch_creates_worktrees() {
  echo ""
  echo "=== Test 8: real dispatch creates worktrees ==="
  local wt_before br_before
  wt_before=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
  br_before=$(git branch --list | wc -l | tr -d ' ')

  bash "$DISPATCH" "EPIC-PARALLEL-3" >/dev/null 2>&1
  local rc=$?

  local wt_after br_after
  wt_after=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
  br_after=$(git branch --list | wc -l | tr -d ' ')

  local wt_delta=$((wt_after - wt_before))
  local br_delta=$((br_after - br_before))

  if [[ $rc -eq 0 ]] && [[ $wt_delta -eq 3 ]]; then
    log_pass "real dispatch created 3 worktrees (count $wt_before → $wt_after)"
  else
    log_fail "real dispatch did not create 3 worktrees (rc=$rc, count $wt_before → $wt_after, delta=$wt_delta)"
  fi
  if [[ $br_delta -eq 3 ]]; then
    log_pass "real dispatch created 3 branches (count $br_before → $br_after)"
  else
    log_fail "real dispatch did not create 3 branches (count $br_before → $br_after, delta=$br_delta)"
  fi

  # Cleanup: remove worktrees + branches so test is idempotent
  for tid in EPIC-PARALLEL-3-A EPIC-PARALLEL-3-B EPIC-PARALLEL-3-C; do
    local safe_id branch wt
    safe_id=$(echo "${tid}" | tr '[:upper:]' '[:lower:]')
    branch="feature/${safe_id}"
    wt=".claude/worktrees/performer-${safe_id}"
    git worktree remove --force "${wt}" 2>/dev/null || true
    git branch -D "${branch}" 2>/dev/null || true
  done
}

#===============================================================================
# Main
#===============================================================================
echo "=== Parallel Dispatch Integration Tests (EPIC-015-I) ==="
setup_test_repo

test_script_exists
test_no_args_fails
test_missing_epic_fails
test_parallel_group
test_single_ticket_serial
test_deps_serial_chain
test_dry_run_no_side_effects
test_real_dispatch_creates_worktrees

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
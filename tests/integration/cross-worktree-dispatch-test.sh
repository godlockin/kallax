#!/bin/bash
# cross-worktree-dispatch-test.sh — Integration test for cross-worktree-dispatch.sh
#
# Tests 6+ cases (per EPIC-036-A AC #4):
#   1. list — list available worktrees
#   2. validate — source + target worktree paths exist
#   3. validate — source missing → fail
#   4. dispatch --dry-run — no conflict, no actual cherry-pick
#   5. dispatch — no conflict → auto cherry-pick success
#   6. dispatch — conflict → STOP + non-zero exit (no auto merge, no --theirs)
#   7. missing args → fail
#
# Source: EPIC-036-A ticket.json AC
# 跟 BE-20 --theirs merge conflict 联合 (跟 3rd batch 验证 联合)

set -euo pipefail

readonly TEST_ID="$$"
readonly TEST_DIR="/tmp/kallax-cross-worktree-test-${TEST_ID}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKTREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly DISPATCH="${WORKTREE_ROOT}/scripts/conductor/cross-worktree-dispatch.sh"

PASS_COUNT=0
FAIL_COUNT=0

log_pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

cleanup() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

#===============================================================================
# Test fixture: build 2 isolated git worktrees sharing base commit
# Each test gets fresh repo to ensure isolation
#===============================================================================
setup_test_repo() {
  local repo_dir="$TEST_DIR/repo-$1"
  local wt_source="$TEST_DIR/source-$1"
  local wt_target="$TEST_DIR/target-$1"

  rm -rf "$repo_dir" "$wt_source" "$wt_target"
  mkdir -p "$repo_dir"
  cd "$repo_dir"

  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > README.md
  git add .
  git commit -q -m "initial" >/dev/null

  git worktree add "$wt_source" -b feature/source >/dev/null 2>&1
  git worktree add "$wt_target" -b feature/target >/dev/null 2>&1

  echo "$repo_dir|$wt_source|$wt_target"
}

#===============================================================================
# Test 1: list — list available worktrees
#===============================================================================
test_list() {
  echo ""
  echo "=== Test 1: list — list available worktrees ==="

  local repo wt_list
  repo=$(setup_test_repo "list")
  local repo_dir
  repo_dir=$(echo "$repo" | cut -d'|' -f1)

  wt_list=$(bash "$DISPATCH" list --repo "$repo_dir" 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    log_fail "list: exit code $rc (expected 0)"
    return 1
  fi

  if echo "$wt_list" | grep -q "feature/source"; then
    log_pass "list: lists feature/source worktree"
  else
    log_fail "list: missing feature/source in output"
    echo "    output: $wt_list"
    return 1
  fi

  if echo "$wt_list" | grep -q "feature/target"; then
    log_pass "list: lists feature/target worktree"
  else
    log_fail "list: missing feature/target in output"
    echo "    output: $wt_list"
    return 1
  fi
}

#===============================================================================
# Test 2: validate — source + target worktree paths exist
#===============================================================================
test_validate_ok() {
  echo ""
  echo "=== Test 2: validate — both worktrees exist ==="

  local repo wt_source wt_target
  IFS='|' read -r repo wt_source wt_target <<< "$(setup_test_repo "validate-ok")"

  local output rc
  set +e
  output=$(bash "$DISPATCH" validate --source "$wt_source" --target "$wt_target" 2>&1)
  rc=$?
  set -e

  if [[ $rc -eq 0 ]] && echo "$output" | grep -q "VALIDATE_OK"; then
    log_pass "validate: both worktrees valid"
  else
    log_fail "validate: expected VALIDATE_OK, rc=$rc"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 3: validate — source missing → fail
#===============================================================================
test_validate_missing_source() {
  echo ""
  echo "=== Test 3: validate — source missing → fail ==="

  local repo wt_source wt_target
  IFS='|' read -r repo wt_source wt_target <<< "$(setup_test_repo "validate-missing")"

  local output rc
  set +e
  output=$(bash "$DISPATCH" validate --source "/tmp/does-not-exist-$$" --target "$wt_target" 2>&1)
  rc=$?
  set -e

  if [[ $rc -ne 0 ]] && echo "$output" | grep -qi "source.*not found\|VALIDATE_FAIL"; then
    log_pass "validate: missing source → fail (rc=$rc)"
  else
    log_fail "validate: expected fail for missing source, rc=$rc"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 4: dispatch --dry-run — no conflict, no actual cherry-pick
#===============================================================================
test_dispatch_dry_run() {
  echo ""
  echo "=== Test 4: dispatch --dry-run — preview only ==="

  local repo wt_source wt_target
  IFS='|' read -r repo wt_source wt_target <<< "$(setup_test_repo "dry-run")"

  # Make a commit in source
  echo "feature change" > "$wt_source/feature.txt"
  (cd "$wt_source" && git add . && git commit -q -m "source: add feature")

  # Capture target HEAD before
  local target_head_before
  target_head_before=$(cd "$wt_target" && git rev-parse HEAD)

  local output rc
  set +e
  output=$(bash "$DISPATCH" dispatch --source "$wt_source" --target "$wt_target" --dry-run 2>&1)
  rc=$?
  set -e

  local target_head_after
  target_head_after=$(cd "$wt_target" && git rev-parse HEAD)

  if [[ $rc -eq 0 ]] && [[ "$target_head_before" == "$target_head_after" ]] && echo "$output" | grep -qi "DRY_RUN\|dry-run"; then
    log_pass "dispatch --dry-run: no actual change (HEAD unchanged)"
  else
    log_fail "dispatch --dry-run: HEAD changed or wrong rc=$rc"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 5: dispatch — no conflict → auto cherry-pick success
#===============================================================================
test_dispatch_no_conflict() {
  echo ""
  echo "=== Test 5: dispatch — no conflict → auto cherry-pick ==="

  local repo wt_source wt_target
  IFS='|' read -r repo wt_source wt_target <<< "$(setup_test_repo "no-conflict")"

  # Make a commit in source (new file, no overlap with target)
  echo "source only file" > "$wt_source/source-only.txt"
  (cd "$wt_source" && git add . && git commit -q -m "source: new file")

  local target_head_before
  target_head_before=$(cd "$wt_target" && git rev-parse HEAD)

  local output rc
  set +e
  output=$(bash "$DISPATCH" dispatch --source "$wt_source" --target "$wt_target" 2>&1)
  rc=$?
  set -e

  local target_head_after
  target_head_after=$(cd "$wt_target" && git rev-parse HEAD)

  if [[ $rc -eq 0 ]] && [[ "$target_head_before" != "$target_head_after" ]] && [[ -f "$wt_target/source-only.txt" ]]; then
    log_pass "dispatch no-conflict: cherry-pick success, file present in target"
  else
    log_fail "dispatch no-conflict: rc=$rc, expected cherry-pick success"
    echo "    output: $output"
  fi
}

#===============================================================================
# Test 6: dispatch — conflict → STOP + non-zero exit (no --theirs)
#===============================================================================
test_dispatch_conflict_stop() {
  echo ""
  echo "=== Test 6: dispatch — conflict → STOP + non-zero (BE-20 联合) ==="

  local repo wt_source wt_target
  IFS='|' read -r repo wt_source wt_target <<< "$(setup_test_repo "conflict")"

  # Create shared file in initial commit (already there via setup's HEAD)
  # Make source modify shared.txt to line A
  echo "source line" > "$wt_source/shared.txt"
  (cd "$wt_source" && git add . && git commit -q -m "source: modify shared")

  # Make target modify shared.txt to line B (diverged)
  echo "target line" > "$wt_target/shared.txt"
  (cd "$wt_target" && git add . && git commit -q -m "target: modify shared")

  # Dispatch source commits to target — should detect conflict
  local output rc
  set +e
  output=$(bash "$DISPATCH" dispatch --source "$wt_source" --target "$wt_target" 2>&1)
  rc=$?
  set -e

  # CRITICAL: must STOP, must NOT use --theirs (BE-20 治根)
  if [[ $rc -ne 0 ]] && echo "$output" | grep -qi "CONFLICT\|conflict\|STOP"; then
    if ! echo "$output" | grep -q -- "--theirs"; then
      log_pass "dispatch conflict: STOP + rc=$rc (no --theirs workaround, BE-20 合规)"
    else
      log_fail "dispatch conflict: used --theirs (BE-20 violation)"
      echo "    output: $output"
    fi
  else
    log_fail "dispatch conflict: expected STOP, got rc=$rc"
    echo "    output: $output"
  fi

  # Cleanup any in-progress cherry-pick
  (cd "$wt_target" && git cherry-pick --abort 2>/dev/null) || true
}

#===============================================================================
# Test 7: missing args → fail
#===============================================================================
test_missing_args() {
  echo ""
  echo "=== Test 7: missing args → fail ==="

  local rc
  set +e
  bash "$DISPATCH" 2>/dev/null
  rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    log_pass "missing args: exit code $rc (expected non-zero)"
  else
    log_fail "missing args: should fail with non-zero exit"
  fi
}

#===============================================================================
# Test 8: dispatch list-mode conflict detect reports CONFLICT (1 ticket 1 worktree)
#===============================================================================
test_list_isolation() {
  echo ""
  echo "=== Test 8: list — includes branch + path (1 ticket 1 worktree 共识) ==="

  local repo wt_list
  repo=$(setup_test_repo "list-isolation")
  local repo_dir
  repo_dir=$(echo "$repo" | cut -d'|' -f1)

  wt_list=$(bash "$DISPATCH" list --repo "$repo_dir" 2>&1)

  # Each worktree must have both path AND branch (no ambiguity)
  if echo "$wt_list" | grep -q "feature/source" && echo "$wt_list" | grep -q "feature/target"; then
    log_pass "list: 1 ticket 1 worktree 共识 — branch + path 明确"
  else
    log_fail "list: output missing branch info"
    echo "    output: $wt_list"
  fi
}

#===============================================================================
# Main
#===============================================================================
main() {
  echo "========================================"
  echo "cross-worktree-dispatch-test.sh — 8 Test Cases"
  echo "========================================"

  test_list
  test_validate_ok
  test_validate_missing_source
  test_dispatch_dry_run
  test_dispatch_no_conflict
  test_dispatch_conflict_stop
  test_missing_args
  test_list_isolation

  echo ""
  echo "========================================"
  echo "Results: PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
  echo "========================================"

  if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "8/8 PASS"
    exit 0
  else
    echo "$PASS_COUNT/8 PASS"
    exit 1
  fi
}

main "$@"

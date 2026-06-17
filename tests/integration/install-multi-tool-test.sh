#!/usr/bin/env bash
# tests/integration/install-multi-tool-test.sh — EPIC-057-A
# Integration tests for scripts/install.sh --target=flag (multi-tool support)
#
# Test cases (6/6 Rule 9 KPI):
#   Test 1: --target=auto + 4 工具 mock → 全装 (4 skills dirs created)
#   Test 2: --target=all + 0 工具 mock → 强制装 4 工具
#   Test 3: --target=claude + ~/.claude 不存在 → exit 1
#   Test 4: --target=opencode,codex (多工具逗号) → 装 2 工具
#   Test 5: --target=nonexistent → exit 1 (unknown tool)
#   Test 6: 0 工具 detected + 0 binary → exit 1 + suggestion
#
# Exit code: 0 iff 6/6 PASS (Rule 9 100.0%)
# Run from worktree root: ./tests/integration/install-multi-tool-test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SH="$KALLAX_ROOT/scripts/install.sh"

# Sanity: install.sh must exist
[[ -f "$INSTALL_SH" ]] || { echo "FATAL: $INSTALL_SH not found"; exit 99; }

PASS_COUNT=0
FAIL_COUNT=0
TEST_COUNT=0

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

run_test() {
  local name="$1"; local fn="$2"
  TEST_COUNT=$((TEST_COUNT + 1))
  echo ""
  echo "=== Test $TEST_COUNT: $name ==="
  if $fn; then pass "$name"; else fail "$name"; fi
}

# ── Helpers ──────────────────────────────────────────────────────────────

# Run install.sh with isolated HOME and PATH, return exit code; capture stdout/stderr.
# Args: <expected_exit_code> <output_var> <env_HOME> <env_PATH> -- <install.sh args...>
run_install() {
  local expected_exit="$1" out_var="$2" fake_home="$3" fake_path="$4"
  shift 4
  # remaining args = install.sh args (need to keep -- separator consumed)
  local captured
  set +e
  captured=$(HOME="$fake_home" PATH="$fake_path" \
    bash "$INSTALL_SH" "$@" 2>&1)
  local actual_exit=$?
  set -e
  eval "$out_var=\$captured"
  return $actual_exit
}

# Assert directory exists at $1 (test 1/2/4 main assertion)
assert_dir_exists() {
  local p="$1"
  [ -d "$p" ] || { echo "    expected dir: $p (missing)"; return 1; }
}

# Assert file exists at $1
assert_file_exists() {
  local p="$1"
  [ -f "$p" ] || { echo "    expected file: $p (missing)"; return 1; }
}

# ── Fixture builder ─────────────────────────────────────────────────────
# Builds a fake project root with source skills + commands dirs.
# install.sh reads $PROJECT_ROOT = parent of $SCRIPT_DIR = $KALLAX_ROOT.
# So we create a wrapper script that re-execs install.sh after copying itself
# to look like it's under a fake project. Actually simpler: source dirs already
# exist in real $KALLAX_ROOT, so we just need to isolate $HOME for detection.
# If source is missing (e.g. in fresh fixture), install.sh logs warn and skips —
# test still verifies detection + dispatch (skill dir created if source exists).

# ── Test 1: --target=auto + 4 mock → 全装 ──────────────────────────────
test_1_target_auto_4_tools() {
  local tmp; tmp=$(mktemp -d)
  # Mock all 4 base dirs
  for d in .claude .opencode .codex .gemini; do mkdir -p "$tmp/$d"; done
  local out
  set +e
  out=$(HOME="$tmp" bash "$INSTALL_SH" --target=auto 2>&1)
  local rc=$?
  set -e
  echo "    exit=$rc output=$out"
  [ "$rc" -eq 0 ] || { rm -rf "$tmp"; return 1; }
  local ok=true
  for tool in claude opencode codex gemini; do
    if ! assert_dir_exists "$tmp/.$tool/skills/kallax"; then ok=false; fi
  done
  rm -rf "$tmp"
  $ok
}

# ── Test 2: --target=all + 0 mock → 强制装 4 工具 ──────────────────────
test_2_target_all_force() {
  local tmp; tmp=$(mktemp -d)
  # No base dirs, no binaries (PATH=/usr/bin:/bin only minimal)
  local out
  set +e
  out=$(HOME="$tmp" PATH="/usr/bin:/bin" bash "$INSTALL_SH" --target=all 2>&1)
  local rc=$?
  set -e
  echo "    exit=$rc output=$out"
  [ "$rc" -eq 0 ] || { rm -rf "$tmp"; return 1; }
  local ok=true
  for tool in claude opencode codex gemini; do
    if ! assert_dir_exists "$tmp/.$tool/skills/kallax"; then ok=false; fi
  done
  rm -rf "$tmp"
  $ok
}

# ── Test 3: --target=claude + ~/.claude 不存在 → exit 1 ───────────────
test_3_target_claude_missing() {
  local tmp; tmp=$(mktemp -d)
  # No .claude base dir
  local out
  set +e
  out=$(HOME="$tmp" PATH="/usr/bin:/bin" bash "$INSTALL_SH" --target=claude 2>&1)
  local rc=$?
  set -e
  echo "    exit=$rc output=$out"
  rm -rf "$tmp"
  # Expect exit non-zero (specific tool explicit but not detected)
  [ "$rc" -ne 0 ] || return 1
  # Expect error message mentions claude or "not detected"
  echo "$out" | grep -iqE "(claude|detect|missing|not found)" || return 1
  return 0
}

# ── Test 4: --target=opencode,codex → 装 2 工具 ─────────────────────────
test_4_target_multi_comma() {
  local tmp; tmp=$(mktemp -d)
  # Mock all 4 base dirs (so install proceeds for the 2 we asked)
  for d in .claude .opencode .codex .gemini; do mkdir -p "$tmp/$d"; done
  local out
  set +e
  out=$(HOME="$tmp" bash "$INSTALL_SH" --target=opencode,codex 2>&1)
  local rc=$?
  set -e
  echo "    exit=$rc output=$out"
  [ "$rc" -eq 0 ] || { rm -rf "$tmp"; return 1; }
  local ok=true
  # opencode + codex MUST be installed
  assert_dir_exists "$tmp/.opencode/skills/kallax" || ok=false
  assert_dir_exists "$tmp/.codex/skills/kallax" || ok=false
  # claude + gemini MUST NOT be installed (user didn't ask)
  if [ -d "$tmp/.claude/skills/kallax" ]; then
    echo "    unexpected: .claude/skills/kallax was created (should not be)"
    ok=false
  fi
  if [ -d "$tmp/.gemini/skills/kallax" ]; then
    echo "    unexpected: .gemini/skills/kallax was created (should not be)"
    ok=false
  fi
  rm -rf "$tmp"
  $ok
}

# ── Test 5: --target=nonexistent → exit 1 ───────────────────────────────
test_5_target_unknown_tool() {
  local tmp; tmp=$(mktemp -d)
  local out
  set +e
  out=$(HOME="$tmp" PATH="/usr/bin:/bin" bash "$INSTALL_SH" --target=nonexistent 2>&1)
  local rc=$?
  set -e
  echo "    exit=$rc output=$out"
  rm -rf "$tmp"
  [ "$rc" -ne 0 ] || return 1
  echo "$out" | grep -iqE "(unknown|invalid|unsupported|nonexistent)" || return 1
  return 0
}

# ── Test 6: 0 detected + 0 binary → exit 1 + suggestion ─────────────────
test_6_no_tools_detected() {
  local tmp; tmp=$(mktemp -d)
  local out
  set +e
  out=$(HOME="$tmp" PATH="/usr/bin:/bin" bash "$INSTALL_SH" --target=auto 2>&1)
  local rc=$?
  set -e
  echo "    exit=$rc output=$out"
  rm -rf "$tmp"
  [ "$rc" -ne 0 ] || return 1
  # Expect suggestion (--target=all or install hint)
  echo "$out" | grep -iqE "(target=all|install|available|tool)" || return 1
  return 0
}

# ── Run ──────────────────────────────────────────────────────────────────

echo "=========================================="
echo "EPIC-057-A install-multi-tool integration"
echo "=========================================="
echo "Root: $KALLAX_ROOT"
echo "Install.sh: $INSTALL_SH"
echo "Bash: ${BASH_VERSION}"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

run_test "target=auto + 4 mock → all 4 installed" test_1_target_auto_4_tools
run_test "target=all + 0 mock → force all 4" test_2_target_all_force
run_test "target=claude + no ~/.claude → exit 1" test_3_target_claude_missing
run_test "target=opencode,codex → install 2 only" test_4_target_multi_comma
run_test "target=nonexistent → exit 1" test_5_target_unknown_tool
run_test "0 tools + 0 binary → exit 1 + suggestion" test_6_no_tools_detected

echo ""
echo "=========================================="
echo "SUMMARY: ${PASS_COUNT}/${TEST_COUNT} PASS (${FAIL_COUNT} FAIL)"
echo "=========================================="

# Rule 9 KPI enforcement: 6/6 = 100.0%
if [ "$PASS_COUNT" -eq 6 ] && [ "$FAIL_COUNT" -eq 0 ]; then
  echo "Rule 9 KPI: 6/6 = 100.0% ✅"
  exit 0
else
  # bash 3.2 compat: integer math only
  echo "Rule 9 KPI: ${PASS_COUNT}/6 = $(( PASS_COUNT * 100 / 6 ))% ❌"
  exit 1
fi
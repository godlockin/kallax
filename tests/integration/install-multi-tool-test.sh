#!/usr/bin/env bash
# tests/integration/install-multi-tool-test.sh — EPIC-057-A (6/6) + EPIC-057-D (8/8)
# Integration tests for scripts/install.sh --target=flag (multi-tool support)
#
# Test cases (8/8 Rule 9 KPI, EPIC-057-D ticket AC#1):
#   Test 1: --target=auto + 4 工具 mock → 全装 (4 skills dirs created)
#   Test 2: --target=all + 0 工具 mock → 强制装 4 工具
#   Test 3: --target=claude + ~/.claude 不存在 → exit 1
#   Test 4: --target=opencode,codex (多工具逗号) → 装 2 工具
#   Test 5: --target=nonexistent → exit 1 (unknown tool)
#   Test 6: 0 工具 detected + 0 binary → exit 1 + suggestion
#   Test 7 (EPIC-057-D): SKILL.md loadable — 装完后 ~/.claude/skills/kallax/SKILL.md
#           存在 + frontmatter 含 `name:` + ≥14 files
#   Test 8 (EPIC-057-D): permissions configured — 装完后 ~/.claude/settings.json
#           存在 + .permissions.auto 含 "Bash:.claude/commands/*.sh" (jq verify)
#
# Exit code: 0 iff 8/8 PASS (Rule 9 100.0%)
# Run from worktree root: ./tests/integration/install-multi-tool-test.sh
#
# EPIC-057-D 拓展背景: 057-A 写了 6/6, 跟 ticket AC#1 8/8 不符.
# 057-D (this ticket) 闭环 AC#1 by appending TC7 + TC8 (file_scope 明确 include 此 file).
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

# ── Test 7 (EPIC-057-D NEW): SKILL.md loadable ─────────────────────────
# 装完后 ~/.claude/skills/kallax/SKILL.md 存在 + frontmatter 含 "name:" + ≥14 files
# 验证 skills 不只是 mkdir, 而是 real content (避免空目录假成功)
test_7_skill_md_loadable() {
  local tmp; tmp=$(mktemp -d)
  # Mock all 4 base dirs → --target=auto 全装 → 全 4 tools 都有 skills
  for d in .claude .opencode .codex .gemini; do mkdir -p "$tmp/$d"; done
  set +e
  HOME="$tmp" bash "$INSTALL_SH" --target=auto >/dev/null 2>&1
  local rc=$?
  set -e
  [ "$rc" -eq 0 ] || { echo "    install failed rc=$rc"; rm -rf "$tmp"; return 1; }
  local skill="$tmp/.claude/skills/kallax/SKILL.md"
  # Assertion 1: file exists
  [ -f "$skill" ] || { echo "    missing: $skill"; rm -rf "$tmp"; return 1; }
  # Assertion 2: frontmatter contains "name:" (loadable = parseable)
  grep -qE "^name:" "$skill" || { echo "    SKILL.md frontmatter missing 'name:'"; rm -rf "$tmp"; return 1; }
  # Assertion 3: skills dir has ≥14 files (跟 install.sh verification 数字一致)
  local n
  n=$(find "$tmp/.claude/skills/kallax" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n" -lt 14 ]; then
    echo "    skills dir only has $n files (expected ≥14)"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
  return 0
}

# ── Test 8 (EPIC-057-D NEW): permissions configured ────────────────────
# 装完后 ~/.claude/settings.json 存在 + .permissions.auto 含
# "Bash:.claude/commands/*.sh" (jq verify, 跟 install.sh:418 契约)
# Note: 仅 claude 自动配, opencode/codex/gemini 是 best-effort hint (跟 install.sh:448-476 一致)
test_8_permissions_configured() {
  local tmp; tmp=$(mktemp -d)
  for d in .claude .opencode .codex .gemini; do mkdir -p "$tmp/$d"; done
  set +e
  HOME="$tmp" bash "$INSTALL_SH" --target=auto >/dev/null 2>&1
  local rc=$?
  set -e
  [ "$rc" -eq 0 ] || { echo "    install failed rc=$rc"; rm -rf "$tmp"; return 1; }
  local settings="$tmp/.claude/settings.json"
  # Assertion 1: settings.json exists
  [ -f "$settings" ] || { echo "    missing: $settings"; rm -rf "$tmp"; return 1; }
  # Assertion 2: jq available (跟 install.sh:416 条件一致)
  if ! command -v jq >/dev/null 2>&1; then
    echo "    jq not available — cannot verify permissions (skip)"
    rm -rf "$tmp"
    return 0
  fi
  # Assertion 3: .permissions.auto contains expected glob
  local has_perm
  has_perm=$(jq -r '.permissions.auto // [] | map(select(. == "Bash:.claude/commands/*.sh")) | length' "$settings" 2>/dev/null || echo "0")
  if [ "$has_perm" = "0" ] || [ -z "$has_perm" ]; then
    echo "    permissions.auto missing 'Bash:.claude/commands/*.sh' (got length=$has_perm)"
    cat "$settings" | head -20
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
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
run_test "SKILL.md loadable (frontmatter + ≥14 files)" test_7_skill_md_loadable
run_test "permissions configured (settings.json + .permissions.auto)" test_8_permissions_configured

echo ""
echo "=========================================="
echo "SUMMARY: ${PASS_COUNT}/${TEST_COUNT} PASS (${FAIL_COUNT} FAIL)"
echo "=========================================="

# Rule 9 KPI enforcement: 8/8 = 100.0% (EPIC-057-D AC#1)
if [ "$PASS_COUNT" -eq 8 ] && [ "$FAIL_COUNT" -eq 0 ]; then
  echo "Rule 9 KPI: 8/8 = 100.0% ✅"
  exit 0
else
  # bash 3.2 compat: integer math only
  echo "Rule 9 KPI: ${PASS_COUNT}/8 = $(( PASS_COUNT * 100 / 8 ))% ❌"
  exit 1
fi
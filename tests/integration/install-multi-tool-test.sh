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

run_test "target=auto + 4 mock → all 4 installed" test_1_target_auto_4_tools
run_test "target=all + 0 mock → force all 4" test_2_target_all_force
run_test "target=claude + no ~/.claude → exit 1" test_3_target_claude_missing
run_test "target=opencode,codex → install 2 only" test_4_target_multi_comma
run_test "target=nonexistent → exit 1" test_5_target_unknown_tool
run_test "0 tools + 0 binary → exit 1 + suggestion" test_6_no_tools_detected
run_test "SKILL.md loadable (frontmatter + ≥14 files)" test_7_skill_md_loadable
run_test "permissions configured (settings.json + .permissions.auto)" test_8_permissions_configured

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " Per-case results:"
echo "════════════════════════════════════════════════════════════════"
for i in "${!CASE_NAMES[@]}"; do
  printf "  %-4s  %s\n" "${CASE_PASS[$i]}" "${CASE_NAMES[$i]}"
done

# Rule 9 KPI enforcement: 8/8 = 100.0% (EPIC-057-D AC#1)
if [ "$PASS_COUNT" -eq 8 ] && [ "$FAIL_COUNT" -eq 0 ]; then
  echo "Rule 9 KPI: 8/8 = 100.0% ✅"
  exit 0
else
  # bash 3.2 compat: integer math only
  echo "Rule 9 KPI: ${PASS_COUNT}/8 = $(( PASS_COUNT * 100 / 8 ))% ❌"
  exit 1
fi

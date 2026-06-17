#!/usr/bin/env bash
# tests/integration/onramp-tool-detect-test.sh — EPIC-057-B
# Integration tests for scripts/kallax-onramp/lib/tool-detect.sh + dispatch.sh
# 跟 install.sh 4 工具 paths 一致, 跟 "反讽" 闭环 (写死 claude → multi-tool)
#
# Test cases (6/6 Rule 9 KPI):
#   Test 1: claude detected (mock $HOME/.claude + PATH) → JSON.tool=="claude"
#   Test 2: opencode detected (mock $HOME/.opencode + PATH) → JSON.tool=="opencode"
#   Test 3: codex missing binary → fallback (no other tools) → exit 1
#   Test 4: gemini detected (mock $HOME/.gemini + PATH) → JSON.tool=="gemini"
#   Test 5: multi-tool priority (claude + opencode both) → claude wins
#   Test 6: no-tool fallback (0 detected) → stderr "No AI CLI tool detected" + exit 1
#
# Exit code: 0 iff 6/6 PASS (Rule 9 100.0%)
# Run from worktree root: ./tests/integration/onramp-tool-detect-test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TOOL_DETECT_SH="$KALLAX_ROOT/scripts/kallax-onramp/lib/tool-detect.sh"
DISPATCH_SH="$KALLAX_ROOT/scripts/kallax-onramp/lib/dispatch.sh"

# Sanity: scripts must exist
[[ -f "$TOOL_DETECT_SH" ]] || { echo "FATAL: $TOOL_DETECT_SH not found"; exit 99; }
[[ -f "$DISPATCH_SH" ]] || { echo "FATAL: $DISPATCH_SH not found"; exit 99; }

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

# Build a tmpdir with: $HOME (base config dir), $BIN (with fake binaries).
# Args: <tools_with_dir>... (e.g. "claude" "opencode")
# Stdout: path to tmpdir. Creates $tmp/.<tool>/ + $tmp/bin/<tool> fake binary.
# Note: caller captures via $(make_fake_env ...) — eval-in-parent doesn't work
# when caller uses `local tmp` (eval stays in function scope).
make_fake_env() {
  local tmp; tmp=$(mktemp -d)
  local t bin_dir="$tmp/bin"
  mkdir -p "$bin_dir"
  for t in "$@"; do
    mkdir -p "$tmp/.$t"
    # Fake binary: prints "fake <tool> v1.0.0" — enough for our tests' assert
    cat > "$bin_dir/$t" <<EOF
#!/usr/bin/env bash
echo "fake $t v1.0.0"
EOF
    chmod +x "$bin_dir/$t"
  done
  echo "$tmp"
}

# Run tool-detect.sh with isolated HOME and PATH. Returns exit code, captures stdout+stderr.
# NOTE: PATH must include /bin + /usr/bin so bash + jq are findable when we override
# the test's PATH to a restricted set (e.g. for codex-missing-binary test).
run_detect() {
  local out_var="$1" fake_home="$2" fake_path="$3"
  local captured
  set +e
  captured=$(HOME="$fake_home" PATH="$fake_path:/bin:/usr/bin" \
    bash "$TOOL_DETECT_SH" 2>&1)
  local rc=$?
  set -e
  eval "$out_var=\$captured"
  return $rc
}

# ── Test 1: claude detected ──────────────────────────────────────────────
test_1_claude_detected() {
  local tmp bin_path
  tmp=$(make_fake_env "claude")
  bin_path="$tmp/bin"
  local out
  if ! run_detect out "$tmp" "$bin_path"; then
    echo "    tool-detect exit non-zero"; rm -rf "$tmp"; return 1
  fi
  echo "    output=$out"
  local tool
  tool=$(echo "$out" | jq -r '.tool' 2>/dev/null)
  [[ "$tool" == "claude" ]] || { echo "    expected tool=claude, got: $tool"; rm -rf "$tmp"; return 1; }
  local binary
  binary=$(echo "$out" | jq -r '.binary')
  [[ -n "$binary" && -x "$binary" ]] || { echo "    binary not executable: $binary"; rm -rf "$tmp"; return 1; }
  local skills
  skills=$(echo "$out" | jq -r '.skills_dir')
  [[ "$skills" == *"/.claude/skills/kallax/" ]] || { echo "    wrong skills_dir: $skills"; rm -rf "$tmp"; return 1; }
  local cmds
  cmds=$(echo "$out" | jq -r '.commands_dir')
  [[ "$cmds" == *"/.claude/commands/" ]] || { echo "    wrong commands_dir: $cmds"; rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  return 0
}

# ── Test 2: opencode detected ───────────────────────────────────────────
test_2_opencode_detected() {
  local tmp bin_path
  tmp=$(make_fake_env "opencode")
  bin_path="$tmp/bin"
  local out
  if ! run_detect out "$tmp" "$bin_path"; then
    echo "    tool-detect exit non-zero"; rm -rf "$tmp"; return 1
  fi
  echo "    output=$out"
  local tool
  tool=$(echo "$out" | jq -r '.tool' 2>/dev/null)
  [[ "$tool" == "opencode" ]] || { echo "    expected tool=opencode, got: $tool"; rm -rf "$tmp"; return 1; }
  local skills
  skills=$(echo "$out" | jq -r '.skills_dir')
  # opencode uses .opencode/skills/kallax/ (跟 install.sh 一致)
  [[ "$skills" == *"/.opencode/skills/kallax/" ]] || { echo "    wrong skills_dir: $skills"; rm -rf "$tmp"; return 1; }
  local cmds
  cmds=$(echo "$out" | jq -r '.commands_dir')
  # opencode commands_dir is SINGULAR: .opencode/command/ (跟 install.sh 一致)
  [[ "$cmds" == *"/.opencode/command/" ]] || { echo "    wrong commands_dir: $cmds"; rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  return 0
}

# ── Test 3: codex missing binary → fallback (no other) → exit 1 ────────
# 验证: 有 $HOME/.codex/ 但 PATH 无 codex binary → codex NOT detected
#        无任何其他工具 → 全失败 → exit 1 (跟 AC#5 fallback 联合)
test_3_codex_missing_binary() {
  local tmp bin_path
  tmp=$(make_fake_env "codex")
  # REMOVE the codex binary from PATH (intentionally missing binary)
  bin_path="/usr/bin:/bin"  # no $tmp/bin — codex binary unavailable
  local out
  set +e
  run_detect out "$tmp" "$bin_path"
  local rc=$?
  set -e
  echo "    exit=$rc output=$out"
  rm -rf "$tmp"
  # Expect exit 1: codex has dir but no binary → not detected
  # No other tools → all 4 fail → exit 1 + "No AI CLI tool detected" message
  [[ "$rc" -ne 0 ]] || { echo "    expected exit non-zero"; return 1; }
  echo "$out" | grep -iqE "no ai cli tool detected" || { echo "    missing fallback msg"; return 1; }
  return 0
}

# ── Test 4: gemini detected ─────────────────────────────────────────────
test_4_gemini_detected() {
  local tmp bin_path
  tmp=$(make_fake_env "gemini")
  bin_path="$tmp/bin"
  local out
  if ! run_detect out "$tmp" "$bin_path"; then
    echo "    tool-detect exit non-zero"; rm -rf "$tmp"; return 1
  fi
  echo "    output=$out"
  local tool
  tool=$(echo "$out" | jq -r '.tool' 2>/dev/null)
  [[ "$tool" == "gemini" ]] || { echo "    expected tool=gemini, got: $tool"; rm -rf "$tmp"; return 1; }
  local cmds
  cmds=$(echo "$out" | jq -r '.commands_dir')
  [[ "$cmds" == *"/.gemini/commands/" ]] || { echo "    wrong commands_dir: $cmds"; rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  return 0
}

# ── Test 5: multi-tool priority (claude wins over opencode) ─────────────
test_5_multi_tool_priority() {
  local tmp bin_path
  tmp=$(make_fake_env "claude" "opencode")
  bin_path="$tmp/bin"
  local out
  if ! run_detect out "$tmp" "$bin_path"; then
    echo "    tool-detect exit non-zero"; rm -rf "$tmp"; return 1
  fi
  echo "    output=$out"
  local tool
  tool=$(echo "$out" | jq -r '.tool' 2>/dev/null)
  # claude > opencode priority → claude wins
  [[ "$tool" == "claude" ]] || { echo "    expected priority winner=claude, got: $tool"; rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  return 0
}

# ── Test 6: no-tool fallback (0 detected) → exit 1 + suggestion ────────
test_6_no_tool_fallback() {
  local tmp bin_path
  tmp=$(mktemp -d)
  # No base dirs, no binaries
  bin_path="/usr/bin:/bin"
  local out
  set +e
  run_detect out "$tmp" "$bin_path"
  local rc=$?
  set -e
  echo "    exit=$rc output=$out"
  rm -rf "$tmp"
  [[ "$rc" -ne 0 ]] || { echo "    expected exit non-zero"; return 1; }
  # Expect fallback message (跟 AC#5 联合)
  echo "$out" | grep -iqE "no ai cli tool detected" || { echo "    missing 'No AI CLI tool detected' msg"; return 1; }
  # Expect suggestion: install claude hint
  echo "$out" | grep -iqE "install|claude" || { echo "    missing install suggestion"; return 1; }
  return 0
}

# ── Run ──────────────────────────────────────────────────────────────────

echo "=========================================="
echo "EPIC-057-B onramp-tool-detect integration"
echo "=========================================="
echo "Root: $KALLAX_ROOT"
echo "tool-detect.sh: $TOOL_DETECT_SH"
echo "dispatch.sh: $DISPATCH_SH"
echo "Bash: ${BASH_VERSION}"
echo "jq: $(jq --version 2>&1)"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

run_test "claude detected (mock HOME+PATH) → tool=claude" test_1_claude_detected
run_test "opencode detected (mock HOME+PATH) → tool=opencode" test_2_opencode_detected
run_test "codex dir only, no binary → exit 1 + fallback" test_3_codex_missing_binary
run_test "gemini detected (mock HOME+PATH) → tool=gemini" test_4_gemini_detected
run_test "claude + opencode both → claude wins (priority)" test_5_multi_tool_priority
run_test "0 tools + 0 binary → exit 1 + 'No AI CLI tool detected'" test_6_no_tool_fallback

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

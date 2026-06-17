#!/usr/bin/env bash
# tests/integration/multi-tool-e2e-test.sh — EPIC-057-D
# End-to-end integration test: install.sh + tool-detect.sh cross-contract
# 跨 EPIC-057-A (install) + EPIC-057-B (onramp tool-detect) 集成.
#
# Test cases (4/4 Rule 9 KPI, EPIC-057-D ticket AC#3):
#   Test 1: install → onramp flow (4 tools mock → install --target=all → tool-detect
#           picks claude (priority) — 验证 install + detect 路径 一致)
#   Test 2: --target=claude + no ~/.claude → exit 1 (跟 AC#7 联合, 跟 install TC3 一致)
#   Test 3: 0 tools + 0 binary → tool-detect exit 1 + 'install claude' suggestion (AC#8)
#   Test 4: cross-ticket consistency: install.sh TOOL_SKILLS_DIR 4 工具 paths ==
#           tool-detect.sh detected skills_dir paths (paths 必须对齐, 否则 onramp 选错工具)
#
# KALLAX_TEST_HOME 环境变量:
#   - 默认值: $HOME (跟 install.sh / tool-detect.sh 标准 bash 模式兼容)
#   - override: KALLAX_TEST_HOME=/tmp/foo bash multi-tool-e2e-test.sh
#   - 跟 EPIC-053-A l3-l4-consistency 环境隔离模式联动 (ticket AC#5)
#
# Exit code: 0 iff 4/4 PASS (Rule 9 100.0%)
# Run from worktree root: ./tests/integration/multi-tool-e2e-test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SH="$KALLAX_ROOT/scripts/install.sh"
TOOL_DETECT_SH="$KALLAX_ROOT/scripts/kallax-onramp/lib/tool-detect.sh"

# KALLAX_TEST_HOME layer (跟 053-A 隔离模式联动, ticket AC#5)
# 默认 $HOME — override 时 sets 整个 test suite 隔离.
KALLAX_TEST_HOME="${KALLAX_TEST_HOME:-$HOME}"
export KALLAX_TEST_HOME

# Sanity: scripts must exist
[[ -f "$INSTALL_SH" ]] || { echo "FATAL: $INSTALL_SH not found"; exit 99; }
[[ -f "$TOOL_DETECT_SH" ]] || { echo "FATAL: $TOOL_DETECT_SH not found"; exit 99; }

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

# Build a fake env: $HOME base + 4 工具 .<tool>/ dirs + $BIN with fake binaries.
# Args: <tools_to_mock>... (e.g. "claude" "opencode")
# Stdout: $tmp (caller captures). Creates $tmp/.<tool>/ + $tmp/bin/<tool> binary.
make_fake_env() {
  local tmp; tmp=$(mktemp -d)
  local t bin_dir="$tmp/bin"
  mkdir -p "$bin_dir"
  for t in "$@"; do
    mkdir -p "$tmp/.$t"
    cat > "$bin_dir/$t" <<EOF
#!/usr/bin/env bash
echo "fake $t v1.0.0"
EOF
    chmod +x "$bin_dir/$t"
  done
  echo "$tmp"
}

# Run install.sh with isolated HOME. Returns exit code, captures output.
run_install() {
  local out_var="$1" fake_home="$2"
  shift 2
  local captured
  set +e
  captured=$(HOME="$fake_home" bash "$INSTALL_SH" "$@" 2>&1)
  local rc=$?
  set -e
  eval "$out_var=\$captured"
  return $rc
}

# Run tool-detect.sh with isolated HOME + PATH. Returns exit code, captures output.
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

# ── Test 1: install → onramp flow (4 tools e2e) ────────────────────────
# install --target=all → 4 tools installed → tool-detect picks claude (priority)
test_1_install_onramp_flow() {
  local tmp bin_path out
  tmp=$(make_fake_env "claude" "opencode" "codex" "gemini")
  bin_path="$tmp/bin"
  # Step 1: install all 4 tools
  if ! run_install out "$tmp" --target=all >/dev/null; then
    echo "    install failed: $out"
    rm -rf "$tmp"; return 1
  fi
  # Verify all 4 skills dirs created
  local ok=true
  for tool in claude opencode codex gemini; do
    if [ ! -d "$tmp/.$tool/skills/kallax" ]; then
      echo "    missing install dir: $tmp/.$tool/skills/kallax"
      ok=false
    fi
  done
  if ! $ok; then rm -rf "$tmp"; return 1; fi
  # Step 2: onramp tool-detect → must pick claude (priority)
  if ! run_detect out "$tmp" "$bin_path"; then
    echo "    tool-detect failed: $out"
    rm -rf "$tmp"; return 1
  fi
  local tool
  tool=$(echo "$out" | jq -r '.tool' 2>/dev/null)
  if [ "$tool" != "claude" ]; then
    echo "    expected tool=claude (priority), got: $tool"
    rm -rf "$tmp"; return 1
  fi
  # Step 3: cross-verify skills_dir points to install location
  local detected_skills
  detected_skills=$(echo "$out" | jq -r '.skills_dir')
  if [ ! -d "$detected_skills" ]; then
    echo "    detected skills_dir missing: $detected_skills"
    rm -rf "$tmp"; return 1
  fi
  rm -rf "$tmp"
  return 0
}

# ── Test 2: --target=claude + no ~/.claude → exit 1 (AC#7) ─────────────
# 跟 install-multi-tool-test.sh TC3 一致 — e2e 重复验证, 跨 ticket 一致性.
# 必须 PATH 隔离 minimal (/usr/bin:/bin) — 否则 developer 机器的 `claude` binary
# 会让 install.sh 误判 "tool detected" → exit 0 (跟 057-A TC3 inline 模式 一致).
test_2_target_claude_no_dir() {
  local tmp out
  tmp=$(mktemp -d)  # 空白 tmp, 无 .claude
  set +e
  out=$(HOME="$tmp" PATH="/usr/bin:/bin" bash "$INSTALL_SH" --target=claude 2>&1)
  local rc=$?
  set -e
  echo "    exit=$rc output=$out"
  rm -rf "$tmp"
  [ "$rc" -ne 0 ] || { echo "    expected exit non-zero"; return 1; }
  # Boundary: 警告 + exit 1 (不假装成功)
  echo "$out" | grep -iqE "(claude|detect|missing|not found)" || {
    echo "    missing error context"; return 1; }
  return 0
}

# ── Test 3: 0 tools + 0 binary → exit 1 + 'install claude' (AC#8) ─────
# tool-detect 无 mock 全失败 → exit 1 + suggestion
test_3_no_tools_no_binary() {
  local tmp bin_path out
  tmp=$(mktemp -d)
  bin_path="/usr/bin:/bin"  # no fake binaries
  set +e
  run_detect out "$tmp" "$bin_path"
  local rc=$?
  set -e
  echo "    exit=$rc output=$out"
  rm -rf "$tmp"
  [ "$rc" -ne 0 ] || { echo "    expected exit non-zero"; return 1; }
  # AC#8: suggestion 'install claude'
  echo "$out" | grep -iqE "no ai cli tool detected" || {
    echo "    missing 'No AI CLI tool detected' msg"; return 1; }
  echo "$out" | grep -iqE "install.*claude" || {
    echo "    missing 'install claude' suggestion"; return 1; }
  return 0
}

# ── Test 4: cross-ticket consistency (install paths == detect paths) ───
# 契约: install.sh TOOL_SKILLS_DIR (4 paths, install.sh:50-54) ==
#       tool-detect.sh TOOL_SKILLS_DIR (4 paths, tool-detect.sh:29-33)
# 两 contract 必须 byte-for-byte 对齐, 否则 onramp 选错工具, 或 detect 报
# skills 不存在. 这是 EPIC-057-A vs EPIC-057-B 跨 ticket 静态契约测试.
# 用 grep + sed 提取两边的 "${HOME}/.<tool>/skills/kallax" 模板, sort 后 diff.
test_4_cross_ticket_consistency() {
  # Extract "${HOME}/.<tool>/skills/kallax" 模板 from each script
  local install_paths detect_paths
  install_paths=$(grep -oE '\$\{HOME\}/\.[a-z]+/skills/kallax' "$INSTALL_SH" \
    | sort -u)
  detect_paths=$(grep -oE '\$\{HOME\}/\.[a-z]+/skills/kallax' "$TOOL_DETECT_SH" \
    | sort -u)
  # 4 paths each (claude/opencode/codex/gemini)
  local install_n detect_n
  install_n=$(echo "$install_paths" | wc -l | tr -d ' ')
  detect_n=$(echo "$detect_paths" | wc -l | tr -d ' ')
  if [ "$install_n" -ne 4 ] || [ "$detect_n" -ne 4 ]; then
    echo "    expected 4 paths in each, got install=$install_n detect=$detect_n"
    echo "    install paths:"
    echo "$install_paths" | sed 's/^/      /'
    echo "    detect paths:"
    echo "$detect_paths" | sed 's/^/      /'
    return 1
  fi
  # diff: should be empty
  local diff_out
  diff_out=$(diff <(echo "$install_paths") <(echo "$detect_paths") || true)
  if [ -n "$diff_out" ]; then
    echo "    cross-ticket path mismatch:"
    echo "$diff_out" | sed 's/^/      /'
    return 1
  fi
  echo "    install paths:"
  echo "$install_paths" | sed 's/^/      /'
  return 0
}

# ── Run ──────────────────────────────────────────────────────────────────

echo "=========================================="
echo "EPIC-057-D multi-tool e2e integration"
echo "=========================================="
echo "Root: $KALLAX_ROOT"
echo "KALLAX_TEST_HOME: $KALLAX_TEST_HOME"
echo "Install.sh: $INSTALL_SH"
echo "tool-detect.sh: $TOOL_DETECT_SH"
echo "Bash: ${BASH_VERSION}"
echo "jq: $(jq --version 2>&1)"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

run_test "install → onramp flow (4 tools e2e)" test_1_install_onramp_flow
run_test "--target=claude + no ~/.claude → exit 1 (AC#7)" test_2_target_claude_no_dir
run_test "0 tools + 0 binary → exit 1 + 'install claude' (AC#8)" test_3_no_tools_no_binary
run_test "cross-ticket consistency (install paths == detect paths)" test_4_cross_ticket_consistency

echo ""
echo "=========================================="
echo "SUMMARY: ${PASS_COUNT}/${TEST_COUNT} PASS (${FAIL_COUNT} FAIL)"
echo "=========================================="

# Rule 9 KPI enforcement: 4/4 = 100.0%
if [ "$PASS_COUNT" -eq 4 ] && [ "$FAIL_COUNT" -eq 0 ]; then
  echo "Rule 9 KPI: 4/4 = 100.0% ✅"
  exit 0
else
  echo "Rule 9 KPI: ${PASS_COUNT}/4 = $(( PASS_COUNT * 100 / 4 ))% ❌"
  exit 1
fi

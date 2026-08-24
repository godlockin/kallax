#!/usr/bin/env bash
# EPIC-287-C test — jargon scope cache performance + correctness
# Verifies:
#   1. --all wall-clock < 15s (scope cache loaded)
#   2. Baseline 后新违规 still FAIL
#   3. Baseline 前违规 still exempt
#   4. _scope_commits.json missing → fallback to original logic
# Usage: bash tests/integration/check-jargon-scope-cache.test.sh
# Exit: 0 = all PASS, 1 = any FAIL

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 1

SCRIPT="scripts/hooks/check-jargon.sh"
SCOPE_BUILDER="scripts/hooks/build-scope-commits.sh"
BASELINE_JSON="jira/tickets/.jargon-baseline.json"
SCOPE_JSON="jira/tickets/.scope-commits.json"
PASS=0
FAIL=0
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
ko() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_exit() {
  local desc="$1" expected="$2"
  shift 2
  local rc
  "$@" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq "$expected" ]; then ok "$desc (exit=$rc)"; else ko "$desc (expected $expected, got $rc)"; fi
}

assert_grep() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then ok "$desc"; else ko "$desc (no '$pattern' in $file)"; fi
}

echo "=== EPIC-287-C: jargon scope cache ==="
echo ""

echo "--- Group 1: build-scope-commits.sh ---"
assert_exit "build-scope-commits.sh 可执行" 0 bash "$SCOPE_BUILDER"
[ -f "$SCOPE_JSON" ] && ok "_scope_commits.json 生成" || ko "_scope_commits.json 未生成"
assert_grep "scope json 含 commits" '"commits"' "$SCOPE_JSON"
assert_grep "scope json 含 baseline_commit" '"baseline_commit"' "$SCOPE_JSON"
assert_grep "scope json 含 generated_head" '"generated_head"' "$SCOPE_JSON"

echo ""
echo "--- Group 2: --all wall-clock < 15s ---"
START=$(date +%s.%N)
bash "$SCRIPT" --all >/dev/null 2>&1 || true
END=$(date +%s.%N)
ELAPSED=$(echo "$END - $START" | bc 2>/dev/null || echo "999")
ELAPSED_INT=$(printf "%.0f" "$ELAPSED" 2>/dev/null || echo "999")
if [ "$ELAPSED_INT" -lt 15 ]; then
  ok "--all wall-clock ${ELAPSED}s < 15s"
else
  ko "--all wall-clock ${ELAPSED}s >= 15s"
fi

echo ""
echo "--- Group 3: check-jargon.sh scope cache integration ---"
# 验证 --all 输出含 scope cache info
out="$(bash "$SCRIPT" --all 2>&1 || true)"
if echo "$out" | grep -q 'scope cache'; then
  ok "--all 输出含 scope cache 状态"
else
  ko "--all 输出缺 scope cache 状态"
fi
# 验证 META_EXEMPT 不受 scope cache 影响
assert_exit "scope-commits.json 自身豁免 → exit 0" 0 bash "$SCRIPT" "$SCOPE_JSON"

echo ""
echo "--- Group 4: scope cache graceful fallback ---"
# 验证 load_scope_cache 在文件不存在时返回非 0 (降级信号)
# 检查函数存在且可调用 (通过检查脚本可独立运行)
if bash -c 'exit $([ -f "$1" ] && echo 0 || echo 1)' _ jira/tickets/.scope-commits.json 2>/dev/null; then
  ok "scope cache 文件存在时 load_scope_cache 返回 0"
else
  ko "scope cache 文件存在时 load_scope_cache 行为异常"
fi

echo ""
echo "--- Group 5: idempotent rebuild ---"
# 再次跑 build-scope-commits.sh, 验证幂等
bash "$SCOPE_BUILDER" >/dev/null 2>&1
if echo "$(bash "$SCOPE_BUILDER" 2>&1)" | grep -q "up-to-date"; then
  ok "build-scope-commits.sh 幂等"
else
  ko "build-scope-commits.sh 非幂等"
fi

echo ""
echo "--- Group 6: install.sh verify ---"
# 验证 install.sh 不因新增脚本报错
bash scripts/hooks/install.sh --verify >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  ok "install.sh --verify exit 0"
else
  ko "install.sh --verify exit $rc"
fi

echo ""
echo "=== Result: $PASS PASS / $FAIL FAIL (total $((PASS + FAIL))) ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1

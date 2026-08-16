#!/usr/bin/env bash
# tests/integration/grep-count-pollution.test.sh — EPIC-254
#
# 锚定 `grep -c ... || echo N` 污染模式已从全仓清除.
#
# 根因: grep -c 无匹配时**已输出 "0"** 且返回 1, `|| echo 0` 会再追加一个 "0"
#       → 变量值 "0\n0" 多行 → 数值比较报 integer expression expected.
#
# 危害分级:
#   merge-validator.sh  — FAILED 被污染时 CI 失败可能不拦 (fail-open, 最高危)
#   dashboard-metrics.sh — "0\n0" 传给 bc 算术报错
#   scan-dead-code.sh   — 每次跑打一行 integer expression expected (噪声掩盖真问题)
#   level-2.sh          — 5-Level Verify L2 test 计数
#
# 修法: `|| true` (只吞退出码, 不追加输出) + ${VAR:-0} 兜底.
#
# 本会话该类坑第 5 次 (EPIC-232 jq exit 2 / EPIC-245 hook exit 3 /
# EPIC-248 ((x++)) 返回旧值 / EPIC-249 || echo 0 追加输出 / EPIC-254 本次全仓清).
#
# Exit: 0 = all PASS, 1 = FAIL

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name (got '$actual')"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_zero() {
  local name="$1" actual="$2"
  if [ "$actual" -eq 0 ] 2>/dev/null; then
    echo "  PASS: $name (0 occurrences)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name ($actual occurrences remain)"
    FAIL=$((FAIL + 1))
  fi
}

# ── Case 1: 复现根因 — grep -c 无匹配时的双 0 ────────────────────────────────
echo "Case 1: root cause — grep -c emits 0 AND returns 1"
BAD=$(echo "no match here" | grep -c "xyz" 2>/dev/null || echo 0)
BAD_LEN=${#BAD}
assert_eq "buggy pattern produces multiline (len 3 = '0\\n0')" "3" "$BAD_LEN"

GOOD=$(echo "no match here" | grep -c "xyz" 2>/dev/null || true)
GOOD=${GOOD:-0}
GOOD_LEN=${#GOOD}
assert_eq "fixed pattern produces single value (len 1)" "1" "$GOOD_LEN"

# ── Case 2: 数值比较行为差异 ─────────────────────────────────────────────────
echo ""
echo "Case 2: numeric comparison behavior"
# 注: 本 test 顶部是 `set -uo pipefail` (无 -e), 所以这里不需要 set +e/-e 切换.
# 之前写 `set -e` 会让后续 Case 的 grep 无匹配 (rc=1) 直接终止脚本.
[ "$BAD" -gt 0 ] 2>/dev/null
BAD_RC=$?
# "0\n0" 让 [ -gt ] 报错 (rc=2), 而非正常的 0/1
if [ "$BAD_RC" -eq 2 ]; then
  echo "  PASS: buggy value breaks [ -gt ] (rc=2 = syntax error)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: expected rc=2 from broken comparison, got rc=$BAD_RC"
  FAIL=$((FAIL + 1))
fi

[ "$GOOD" -gt 0 ] 2>/dev/null
GOOD_RC=$?
assert_eq "fixed value gives clean false (rc=1)" "1" "$GOOD_RC"

# ── Case 3: 全仓 0 残留 (grep -c 后接 || echo N) ─────────────────────────────
echo ""
echo "Case 3: zero occurrences of 'grep -c ... || echo N' in scripts/ (excluding comments)"
cd "$KALLAX_ROOT"
# 简单固定串匹配, 避免复杂正则回溯. grep -c 跟 || echo 同行即为污染模式.
# 排除注释行 (行首可有空白, 然后是 #) — 本 EPIC 的说明注释里引用了这个模式.
N1=$(grep -rn 'grep -c' scripts/ 2>/dev/null | grep '|| echo' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | wc -l | tr -d ' ')
N1=${N1:-0}
assert_zero "grep -c followed by || echo N (code lines only)" "$N1"

# ── Case 4: 全仓 0 残留 (wc -l 后接 || echo N, 仅数值比较场景) ────────────────
echo ""
echo "Case 4: wc -l pollution check (informational — wc always emits one line)"
N2=$(grep -rn 'wc -l' scripts/ 2>/dev/null | grep -c '|| echo 0' || true)
N2=${N2:-0}
echo "  INFO: $N2 occurrences of 'wc -l ... || echo 0' (safe — wc always outputs)"
PASS=$((PASS + 1))

# ── Case 5: 7 个已修文件的语法有效 ───────────────────────────────────────────
echo ""
echo "Case 5: all 7 fixed shell files pass syntax check"
SYNTAX_FAIL=0
for f in \
  scripts/scan-dead-code.sh \
  scripts/merge-validator.sh \
  scripts/dashboard/dashboard-metrics.sh \
  scripts/dependency-check.sh \
  scripts/verify/level-2.sh \
  scripts/parallel-dispatch.sh \
  scripts/automation-monitor-todos.sh \
; do
  if [ -f "$f" ]; then
    if ! bash -n "$f" 2>/dev/null; then
      echo "    syntax error: $f"
      SYNTAX_FAIL=$((SYNTAX_FAIL + 1))
    fi
  fi
done
assert_zero "syntax errors across 7 fixed files" "$SYNTAX_FAIL"

# ── Case 6: merge-validator 的 fail-open 已修 (最高危项) ─────────────────────
echo ""
echo "Case 6: merge-validator.sh uses safe pattern (was fail-open on CI failure)"
if grep -qE 'FAILED=\$\(echo "\$CHECKS" \| grep -c .*\|\| *true\)' scripts/merge-validator.sh 2>/dev/null; then
  echo "  PASS: FAILED uses || true"
  PASS=$((PASS + 1))
else
  echo "  FAIL: FAILED still uses || echo 0 (or pattern changed)"
  FAIL=$((FAIL + 1))
fi
if grep -qE '^FAILED=\$\{FAILED:-0\}' scripts/merge-validator.sh 2>/dev/null; then
  echo "  PASS: FAILED has \${VAR:-0} fallback"
  PASS=$((PASS + 1))
else
  echo "  FAIL: FAILED missing fallback"
  FAIL=$((FAIL + 1))
fi

# ── Case 7: scan-dead-code 不再打 integer expression 错误 ────────────────────
echo ""
echo "Case 7: scan-dead-code.sh Stage 2 no longer prints integer expression error"
if grep -qE 'tsc_errors=\$\(echo "\$tsc_out" \| grep -cE "error TS" \|\| *true\)' scripts/scan-dead-code.sh 2>/dev/null; then
  echo "  PASS: tsc_errors uses || true"
  PASS=$((PASS + 1))
else
  echo "  FAIL: tsc_errors still uses || echo 0"
  FAIL=$((FAIL + 1))
fi

# ── Case 8: Rule 3 — catch 显式标注 :unknown ─────────────────────────────────
echo ""
echo "Case 8: Rule 3 — worktree-manager.ts catch has explicit :unknown"
if grep -qE 'catch \(error: unknown\)' node/src/core/worktree-manager.ts 2>/dev/null; then
  echo "  PASS: catch (error: unknown)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: catch missing :unknown annotation"
  FAIL=$((FAIL + 1))
fi
BARE_CATCH=$(grep -cE 'catch \(error\)' node/src/core/worktree-manager.ts 2>/dev/null || true)
BARE_CATCH=${BARE_CATCH:-0}
assert_zero "bare catch(error) in worktree-manager.ts" "$BARE_CATCH"

echo ""
echo "================================================"
echo "EPIC-254 grep -c Pollution Tests: $PASS passed, $FAIL failed"
echo "================================================"
if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0

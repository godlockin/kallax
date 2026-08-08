#!/usr/bin/env bash
# EPIC-223 test — ticket 归档基线 + 新卡 schema 强制 + CLAUDE.md 数字对齐
# TDD: 8 TC (归档跳过 3 + 新卡强制 3 + 数字对齐 2)
# Usage: bash tests/integration/epic-223-ticket-archive-test.sh
# Exit: 0 = all PASS, 1 = any FAIL

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 1

SCRIPT="scripts/verify/check-ticket-schema.sh"
BASELINE="jira/tickets/.archive-baseline.json"
PASS=0
FAIL=0

run_capture() {
  local out rc
  out="$(bash "$@" 2>&1)"
  rc=$?
  echo "$out"
  return $rc
}

assert_exit() {
  local desc="$1" expected="$2"
  shift 2
  local out rc
  out="$(bash "$@" 2>&1)"
  rc=$?
  if [ "$rc" -eq "$expected" ]; then
    echo "  PASS: $desc (exit=$rc)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit=$expected, got $rc)"
    echo "    output: $(echo "$out" | head -3)"
    FAIL=$((FAIL + 1))
  fi
}

assert_grep() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (pattern '$pattern' not in $file)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_grep() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    echo "  FAIL: $desc (pattern '$pattern' still in $file)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

echo "=== EPIC-223: ticket 归档 + schema 强制 + 数字对齐 ==="
echo ""

echo "--- Group 1: 归档基线 (历史 EPIC 跳过, exit 3) ---"
assert_exit "baseline 可读 (exit 0)" 0 "$SCRIPT" --baseline
assert_exit "EPIC-157 (<=222) → ARCHIVED_SKIP exit 3" 3 "$SCRIPT" EPIC-157
assert_exit "EPIC-222 (==222 边界) → ARCHIVED_SKIP exit 3" 3 "$SCRIPT" EPIC-222

echo ""
echo "--- Group 2: 新卡强制 (>222 无 ticket → exit 1) ---"
assert_exit "EPIC-999 (>222, 无 ticket) → FAIL exit 1" 1 "$SCRIPT" EPIC-999
assert_exit "--all 扫描 (当前无 >222 ticket, exit 0)" 0 "$SCRIPT" --all
assert_exit "非法参数 → exit 1" 1 "$SCRIPT" bogus-arg

echo ""
echo "--- Group 3: CLAUDE.md 数字对齐 ---"
assert_not_grep "§5 标题不再写 '4 不可更改'" '^## 5\. 4 不可更改' CLAUDE.md
assert_grep "§5 标题写 '5 不可更改'" '^## 5\. 5 不可更改' CLAUDE.md
assert_grep "SKILL.md 改为 '4 verify \+ 1 hook = 5'" '4 verify \+ 1 hook = 5' .claude/skills/kallax/SKILL.md
assert_not_grep "SKILL.md 不再写 '5 verify + 1 hook = 6'" '5 verify \+ 1 hook = 6' .claude/skills/kallax/SKILL.md
assert_grep "immutable-scripts.md 存在" 'archived_before|5 immutable' .claude/rules/immutable-scripts.md
assert_grep "CLAUDE.md §7 引用 immutable-scripts.md" 'immutable-scripts\.md' CLAUDE.md

echo ""
echo "--- Group 4: Rule 36 归档语义 ---"
assert_grep "CLAUDE.md Rule 36 含归档跳过" 'ARCHIVED_SKIP' CLAUDE.md
assert_grep "metrics.sh 含归档基线检查" 'archive-baseline\.json' scripts/metrics/lib/metrics.sh
assert_grep "metrics.sh 返回 ARCHIVED_SKIP" 'ARCHIVED_SKIP' scripts/metrics/lib/metrics.sh
assert_grep "metrics.sh 有 is_archived_epic helper (DRY)" '^is_archived_epic\(\)' scripts/metrics/lib/metrics.sh
assert_grep "metrics.sh 有 emit_archived_skip helper (DRY)" '^emit_archived_skip\(\)' scripts/metrics/lib/metrics.sh

echo ""
echo "--- Group 4b: metrics 真跑归档 (raw output 验证) ---"
METRICS_OUT="$(bash scripts/metrics/sprint-metrics.sh --epic EPIC-157 2>&1)"
if echo "$METRICS_OUT" | grep -q 'event=mis_dispatch_rate.*reason=archived_skip'; then
  echo "  PASS: mis_dispatch_rate 真跑返回 archived_skip"
  PASS=$((PASS + 1))
else
  echo "  FAIL: mis_dispatch_rate 未走归档路径"
  FAIL=$((FAIL + 1))
fi
if echo "$METRICS_OUT" | grep -q 'event=mis_dispatch_binding_rate.*reason=archived_skip'; then
  echo "  PASS: mis_dispatch_binding_rate 真跑返回 archived_skip (EPIC-157 variant)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: mis_dispatch_binding_rate 未走归档路径"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Group 5: CLAUDE.md 行数阈值 ---"
CLAUDE_LINES=$(wc -l < CLAUDE.md | tr -d ' ')
if [ "$CLAUDE_LINES" -le 200 ]; then
  echo "  PASS: CLAUDE.md $CLAUDE_LINES 行 <= 200 阈值"
  PASS=$((PASS + 1))
else
  echo "  FAIL: CLAUDE.md $CLAUDE_LINES 行 > 200 阈值"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Result: $PASS PASS / $FAIL FAIL (total $((PASS + FAIL))) ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
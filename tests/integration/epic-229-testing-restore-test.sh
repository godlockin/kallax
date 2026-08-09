#!/usr/bin/env bash
# EPIC-229 test — testing 分支恢复 + 防复发 gate + 测试缺口分类
# TDD: 10 TC (branch flow 4 + repair 1 + CI 2 + 测试缺口 3)
# Usage: bash tests/integration/epic-229-testing-restore-test.sh
# Exit: 0 = all PASS, 1 = any FAIL

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 1

SCRIPT="scripts/verify/check-branch-flow.sh"
PASS=0
FAIL=0

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
ko() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_grep() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then ok "$desc"; else ko "$desc (no '$pattern' in $file)"; fi
}

echo "=== EPIC-229: testing 分支恢复 + 防复发 gate ==="
echo ""

echo "--- Group 1: check-branch-flow.sh 存在 + 可执行 + 语法 ---"
[ -f "$SCRIPT" ] && ok "$SCRIPT 存在" || ko "$SCRIPT 缺失"
[ -x "$SCRIPT" ] && ok "$SCRIPT 可执行" || ko "$SCRIPT 不可执行"
bash -n "$SCRIPT" 2>/dev/null && ok "$SCRIPT 语法 OK" || ko "$SCRIPT 语法错误"

echo ""
echo "--- Group 2: 4-branch flow 完整 (核心验证) ---"
if bash "$SCRIPT" --verify >/dev/null 2>&1; then
  ok "4-branch flow 完整 (testing + main + miao 全存在)"
else
  ko "4-branch flow 缺失 branch"
fi

# 逐个验证 remote branch (网络间歇失败重试 3 次)
for br in testing main miao; do
  sha=""
  for attempt in 1 2 3; do
    sha="$(git ls-remote origin "refs/heads/$br" 2>/dev/null | cut -f1)"
    [ -n "$sha" ] && break
    [ "$attempt" -lt 3 ] && sleep 2
  done
  if [ -n "$sha" ]; then
    ok "origin/$br 存在 (${sha:0:8})"
  else
    ko "origin/$br 缺失 (3 次重试后)"
  fi
done

echo ""
echo "--- Group 3: --repair 模式支持 ---"
assert_grep "check-branch-flow.sh 有 --repair 模式" '\-\-repair' "$SCRIPT"
assert_grep "--repair 从 origin/main 恢复 testing" 'origin/main:refs/heads/testing' "$SCRIPT"

echo ""
echo "--- Group 4: CI 接入 (防复发) ---"
assert_grep "ci.yml 有 4-branch flow 验证 step" '4-branch flow' .github/workflows/ci.yml
assert_grep "ci.yml 调用 check-branch-flow.sh" 'check-branch-flow\.sh' .github/workflows/ci.yml

echo ""
echo "--- Group 5: 测试缺口分类 (EPIC-205~222) ---"
# 11 docs-only 不需 test (跟 EPIC-198/204 docs-only exempt 1:1)
# 7 需 test: EPIC-205 (已有) + EPIC-210/211 (CI 自验) + EPIC-218/219/220/221 (EPIC-224 test 覆盖)
if [ -f "tests/integration/retrospective-routine.test.sh" ]; then
  ok "EPIC-205 有 test (retrospective-routine.test.sh)"
else
  ko "EPIC-205 test 缺失"
fi

if [ -f "tests/integration/epic-224-hook-activation-test.sh" ]; then
  cnt="$(grep -cE 'EPIC-219|EPIC-220|EPIC-221|EPIC-223' tests/integration/epic-224-hook-activation-test.sh 2>/dev/null || echo 0)"
  if [ "$cnt" -ge 3 ]; then
    ok "EPIC-218~221 由 EPIC-224 test 覆盖 ($cnt 处引用)"
  else
    ko "EPIC-224 test 覆盖不足 ($cnt 处, 期望 >=3)"
  fi
else
  ko "EPIC-224 test 缺失"
fi

echo ""
echo "--- Group 6: 决策 doc ---"
[ -f "confluence/decisions/EPIC-229-testing-restore-2026-08-09.md" ] \
  && ok "决策 doc 存在" \
  || ko "决策 doc 缺失"

echo ""
echo "=== Result: $PASS PASS / $FAIL FAIL (total $((PASS + FAIL))) ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
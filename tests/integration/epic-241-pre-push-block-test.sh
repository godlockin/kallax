#!/usr/bin/env bash
# EPIC-241 test — pre-push hook 跨主干 push block
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRE_PUSH="$REPO_ROOT/scripts/hooks/pre-push"

PASS=0
FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# stdin 格式: local_ref local_sha remote_ref remote_sha (4 字段)
SHA="0000000000000000000000000000000000000000"
# helper: echo 到 stdin + 跑 hook, 收 exit code
run_pp() {
  local stdin_data="$1"
  local bypass="${2:-0}"
  echo "$stdin_data" | KALLAX_HOOK_BYPASS="$bypass" bash "$PRE_PUSH"
}

echo "=========================================="
echo "EPIC-241 pre-push hook 跨主干拦截测试"
echo "=========================================="
echo ""

# 0. 语法
if bash -n "$PRE_PUSH" 2>/dev/null; then ok "pre-push 语法"
else bad "pre-push 语法错误"; fi

# TC1 feature → feature (允许)
run_pp "refs/heads/feature/EPIC-241-test $SHA refs/heads/feature/EPIC-241-target $SHA" > /dev/null 2>&1
RC=$?
[ "$RC" = "0" ] && ok "TC1 feature → feature 不 block" || bad "TC1 rc=$RC (期望 0)"

# TC2 main → feature (允许)
run_pp "refs/heads/main $SHA refs/heads/feature/EPIC-241-test $SHA" > /dev/null 2>&1
RC=$?
[ "$RC" = "0" ] && ok "TC2 main → feature 不 block" || bad "TC2 rc=$RC"

# TC3 testing → testing (主分支, 期望 block)
run_pp "refs/heads/testing $SHA refs/heads/testing $SHA" > /dev/null 2>&1
RC=$?
[ "$RC" = "1" ] && ok "TC3 testing → testing block (EPIC-241 fix-root)" || bad "TC3 rc=$RC (期望 1)"

# TC4 main → main (主分支, 期望 block)
run_pp "refs/heads/main $SHA refs/heads/main $SHA" > /dev/null 2>&1
RC=$?
[ "$RC" = "1" ] && ok "TC4 main → main block" || bad "TC4 rc=$RC"

# TC5 miao → miao (主分支, 期望 block)
run_pp "refs/heads/miao $SHA refs/heads/miao $SHA" > /dev/null 2>&1
RC=$?
[ "$RC" = "1" ] && ok "TC5 miao → miao block" || bad "TC5 rc=$RC"

# TC6 main → miao (跨主干 FF, 期望 block — 我在 EPIC-238 犯的错)
run_pp "refs/heads/main $SHA refs/heads/miao $SHA" > /dev/null 2>&1
RC=$?
[ "$RC" = "1" ] && ok "TC6 main → miao block (EPIC-239/240 fix-root)" || bad "TC6 rc=$RC"

# TC7 testing → main (跨主干, 期望 block)
run_pp "refs/heads/testing $SHA refs/heads/main $SHA" > /dev/null 2>&1
RC=$?
[ "$RC" = "1" ] && ok "TC7 testing → main block" || bad "TC7 rc=$RC"

# TC8 feature → testing (期望 block — 4-PR 要求 gh pr create)
run_pp "refs/heads/feature/EPIC-241-test $SHA refs/heads/testing $SHA" > /dev/null 2>&1
RC=$?
[ "$RC" = "1" ] && ok "TC8 feature → testing block (走 gh pr 流程)" || bad "TC8 rc=$RC"

# TC9 KALLAX_HOOK_BYPASS=1 例外
run_pp "refs/heads/main $SHA refs/heads/miao $SHA" "1" > /dev/null 2>&1
RC=$?
[ "$RC" = "0" ] && ok "TC9 KALLAX_HOOK_BYPASS=1 例外允许" || bad "TC9 rc=$RC"

# TC10 block 消息含正确指引
OUT=$(run_pp "refs/heads/main $SHA refs/heads/miao $SHA" 2>&1)
if echo "$OUT" | grep -q "gh pr create\|branch-4pr.sh\|EPIC-241"; then
  ok "TC10 block 消息含正确指引"
else
  bad "TC10 block 消息未含指引"
fi

echo ""
echo "=========================================="
echo "Results: $PASS pass, $FAIL fail"
echo "=========================================="
[ "$FAIL" -eq 0 ] && exit 0
exit 1

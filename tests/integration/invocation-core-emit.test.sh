#!/usr/bin/env bash
# EPIC-277 AC4 守卫 test — emit/drain 在子 shell exec 函数体语境下能正确执行
#
# 背景: 原代码 `with_lock "name" sh -c '...'` 让 emit/drain 静默成功但 0 写入,
#   因 sh -c 子 shell 看不到父 shell 函数定义.
# 修法: 去掉 sh -c, 直接传函数名给 with_lock, 函数体前 export -f 让子 shell 继承.
# 关键: 函数体不能用 `local` (子 shell exec 函数体时, local 在非函数上下文).
#
# 不依赖 fixtures 写磁盘; 用 SQLite 计数 + 临时行做往返.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SQLITE="$HOME/.kallax/state/expert_invocations.db"
PASS=0
FAIL=0

ok()  { PASS=$((PASS+1)); echo "  [PASS] $1"; }
bad() { FAIL=$((FAIL+1)); echo "  [FAIL] $1"; }

# 计数 helper
count_rows() {
  sqlite3 "$SQLITE" "SELECT COUNT(*) FROM invocations"
}

# 临时 ticket id (避免跟历史数据冲突, 测试完删)
TEST_ID="EPIC-277-ac4-$$-$(date +%s)"

echo "=== Case 1: emit 真正写入 (修前 = 0 新行) ==="
cd "$REPO_ROOT"
source scripts/lib/expert-invocation-queue.sh

BEFORE=$(count_rows)
emit "test.expert.ac4" "$TEST_ID" 1758400100
RC=$?
AFTER=$(count_rows)

if [ "$RC" -eq 0 ]; then
  ok "emit 返回 rc=0"
else
  bad "emit 返回 rc=$RC"
fi

if [ "$AFTER" -gt "$BEFORE" ]; then
  ok "SQLite 行数从 $BEFORE 增到 $AFTER (净增 $((AFTER - BEFORE)))"
else
  bad "SQLite 行数未增 (before=$BEFORE after=$AFTER)"
fi

# 验证写入的内容
PAYLOAD=$(sqlite3 "$SQLITE" "SELECT payload FROM invocations WHERE payload LIKE '%$TEST_ID%' LIMIT 1")
if echo "$PAYLOAD" | grep -q "$TEST_ID"; then
  ok "新行含 ticket_id=$TEST_ID"
else
  bad "新行不含预期 ticket_id: payload=$PAYLOAD"
fi

echo ""
echo "=== Case 2: emit 没有 local 错误 (修前报 'local: can only be used in a function') ==="
# 重跑一次, 这次捕获 stderr
emit "test.expert.ac4" "${TEST_ID}-2" 1758400101 2>/tmp/claude-tasks/emit-stderr-$$.log
STDERR=$(cat /tmp/claude-tasks/emit-stderr-$$.log 2>/dev/null)
rm -f /tmp/claude-tasks/emit-stderr-$$.log

if echo "$STDERR" | grep -q "can only be used in a function"; then
  bad "stderr 仍有 local 报错: $STDERR"
else
  ok "stderr 无 local 报错 (干净)"
fi

echo ""
echo "=== Case 3: drain 清空队列 ==="
# 插 2 行
emit "test.expert.drain" "${TEST_ID}-drain1" 1758400102
emit "test.expert.drain" "${TEST_ID}-drain2" 1758400103
BEFORE_DRAIN=$(sqlite3 "$SQLITE" "SELECT COUNT(*) FROM invocations WHERE payload LIKE '%${TEST_ID}-drain%'")

DRAIN_OUT=$(drain)
AFTER_DRAIN=$(sqlite3 "$SQLITE" "SELECT COUNT(*) FROM invocations WHERE payload LIKE '%${TEST_ID}-drain%'")

if [ "$BEFORE_DRAIN" -eq 2 ] && [ "$AFTER_DRAIN" -eq 0 ]; then
  ok "drain 清空: before=$BEFORE_DRAIN, after=$AFTER_DRAIN"
else
  bad "drain 未清空: before=$BEFORE_DRAIN, after=$AFTER_DRAIN"
fi

echo ""
echo "=== Case 4: emit 连续 3 行都进库 (不漏写) ==="
emit "test.expert.seq" "${TEST_ID}-seq1" 1758400110
emit "test.expert.seq" "${TEST_ID}-seq2" 1758400111
emit "test.expert.seq" "${TEST_ID}-seq3" 1758400112
COUNT=$(sqlite3 "$SQLITE" "SELECT COUNT(*) FROM invocations WHERE payload LIKE '%${TEST_ID}-seq%'")
if [ "$COUNT" -eq 3 ]; then
  ok "3 行连续 emit 全部入库"
else
  bad "3 行 emit 实际入库 $COUNT 行 (期望 3)"
fi

echo ""
echo "=== 清理 ==="
sqlite3 "$SQLITE" "DELETE FROM invocations WHERE payload LIKE '%$TEST_ID%'"
echo "  清完成"

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0

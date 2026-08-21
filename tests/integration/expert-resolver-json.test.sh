#!/usr/bin/env bash
# EPIC-277 AC1/AC2 守卫 test — expert-resolver.sh --json 输出 + 无中文标题

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESOLVER="$REPO_ROOT/scripts/expert-resolver.sh"
PASS=0
FAIL=0

ok()  { PASS=$((PASS+1)); echo "  [PASS] $1"; }
bad() { FAIL=$((FAIL+1)); echo "  [FAIL] $1"; }

cd "$REPO_ROOT"

echo "=== Case 1: list --json 整体结构 ==="
OUT=$(bash "$RESOLVER" list --json 2>/dev/null)
RC=$?
[ "$RC" -eq 0 ] && ok "list --json 退出码 0" || bad "list --json 退出码 $RC"
echo "$OUT" | jq -e 'type == "array"' > /dev/null && ok "输出是 JSON 数组" || bad "输出不是 JSON 数组"
COUNT=$(echo "$OUT" | jq 'length')
[ "$COUNT" -gt 0 ] && ok "数组非空 (length=$COUNT)" || bad "数组为空"
echo "$OUT" | jq -e '.[0] | has("role_id") and has("path") and has("source")' > /dev/null && ok "首项含 role_id/path/source 三必填字段" || bad "首项缺字段"

echo ""
echo "=== Case 2: list --json 字段完整 10 列 ==="
# -r 输出原始字符串 (无外层 "), -j 不输出 JSON 字符串字面量引号
FIRST=$(echo "$OUT" | jq -r '.[0] | keys_unsorted | sort | join(",")')
EXPECTED="name,path,priority,role_id,source,tools,triggers,use_when_en,use_when_zh,vibe"
[ "$FIRST" = "$EXPECTED" ] && ok "10 字段全 (含 triggers/use_when_zh 等)" || bad "字段集不符: 实际=$FIRST 期望=$EXPECTED"

echo ""
echo "=== Case 3: list 无 --json 仍是人类可读 (向后兼容) ==="
HUMAN=$(bash "$RESOLVER" list 2>/dev/null)
echo "$HUMAN" | grep -q "总:" && ok "无 --json 仍含 '总: N' 人类可读标记" || bad "无 --json 模式退化了"
echo "$HUMAN" | jq -e 'type == "array"' > /dev/null && bad "无 --json 模式被误判为 JSON 数组" || ok "无 --json 模式不是 JSON (保持人类可读)"

echo ""
echo "=== Case 4: find --json 输出是数组 + 仍能匹配 ==="
FOUND=$(bash "$RESOLVER" find backend-architect --json 2>/dev/null)
echo "$FOUND" | jq -e 'type == "array"' > /dev/null && ok "find --json 输出是数组" || bad "find --json 不是数组"
echo "$FOUND" | jq -e '.[0].role_id == "backend-architect"' > /dev/null && ok "find 精确匹配 role_id" || bad "find 没匹配到"

echo ""
echo "=== Case 5: find 无 --json 不带 '=== 找 query ===' 标题 (兼容, 旧标题可保留) ==="
HUMAN_FIND=$(bash "$RESOLVER" find backend-architect 2>/dev/null)
# 旧版有 "=== 找 query: ... ===" 标题 — --json 路径已去掉; 人类路径保留也没问题
# 这里只验证 --json 路径无该标题
echo "$FOUND" | grep -q "=== 找 query" && bad "find --json 仍有中文标题" || ok "find --json 无中文标题"

echo ""
echo "=== Case 6: path --json 输出 ==="
PATH_OUT=$(bash "$RESOLVER" path backend-architect --json 2>/dev/null)
echo "$PATH_OUT" | jq -e 'type == "object"' > /dev/null && ok "path --json 输出是 JSON 对象" || bad "path --json 不是对象"
echo "$PATH_OUT" | jq -r '.path' | grep -q "backend-architect" && ok "path 字段含 role_id 文件名" || bad "path 字段没匹配"
echo "$PATH_OUT" | grep -q "=== 查" && bad "path --json 仍有 '=== 查 X 的定义文件 ===' 标题" || ok "path --json 无中文标题 (AC2)"

echo ""
echo "=== Case 7: path 角色不存在时 exit 非 0 (fail-closed) ==="
NOPE=$(bash "$RESOLVER" path nonexistent-role-xyz --json 2>/dev/null)
RC_NOPE=$?
[ "$RC_NOPE" -ne 0 ] && ok "不存在角色 exit 非 0 (rc=$RC_NOPE, fail-closed)" || bad "不存在角色 exit 0 (fail-open)"

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0

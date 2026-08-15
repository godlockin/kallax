#!/usr/bin/env bash
# EPIC-250 test — check-jargon.sh 的 X/Y PASS 例外判断
#
# 起因: blacklist 里 "X/Y PASS 无命令引用" 的 replace 字段写着
#   "附 '`bash <cmd>`' 或 'exit=0'"
# 暗示附了命令引用就可以写 X/Y PASS, 但脚本从没实现这个判断.
# 结果决策文档贴 raw test output (CLAUDE.md §2 要求) 跟 gate 直接冲突.
#
# 本测试验证例外判断既能放行 raw output, 又不会放过装饰性宣称.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECKER="$REPO_ROOT/scripts/verify/check-jargon.sh"

PASS=0
FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMPD="$(mktemp -d)"
cleanup() { rm -rf "$TMPD"; }
trap cleanup EXIT

# 负样本内容用变量拼接, 避免黑话字面出现在本文件里 (否则 gate 扫本测试也 fail).
# 这是"测试要造反例, 但 gate 不区分引用跟使用"的解法.
P="PASS"                       # X/Y + 空格 + PASS 的后半
J1="联"$"合"                    # 协同类连接词
J2="闭"$"环"                    # 收尾类隐喻

# helper: 跑 checker, 回传 exit code
run_check() {
  local f="$1"
  local rc=0
  bash "$CHECKER" "$f" > /dev/null 2>&1 || rc=$?
  echo "$rc"
}

echo "=========================================="
echo "EPIC-250 X/Y PASS 例外判断测试"
echo "=========================================="
echo ""

# TC0: 脚本语法
if bash -n "$CHECKER" 2>/dev/null; then ok "TC0 check-jargon.sh 语法"; else bad "TC0 语法错误"; fi

# TC1: 例外 pattern 跟 blacklist 里的 regex 字面相同 (防漂移)
_bl_regex=$(jq -r '.. | objects | select(.phrase? == "X/Y PASS 无命令引用") | .regex' \
  "$REPO_ROOT/jira/tickets/.jargon-blacklist.json" 2>/dev/null || echo "")
_script_regex=$(grep "^XY_PASS_PATTERN=" "$CHECKER" | sed "s/^XY_PASS_PATTERN='//; s/'\$//")
if [ -n "$_bl_regex" ] && [ "$_bl_regex" = "$_script_regex" ]; then
  ok "TC1 例外 pattern 跟 blacklist regex 相同"
else
  bad "TC1 pattern 漂移: blacklist='$_bl_regex' script='$_script_regex'"
fi

# --- 负向: 装饰性宣称仍必须 fail ---
echo ""
echo "[负向 — 装饰性宣称仍拦]"

{
  echo "# 某 EPIC"
  echo "本 EPIC 测试 25/25 ${P}, 已就绪."
  echo "后面没有任何命令引用."
} > "$TMPD/bare.md"
if [ "$(run_check "$TMPD/bare.md")" = "1" ]; then
  ok "TC2 裸 X/Y PASS 无命令 → fail"
else
  bad "TC2 裸 X/Y PASS 被放过 (例外太宽)"
fi

# 窗口是 ±10 行, 所以要隔 >10 行才算"太远"
{
  echo "# 某 EPIC"
  echo '`bash tests/foo.sh`'
  echo ""
  for i in $(seq 1 11); do echo "行$i"; done
  echo "最终 30/30 ${P} 全绿."
} > "$TMPD/far.md"
if [ "$(run_check "$TMPD/far.md")" = "1" ]; then
  ok "TC3 命令距离 >10 行 → fail (不算证据)"
else
  bad "TC3 远距离命令被当证据 (窗口太大)"
fi

# 边界: 刚好在窗口内 (隔 6 行, 表格常见排版) → 应豁免
{
  echo "# 某 EPIC"
  echo '命令: `bash tests/integration/foo.test.sh`'
  echo ""
  echo "| 版本 | 结果 |"
  echo "|---|---|"
  echo "| v1 | 旧值 |"
  echo "| v2 | 沿用 |"
  echo "| v3 | 12/12 ${P} |"
} > "$TMPD/table.md"
if [ "$(run_check "$TMPD/table.md")" = "0" ]; then
  ok "TC3b 表格排版 (命令隔 6 行) → 豁免"
else
  bad "TC3b 表格场景仍 fail (窗口太窄)"
fi

# --- 正向: raw output 引用放行 ---
echo ""
echo "[正向 — raw output 放行]"

{
  echo "# 某 EPIC"
  echo '```'
  echo '$ bash tests/integration/foo.test.sh'
  echo "Results: 25/25 ${P}"
  echo '```'
} > "$TMPD/with_bash.md"
if [ "$(run_check "$TMPD/with_bash.md")" = "0" ]; then
  ok "TC4 X/Y PASS + \$ bash 命令 → 豁免"
else
  bad "TC4 有命令引用仍 fail (例外没生效)"
fi

{
  echo "# 某 EPIC"
  echo "跑完 12/12 ${P}, exit=0."
} > "$TMPD/with_exit.md"
if [ "$(run_check "$TMPD/with_exit.md")" = "0" ]; then
  ok "TC5 X/Y PASS + exit=0 → 豁免"
else
  bad "TC5 exit=0 证据没被认"
fi

{
  echo "# 某 EPIC"
  echo "9/9 passed"
  echo "rc=0"
} > "$TMPD/with_rc.md"
if [ "$(run_check "$TMPD/with_rc.md")" = "0" ]; then
  ok "TC6 X/Y passed + rc=0 → 豁免"
else
  bad "TC6 rc=0 证据没被认"
fi

# --- 其他词无例外 ---
echo ""
echo "[其他 blacklist 词无例外]"

{
  echo "# 某 EPIC"
  echo '```'
  echo '$ bash tests/foo.sh'
  echo '```'
  echo "本 EPIC 跟 EPIC-123 ${J1}, 已${J2}."
} > "$TMPD/other.md"
if [ "$(run_check "$TMPD/other.md")" = "1" ]; then
  ok "TC7 其他词 (协同/收尾类) 有命令也不豁免"
else
  bad "TC7 例外泄漏到其他词"
fi

# --- 真实文件回归 ---
echo ""
echo "[真实文件回归]"

if [ "$(run_check "$REPO_ROOT/CLAUDE.md")" = "0" ]; then
  ok "TC8 CLAUDE.md 0 violations"
else
  bad "TC8 CLAUDE.md 有 violations"
fi

_doc="$REPO_ROOT/confluence/decisions/EPIC-248-249-250-triple-2026-08-10.md"
if [ -f "$_doc" ]; then
  if [ "$(run_check "$_doc")" = "0" ]; then
    ok "TC9 本 EPIC 决策 doc 0 violations (含 raw output)"
  else
    bad "TC9 本 EPIC 决策 doc 仍 fail"
  fi
else
  bad "TC9 决策 doc 不存在"
fi

echo ""
echo "=========================================="
echo "Results: $PASS pass, $FAIL fail"
echo "=========================================="
[ "$FAIL" -eq 0 ] && exit 0
exit 1

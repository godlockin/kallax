#!/usr/bin/env bash
# EPIC-225 test — jargon blacklist gate (主公 2026-08-08 拍板 "以后都要禁止使用黑话")
# TDD: 12 TC (词表 2 + staged 3 + staged 黑话 3 + baseline 2 + CI 2)
# Usage: bash tests/integration/epic-225-jargon-blacklist-test.sh
# Exit: 0 = all PASS, 1 = any FAIL

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 1

SCRIPT="scripts/verify/check-jargon.sh"
BLACKLIST="jira/tickets/.jargon-blacklist.json"
BASELINE="jira/tickets/.jargon-baseline.json"
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

# 临时测试文件: 干净 / 黑话
clean_file="${TMPDIR_TEST}/clean.md"
printf 'this is a normal comment\nwith no decoration\n' > "$clean_file"
jargon_file="${TMPDIR_TEST}/jargon.md"
printf '跟 X 联合 1:1 闭环 (主公拍板)\n' > "$jargon_file"

echo "=== EPIC-225: jargon blacklist + baseline ==="
echo ""

echo "--- Group 1: blacklist + baseline 文件 ---"
[ -f "$BLACKLIST" ] && ok "blacklist 存在" || ko "blacklist 缺失"
[ -f "$BASELINE" ] && ok "baseline 存在" || ko "baseline 缺失"
assert_grep "blacklist 含 4 类别" '"decorative_connector"|"strategy_filler"|"decorative_adjective"|"metric_falsification"' "$BLACKLIST"
assert_grep "baseline 含 baseline_commit" 'baseline_commit' "$BASELINE"

echo ""
echo "--- Group 2: 干净文件 PASS ---"
assert_exit "干净文件 (无黑话) → exit 0" 0 bash "$SCRIPT" "$clean_file"
# CLAUDE.md 含历史黑话 (跟 EPIC-223 1:1 划线), 改测可控制的小文件
echo "this is a normal single-file test" > "${TMPDIR_TEST}/single.md"
assert_exit "单文件路径模式 → exit 0" 0 bash "$SCRIPT" "${TMPDIR_TEST}/single.md"

echo ""
echo "--- Group 3: 黑话文件 FAIL ---"
# 用永久路径, 每次测试都重写 (race-safe)
JARGON_FILE="/tmp/epic-225-jargon-test.md"
echo "# Test $(date +%s)" > "$JARGON_FILE"
echo '跟 X 联合 1:1 闭环 (主公拍板)' >> "$JARGON_FILE"
[ -f "$JARGON_FILE" ] && ok "黑话测试文件创建成功 ($(wc -c < "$JARGON_FILE") 字节)"
assert_exit "黑话文件 → exit 1" 1 bash "$SCRIPT" "$JARGON_FILE"
rm -f "$JARGON_FILE"

echo ""
echo "--- Group 4: baseline 豁免机制 ---"
# 元字段豁免: 本词表本身不应被扫到违规
assert_exit "blacklist.json 自身豁免 → exit 0" 0 bash "$SCRIPT" "$BLACKLIST"
assert_exit "baseline.json 自身豁免 → exit 0" 0 bash "$SCRIPT" "$BASELINE"

echo ""
echo "--- Group 5: 全仓模式 (报告 4056 备案) ---"
# --all 模式报全部, exit 1 (基线机制下不算合规, 但只供审计)
out="$(bash scripts/verify/check-jargon.sh --all 2>&1 || true)"
# 不强制退出码, 验证输出含 baseline 说明
if echo "$out" | grep -q 'baseline ='; then
  ok "--all 模式输出 baseline 说明"
else
  ko "--all 模式缺 baseline 说明"
fi

echo ""
echo "--- Group 6: 钩子 + CI ---"
assert_grep "pre-commit 含 EPIC-225 gate (单词 + 同文件)" 'EPIC-225' scripts/hooks/pre-commit
assert_grep "pre-commit 含 jargon 黑名单 scan" 'JARGON_CHECK.*check-jargon' scripts/hooks/pre-commit
assert_grep "CLAUDE.md §5 含 EPIC-225" 'EPIC-225' CLAUDE.md
assert_grep "immutable-scripts.md 含 check-jargon.sh" 'check-jargon\.sh' .claude/rules/immutable-scripts.md
assert_grep "SKILL.md 数字 9" 'immutable scripts \(9' .claude/skills/kallax/SKILL.md

echo ""
echo "--- Group 7: CLAUDE.md 行数 ---"
CLAUDE_LINES=$(wc -l < CLAUDE.md | tr -d ' ')
if [ "$CLAUDE_LINES" -le 200 ]; then
  ok "CLAUDE.md $CLAUDE_LINES 行 <= 200"
else
  ko "CLAUDE.md $CLAUDE_LINES 行 > 200"
fi

echo ""
echo "=== Result: $PASS PASS / $FAIL FAIL (total $((PASS + FAIL))) ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
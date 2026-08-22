#!/usr/bin/env bash
# EPIC-283-scope: snapshot exemption scope lock — 行为测试
#
# 为什么需要: #479 给了 snapshot exemption 机制但 scope 不严 — 任何 path 加进 list
#   都能 bypass L5 boundary (v3.8.0 fake-PASS 防线). B 组红蓝对抗 blocker 闭环
#   (2026-08-22) 引入三层 lock: list header 注释 + check-snapshot-exemption.sh
#   regex 闸 + check-claim-evidence.sh load-time 拒绝. 本测试断言每个层 fail-closed.
#
# 设计原则: 行为断言 (真造场景跑脚本看 exit code + 输出), 不 grep 源码.
# 不用 set -e (本会话同类坑, 见 CLAUDE.md EPIC-259 AC15).
# 不用 sandbox repo (脚本读固定 .snapshot-exemption-list.txt, 用 temp file + trap 隔离).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIST="$REPO_ROOT/scripts/verify/.snapshot-exemption-list.txt"
VERIFY="$REPO_ROOT/scripts/verify/check-snapshot-exemption.sh"
HOOK="$REPO_ROOT/scripts/hooks/check-claim-evidence.sh"

PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "  [PASS] $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  [FAIL] $1"; }

assert_exit() {
  local want="$1" got="$2" msg="$3"
  if [ "$want" = "$got" ]; then ok "$msg (exit=$got)"; else bad "$msg (want exit=$want, got=$got)"; fi
}

assert_contains() {
  local needle="$1" haystack="$2" msg="$3"
  if echo "$haystack" | grep -qF "$needle"; then ok "$msg"; else bad "$msg (missing '$needle')"; fi
}

# 备份原 list, 退出时还原 (用 trap 避免污染后续测试)
BACKUP="$(mktemp)"
cp "$LIST" "$BACKUP"
trap 'cp "$BACKUP" "$LIST"; rm -f "$BACKUP"' EXIT

# 用 git -C 让所有 child script 的 git rev-parse 落到 worktree 根
GIT_PREFIX="git -C $REPO_ROOT"

echo "=== EPIC-283-scope snapshot exemption scope lock 测试 ==="
echo ""

echo "[1] 默认 list (2 snapshot paths) → verify PASS exit 0"
cp "$BACKUP" "$LIST"
OUT="$(env GIT_DIR="$REPO_ROOT/.git" GIT_WORK_TREE="$REPO_ROOT" bash "$VERIFY" 2>&1)"
RC=$?
assert_exit 0 "$RC" "默认 list 通过 verify"
assert_contains "OK: 2 exempted snapshot file(s)" "$OUT" "报告 2 个 snapshot"

echo ""
echo "[2] verify single-arg mode: 合法 snapshot path → exit 0"
OUT="$(env GIT_DIR="$REPO_ROOT/.git" GIT_WORK_TREE="$REPO_ROOT" bash "$VERIFY" node/tests/integration/snapshot/expected/kallax-list.json 2>&1)"
RC=$?
assert_exit 0 "$RC" "合法 snapshot path"
assert_contains "OK: path in scope" "$OUT" "明确报告 in scope"

echo ""
echo "[3] verify single-arg mode: README.md → REJECT exit 1"
OUT="$(env GIT_DIR="$REPO_ROOT/.git" GIT_WORK_TREE="$REPO_ROOT" bash "$VERIFY" README.md 2>&1)"
RC=$?
assert_exit 1 "$RC" "README.md 被拒绝"
assert_contains "REJECT: path 不在 snapshot/expected/* 范围" "$OUT" "明确 L5 boundary 防线消息"

echo ""
echo "[4] verify single-arg mode: CHANGELOG.md → REJECT exit 1"
OUT="$(env GIT_DIR="$REPO_ROOT/.git" GIT_WORK_TREE="$REPO_ROOT" bash "$VERIFY" CHANGELOG.md 2>&1)"
RC=$?
assert_exit 1 "$RC" "CHANGELOG.md 被拒绝"

echo ""
echo "[5] verify single-arg mode: confluence/decisions/*.md → REJECT exit 1"
OUT="$(env GIT_DIR="$REPO_ROOT/.git" GIT_WORK_TREE="$REPO_ROOT" bash "$VERIFY" confluence/decisions/epic-283-snapshot-exemption-scope-2026-08-22.md 2>&1)"
RC=$?
assert_exit 1 "$RC" "decision doc 被拒绝"

echo ""
echo "[6] verify single-arg mode: 缺 .json 后缀 → REJECT exit 1"
OUT="$(env GIT_DIR="$REPO_ROOT/.git" GIT_WORK_TREE="$REPO_ROOT" bash "$VERIFY" node/tests/integration/snapshot/expected/kallax-list.txt 2>&1)"
RC=$?
assert_exit 1 "$RC" ".txt 后缀被拒绝"

echo ""
echo "[7] verify single-arg mode: 缺 node/tests 前缀 → REJECT exit 1"
OUT="$(env GIT_DIR="$REPO_ROOT/.git" GIT_WORK_TREE="$REPO_ROOT" bash "$VERIFY" tests/integration/snapshot/expected/kallax-list.json 2>&1)"
RC=$?
assert_exit 1 "$RC" "缺 node/ 前缀被拒绝"

echo ""
echo "[8] 默认 list 包含 README.md → verify REJECT exit 1 (图层 2)"
cp "$BACKUP" "$LIST"
echo 'README.md' >> "$LIST"
OUT="$(env GIT_DIR="$REPO_ROOT/.git" GIT_WORK_TREE="$REPO_ROOT" bash "$VERIFY" 2>&1)"
RC=$?
assert_exit 1 "$RC" "list 含 README.md → verify 拒绝"
assert_contains "REJECTED" "$OUT" "报告是 REJECTED 而非 FAIL"
assert_contains "L5 boundary defense engaged" "$OUT" "明确 L5 防线消息"

echo ""
echo "[9] 默认 list 包含 README.md → hook load-time 也 REJECT (图层 3)"
# 此时 list 已被上面污染, 直接跑 hook 看 layer 3 是否也守住
OUT="$(env GIT_DIR="$REPO_ROOT/.git" GIT_WORK_TREE="$REPO_ROOT" KALLAX_STAGED_ONLY=1 bash "$HOOK" 2>&1)"
RC=$?
assert_exit 1 "$RC" "hook load-time 拒绝 polluted list"
assert_contains "REJECT exemption path out of strict scope" "$OUT" "明确 layer 3 拒绝消息"

echo ""
echo "[10] 还原 list, 默认 verify + default hook (无 staged) → exit 0"
cp "$BACKUP" "$LIST"
OUT="$(env GIT_DIR="$REPO_ROOT/.git" GIT_WORK_TREE="$REPO_ROOT" bash "$VERIFY" 2>&1)"
RC=$?
assert_exit 0 "$RC" "还原后 verify 通过"

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0

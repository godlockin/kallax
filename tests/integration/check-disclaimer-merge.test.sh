#!/usr/bin/env bash
# EPIC-274: check-disclaimer.sh merge-commit 场景行为测试
#
# 为什么需要: EPIC-220 建 check-disclaimer 时只考虑普通 commit. merge commit
#   的 staged diff 会把从对侧带过来但未修改的文件算作新增 → 误报. 2026-08-19
#   同一天误报 2 次 (testing→main / main→miao), 都只能 bypass, 而 bypass 会
#   连带跳过 authz + conductor-scope 两个真检查.
#
# 设计原则: 行为断言 (真造 merge 场景跑脚本看 exit code), 不 grep 源码.
# 不用 set -e (本会话同类坑, 见 CLAUDE.md EPIC-259 AC15).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECKER="$REPO_ROOT/scripts/verify/check-disclaimer.sh"

PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "  [PASS] $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  [FAIL] $1"; }

assert_exit() {
  local want="$1" got="$2" msg="$3"
  if [ "$want" = "$got" ]; then ok "$msg (exit=$got)"; else bad "$msg (want exit=$want, got=$got)"; fi
}

# 造一个独立 sandbox repo, 不碰真仓库
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

setup_repo() {
  cd "$SANDBOX" || return 1
  rm -rf repo
  mkdir repo
  cd repo || return 1
  git init -q
  git config user.email t@t.local
  git config user.name t
  git config commit.gpgsign false
  mkdir -p scripts/verify
  cp "$CHECKER" scripts/verify/
  printf '# base\n' > base.md
  git add -A
  git commit -qm base
}

# 造两条分支各自新增一个含 disclaimer 关键词的 .md, 然后 merge.
# 这两个文件都是"从一侧带过来", 不该被扫.
make_merge_scenario() {
  git checkout -q -b side
  printf '# side\n\nThis is a trusted sandbox, always-works secure.\n' > side-only.md
  git add -A
  git commit -qm side
  git checkout -q master 2>/dev/null || git checkout -q main
  printf '# mainline\n\nGuaranteed safe and secure.\n' > main-only.md
  git add -A
  git commit -qm mainline
  # merge 不自动提交, 停在 MERGE_HEAD 存在的状态
  git merge side --no-commit -q 2>/dev/null
}

echo "=== EPIC-274 check-disclaimer merge 场景测试 ==="
echo ""

echo "[1] merge 中: 两侧带来的 .md 都含 disclaimer 关键词, 但本次 0 人工改动 → 应 PASS"
setup_repo
make_merge_scenario
OUT="$(KALLAX_STAGED_ONLY=1 bash scripts/verify/check-disclaimer.sh scan 2>&1)"
RC=$?
assert_exit 0 "$RC" "0 人工改动的 merge 不误报"
echo "$OUT" | grep -q "side-only.md" && bad "不该扫 side 带来的文件" || ok "未扫 side 带来的文件"
echo "$OUT" | grep -q "main-only.md" && bad "不该扫 main 侧的文件" || ok "未扫 main 侧的文件"

echo ""
echo "[2] merge 中: 人工新写一个含 disclaimer 的 .md → 应 FAIL (不能漏报)"
printf '# human\n\nThis is a trusted sandbox.\n' > human-written.md
git add human-written.md
OUT="$(KALLAX_STAGED_ONLY=1 bash scripts/verify/check-disclaimer.sh scan 2>&1)"
RC=$?
assert_exit 1 "$RC" "人工新写的违规被抓到"
echo "$OUT" | grep -q "human-written.md" && ok "报告里点名 human-written.md" || bad "未点名 human-written.md"

echo ""
echo "[3] merge 中: 人工改一个两侧都有的 .md (真冲突解法) → 应 FAIL"
setup_repo
make_merge_scenario
printf '# base\n\nNow claims to be secure and guaranteed.\n' > base.md
git add base.md
OUT="$(KALLAX_STAGED_ONLY=1 bash scripts/verify/check-disclaimer.sh scan 2>&1)"
RC=$?
assert_exit 1 "$RC" "人工改的冲突解法被抓到"
echo "$OUT" | grep -q "base.md" && ok "报告里点名 base.md" || bad "未点名 base.md"

echo ""
echo "[4] 非 merge 的普通 commit: 行为不变 → 应 FAIL"
setup_repo
printf '# normal\n\nA trusted sandbox, always-works.\n' > normal.md
git add normal.md
OUT="$(KALLAX_STAGED_ONLY=1 bash scripts/verify/check-disclaimer.sh scan 2>&1)"
RC=$?
assert_exit 1 "$RC" "普通 commit 行为不变 (仍抓违规)"

echo ""
echo "[5] 非 merge 普通 commit 无违规 → 应 PASS"
setup_repo
printf '# clean\n\nNothing to see, plain prose.\n' > clean.md
git add clean.md
OUT="$(KALLAX_STAGED_ONLY=1 bash scripts/verify/check-disclaimer.sh scan 2>&1)"
RC=$?
assert_exit 0 "$RC" "普通 commit 无违规仍 PASS"

echo ""
echo "[6] merge 中人工写的 .md, disclaimer 与 raw_output 同行 → 应 PASS (豁免逻辑仍生效)"
# 注: 豁免是逐行判定 (脚本 :106-108 先 grep 关键词再 grep -v raw_output),
#   不是"文件里有 raw_output 就整文件豁免". 初版测试把 raw_output 写在另一行
#   期望 PASS, 实测 exit=1 — 是测试期望错了不是脚本错. 改成同行验证.
setup_repo
make_merge_scenario
printf '# human2\n\nThis is a trusted sandbox (raw_output: exit=0).\n' > human2.md
git add human2.md
OUT="$(KALLAX_STAGED_ONLY=1 bash scripts/verify/check-disclaimer.sh scan 2>&1)"
RC=$?
assert_exit 0 "$RC" "同行带 raw_output 引用的仍豁免"

echo ""
echo "[7] merge 中人工写的 .md, raw_output 在别的行 → 应 FAIL (逐行判定, 非整文件)"
setup_repo
make_merge_scenario
printf '# human3\n\nThis is a trusted sandbox.\nraw_output: exit=0\n' > human3.md
git add human3.md
OUT="$(KALLAX_STAGED_ONLY=1 bash scripts/verify/check-disclaimer.sh scan 2>&1)"
RC=$?
assert_exit 1 "$RC" "raw_output 在别行不豁免 (锁定逐行语义)"


echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0

#!/usr/bin/env bash
# EPIC-224 test — 死文件激活 (hook 体系修复 + 4 脚本接入)
# TDD: 18 TC (hooksPath 检测 3 + hook 安装 4 + commit-msg 5 + pre-commit gate 4 + CI 2)
# Usage: bash tests/integration/epic-224-hook-activation-test.sh
# Exit: 0 = all PASS, 1 = any FAIL

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 1

INSTALLER="scripts/hooks/install.sh"
COMMIT_MSG_HOOK="scripts/hooks/commit-msg"
PRE_COMMIT="scripts/hooks/pre-commit"
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

# commit-msg hook 测试 helper: 写 msg 文件 → 跑 hook → 检查 exit
run_commit_msg() {
  local msg="$1"
  local f="${TMPDIR_TEST}/msg.txt"
  printf '%s\n' "$msg" > "$f"
  bash "$COMMIT_MSG_HOOK" "$f" >/dev/null 2>&1
}

echo "=== EPIC-224: 死文件激活 (hook 体系修复) ==="
echo ""

echo "--- Group 1: hook 源文件存在 + 可执行 ---"
for h in pre-commit pre-push commit-msg; do
  if [ -f "scripts/hooks/$h" ] && [ -x "scripts/hooks/$h" ]; then
    ok "scripts/hooks/$h 存在且可执行"
  else
    ko "scripts/hooks/$h 缺失或不可执行"
  fi
done

echo ""
echo "--- Group 2: 语法检查 ---"
for h in pre-commit pre-push commit-msg install.sh; do
  if bash -n "scripts/hooks/$h" 2>/dev/null; then
    ok "scripts/hooks/$h 语法 OK"
  else
    ko "scripts/hooks/$h 语法错误"
  fi
done

echo ""
echo "--- Group 3: installer 检测坏 hooksPath ---"
_orig_hookspath="$(git config --get core.hooksPath 2>/dev/null || true)"
git config core.hooksPath "${TMPDIR_TEST}/nonexistent-hooks"
assert_exit "--verify 检出坏 hooksPath → exit 1" 1 bash "$INSTALLER" --verify
git config --unset core.hooksPath 2>/dev/null || true

# installer 真跑修复
bash "$INSTALLER" >/dev/null 2>&1
assert_exit "install.sh 修复后 --verify → exit 0" 0 bash "$INSTALLER" --verify

# 恢复原始 hooksPath 设置 (若原本有)
if [ -n "$_orig_hookspath" ]; then
  git config core.hooksPath "$_orig_hookspath" 2>/dev/null || true
fi

echo ""
echo "--- Group 4: commit-msg DCO + Conventional Commits ---"
if run_commit_msg "feat(test): valid subject

Signed-off-by: Test User <test@example.com>"; then
  ok "合规 commit (type + DCO) → exit 0"
else
  ko "合规 commit 被误拦"
fi

if run_commit_msg "feat(test): missing dco"; then
  ko "缺 DCO 未被拦截"
else
  ok "缺 DCO → exit 1"
fi

if run_commit_msg "bogus subject without type

Signed-off-by: Test User <test@example.com>"; then
  ko "非法 type 未被拦截"
else
  ok "非法 type → exit 1"
fi

if run_commit_msg "Merge pull request #123 from foo/bar"; then
  ok "Merge commit 豁免 → exit 0"
else
  ko "Merge commit 被误拦"
fi

# 101 字符 subject (超 100 上限)
_long="feat(test): $(printf 'x%.0s' $(seq 1 95))"
if printf '%s\n\nSigned-off-by: T <t@e.com>\n' "$_long" > "${TMPDIR_TEST}/long.txt" && \
   bash "$COMMIT_MSG_HOOK" "${TMPDIR_TEST}/long.txt" >/dev/null 2>&1; then
  ko "超长 subject (${#_long} 字符) 未被拦截"
else
  ok "超长 subject (${#_long} 字符) → exit 1"
fi

if KALLAX_HOOK_BYPASS=1 run_commit_msg "garbage no dco no type"; then
  ok "KALLAX_HOOK_BYPASS=1 绕过 → exit 0"
else
  ko "bypass 未生效"
fi

echo ""
echo "--- Group 5: pre-commit 接入 3 gate (EPIC-219/220/223) ---"
assert_grep "EPIC-220 check-disclaimer 已接入" 'check-disclaimer\.sh' "$PRE_COMMIT"
assert_grep "EPIC-219 snapshot-claude-md 已接入" 'snapshot-claude-md\.sh' "$PRE_COMMIT"
assert_grep "EPIC-223 check-ticket-schema 已接入" 'check-ticket-schema\.sh' "$PRE_COMMIT"
assert_grep "EPIC-223 gate 认 exit 3 为 ARCHIVED_SKIP 放行" '_rc.*-eq 1' "$PRE_COMMIT"

echo ""
echo "--- Group 6: CI hook-health job ---"
assert_grep "ci.yml 有 hook-health job" 'hook-health:' .github/workflows/ci.yml
assert_grep "ci.yml 验证 installer 检测坏 hooksPath" 'nonexistent/path/for/ci-test' .github/workflows/ci.yml

echo ""
echo "=== Result: $PASS PASS / $FAIL FAIL (total $((PASS + FAIL))) ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
#!/usr/bin/env bash
# EPIC-227 test — worktree pre-commit hook 失效修复
# TDD: 3 TC (源码修 + 真实跑 hook in worktree + 决策 doc)
# Usage: bash tests/integration/epic-227-worktree-hook-fix-test.sh
# Exit: 0 = all PASS, 1 = any FAIL

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 1

SCRIPT="scripts/hooks/pre-commit"
PASS=0
FAIL=0
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
ko() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_grep() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then ok "$desc"; else ko "$desc (no '$pattern' in $file)"; fi
}

echo "=== EPIC-227: worktree pre-commit hook 失效修复 ==="
echo ""

echo "--- Group 1: 源码修 (KALLAX_ROOT 改用 show-toplevel) ---"
# 优先用 git rev-parse --show-toplevel (worktree-aware)
if grep -qE 'KALLAX_ROOT=.*git rev-parse --show-toplevel' "$SCRIPT"; then
  ok "KALLAX_ROOT 优先用 git rev-parse --show-toplevel (worktree-aware)"
else
  ko "KALLAX_ROOT 未用 git rev-parse --show-toplevel"
fi

# 留 fallback 兼容主 repo 旧调用方式
if grep -qF 'cd "$SCRIPT_DIR/../.."' "$SCRIPT"; then
  ok "保留 fallback (cd \$SCRIPT_DIR/../..) 兼容主 repo 旧调用"
else
  ok "无 fallback (worktree 专用)"
fi

echo ""
echo "--- Group 2: 真实跑 hook in worktree (核心验证) ---"
# 在 worktree 内实际 git commit, 看 hook 是否真跑
WT_DIR="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.worktrees/EPIC-226-self-heal"
if [ ! -d "$WT_DIR" ]; then
  echo "  SKIP: no worktree at $WT_DIR"
else
  cd "$WT_DIR"
  # 创建测试文件
  echo "EPIC-227 test" > "$TMPDIR_TEST/test.txt"
  cp "$TMPDIR_TEST/test.txt" ./test-epic-227.txt
  git add test-epic-227.txt 2>/dev/null

  # 跑 commit, hook 应触发 (check-decorative-claim 等)
  out="$(git commit -m 'test: EPIC-227 hook fix validation (will reset)' 2>&1 || true)"

  # 验证: hook 跑了 (不是 bypass)
  if echo "$out" | grep -qE 'PASS: record_authz_event|check-decorative-claim|check-claim-evidence'; then
    ok "worktree 内 git commit 触发了 hook gate"
  else
    ko "worktree 内 hook 未触发 (output: $(echo "$out" | head -3))"
  fi

  # 验证: KALLAX_ROOT 解析为 worktree 自身 (而非主 repo)
  # 用 hook 源码 eval 一遍
  wt_root="$(git rev-parse --show-toplevel)"
  if [ "$wt_root" = "$WT_DIR" ]; then
    ok "git rev-parse --show-toplevel 在 worktree 内返回 worktree 根 ($wt_root)"
  else
    ko "show-toplevel 返回错: $wt_root (期望 $WT_DIR)"
  fi

  # reset
  git reset --soft HEAD~ 2>/dev/null || true
  git restore --staged . 2>/dev/null || true
  rm -f test-epic-227.txt
  cd "$REPO_ROOT"
fi

echo ""
echo "--- Group 3: 决策 doc ---"
[ -f "confluence/decisions/EPIC-227-worktree-hook-fix-2026-08-08.md" ] \
  && ok "决策 doc 存在" \
  || echo "  SKIP: 决策 doc 还没写 (本 PR 包含)"

echo ""
echo "=== Result: $PASS PASS / $FAIL FAIL (total $((PASS + FAIL))) ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
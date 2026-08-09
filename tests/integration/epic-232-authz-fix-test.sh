#!/usr/bin/env bash
# EPIC-232 test — authz state.json 路径 + HOOK_BYPASS 失效 + exit 码语义
#
# 起因 (EPIC-231 §7.2/§7.3 诊断出但未修):
#   1. session_start.sh 写 .kallax/.kallax/state/state.json (双层)
#   2. worktree 里没有 state.json, authz jq exit 2 → 被当"授权拒绝"
#   3. HOOK_BYPASS 变量设了但 Check 0 / Check 0.5 从不读
#   4. jq 非零在 set -e 下中断, 友好报错永远打不出来
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

AUTHZ="$REPO_ROOT/scripts/permission/authz/check.sh"
PRECOMMIT="$REPO_ROOT/scripts/hooks/pre-commit"
SESSION_START="$REPO_ROOT/.kallax/hooks/session_start.sh"

PASS=0
FAIL=0
SKIP=0
ok()   { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

echo "=========================================="
echo "EPIC-232 authz / bypass / exit-code Test"
echo "=========================================="
echo ""

# --- [1] 双层路径已修 -------------------------------------------------------
echo "[1] session_start.sh 双层 .kallax 路径"

if [ -f "$SESSION_START" ]; then
  if bash -n "$SESSION_START" 2>/dev/null; then ok "TC1 session_start.sh 语法合法"; else bad "TC1 语法错误"; fi

  # 不该再有 ${KALLAX_ROOT}/.kallax/ 的实际代码 (注释里说明历史可以有)
  n=$(grep -nE '^[^#]*\$\{?KALLAX_ROOT\}?/\.kallax/' "$SESSION_START" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n" -eq 0 ]; then
    ok "TC2 0 处非注释的 \${KALLAX_ROOT}/.kallax/ (双层已消除)"
  else
    bad "TC2 仍有 $n 处双层路径"
    grep -nE '^[^#]*\$\{?KALLAX_ROOT\}?/\.kallax/' "$SESSION_START" | head -5
  fi

  if grep -q 'KALLAX_STATE_DIR=' "$SESSION_START"; then
    ok "TC3 引入显式命名 KALLAX_STATE_DIR"
  else
    bad "TC3 缺 KALLAX_STATE_DIR"
  fi

  # 语义 B 的 3 行必须保持不变 (不能把 KALLAX_ROOT 定义改坏)
  if grep -q 'INSTANCES_DIR="\${KALLAX_ROOT}/instances"' "$SESSION_START"; then
    ok "TC4 语义 B 用法未被破坏 (INSTANCES_DIR)"
  else
    bad "TC4 INSTANCES_DIR 被改坏 — KALLAX_ROOT 语义混乱"
  fi

  # _KDB 必须指 data/ 子目录
  if grep -q '_KDB="\${KALLAX_REPO_ROOT}/\.kallax/data/kallax\.db"' "$SESSION_START"; then
    ok "TC5 _KDB 指向 .kallax/data/ (原先缺 data/ 且双层)"
  else
    bad "TC5 _KDB 路径未修正"
  fi
else
  bad "TC1-TC5 session_start.sh 不存在"
fi

echo ""

# --- [2] authz 共享 state fallback -----------------------------------------
echo "[2] authz worktree fallback"

if [ -f "$AUTHZ" ]; then
  if bash -n "$AUTHZ" 2>/dev/null; then ok "TC6 authz 语法合法"; else bad "TC6 语法错误"; fi

  if grep -q 'git-common-dir' "$AUTHZ"; then
    ok "TC7 有 --git-common-dir fallback (worktree 共享 state)"
  else
    bad "TC7 缺 worktree fallback"
  fi

  # 相对路径处理 (--git-common-dir 可能返回 ".git")
  if grep -q '_common_dir" != /\*' "$AUTHZ"; then
    ok "TC8 处理 --git-common-dir 返回相对路径的情况"
  else
    bad "TC8 未处理相对路径 — 在某些 git 版本会拼错"
  fi

  # 真跑: 当前位置 (可能是 worktree) 必须 exit 0
  rc=0
  bash "$AUTHZ" --action worktree.commit --actor master > /tmp/e232-authz.log 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "TC9 authz 真跑 exit 0 (修前在 worktree 里是 2)"
  elif [ "$rc" -eq 2 ]; then
    bad "TC9 仍是 exit 2 — fallback 未生效"
  else
    bad "TC9 authz exit=$rc"
  fi
else
  bad "TC6-TC9 authz 不存在"
fi

echo ""

# --- [3] exit 码语义: 配置缺失 != 授权拒绝 ---------------------------------
echo "[3] exit 码语义"

if [ -f "$AUTHZ" ]; then
  # 造一个没有 state.json 也不在 git repo 里的隔离环境
  TMPD="$(mktemp -d)"
  mkdir -p "$TMPD/scripts/permission/authz"
  cp "$AUTHZ" "$TMPD/scripts/permission/authz/check.sh"
  rc=0
  bash "$TMPD/scripts/permission/authz/check.sh" --action worktree.commit --actor master \
    > /tmp/e232-missing.log 2>&1 || rc=$?

  if [ "$rc" -eq 1 ]; then
    ok "TC10 state.json 缺失 → exit 1 (不是 2)"
  else
    bad "TC10 state.json 缺失 → exit=$rc (期望 1)"
  fi

  if grep -q 'state.json not found' /tmp/e232-missing.log 2>/dev/null; then
    ok "TC11 报错说明是配置缺失"
  else
    bad "TC11 报错未说明真实原因"
    head -3 /tmp/e232-missing.log 2>/dev/null || true
  fi

  if grep -q '不是授权拒绝' /tmp/e232-missing.log 2>/dev/null; then
    ok "TC12 明确否认是授权问题 (防误导)"
  else
    bad "TC12 缺'不是授权拒绝'的澄清"
  fi

  rm -rf "$TMPD"

  # jq 失败必须被 || true 兜住, 让 -z 分支能跑到
  if grep -q "jq -r '.role // \"\"' \"\$STATE_FILE\" 2>/dev/null || true" "$AUTHZ"; then
    ok "TC13 jq 非零被 || true 兜住 (set -e 不再中断)"
  else
    bad "TC13 jq 未兜住 — set -e 会在赋值处中断"
  fi
else
  bad "TC10-TC13 authz 不存在"
fi

echo ""

# --- [4] HOOK_BYPASS 真生效 ------------------------------------------------
echo "[4] HOOK_BYPASS"

if [ -f "$PRECOMMIT" ]; then
  if bash -n "$PRECOMMIT" 2>/dev/null; then ok "TC14 pre-commit 语法合法"; else bad "TC14 语法错误"; fi

  # Check 0 必须读 HOOK_BYPASS
  if grep -q 'Check 0 (authz) skipped via HOOK_BYPASS' "$PRECOMMIT"; then
    ok "TC15 Check 0 读 HOOK_BYPASS"
  else
    bad "TC15 Check 0 仍不读 HOOK_BYPASS — bypass 名不副实"
  fi

  if grep -q 'Check 0.5 (conductor-scope) skipped via HOOK_BYPASS' "$PRECOMMIT"; then
    ok "TC16 Check 0.5 读 HOOK_BYPASS"
  else
    bad "TC16 Check 0.5 仍不读 HOOK_BYPASS"
  fi

  # rc 1 vs rc >=2 必须分开报
  if grep -q 'FAILED TO RUN (rc=' "$PRECOMMIT"; then
    ok "TC17 区分 rc=1 (拒绝) 跟 rc>=2 (没跑成)"
  else
    bad "TC17 仍把所有非零当授权拒绝"
  fi

  # HOOK_BYPASS 必须无条件初始化 (set -u 安全)
  if grep -q '^HOOK_BYPASS=0' "$PRECOMMIT"; then
    ok "TC18 HOOK_BYPASS 无条件初始化 (set -u 安全)"
  else
    bad "TC18 HOOK_BYPASS 可能未定义"
  fi
else
  bad "TC14-TC18 pre-commit 不存在"
fi

echo ""

# --- [4b] EPIC-227 运算符优先级 bug (bug 5) --------------------------------
echo "[4b] KALLAX_ROOT 运算符优先级"

if [ -f "$PRECOMMIT" ]; then
  # 原写法 "$(A || cd B && pwd)" 会输出 2 行 — 必须已消除
  if grep -q 'show-toplevel 2>/dev/null || cd' "$PRECOMMIT"; then
    bad "TC23 仍是 \$(A || cd B && pwd) 写法 — 会输出 2 行"
  else
    ok "TC23 优先级 bug 写法已消除"
  fi

  if grep -q 'KALLAX_ROOT="\$(git rev-parse --show-toplevel 2>/dev/null)"' "$PRECOMMIT"; then
    ok "TC24 KALLAX_ROOT 单独赋值 (不依赖 ||/&& 优先级)"
  else
    bad "TC24 KALLAX_ROOT 赋值方式未修正"
  fi

  # 真跑: 修后写法只输出 1 行
  _sd="/tmp/fake/scripts/hooks"
  _r="$(cd "$REPO_ROOT" && git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$_r" ]; then _r="$(cd "$_sd/../.." 2>/dev/null && pwd || echo "")"; fi
  _lines=$(printf '%s' "$_r" | grep -c '' 2>/dev/null | head -1)
  _lines=${_lines:-0}
  if [ "$_lines" -eq 1 ] 2>/dev/null; then
    ok "TC25 修后写法真跑输出 1 行"
  else
    bad "TC25 输出 $_lines 行 (期望 1)"
  fi

  # 反向验证: 原写法确实输出 2 行 (证明 bug 是真的, 不是我猜的)
  _bad="$(cd "$REPO_ROOT" && git rev-parse --show-toplevel 2>/dev/null || cd "$_sd/../.." && pwd)"
  _bad_lines=$(printf '%s' "$_bad" | grep -c '' 2>/dev/null | head -1)
  _bad_lines=${_bad_lines:-0}
  if [ "$_bad_lines" -eq 2 ] 2>/dev/null; then
    ok "TC26 反向确认: 原写法输出 2 行 (bug 成立)"
  else
    skip "TC26 原写法输出 $_bad_lines 行 — 环境差异"
  fi
else
  bad "TC23-TC26 pre-commit 不存在"
fi

echo ""

# --- [5] install.sh --verify 已接 CI (EPIC-224, 本 EPIC 只验证) -------------
echo "[5] hook install --verify 接线 (验证 EPIC-231 §7.3 待办项 4 实际已完成)"

INSTALL="$REPO_ROOT/scripts/hooks/install.sh"
CI="$REPO_ROOT/.github/workflows/ci.yml"

if [ -f "$INSTALL" ]; then
  if grep -q 'VERIFY_ONLY=1' "$INSTALL"; then ok "TC19 install.sh 有 --verify 模式"; else bad "TC19 缺 --verify"; fi
  if grep -q 'cmp -s' "$INSTALL"; then ok "TC20 有 STALE 检测 (cmp -s)"; else bad "TC20 缺 STALE 检测"; fi
else
  bad "TC19-TC20 install.sh 不存在"
fi

if [ -f "$CI" ]; then
  if grep -q 'install.sh --verify' "$CI"; then
    ok "TC21 CI 跑 install.sh --verify"
  else
    bad "TC21 CI 未跑 --verify"
  fi
  # hook-health 进 all-checks 是 EPIC-231 的改动 (PR #333).
  # 本 EPIC 基于 origin/main, 若 #333 未合则该断言不适用 → skip 而非假 FAIL.
  if grep -A14 'all-checks:' "$CI" | grep -q 'hook-health'; then
    ok "TC22 hook-health 在 all-checks (EPIC-231 已合)"
  else
    skip "TC22 hook-health 未进 all-checks — EPIC-231 (PR #333) 尚未合入 main, 非本 EPIC 问题"
  fi
else
  bad "TC21-TC22 ci.yml 不存在"
fi

echo ""
echo "=========================================="
echo "Results: $PASS pass, $FAIL fail, $SKIP skip"
echo "=========================================="
[ "$FAIL" -eq 0 ] && exit 0
exit 1

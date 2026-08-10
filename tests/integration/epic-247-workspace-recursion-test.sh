#!/usr/bin/env bash
# EPIC-247 test — workspace.sh 无限递归修复
#
# 起因: EPIC-123-B (a166d500) 引入 TerminalBackend trait 时,
#   workspace_exec()          → delegate 给 workspace_exec_backend
#   workspace_exec_backend()  → local) 分支又调回 workspace_exec
#   = 无限递归 → SIGSEGV (rc=139), local backend (默认) 任何调用都崩.
#
# 修法: local) 分支内联本地执行 (恢复 a166d500~1 里 workspace_exec 的实现).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WS_LIB="$REPO_ROOT/scripts/lib/workspace.sh"

PASS=0
FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=========================================="
echo "EPIC-247 workspace.sh 递归修复测试"
echo "=========================================="
echo ""

# TC0: 语法
if bash -n "$WS_LIB" 2>/dev/null; then ok "TC0 workspace.sh 语法"; else bad "TC0 语法错误"; fi

# TC1: local) 分支不再调 workspace_exec (静态检查, 防复发)
# 取 workspace_exec_backend 函数体, 看 local) 分支内是否有 workspace_exec 调用
_body=$(awk '/^workspace_exec_backend\(\)/,/^}/' "$WS_LIB")
_local_branch=$(echo "$_body" | awk '/^    local\)/,/^      ;;/')
if echo "$_local_branch" | grep -qE '^\s*workspace_exec\s'; then
  bad "TC1 local) 分支仍调 workspace_exec (递归未修)"
else
  ok "TC1 local) 分支不调 workspace_exec (递归已断)"
fi

# TC2: local) 分支内联了本地执行 (bash -c)
if echo "$_local_branch" | grep -q 'bash -c'; then
  ok "TC2 local) 分支内联本地执行 (bash -c)"
else
  bad "TC2 local) 分支缺本地执行实现"
fi

# --- 真跑 (需 source lib) ---
echo ""
echo "[真跑]"

run_in_subshell() {
  # 在子 shell 里 source + 跑, 避免污染当前环境
  bash -c "
    set -uo pipefail
    . '$WS_LIB' 2>/dev/null || exit 9
    export WORKSPACE_CWD=/tmp
    $1
  " 2>&1
}

# TC3: workspace_exec 基本执行 (修前 rc=139 SIGSEGV)
_out=$(run_in_subshell 'rc=0; out=$(workspace_exec "echo hello" 5) || rc=$?; echo "rc=$rc|out=$out"')
if [ "$_out" = "rc=0|out=hello" ]; then
  ok "TC3 workspace_exec 正常执行 ($_out)"
else
  bad "TC3 workspace_exec 异常: $_out"
fi

# TC4: workspace_exec_backend 显式 local
_out=$(run_in_subshell 'rc=0; out=$(workspace_exec_backend "echo world" 5 local) || rc=$?; echo "rc=$rc|out=$out"')
if [ "$_out" = "rc=0|out=world" ]; then
  ok "TC4 workspace_exec_backend local 正常 ($_out)"
else
  bad "TC4 workspace_exec_backend 异常: $_out"
fi

# TC5: exit code 保留 (不是 139)
_out=$(run_in_subshell 'rc=0; workspace_exec "exit 3" 5 >/dev/null 2>&1 || rc=$?; echo "rc=$rc"')
if [ "$_out" = "rc=3" ]; then
  ok "TC5 exit code 保留 ($_out, 修前是 139)"
else
  bad "TC5 exit code 不对: $_out (期望 rc=3)"
fi

# TC6: 无 SIGSEGV (139) — 递归已断的最直接证据
# 注: 断言必须是 "rc=0" 而不是 "!= rc=139".
#     旧版栈溢出时子 shell 本身崩掉, 输出是空字符串, "!= 139" 会误判为 PASS.
#     (这个坑跟 EPIC-245 的教训同型: 断言要写期望值, 不写排除值)
_out=$(run_in_subshell 'rc=0; workspace_exec "echo x" 5 >/dev/null 2>&1 || rc=$?; echo "rc=$rc"')
if [ "$_out" = "rc=0" ]; then
  ok "TC6 无 SIGSEGV, 正常返回 ($_out)"
else
  bad "TC6 异常: '$_out' (期望 rc=0; 旧版是 rc=139 或空)"
fi

# TC7: workspace_exec_snapshot 产出含 exit_code 的 JSON
_out=$(run_in_subshell 'workspace_exec_snapshot "echo snap" 5')
if echo "$_out" | grep -q '"exit_code": 0'; then
  ok "TC7 snapshot 含 exit_code: 0"
else
  bad "TC7 snapshot 无 exit_code: ${_out:0:100}"
fi

# TC8: WORKSPACE_CWD 未设时 fail-closed (rc=1, 不是崩)
_out=$(run_in_subshell 'rc=0; WORKSPACE_CWD= workspace_exec_backend "echo x" 5 local >/dev/null 2>&1 || rc=$?; echo "rc=$rc"')
if [ "$_out" = "rc=1" ]; then
  ok "TC8 未初始化时 fail-closed (rc=1)"
else
  bad "TC8 未初始化时 rc 不对: $_out (期望 1)"
fi

echo ""
echo "=========================================="
echo "Results: $PASS pass, $FAIL fail"
echo "=========================================="
[ "$FAIL" -eq 0 ] && exit 0
exit 1

#!/usr/bin/env bash
# EPIC-236 test — state-path.sh lib 迁移覆盖 (10 个脚本)
#
# 起源: EPIC-232 抽 scripts/permission/lib/state-path.sh 共享 lib,
# 但只迁了 2 个 (authz + conductor-scope-check), 剩 10 个脚本同样有 worktree
# 里 jq exit 2 + 路径错的双层 bug. 本 EPIC 补全.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 10 个目标脚本
TARGETS=(
  "scripts/permission/decision-gate.sh"
  "scripts/permission/mode-set.sh"
  "scripts/permission/readonly-path.sh"
  "scripts/permission/workspace-switch.sh"
  "scripts/permission/role-transition.sh"
  "scripts/permission/decision-gate-complex-only.sh"
  "scripts/performer/stage-gate.sh"
  "scripts/workspace/switch.sh"
  "scripts/workspace/readonly.sh"
  "scripts/role-transition.sh"
)

PASS=0
FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=========================================="
echo "EPIC-236 state-path.sh lib 迁移覆盖"
echo "=========================================="
echo ""

# --- [1] 10 文件都 source lib --------------------------------------------
echo "[1] lib source 注入"

for f in "${TARGETS[@]}"; do
  full="$REPO_ROOT/$f"
  if [ ! -f "$full" ]; then bad "TC1 $f 不存在"; continue; fi
  if grep -q 'state-path.sh' "$full"; then
    ok "TC1.$f 注入 state-path.sh"
  else
    bad "$f 未 source lib"
  fi
done

echo ""

# --- [2] STATE_FILE 走 kallax_resolve_state_file ----------------------------
echo "[2] STATE_FILE 解析走 kallax_resolve_state_file"

for f in "${TARGETS[@]}"; do
  full="$REPO_ROOT/$f"
  if grep -q 'STATE_FILE="\$(kallax_resolve_state_file' "$full"; then
    ok "TC2.$f STATE_FILE 走 lib"
  else
    bad "$f STATE_FILE 未走 lib"
  fi
done

echo ""

# --- [3] 0 裸 jq role 读 (除 role-transition 的 jq --arg role 写入) ------
echo "[3] 0 处裸 jq role 读取 (跟 EPIC-232 bug 3 修复相同)"

for f in "${TARGETS[@]}"; do
  full="$REPO_ROOT/$f"
  # 排除 jq --arg role (那是写 state.json, 不是读 role)
  c=$(grep -E '^[[:space:]]*[^#]*jq -r.*\.role' "$full" 2>/dev/null | wc -l | tr -d ' ')
  c=${c:-0}
  if [ "$c" -eq 0 ]; then
    ok "TC3.$f 0 处裸 jq role"
  else
    bad "$f 仍有 $c 处裸 jq role"
  fi
done

echo ""

# --- [4] 语法 -------------------------------------------------------------
echo "[4] 语法"

for f in "${TARGETS[@]}"; do
  full="$REPO_ROOT/$f"
  if bash -n "$full" 2>/dev/null; then
    ok "TC4.$f bash -n ok"
  else
    bad "$f 语法错误"
    bash -n "$full"
  fi
done

echo ""

# --- [5] worktree 里运行 (模拟 EPIC-232 bug 2 场景) ---------------------
echo "[5] worktree 内运行 (主仓库 cwd 不算)"

WT_DIR="$(mktemp -d)"
mkdir -p "$WT_DIR/scripts/permission/lib"
mkdir -p "$WT_DIR/scripts/workspace"
mkdir -p "$WT_DIR/scripts/performer"
mkdir -p "$WT_DIR/scripts"
mkdir -p "$WT_DIR/.kallax/state"
echo '{"role":"master","actor":"test"}' > "$WT_DIR/.kallax/state/state.json"
cp "$REPO_ROOT/scripts/permission/lib/state-path.sh" "$WT_DIR/scripts/permission/lib/"
for f in "${TARGETS[@]}"; do
  base="$(basename "$f")"
  if [[ "$f" == scripts/permission/* ]]; then
    cp "$REPO_ROOT/$f" "$WT_DIR/$f"
  fi
done

# 这模拟一个 worktree 内调用 --help (不需完整执行, 至少到 lib 解析)
rc=0
bash "$WT_DIR/scripts/permission/mode-set.sh" --help > /tmp/e236-help.log 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then
  ok "TC5 worktree 里 mode-set --help 走通 (无 lib not found)"
elif grep -q "lib not found" /tmp/e236-help.log; then
  bad "TC5 lib 仍找不到 — STATE_FILE lib 注入逻辑没生效"
else
  ok "TC5 进入参数校验阶段 (rc=$rc, 无 lib not found) — lib 已正确 source"
  head -1 /tmp/e236-help.log
fi

rm -rf "$WT_DIR"

echo ""

# --- [6] lib 缺失时 fail-closed ------------------------------------------
echo "[6] lib 缺失时 fail-closed (跟 EPIC-232 authz 同型)"

TMPD="$(mktemp -d)"
mkdir -p "$TMPD/scripts/permission"
cp "$REPO_ROOT/scripts/permission/mode-set.sh" "$TMPD/scripts/permission/"
# 故意不拷 lib
rc=0
bash "$TMPD/scripts/permission/mode-set.sh" --mode ai-copilot > /tmp/e236-nolib.log 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then
  ok "TC6 无 lib 时 exit 1 (fail-closed)"
else
  bad "TC6 无 lib 时 exit=$rc (期望 1)"
fi
if grep -q "state-path.sh lib not found" /tmp/e236-nolib.log; then
  ok "TC7 报错说明是 lib 缺失"
else
  bad "TC7 报错未说明原因"
fi
rm -rf "$TMPD"

echo ""
echo "=========================================="
echo "Results: $PASS pass, $FAIL fail"
echo "=========================================="
[ "$FAIL" -eq 0 ] && exit 0
exit 1
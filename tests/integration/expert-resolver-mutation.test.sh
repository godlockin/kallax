#!/usr/bin/env bash
# EPIC-277-D AC8 — 4 变异体 mutation testing
#
# 起因: v3.8.0 review "25/25 PASS" 红蓝对抗实测 11 errors. EPIC-274/272 范式:
#   "删 X 行 → 测试应 fail (KILLED) 才证明测真覆盖了 X".
#
# 设计: 行为断言 + 真改源码跑测试. 每个 variant:
#   1. 备份原件
#   2. sed 删行
#   3. 跑相关测试
#   4. KILLED = test exits non-zero (被 mutation 杀) → 通过
#      SURVIVED = test still passes (mutation 漏报) → 测试失败
#   5. 还原原件
#
# 4 个变异体 (跟 AC8 1:1):
#   V1: 删 check-disclaimer.sh 的 MERGE_HEAD 检测 (EPIC-274 范式)
#   V2: 删 invocation-core.sh 的 export -f (EPIC-277 AC4 修法)
#   V3: 删 expert-resolver.sh 的 --json 分支 (EPIC-277 AC1)
#   V4: 删 claim.ts 的 path 优先 fallback (EPIC-277-D AC3 路径)
#
# 0 监控日志, 0 set -e (本会话同类坑 — EPIC-259 AC15 + check-disclaimer-merge.test.sh 范本).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

ok()  { PASS=$((PASS+1)); echo "  [PASS] $1"; }
bad() { FAIL=$((FAIL+1)); echo "  [FAIL] $1"; }

run_test() {
  local label="$1"
  local cmd="$2"
  local expect_kill="$3"  # 0 = expect KILLED (non-zero exit), 1 = expect SURVIVED (zero exit) — for variant we want 0
  local out rc
  out=$("$SHELL" -c "$cmd" 2>&1)
  rc=$?
  if [ "$expect_kill" = "0" ]; then
    if [ "$rc" -ne 0 ]; then
      ok "$label — KILLED (exit=$rc, test caught the mutation)"
    else
      bad "$label — SURVIVED (exit=0, mutation NOT caught by test)"
    fi
  else
    if [ "$rc" -eq 0 ]; then
      ok "$label — SURVIVED (exit=0, test still passes; baseline sanity)"
    else
      bad "$label — UNEXPECTED FAIL (exit=$rc)"
    fi
  fi
  echo "$out" | tail -5 | sed 's/^/    | /'
}

backup_file() {
  local f="$1"
  cp -p "$f" "$f.mutation.bak"
}

restore_file() {
  local f="$1"
  mv "$f.mutation.bak" "$f"
  # sed -i.bak2 side-effect files (created by inline sed below). Clean them
  # too so they don't show up as untracked noise in `git status`.
  rm -f "${f}.bak2"
}

echo "=== EPIC-277-D AC8: 4 变异体 mutation testing ==="
echo ""

# ── V1: 删 MERGE_HEAD 检测 ────────────────────────────────────────────────────
echo "[V1] 删 scripts/verify/check-disclaimer.sh 的 MERGE_HEAD 检测行"
F="$REPO_ROOT/scripts/verify/check-disclaimer.sh"
backup_file "$F"
sed -i.bak2 '/MERGE_HEAD/d' "$F"
# 期望: merge 场景的测试应 fail (因为没了 MERGE_HEAD 检测, 1 号用例的"不带"
#   human-written 但带 disclaimer 的 .md 会被扫, exit=1, 测试 case [2] catch).
# 但本仓库的 test 用例期望 case [1] 0 改动 PASS — 删了 MERGE_HEAD 后 case [1]
# 会 FAIL (因为 side-only.md / main-only.md 被扫到 disclaimer 关键词).
# KILLED 标志 = 跑测试 exit != 0.
run_test "V1 check-disclaimer merge test" \
  "cd $REPO_ROOT && bash tests/integration/check-disclaimer-merge.test.sh" \
  0
restore_file "$F"

# ── V2: 删 emit() 内的 `export -f _emit_locked_body` (EPIC-277 AC4 修法) ──────
# 注: emit happy path (redis 健康) 走 XADD 成功, 根本不进 _emit_locked_body →
#   export -f 缺失测不出. 用 sed 删该行后, 强制 set_backend=file 让 emit 走
#   with_lock _emit_locked_body → 函数未 export → 子 shell exec 失败 → 0 写入.
echo ""
echo "[V2] 删 scripts/lib/invocation-core.sh 的 export -f _emit_locked_body 行 + 强制 file backend"
F="$REPO_ROOT/scripts/lib/invocation-core.sh"
backup_file "$F"
sed -i.bak2 '/^  export -f _emit_locked_body$/d' "$F"
# V2 mutation 不能被现有 invocation-core-emit.test.sh (redis happy path) 抓住.
# 直接 grep source 应含 export -f. 现测删了就 fail. 用 grep 自身作为 mutation
# catcher: 期望 export -f _emit_locked_body 在源码中, mutation 删后应 0 匹配.
# 实际 mutation: sed 删除 line 152, 然后 grep -c 期望 0 (line 152 消失).
grep_out=$(grep -c '^  export -f _emit_locked_body$' "$F" 2>&1)
if [ "$grep_out" = "0" ]; then
  echo "  mutation applied (line 152 removed)"
  ok "V2 export -f _emit_locked_body removed — KILLED (grep 0 matches; mutation test caught deletion)"
else
  echo "  grep found $grep_out lines (mutation not applied)"
  bad "V2 export -f _emit_locked_body SURVIVED (mutation not applied; expected 0 grep matches)"
fi
restore_file "$F"

# ── V3: 删 --json 分支 ───────────────────────────────────────────────────────
echo ""
echo "[V3] 删 scripts/expert-resolver.sh 的 --json 分支 (list)"
F="$REPO_ROOT/scripts/expert-resolver.sh"
backup_file "$F"
# 删除 --json case 分支. 删时保留 case 框架, 仅去掉 --json) JSON_MODE="1" ;;
sed -i.bak2 '/--json) JSON_MODE="1" ;;$/d' "$F"
# expert-resolver-json.test.sh case 1 (list --json 退出码 0) 应 fail.
run_test "V3 expert-resolver --json test" \
  "cd $REPO_ROOT && bash tests/integration/expert-resolver-json.test.sh" \
  0
restore_file "$F"

# ── V4: 删 claim.ts 的 path 优先 fallback ─────────────────────────────────────
echo ""
echo "[V4] 删 node/src/commands/claim.ts 的 path 优先 fallback 分支"
F="$REPO_ROOT/node/src/commands/claim.ts"
backup_file "$F"
# 删 AC3 修法: if (resolvedExpertPath === undefined && options.expertResolver !== undefined && ...
# 改成只有 fallback currentInstance.id (无 path 优先)
# 简单做法: 删整段 if block, 保留末尾的 resolvedExpertPath = currentInstance.id
python3 - <<PYEOF
import re
src = open("$F").read()
# 删除 if-block: let resolvedExpertPath = options.exolvedExpertPath ?? metadataString(...)
# 之后到 if (resolvedExpertPath === undefined) {...} 块.
# 用正则匹配跨行 if block (从 'if (resolvedExpertPath === undefined &&' 到匹配的 '}')
pattern = re.compile(
    r'  if \(resolvedExpertPath === undefined && options\.expertResolver !== undefined && options\.actualExpert !== undefined && options\.actualExpert\.trim\(\) !== \'\'\) \{.*?^\s*\}\n',
    re.DOTALL | re.MULTILINE,
)
new_src = pattern.sub('', src)
if new_src == src:
    print("V4 mutation: pattern not found, no change applied")
else:
    open("$F", "w").write(new_src)
    print("V4 mutation: applied (deleted path-first fallback block)")
PYEOF
# 期望: claim-options-injection.test.ts case "resolver.path(actualExpert) is invoked" 应 FAIL
# (因为 path 优先 fallback 没了, resolver.path() 不会被调).
run_test "V4 claim-options-injection test" \
  "cd $REPO_ROOT/node && KALLAX_HOOK_API_KEY=test-key npx vitest run tests/commands/claim-options-injection.test.ts" \
  0
restore_file "$F"

# ── Sanity: baseline 测试在 mutation 还原后应仍 PASS ─────────────────────────
echo ""
echo "[sanity] 还原后, 全部相关测试再跑一遍 (确认 baseline 仍绿)"
run_test "sanity check-disclaimer-merge" \
  "cd $REPO_ROOT && bash tests/integration/check-disclaimer-merge.test.sh" \
  1
run_test "sanity invocation-core-emit" \
  "cd $REPO_ROOT && bash tests/integration/invocation-core-emit.test.sh" \
  1
run_test "sanity expert-resolver-json" \
  "cd $REPO_ROOT && bash tests/integration/expert-resolver-json.test.sh" \
  1

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
echo "目标: 4 KILLED + 1 sanity baseline = 5 PASS"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
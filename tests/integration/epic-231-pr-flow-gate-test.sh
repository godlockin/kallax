#!/usr/bin/env bash
# EPIC-231 test — check-branch-flow.sh PR gate ([B] 方向 / [C] 空 PR / [D] squash)
#
# 起因: PR #316 (miao→testing, 0 files) + #317 (testing→main, 0 files)
#   空 commit 顶 "EPIC-217 elevator" 标题进 main.
#   实测 EPIC-217 README 从未进主干: git show origin/main:README.md | grep -c "When to use" → 0
#
# 网络相关 TC 在 gh 不可用时 skip (跟 .claude/rules/testing.md live-test skipIf 一致).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$REPO_ROOT/scripts/verify/check-branch-flow.sh"

PASS=0
FAIL=0
SKIP=0

ok()   { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# gh 可用性探测 (一次, 后续复用)
GH_OK=0
if command -v gh > /dev/null 2>&1; then
  if gh auth status > /dev/null 2>&1; then
    GH_OK=1
  fi
fi

echo "=========================================="
echo "EPIC-231 PR Flow Gate Test"
echo "=========================================="
echo ""

# --- 静态检查 ---------------------------------------------------------------
echo "[静态]"

if [ -f "$TARGET" ]; then ok "TC1 脚本存在"; else bad "TC1 脚本不存在: $TARGET"; fi
if [ -x "$TARGET" ]; then ok "TC2 可执行位"; else bad "TC2 缺可执行位"; fi
if bash -n "$TARGET" 2>/dev/null; then ok "TC3 语法合法"; else bad "TC3 语法错误"; fi

# fail-closed: 必须有 set -euo pipefail
if grep -q 'set -euo pipefail' "$TARGET"; then ok "TC4 fail-closed (set -euo pipefail)"; else bad "TC4 缺 set -euo pipefail"; fi

# 4 个检查全在
for tag in 'is_allowed_direction' 'check_single_pr' 'check_merge_method' 'audit_history'; do
  if grep -q "$tag" "$TARGET"; then ok "TC5.$tag 函数存在"; else bad "TC5.$tag 函数缺失"; fi
done

# 未知参数必须 exit 1 (不静默通过)
rc=0
bash "$TARGET" --bogus-flag > /dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then ok "TC6 未知参数 exit 1"; else bad "TC6 未知参数 exit=$rc (期望 1)"; fi

# --pr 缺编号必须 exit 1
rc=0
bash "$TARGET" --pr > /dev/null 2>&1 || rc=$?
if [ "$rc" -eq 1 ]; then ok "TC7 --pr 缺编号 exit 1"; else bad "TC7 --pr 缺编号 exit=$rc (期望 1)"; fi

echo ""

# --- 方向 allowlist 单元测试 (纯逻辑, 不需网络) ------------------------------
echo "[方向 allowlist]"

# source 出 is_allowed_direction 单独测. 直接 source 会跑 main, 所以抽函数体.
cat > /tmp/epic231-dir.sh <<'DIREOF'
is_allowed_direction() {
  local head="$1" base="$2"
  case "$base" in
    testing) [[ "$head" == feature/* ]] && return 0 ;;
    main)    [ "$head" = "testing" ] && return 0 ;;
    miao)    [ "$head" = "main" ] && return 0 ;;
  esac
  if [ "$base" = "main" ] && [[ "$head" == feature/hotfix-* ]]; then
    return 0
  fi
  return 1
}
DIREOF
# shellcheck disable=SC1091
. /tmp/epic231-dir.sh

# 校验抽出的副本跟 TARGET 里的一致 (防副本漂移)
if grep -q 'feature/hotfix-\*' "$TARGET"; then
  ok "TC8 hotfix 例外在源脚本中 (副本未漂移)"
else
  bad "TC8 源脚本缺 hotfix 例外 — 测试副本已漂移"
fi

# 合法方向
check_dir() {
  local head="$1" base="$2" want="$3" label="$4"
  local r=0
  is_allowed_direction "$head" "$base" || r=1
  if [ "$r" -eq "$want" ]; then ok "$label"; else bad "$label (got=$r want=$want)"; fi
}

check_dir "feature/EPIC-231-pr-gate" "testing" 0 "TC9  feature/*  -> testing  合法"
check_dir "testing"                  "main"    0 "TC10 testing    -> main     合法"
check_dir "main"                     "miao"    0 "TC11 main       -> miao     合法"
check_dir "feature/hotfix-crash"     "main"    0 "TC12 hotfix     -> main     合法 (例外)"

# 非法方向 — 全是真实发生过的
check_dir "miao"                     "testing" 1 "TC13 miao       -> testing  非法 (PR #316 实例)"
check_dir "feature/EPIC-228"         "main"    1 "TC14 feature/*  -> main     非法 (跳 testing)"
check_dir "main"                     "testing" 1 "TC15 main       -> testing  非法 (反向)"
check_dir "miao"                     "main"    1 "TC16 miao       -> main     非法 (反向)"
check_dir "testing"                  "miao"    1 "TC17 testing    -> miao     非法 (跳 main)"
check_dir "feature/x"                "miao"    1 "TC18 feature/*  -> miao     非法 (跳 2 级)"

echo ""

# --- squash 检测 (用真 commit, 需 git 历史) ----------------------------------
echo "[squash 断链检测]"

# b98df031 / 27d739d9 是 main→miao squash (1 parent) — 真实历史
for sha in b98df031 27d739d9; do
  if git -C "$REPO_ROOT" cat-file -e "${sha}^{commit}" 2>/dev/null; then
    n="$(git -C "$REPO_ROOT" rev-list --parents -n 1 "$sha" 2>/dev/null | wc -w | tr -d ' ')"
    # n = 1(自身) + parent 数; squash => n=2
    if [ "$n" -eq 2 ]; then
      ok "TC19.$sha squash 确认 (1 parent) — 检测依据成立"
    else
      bad "TC19.$sha 期望 1 parent, 实际 $((n - 1))"
    fi
  else
    skip "TC19.$sha commit 不在本地历史"
  fi
done

# 真 merge commit 必须 >= 2 parent — 找一个
merge_sha="$(git -C "$REPO_ROOT" log --merges --format=%H -n 1 2>/dev/null || true)"
if [ -n "$merge_sha" ]; then
  n="$(git -C "$REPO_ROOT" rev-list --parents -n 1 "$merge_sha" | wc -w | tr -d ' ')"
  if [ "$n" -ge 3 ]; then
    ok "TC20 真 merge commit 有 >=2 parent (${merge_sha:0:8})"
  else
    bad "TC20 merge commit parent 数异常: $((n - 1))"
  fi
else
  skip "TC20 本地无 merge commit"
fi

echo ""

# --- 真跑 (需 gh) -----------------------------------------------------------
echo "[真跑 — gh live]"

if [ "$GH_OK" -eq 0 ]; then
  skip "TC21-TC24 gh 不可用 (未安装 / 未认证)"
else
  # TC21: 负样本 PR #316 必须被拦, 且双命中
  rc=0
  bash "$TARGET" --pr 316 > /tmp/epic231-316.log 2>&1 || rc=$?
  if [ "$rc" -eq 1 ]; then
    ok "TC21 PR #316 被拦 (exit 1)"
  elif [ "$rc" -eq 2 ]; then
    skip "TC21 gh pr view 失败 (exit 2)"
  else
    bad "TC21 PR #316 未被拦 (exit=$rc)"
  fi

  if grep -q "方向非法" /tmp/epic231-316.log 2>/dev/null; then
    ok "TC22 PR #316 命中 [B] 方向非法"
  else
    bad "TC22 PR #316 未命中方向检查"
  fi

  if grep -q "空 PR" /tmp/epic231-316.log 2>/dev/null; then
    ok "TC23 PR #316 命中 [C] 空 PR"
  else
    bad "TC23 PR #316 未命中空 PR 检查"
  fi

  # TC24: 回溯审计能跑出违规 (不断言具体数字 — 会随新 PR 变)
  rc=0
  bash "$TARGET" --audit-history 25 > /tmp/epic231-audit.log 2>&1 || rc=$?
  if [ "$rc" -eq 2 ]; then
    skip "TC24 gh pr list 失败"
  elif grep -qE '结果: [0-9]+/[0-9]+ PR 有违规' /tmp/epic231-audit.log; then
    got="$(grep -oE '结果: [0-9]+/[0-9]+' /tmp/epic231-audit.log | head -1)"
    ok "TC24 回溯审计输出 X/Y 格式 ($got)"
  else
    bad "TC24 回溯审计无 X/Y 结果行"
  fi
fi

echo ""

# --- CI 接线 ---------------------------------------------------------------
echo "[CI 接线]"

CI="$REPO_ROOT/.github/workflows/ci.yml"
if [ -f "$CI" ]; then
  if grep -q 'pr-flow-gate' "$CI"; then ok "TC25 ci.yml 有 pr-flow-gate job"; else bad "TC25 ci.yml 缺 pr-flow-gate"; fi
  if grep -q 'PR_NUMBER: \${{ github.event.number }}' "$CI"; then
    ok "TC26 PR 编号走 env (防注入)"
  else
    bad "TC26 PR 编号未走 env — 有注入风险"
  fi
  # 负向测试必须在 CI 里 (meta-check)
  if grep -q '负向测试' "$CI"; then ok "TC27 CI 含负向测试 (meta-check)"; else bad "TC27 CI 缺负向测试"; fi
  # pull_request branches 必须含 testing + miao
  if grep -qE 'branches: \[main, testing, miao, develop\]' "$CI"; then
    ok "TC28 CI 触发含 testing + miao"
  else
    bad "TC28 CI 触发缺 testing/miao — 跨主干 PR 不跑 CI"
  fi
  # hook-health 必须进 all-checks
  if grep -A14 'all-checks:' "$CI" | grep -q 'hook-health'; then
    ok "TC29 hook-health 进 all-checks"
  else
    bad "TC29 hook-health 未进 all-checks"
  fi
else
  bad "TC25-TC29 ci.yml 不存在"
fi

echo ""
echo "=========================================="
echo "Results: $PASS pass, $FAIL fail, $SKIP skip"
echo "=========================================="

[ "$FAIL" -eq 0 ] && exit 0
exit 1

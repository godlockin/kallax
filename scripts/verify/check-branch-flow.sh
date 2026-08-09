#!/usr/bin/env bash
# KALLAX check-branch-flow.sh — EPIC-229 (branch 存在性) + EPIC-231 (PR 方向/空 PR/squash)
#
# 4 类检查:
#   [A] EPIC-229: 4 branch 全存在 (防 --delete-branch 误删)
#   [B] EPIC-231: PR base/head 方向在 allowlist 内 (防反向 PR)
#   [C] EPIC-231: PR changedFiles > 0 (防空 PR 顶 EPIC 标题进主干)
#   [D] EPIC-231: 跨主干 PR 必须 merge commit, 禁 squash (防历史断链)
#
# Usage:
#   check-branch-flow.sh                    # [A] 检查 4 branch 全存在
#   check-branch-flow.sh --verify           # 同上 (CI 用)
#   check-branch-flow.sh --repair           # testing 缺失时从 main 恢复
#   check-branch-flow.sh --pr <N>           # [B][C] 校验单个 PR (CI pull_request 用)
#   check-branch-flow.sh --audit-history N  # [B][C][D] 回溯审计最近 N 个已合 PR
#
# 4-branch flow (CLAUDE.md §4):
#   feature/* → testing → main (UAT) → miao (stable/prod)
#
# Exit: 0 = PASS, 1 = FAIL (fail-closed), 2 = 环境缺失 (gh 不可用)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

REQUIRED_BRANCHES=(testing main miao)
MODE="${1:---verify}"

# ---------------------------------------------------------------------------
# [B] PR 方向 allowlist — 单向 feature/* → testing → main → miao
#     反向 (e.g. miao → testing) 一律拒绝. 起因: PR #316 是 miao→testing.
# ---------------------------------------------------------------------------
is_allowed_direction() {
  local head="$1" base="$2"
  case "$base" in
    testing) [[ "$head" == feature/* ]] && return 0 ;;
    main)    [ "$head" = "testing" ] && return 0 ;;
    miao)    [ "$head" = "main" ] && return 0 ;;
  esac
  # hotfix 例外: feature/hotfix-* 允许直达 main (需 commit body 注明主公批准)
  if [ "$base" = "main" ] && [[ "$head" == feature/hotfix-* ]]; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# [B][C] 单 PR 校验
# ---------------------------------------------------------------------------
check_single_pr() {
  local pr_num="$1"
  local json head base changed
  if ! json="$(gh pr view "$pr_num" --json number,headRefName,baseRefName,changedFiles 2>/dev/null)"; then
    echo "  BLOCKED-env: gh pr view $pr_num 失败 (gh 未认证 / PR 不存在)"
    return 2
  fi
  head="$(echo "$json" | jq -r '.headRefName')"
  base="$(echo "$json" | jq -r '.baseRefName')"
  changed="$(echo "$json" | jq -r '.changedFiles')"

  local fails=0

  # [B] 方向
  if is_allowed_direction "$head" "$base"; then
    echo "  OK   [B] 方向: $head -> $base"
  else
    echo "  FAIL [B] 方向非法: $head -> $base"
    echo "         allowlist: feature/* -> testing -> main -> miao (单向)"
    echo "         起因: PR #316 是 miao->testing (反向), 空 commit 顶 EPIC-217 标题进主干"
    fails=$((fails + 1))
  fi

  # [C] 空 PR
  if [ "$changed" -gt 0 ] 2>/dev/null; then
    echo "  OK   [C] changedFiles=$changed"
  else
    echo "  FAIL [C] 空 PR (changedFiles=$changed)"
    echo "         空 commit 顶 EPIC 标题 merge = 假闭环"
    echo "         起因: PR #316/#317 均 changedFiles=0, EPIC-217 README 从未进 main"
    fails=$((fails + 1))
  fi

  [ "$fails" -eq 0 ] && return 0
  return 1
}

# ---------------------------------------------------------------------------
# [D] 跨主干 PR merge 方式 — squash 会压平历史, 导致 git log miao..main 永久失真
#     判定: merge commit 只有 1 个 parent = squash/rebase; 2 个 = 真 merge
# ---------------------------------------------------------------------------
check_merge_method() {
  local sha="$1" head="$2" base="$3"
  # 只对跨主干 (testing->main / main->miao) 强制 merge commit
  case "${head}=>${base}" in
    "testing=>main"|"main=>miao") ;;
    *) return 0 ;;
  esac
  local parents
  parents="$(git rev-list --parents -n 1 "$sha" 2>/dev/null | wc -w | tr -d ' ')"
  # 输出含自身 sha, 所以 parent 数 = parents - 1
  if [ "$parents" -ge 3 ]; then
    return 0
  fi
  echo "  FAIL [D] squash merge 断链: $sha ($head -> $base, parent 数 = $((parents - 1)))"
  echo "         跨主干 PR 必须 gh pr merge --merge (禁 --squash)"
  echo "         起因: b98df031 + 27d739d9 均 squash, git log miao..main 永久显示 12 落后"
  return 1
}

# ---------------------------------------------------------------------------
# 回溯审计 (只报告, 不改历史 — 历史债按 EPIC-155/176 备案 pattern 处理)
# ---------------------------------------------------------------------------
audit_history() {
  local limit="${1:-20}"
  local json
  if ! json="$(gh pr list --state merged --limit "$limit" \
      --json number,headRefName,baseRefName,changedFiles,mergeCommit 2>/dev/null)"; then
    echo "BLOCKED-env: gh pr list 失败 (gh 未认证)"
    return 2
  fi

  echo "回溯审计最近 $limit 个已合 PR:"
  echo ""

  local total=0 bad=0
  while IFS=$'\t' read -r num head base changed sha; do
    [ -n "$num" ] || continue
    total=$((total + 1))
    local issues=()
    is_allowed_direction "$head" "$base" || issues+=("方向 $head=>$base")
    [ "$changed" -gt 0 ] 2>/dev/null || issues+=("空 PR")
    if [ -n "$sha" ] && [ "$sha" != "null" ]; then
      check_merge_method "$sha" "$head" "$base" > /dev/null 2>&1 || issues+=("squash 断链")
    fi
    if [ ${#issues[@]} -gt 0 ]; then
      bad=$((bad + 1))
      echo "  #$num  $head -> $base  files=$changed"
      local iss
      for iss in "${issues[@]}"; do echo "         - $iss"; done
    fi
  done < <(echo "$json" | jq -r '.[] | [.number, .headRefName, .baseRefName, .changedFiles, (.mergeCommit.oid // "null")] | @tsv')

  echo ""
  echo "结果: $bad/$total PR 有违规"
  echo ""
  echo "注: 历史债不改 git 历史 (跟 EPIC-155/176 备案 pattern 一致)."
  echo "    本检查用于 CI 拦新 PR, 历史违规需主公拍板备案."
  [ "$bad" -eq 0 ] && return 0
  return 1
}

# ---------------------------------------------------------------------------
# [A] EPIC-229 原有逻辑: 4 branch 存在性
# ---------------------------------------------------------------------------
check_branches_exist() {
  local missing=()
  local br sha attempt
  for br in "${REQUIRED_BRANCHES[@]}"; do
    # 网络间歇失败重试 3 次 (GitHub SSL/TLS 偶发)
    sha=""
    for attempt in 1 2 3; do
      sha="$(git ls-remote origin "refs/heads/$br" 2>/dev/null | cut -f1)"
      [ -n "$sha" ] && break
      [ "$attempt" -lt 3 ] && sleep 2
    done
    if [ -z "$sha" ]; then
      echo "  MISSING: origin/$br (3 次重试后仍无响应)"
      missing+=("$br")
    else
      echo "  OK: origin/$br = ${sha:0:8}"
    fi
  done

  echo ""

  if [ ${#missing[@]} -eq 0 ]; then
    echo "PASS: 4-branch flow 完整 (feature/* + testing + main + miao)"
    return 0
  fi

  echo "FAIL: ${#missing[@]} branch 缺失: ${missing[*]}"
  echo ""
  echo "起因参考 (EPIC-217 事故): gh pr merge --delete-branch 删掉 testing,"
  echo "  导致 EPIC-218~222 跳过 testing 阶段直接 feature->main."
  echo ""

  if [ "$MODE" = "--repair" ]; then
    for br in "${missing[@]}"; do
      case "$br" in
        testing)
          echo "  REPAIR: 从 origin/main 恢复 testing"
          git push origin origin/main:refs/heads/testing
          ;;
        *)
          echo "  SKIP: $br 需人工恢复 (main/miao 是核心分支, 不自动创建)"
          ;;
      esac
    done
    echo ""
    echo "重跑验证: bash scripts/verify/check-branch-flow.sh --verify"
    return 0
  fi

  echo "Fix:"
  echo "  bash scripts/verify/check-branch-flow.sh --repair   # 自动恢复 testing"
  echo "  或手动: git push origin origin/main:refs/heads/testing"
  echo ""
  echo "防复发: gh pr merge 不带 --delete-branch (跟主公 2026-08-08 指示 1:1)"
  return 1
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
echo "=========================================="
echo "Branch Flow Check (EPIC-229 + EPIC-231)"
echo "=========================================="

case "$MODE" in
  --pr)
    PR_NUM="${2:-}"
    if [ -z "$PR_NUM" ]; then
      echo "FAIL: --pr 需 PR 编号. 用法: check-branch-flow.sh --pr 331"
      exit 1
    fi
    echo "PR #$PR_NUM 校验 ([B] 方向 + [C] 空 PR):"
    echo ""
    rc=0
    check_single_pr "$PR_NUM" || rc=$?
    echo ""
    if [ "$rc" -eq 2 ]; then
      echo "BLOCKED-env: gh 不可用, 跳过 (exit 2)"
      exit 2
    fi
    if [ "$rc" -eq 0 ]; then
      echo "PASS: PR #$PR_NUM 方向合法 + 非空"
      exit 0
    fi
    echo "FAIL: PR #$PR_NUM 违反 4-branch flow"
    exit 1
    ;;
  --audit-history)
    rc=0
    audit_history "${2:-20}" || rc=$?
    exit "$rc"
    ;;
  --verify|--repair|"")
    rc=0
    check_branches_exist || rc=$?
    exit "$rc"
    ;;
  *)
    echo "FAIL: 未知参数 '$MODE'"
    echo "用法: check-branch-flow.sh [--verify|--repair|--pr N|--audit-history N]"
    exit 1
    ;;
esac

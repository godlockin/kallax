#!/usr/bin/env bash
# KALLAX check-branch-flow.sh — EPIC-229 (testing 分支恢复 + 防复发)
#
# 防止 4-branch flow 中任一分支被误删 (跟 EPIC-217 PR-2 --delete-branch 事故 1:1).
#
# Usage:
#   check-branch-flow.sh              # 检查 4 branch 全存在
#   check-branch-flow.sh --verify     # 同上 (CI 用)
#   check-branch-flow.sh --repair     # testing 缺失时从 main 恢复
#
# 4-branch flow (CLAUDE.md §4):
#   feature/* → testing → main (UAT) → miao (stable/prod)
#
# Exit: 0 = 4 branch 齐, 1 = 缺失 (fail-closed)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

REQUIRED_BRANCHES=(testing main miao)
MODE="${1:---verify}"

missing=()

echo "=========================================="
echo "Branch Flow Check (EPIC-229)"
echo "=========================================="

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
  exit 0
fi

echo "FAIL: ${#missing[@]} branch 缺失: ${missing[*]}"
echo ""
echo "起因参考 (EPIC-217 事故): gh pr merge --delete-branch 删掉 testing,"
echo "  导致 EPIC-218~222 跳过 testing 阶段直接 feature→main."
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
  exit 0
fi

echo "Fix:"
echo "  bash scripts/verify/check-branch-flow.sh --repair   # 自动恢复 testing"
echo "  或手动: git push origin origin/main:refs/heads/testing"
echo ""
echo "防复发: gh pr merge 不带 --delete-branch (跟主公 2026-08-08 指示 1:1)"
exit 1
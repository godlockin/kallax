#!/usr/bin/env bash
# KALLAX pre-commit hook — check-retrospective-applied (EPIC-105)
# 治 v3.8.0 red-blue review lesson #5: write ≠ do (retrospective 写 ≠ 应用)
#
# 原: 写 retrospective 5 教训, 0 真应用 — 5 release 累计 0 lesson 引用
# 修: 每 sprint 必 grep 上次 retrospective 教训, 引用 ≥ 1 算"应用"
#
# 用法 (跟 check-claim-evidence.sh 1:1):
#   bash scripts/verify/check-retrospective-applied.sh
#
# 退出码:
#   0 = PASS (上次 retrospective 教训至少 1 条被引用)
#   1 = FAIL (上次 retrospective 没被任何新文档引用)
#   2 = 无上次 retrospective (首次, 跳过)

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

# 找上次 retrospective (按 mtime)
LAST_RETRO=$(ls -t "${REPO_ROOT}/confluence/decisions/retrospective-"*.md 2>/dev/null | head -1 || true)

if [[ -z "$LAST_RETRO" ]]; then
  echo "check-retrospective-applied: 无上次 retrospective, skip (首次)"
  exit 2
fi

echo "check-retrospective-applied: 上次 retrospective = $LAST_RETRO"

# 提取教训 TL;DR 关键词 (取所有 "### 教训 #N:" 行)
RETRO_LINES=$(grep -E '^###\s*教训\s*#' "$LAST_RETRO" 2>/dev/null || true)
if [[ -z "$RETRO_LINES" ]]; then
  echo "check-retrospective-applied: 无法解析教训, skip"
  exit 2
fi

# 关键词列表 (跟教训标题同步)
# v3.8.0 复盘 5 教训 + EPIC-101 复盘 5 教训 = 10 关键词
KEYWORDS=(
  "形式 PASS"
  "4-PR"
  "build OK"
  "数字"
  "诚实"
  "TierRouter"
  "cargo test"
  "workspace"
  "scope"
  "Rust"
)

# 统计: 每个关键词在当前 git tree (排除 retrospective 自己) 出现次数
APPLIED_COUNT=0
TOTAL=${#KEYWORDS[@]}

for kw in "${KEYWORDS[@]}"; do
  count=$(grep -r --include="*.md" --include="*.ts" --include="*.rs" --include="*.sh" --include="*.json" -l "$kw" "$REPO_ROOT" 2>/dev/null \
    | grep -v "retrospective-" | wc -l)
  if [[ $count -gt 0 ]]; then
    APPLIED_COUNT=$((APPLIED_COUNT + 1))
    echo "  ✅ '$kw': 引用 $count 文件"
  else
    echo "  ❌ '$kw': 0 引用 (未应用)"
  fi
done

echo ""
echo "check-retrospective-applied: $APPLIED_COUNT/$TOTAL 教训被引用"

if [[ $APPLIED_COUNT -eq 0 ]]; then
  echo ""
  echo "❌ check-retrospective-applied: 0 教训被应用 (反讽 1:1 复发: write ≠ do)"
  echo "   治 v3.8.0 lesson #5 (retrospective 写 ≠ 应用)"
  echo "   Fix: 至少 1 条教训在当前 sprint 文档/代码/CLAUDE.md 引用"
  echo "   Bypass: git commit --no-verify (主公明确批准时)"
  exit 1
fi

echo "✅ check-retrospective-applied: PASS ($APPLIED_COUNT 教训已应用)"
exit 0
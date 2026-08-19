#!/usr/bin/env bash
# scripts/ci/check-review-tier.sh
# EPIC-270 review 分级 gate
# 校验 PR body 里的 review_tier + review_summary 字段:
#   - T1 自评: 0 source + ≤100 行 + 单 commit (Rule 37 阈值)
#   - T2 单 subagent: 有 source 改动 或 >100 行, 必附 review_summary
#   - T3 多 subagent: ≥5 文件 或 >500 行 或 改 immutable/Rule/CI, 必附 review_summary
#
# 注意: evidence 是 PR body 内联 review_summary (主公 2026-08-18 拍板),
#   不是文件路径. 核实报告是过程描述, 不落库. 有决策价值的结论走 confluence/decisions/.
#
# 调用: scripts/ci/check-review-tier.sh <pr-body-file> <diff-stat-line>
# 退出: 0 = 通过, 1 = 拒

set -uo pipefail

usage() {
  echo "Usage: $0 <pr-body-file> <diff-stat-line>"
  echo "  <pr-body-file>: PR body markdown 路径"
  echo "  <diff-stat-line>: 'git diff --stat' 一行 (如 '2 files changed, 6 insertions(+), 2 deletions(-)')"
  exit 2
}

[ $# -eq 2 ] || usage

BODY_FILE="$1"
DIFF_STAT="$2"

# 解析 PR body 里的 review_tier + review_summary (多行, 用 python 或 awk 抽取)
TIER="$(grep -oE 'review_tier[[:space:]]*:[[:space:]]*(T1|T2|T3)' "$BODY_FILE" | head -1 | sed 's/.*://' | tr -d ' ')"
# review_summary 两种形态:
#   1) 单行: review_summary: 一些文字
#   2) 多行 block: review_summary: | 后跟缩进行
SUMMARY="$(awk '
  # 单行形态: review_summary: 后面直接跟非空文本
  /^review_summary:[[:space:]]+[^|>[:space:]]/ {
    # 提取冒号后文本
    line=$0
    sub(/^review_summary:[[:space:]]*/, "", line)
    if (line != "") { print line }
    next
  }
  # block 形态: review_summary: | 或 review_summary: > 后跟缩进行
  /^review_summary:[[:space:]]*[|>][[:space:]]*$/ {
    in_summary=1
    next
  }
  in_summary {
    if ($0 ~ /^[[:space:]]/) {
      if ($0 !~ /^[[:space:]]*$/) { print $0 }
      next
    }
    in_summary=0
  }
' "$BODY_FILE" | tr -d ' \t')"

# 解析 diff stat (从 '+XX, -YY' 抽取净行数)
ADD_LINES="$(printf '%s' "$DIFF_STAT" | grep -oE '[0-9]+ insertion' | head -1 | grep -oE '[0-9]+' || echo 0)"
DEL_LINES="$(printf '%s' "$DIFF_STAT" | grep -oE '[0-9]+ deletion' | head -1 | grep -oE '[0-9]+' || echo 0)"
NET_LINES=$(( ADD_LINES + DEL_LINES ))
FILE_COUNT="$(printf '%s' "$DIFF_STAT" | grep -oE '[0-9]+ files? changed' | head -1 | grep -oE '[0-9]+' || echo 0)"

# 默认: 缺 review_tier 字段拒 (T1 是 claim, 必须显式声明)
if [ -z "$TIER" ]; then
  echo "REJECT: PR body 缺 review_tier 字段 (T1/T2/T3 必填)" >&2
  exit 1
fi

# T1 校验: Rule 37 阈值 (0 源码 + ≤100 行 + 单 commit)
if [ "$TIER" = "T1" ]; then
  if [ "$NET_LINES" -gt 100 ]; then
    echo "REJECT: T1 自评仅限 ≤100 行, 当前 $NET_LINES 行. 改用 T2." >&2
    exit 1
  fi
  echo "OK: T1 自评, $NET_LINES 行"
  exit 0
fi

# T2 / T3 必附 review_summary
if [ -z "$SUMMARY" ]; then
  echo "REJECT: $TIER 必附 review_summary (PR body 缺该字段或为空)" >&2
  exit 1
fi

# T3 校验: ≥5 文件 或 >500 行
if [ "$TIER" = "T3" ]; then
  if [ "$FILE_COUNT" -lt 5 ] && [ "$NET_LINES" -le 500 ]; then
    echo "REJECT: T3 需 ≥5 文件 或 >500 行, 当前 $FILE_COUNT 文件 / $NET_LINES 行. 改用 T2." >&2
    exit 1
  fi
fi

echo "OK: $TIER, review_summary 已填, $FILE_COUNT 文件 / $NET_LINES 行"
exit 0

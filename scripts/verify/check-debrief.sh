#!/usr/bin/env bash
# KALLAX check-debrief.sh — ticket 关闭前检查教训 (借鉴 eket, EPIC-080)
#
# 用法:
#   bash scripts/verify/check-debrief.sh [BASE_REF] [HEAD_REF]
#   bash scripts/verify/check-debrief.sh origin/main HEAD
#
# 退出码:
#   0 = OK
#   1 = ticket 转 done 但没对应 confluence/decisions/ 或 confluence/memory/ 教训
#   2 = usage / git error
set -euo pipefail

BASE="${1:-HEAD~1}"
HEAD_REF="${2:-HEAD}"

if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  echo "check-debrief: invalid base ref: $BASE" >&2
  exit 2
fi
if ! git rev-parse --verify "$HEAD_REF" >/dev/null 2>&1; then
  echo "check-debrief: invalid head ref: $HEAD_REF" >&2
  exit 2
fi

# 检测 ticket status 字段转 done (跟 eket 模式 1:1, 适配 kallax 路径)
done_tickets=$(
  git diff "$BASE" "$HEAD_REF" -- 'jira/tickets/' '.kallax/tickets/' 2>/dev/null \
    | awk '
        /^\+\+\+ b\// { sub(/^\+\+\+ b\//, ""); file=$0; next }
        /\+.*[Ss]tatus.*(done|completed|merged)/ { print file }
      ' \
    | sort -u
)

if [[ -z "$done_tickets" ]]; then
  echo "check-debrief: no ticket transitioned to done in $BASE..$HEAD_REF — OK"
  exit 0
fi

# 检测 confluence lessons 写入
lessons_touched=$(
  git diff --name-only "$BASE" "$HEAD_REF" -- 'confluence/' \
    | grep -v '/\.gitkeep$' \
    | sort -u || true
)

if [[ -z "$lessons_touched" ]]; then
  echo "❌ check-debrief: tickets transitioned to done but no lessons written"
  echo "   Done tickets:"
  echo "$done_tickets" | sed 's/^/     /'
  echo "   Fix: 写 confluence/decisions/<ticket>.md 或 confluence/memory/lessons/<ticket>.md"
  exit 1
fi

echo "check-debrief: PASS (lessons written for done tickets)"
exit 0
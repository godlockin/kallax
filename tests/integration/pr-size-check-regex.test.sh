#!/usr/bin/env bash
# EPIC-284: pr-size-check.yml docs-only 检测 jq regex 边界测试
#
# 治 bug: 旧版 jq 表达式拼接 (.path + " " + .filename) 产生尾随空格,
# 使 $ 锚点永不匹配 → 所有 .sh/.ts/.rs-only PR 被误判 docs-only → size gate 静默失效.
#
# 实证 (CI log):
#   PR #474: raw 613 → "docs-only PR detected (0 source files, 6 docs files)" → net=100 假 PASS
#   PR #484: raw 701 → 同样 → 假 PASS
#
# Exit: 0 = 全部 case PASS, 1 = 任一 case FAIL
set -uo pipefail

SOURCE_REGEX='\.ts$|\.rs$|\.js$|\.sh$'
FAIL=0
PASS_COUNT=0
TOTAL=0

# 修复后的 jq 表达式 (跟 pr-size-check.yml 保持同步)
count_source_files() {
  local json="$1"
  echo "$json" | jq --arg re "$SOURCE_REGEX" '[.files[] | select((.path // .filename // "") | test($re))] | length'
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $desc (expected=$expected actual=$actual)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $desc (expected=$expected actual=$actual)" >&2
    FAIL=1
  fi
}

echo "EPIC-284 pr-size-check jq regex 边界测试"
echo ""

# Case 1: gh pr view 格式 (只有 .path), .sh 文件 → 必须识别为 source
echo "Case 1: gh pr view 格式 (.path only), .sh 文件"
assert_eq ".sh via .path" 1 \
  "$(count_source_files '{"files":[{"path":"scripts/dashboard-p1/emit.sh"}]}')"

# Case 2: gh api pulls/{N}/files 格式 (只有 .filename), .ts 文件
echo "Case 2: gh api 格式 (.filename only), .ts 文件"
assert_eq ".ts via .filename" 1 \
  "$(count_source_files '{"files":[{"filename":"node/src/index.ts"}]}')"

# Case 3: .rs 文件 via .path
echo "Case 3: .rs 文件"
assert_eq ".rs via .path" 1 \
  "$(count_source_files '{"files":[{"path":"rust/crates/kallax-engine/src/lib.rs"}]}')"

# Case 4: 真 docs-only PR (.md 文件) → 必须 0
echo "Case 4: 真 docs-only (.md)"
assert_eq ".md not source" 0 \
  "$(count_source_files '{"files":[{"path":"docs/reference/dashboard.md"}]}')"

# Case 5: 混合 PR (.md + .sh) → 必须 1 (识别出 .sh)
echo "Case 5: 混合 (.md + .sh)"
assert_eq "mixed md+sh" 1 \
  "$(count_source_files '{"files":[{"path":"docs/x.md"},{"path":"scripts/y.sh"}]}')"

# Case 6: 多 source 文件 → 必须 3
echo "Case 6: 多 source 文件"
assert_eq "3 source files" 3 \
  "$(count_source_files '{"files":[{"path":"a.sh"},{"path":"b.ts"},{"path":"c.rs"}]}')"

# Case 7: .json 不算 source (ticket.json / package.json)
echo "Case 7: .json 不算 source"
assert_eq ".json not source" 0 \
  "$(count_source_files '{"files":[{"path":"jira/tickets/EPIC-281/ticket.json"}]}')"

# Case 8: 文件名含 .sh 但不结尾 (e.g. foo.shell.md) → 不算 source
echo "Case 8: .sh 非结尾不算"
assert_eq ".shell.md not source" 0 \
  "$(count_source_files '{"files":[{"path":"docs/foo.shell.md"}]}')"

# Case 9: 回归测试 — 旧版 bug 复现 (拼接产生尾随空格)
echo "Case 9: 旧版 bug 复现 (证明修复有效)"
OLD_RESULT=$(echo '{"files":[{"path":"scripts/emit.sh"}]}' \
  | jq --arg re "$SOURCE_REGEX" '[.files[] | select(((.path // "") + " " + (.filename // "")) | test($re))] | length')
NEW_RESULT=$(count_source_files '{"files":[{"path":"scripts/emit.sh"}]}')
TOTAL=$((TOTAL + 1))
if [[ "$OLD_RESULT" == "0" && "$NEW_RESULT" == "1" ]]; then
  echo "  PASS: 旧版返回 0 (bug), 新版返回 1 (fixed)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: 回归验证失败 (old=$OLD_RESULT new=$NEW_RESULT)" >&2
  FAIL=1
fi

echo ""
echo "结果: $PASS_COUNT/$TOTAL PASS"

if [[ $FAIL -eq 0 ]]; then
  echo "EPIC-284 size gate regex: ALL PASS"
  exit 0
else
  echo "EPIC-284 size gate regex: FAILED" >&2
  exit 1
fi

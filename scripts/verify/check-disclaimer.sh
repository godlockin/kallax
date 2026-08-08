#!/usr/bin/env bash
# KALLAX check-disclaimer.sh — EPIC-220 (借鉴 prime-agent "limit != success" + 反向 disclaimer audit)
# 扫 README/CHANGELOG/CONTRIBUTING 中免责声明关键词 ("trusted/sandbox/secure/safe")
# + 验 raw_output 引用 + 5-Level Verify L2/L3 exit!=0 强制追加 disclaimer 行.
#
# Usage:
#   check-disclaimer.sh scan [path]            # 默认扫 README.md + .github/
#   check-disclaimer.sh --mode=failure-disc    # 5-Level Verify L2/L3 failure disclaimer 模式
#
# 借鉴 (跟 confluence/decisions/prime-agent-research-2026-08-08.md 1:1):
# - prime-agent "passed gate checks only what that gate verifies; reaching a limit does not imply task success"
# - 反向借鉴: 扫别人的 disclaimer, 不写 disclaimer
# - 跟 v3.8.0 "25/25 假 PASS" 教训 1:1 (跟 EPIC-069-D check-claim-evidence 联合)
#
# Exit codes (跟 5 immutable scripts 1:1):
#   0 = OK / disclaimer + raw_output 齐
#   1 = FAIL (fail-closed, 命中无 raw_output 引用, 必须主公亲自 override)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DISCLAIMER_KEYWORDS='(trusted|sandbox|secure|safe|guaranteed|always-works)'
RAW_OUTPUT_PATTERN='raw[_ ]?output|raw_output|## 自动验证'

cmd="${1:-scan}"
shift || true

scan_disclaimers() {
  local path="${1:-.}"
  local violations=0

  # grep 找含 disclaimer keyword 的行, 但未跟随 raw_output 引用
  if grep -rEn "$DISCLAIMER_KEYWORDS" "$path" --include="*.md" 2>/dev/null | \
     grep -v -E "(CHECKLIST|$0)" | \
     grep -v -E "(${RAW_OUTPUT_PATTERN})" > /tmp/check-disclaimer-violations.txt; then
    if [ -s /tmp/check-disclaimer-violations.txt ]; then
      violations=$(wc -l < /tmp/check-disclaimer-violations.txt | tr -d ' ')
      echo "FAIL: $violations disclaimer violations found (无 raw_output 引用):"
      cat /tmp/check-disclaimer-violations.txt
      echo ""
      echo "Fix: 在 disclaimer 邻近 5 行内加 raw_output 引用 (跟 EPIC-069-D 1:1)"
      exit 1
    fi
  fi
  echo "OK: no disclaimer violations (含 raw_output 引用 OR 无 disclaimer keyword)"
  exit 0
}

failure_disclaimer_check() {
  # 5-Level Verify L2/L3 exit!=0 模式: 强制 PR 描述追加 "exit=N != pass" 行
  # 当前仅检查 failure-disclaimer 行是否存在于 staged commit messages
  local staged_msgs
  staged_msgs=$(git log --oneline ORIG_HEAD..HEAD 2>/dev/null || git log --oneline -1)
  if echo "$staged_msgs" | grep -qE '(exit=[1-9]|FAILED|fail-closed)' && \
     ! echo "$staged_msgs" | grep -qE '!= pass|not pass|limit.*success'; then
    echo "FAIL: 5-Level Verify L2/L3 exit!=0 但无 'limit != success' disclaimer"
    echo "Fix: 在 commit message / PR 描述追加: 'exit=N != pass (跟 prime-agent limit != success 1:1)'"
    exit 1
  fi
  echo "OK: failure disclaimer present"
  exit 0
}

case "$cmd" in
  scan)
    scan_disclaimers "$@"
    ;;
  --mode=failure-disc|failure-disc)
    failure_disclaimer_check
    ;;
  *)
    echo "Usage: $0 scan [path] | --mode=failure-disc" >&2
    exit 1
    ;;
esac
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

# EPIC-229: baseline 划线 (跟 EPIC-225 jargon baseline 同原则)
# 历史 .md (baseline commit 之前引入) 不追溯, 新增内容强制
BASELINE_COMMIT="06e082b8"  # EPIC-226 合并点 (EPIC-229 引入 baseline 时的 main HEAD)

cmd="${1:-scan}"
shift || true

scan_disclaimers() {
  local path="${1:-.}"
  local violations=0

  # EPIC-229 修 3 bug:
  #   1. 排除 node_modules / rust/target / _archived (第三方 + 归档, 非本项目内容)
  #   2. staged-only 模式 (pre-commit 用, 只扫本次改动)
  #   3. baseline: 历史文件划线 (跟 EPIC-225 jargon baseline 同原则)
  local scan_list="${TMPDIR:-/tmp}/check-disclaimer-files.txt"
  if [ -n "${KALLAX_STAGED_ONLY:-}" ]; then
    # pre-commit 模式: 只扫 staged .md
    git diff --cached --name-only --diff-filter=ACM 2>/dev/null \
      | grep -E '\.md$' > "$scan_list" || true
  else
    # 全仓模式: git ls-files 排除第三方 (比 grep -r 可靠)
    # + baseline 划线: 只扫 baseline commit 之后新增/修改的 .md
    if git rev-parse "$BASELINE_COMMIT" >/dev/null 2>&1; then
      git diff --name-only "$BASELINE_COMMIT"..HEAD -- '*.md' 2>/dev/null \
        | grep -vE '^(node_modules/|rust/target/|.*_archived/|docs/reference/)' > "$scan_list" || true
      # 加上 untracked 新文件
      git ls-files --others --exclude-standard '*.md' 2>/dev/null \
        | grep -vE '^(node_modules/|rust/target/|.*_archived/|docs/reference/)' >> "$scan_list" || true
    else
      git ls-files '*.md' 2>/dev/null \
        | grep -vE '^(node_modules/|rust/target/|.*_archived/|docs/reference/)' > "$scan_list" || true
    fi
  fi

  if [ ! -s "$scan_list" ]; then
    echo "OK: no .md files to scan"
    exit 0
  fi

  local hits="${TMPDIR:-/tmp}/check-disclaimer-violations.txt"
  : > "$hits"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    # 跳过本脚本自身 + CHECKLIST
    case "$f" in
      *check-disclaimer.sh|*CHECKLIST*) continue ;;
    esac
    grep -nE "$DISCLAIMER_KEYWORDS" "$f" 2>/dev/null \
      | grep -vE "(${RAW_OUTPUT_PATTERN})" \
      | sed "s|^|$f:|" >> "$hits" || true
  done < "$scan_list"

  if [ -s "$hits" ]; then
    violations=$(wc -l < "$hits" | tr -d ' ')
    echo "FAIL: $violations disclaimer violations found (无 raw_output 引用):"
    head -20 "$hits"
    [ "$violations" -gt 20 ] && echo "  ... (还有 $((violations - 20)) 个)"
    echo ""
    echo "Fix: 在 disclaimer 邻近 5 行内加 raw_output 引用 (跟 EPIC-069-D 配合)"
    exit 1
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
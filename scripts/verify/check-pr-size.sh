#!/usr/bin/env bash
# KALLAX check-pr-size.sh — PR 大小检查 (借鉴 eket, EPIC-077)
#
# Rule of 500: 单 PR 净变更 > 500 行需要 Approved-Large-PR-By 标记
# 借鉴 eket scripts/check-pr-size.sh, 简化版本 (跟 CLAUDE.md Rule 联合)
#
# 用法:
#   bash scripts/verify/check-pr-size.sh
#
# 退出码:
#   0 = PASS / WARN
#   1 = FAIL (>500 行无 approval)
#   2 = 参数错误

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 2

WARN_THRESHOLD=100
FAIL_THRESHOLD=500

# 检测 base: feature/* → testing, testing → main, main → miao
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
case "$CURRENT_BRANCH" in
  feature/*) BASE="testing" ;;
  testing)   BASE="main" ;;
  main)      BASE="miao" ;;
  *)         BASE="miao" ;; # default
esac

# 净变更行数
NET=$(git diff --shortstat "$BASE"...HEAD 2>/dev/null | awk '{ins+=$4; del+=$6} END {print ins+del}')
if [[ -z "$NET" || "$NET" == "0" ]]; then
  echo "check-pr-size: no diff vs $BASE, PASS"
  exit 0
fi

# 检查 approval trailer (git log range + pending COMMIT_EDITMSG for pre-commit)
APPROVAL=$(git log -1 --format='%(trailers:key=Approved-Large-PR-By,valueonly)' "$BASE"..HEAD 2>/dev/null | head -1)
if [[ -z "$APPROVAL" ]]; then
  GIT_DIR_RESOLVED=$(git rev-parse --git-dir 2>/dev/null)
  if [[ -n "$GIT_DIR_RESOLVED" ]] && [[ -f "$GIT_DIR_RESOLVED/COMMIT_EDITMSG" ]]; then
    APPROVAL=$(grep -E '^Approved-Large-PR-By:' "$GIT_DIR_RESOLVED/COMMIT_EDITMSG" 2>/dev/null | head -1 | sed 's/^Approved-Large-PR-By:[[:space:]]*//')
  fi
fi

# Pre-commit context: current staged commit not yet in HEAD. If NET is dominated by
# unversioned staged changes, this is a per-commit hook — skip (PR-level check belongs in CI).
# Detect by: are we invoked from a hook? Check for HOOK_INVOCATION marker or GIT_INDEX_FILE.
if [[ -n "${GIT_INDEX_FILE:-}" ]] || [[ -n "${KALLAX_PRE_COMMIT:-}" ]]; then
  if [[ -z "$APPROVAL" ]]; then
    echo "check-pr-size: pre-commit context, PR-level check deferred to CI (approval trailer will be verified there)"
    exit 0
  fi
fi

if [[ "$NET" -gt "$FAIL_THRESHOLD" ]]; then
  if [[ -z "$APPROVAL" ]]; then
    echo "❌ check-pr-size: PR $NET lines > $FAIL_THRESHOLD, no Approved-Large-PR-By trailer"
    echo "   Fix: 拆分 PR OR add 'Approved-Large-PR-By: <main reason>' in commit footer"
    exit 1
  else
    echo "⚠️  check-pr-size: PR $NET lines > $FAIL_THRESHOLD but Approved-Large-PR-By: $APPROVAL"
    exit 0
  fi
elif [[ "$NET" -gt "$WARN_THRESHOLD" ]]; then
  echo "⚠️  check-pr-size: PR $NET lines > $WARN_THRESHOLD (consider splitting)"
  exit 0
else
  echo "check-pr-size: PASS (PR $NET lines)"
  exit 0
fi
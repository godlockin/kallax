#!/usr/bin/env bash
# KALLAX build-scope-commits.sh — EPIC-287-C 缓存 _scope_commits.json
#
# 功能:
#   读 jira/tickets/.jargon-baseline.json 取 baseline_commit
#   用 git log --pretty='%H' --since baseline_commit..HEAD --no-renames --name-only
#     生成 commit → touched files 映射
#   输出 jira/tickets/.scope-commits.json
#
# 幂等: 若 HEAD 未变则不重写
# Exit: 0=success, 2=baseline missing
set -euo pipefail

REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

BASELINE_JSON="${REPO_ROOT}/jira/tickets/.jargon-baseline.json"
OUTPUT_JSON="${REPO_ROOT}/jira/tickets/.scope-commits.json"

# 读取 baseline_commit
if [ ! -f "$BASELINE_JSON" ]; then
  echo "INFO: baseline json not found, skipping scope cache build" >&2
  exit 2
fi

BASELINE_COMMIT="$(jq -r '.baseline_commit // ""' "$BASELINE_JSON" 2>/dev/null || echo "")"
if [ -z "$BASELINE_COMMIT" ]; then
  echo "INFO: baseline_commit not found in $BASELINE_JSON" >&2
  exit 2
fi

# 获取当前 HEAD
CURRENT_HEAD="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"
if [ -z "$CURRENT_HEAD" ]; then
  echo "ERROR: cannot get HEAD" >&2
  exit 1
fi

# 检查是否需要重建 (幂等)
if [ -f "$OUTPUT_JSON" ]; then
  CACHED_HEAD="$(jq -r '.generated_head // ""' "$OUTPUT_JSON" 2>/dev/null || echo "")"
  CACHED_BASELINE="$(jq -r '.baseline_commit // ""' "$OUTPUT_JSON" 2>/dev/null || echo "")"
  if [ "$CACHED_HEAD" = "$CURRENT_HEAD" ] && [ "$CACHED_BASELINE" = "$BASELINE_COMMIT" ]; then
    echo "OK: scope cache up-to-date (HEAD=$CURRENT_HEAD)"
    exit 0
  fi
fi

# 生成新缓存: commit → [files]
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
COMMIT_FILES="${TMPDIR}/commit_files.tsv"

# 获取 baseline 之后的所有 commit 及变更文件
# git log 输出: hash\nfilename\nfilename\n\nhash\nfilename\n...
git -C "$REPO_ROOT" log --pretty='%H' --since="$BASELINE_COMMIT"..HEAD --no-renames --name-only 2>/dev/null \
  | awk '
    BEGIN { commit = "" }
    /^[0-9a-f]{40}$/ { commit = $1; next }
    NF && commit != "" && !seen[commit "\t" $0]++ { print commit "\t" $0 }
  ' > "$COMMIT_FILES"

# 用 jq 构建 JSON (逐行读 tsv)
# 输出格式: { "commits": { "<hash>": ["file1", "file2", ...] }, "generated_at": "...", "generated_head": "...", "baseline_commit": "..." }
{
  echo '{'
  echo '  "commits": {'
  first_commit=1
  prev_commit=""
  first_entry=1
  while IFS=$'\t' read -r commit file; do
    [ -z "$commit" ] && continue
    [ -z "$file" ] && continue
    if [ "$first_commit" -eq 1 ]; then
      [ "$first_entry" -eq 0 ] && echo ','
      printf '    "%s": ["%s"' "$commit" "$file"
      first_commit=0
      first_entry=0
    elif [ "$prev_commit" = "$commit" ]; then
      printf ',"%s"' "$file"
    else
      printf ']'
      echo ','
      printf '    "%s": ["%s"' "$commit" "$file"
    fi
    prev_commit="$commit"
  done < "$COMMIT_FILES"
  [ "$first_commit" -eq 0 ] && printf ']'
  echo ''
  echo '  },'
  echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"generated_head\": \"$CURRENT_HEAD\","
  echo "  \"baseline_commit\": \"$BASELINE_COMMIT\""
  echo '}'
} > "${OUTPUT_JSON}"

echo "OK: scope cache built (HEAD=$CURRENT_HEAD, commits=$(jq '(.commits | length)' "$OUTPUT_JSON"))"
exit 0

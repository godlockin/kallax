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
CURRENT_HEAD="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"
if [ -z "$CURRENT_HEAD" ]; then
  echo "ERROR: cannot get HEAD" >&2
  exit 1
fi

# 检查是否需要重建 (幂等)
if [ -f "$OUTPUT_JSON" ]; then
  CACHED_HEAD="$(jq -r '.generated_head // ""' "$OUTPUT_JSON" 2>/dev/null || echo "")"
  CACHED_BASELINE="$(jq -r '.baseline_commit // ""' "$OUTPUT_JSON" 2>/dev/null || echo "")"
  if [ "$CACHED_HEAD" = "$CURRENT_HEAD" ] && [ "$CACHED_BASELINE" = "$BASELINE_COMMIT" ] \
    && jq -e '.commits | type == "object" and length > 0 and all(.[]; type == "array" and length > 0)' "$OUTPUT_JSON" >/dev/null 2>&1; then
    echo "OK: scope cache up-to-date (HEAD=$CURRENT_HEAD)"
    exit 0
  fi
fi

# 生成新缓存: commit → [files]
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
COMMIT_FILES="${TMPDIR}/commit_files.log"

# 获取 baseline 之后的所有 commit 及变更文件。revision range 必须作为
# git log positional revision；--since 只接受日期。
env -u GIT_DIR -u GIT_WORK_TREE git -C "$REPO_ROOT" log --pretty='%H' --no-renames --name-only "$BASELINE_COMMIT..HEAD" > "$COMMIT_FILES"

# 用 Python 构建 JSON，确保路径中的引号、反斜杠等合法字符正确 escaping。
python3 - "$COMMIT_FILES" "$OUTPUT_JSON" "$CURRENT_HEAD" "$BASELINE_COMMIT" <<'PYEOF'
import json
import sys
from datetime import datetime, timezone

log_path, output_path, current_head, baseline_commit = sys.argv[1:]
commits = {}
current = None
with open(log_path, encoding="utf-8") as handle:
    for raw_line in handle:
        line = raw_line.rstrip("\n")
        if len(line) == 40 and all(char in "0123456789abcdef" for char in line):
            current = line
        elif line and current is not None:
            files = commits.setdefault(current, [])
            if line not in files:
                files.append(line)

payload = {
    "commits": commits,
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "generated_head": current_head,
    "baseline_commit": baseline_commit,
}
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PYEOF

echo "OK: scope cache built (HEAD=$CURRENT_HEAD, commits=$(jq '(.commits | length)' "$OUTPUT_JSON"))"
exit 0

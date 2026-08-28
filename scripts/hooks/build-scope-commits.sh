#!/usr/bin/env bash
# Build local scope optimization cache. Cache is never correctness authority.
set -euo pipefail

REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null)"
BASELINE_JSON="${REPO_ROOT}/jira/tickets/.jargon-baseline.json"
OUTPUT_JSON="${REPO_ROOT}/jira/tickets/.scope-commits.json"

if [ ! -f "$BASELINE_JSON" ]; then
  echo "INFO: baseline json not found, skipping scope cache build" >&2
  exit 2
fi
BASELINE_COMMIT="$(jq -r '.baseline_commit // ""' "$BASELINE_JSON")"
[ -n "$BASELINE_COMMIT" ] || { echo "INFO: baseline_commit missing" >&2; exit 2; }
CURRENT_HEAD="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$REPO_ROOT" rev-parse HEAD)"

if [ -f "$OUTPUT_JSON" ] && jq -e --arg head "$CURRENT_HEAD" --arg base "$BASELINE_COMMIT" \
  '.generated_head == $head and .baseline_commit == $base and (.commits | type == "object")' "$OUTPUT_JSON" >/dev/null 2>&1; then
  echo "OK: scope cache up-to-date (HEAD=$CURRENT_HEAD)"
  exit 0
fi

TMP_OUTPUT="$(mktemp "${OUTPUT_JSON}.tmp.XXXXXX")"
cleanup() { rm -f "$TMP_OUTPUT"; }
trap cleanup EXIT
python3 - "$REPO_ROOT" "$OUTPUT_JSON" "$CURRENT_HEAD" "$BASELINE_COMMIT" "$TMP_OUTPUT" <<'PYEOF'
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

root, output, head, baseline, tmp = sys.argv[1:]
env = os.environ.copy()
env.pop("GIT_DIR", None)
env.pop("GIT_WORK_TREE", None)
def git(*args):
    return subprocess.run(["git", "-C", root, *args], check=True, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env).stdout
commits = {}
for commit in git("rev-list", f"{baseline}..{head}").splitlines():
    names = git("diff-tree", "--root", "--no-commit-id", "--name-only", "-r", "--no-renames", commit).splitlines()
    commits[commit] = list(dict.fromkeys(name for name in names if name))
payload = {"commits": commits, "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
           "generated_head": head, "baseline_commit": baseline}
with open(tmp, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
    handle.flush()
    os.fsync(handle.fileno())
os.replace(tmp, output)
PYEOF

echo "OK: scope cache built (HEAD=$CURRENT_HEAD, commits=$(jq '.commits | length' "$OUTPUT_JSON"))"

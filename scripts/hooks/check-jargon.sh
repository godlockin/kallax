#!/usr/bin/env bash
# KALLAX check-jargon.sh — EPIC-225 + EPIC-287 (Python single-process <15s)
# 扫 staged / 全仓文件, 命中黑话词表 fail-closed exit 1.
set -euo pipefail

REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --show-toplevel 2>/dev/null || pwd)"
BLACKLIST="${REPO_ROOT}/jira/tickets/.jargon-blacklist.json"
BASELINE_JSON="${REPO_ROOT}/jira/tickets/.jargon-baseline.json"

if [ ! -f "$BLACKLIST" ]; then
  echo "FAIL: blacklist not found: $BLACKLIST" >&2
  exit 1
fi

BASELINE_COMMIT="$(jq -r '.baseline_commit // ""' "$BASELINE_JSON" 2>/dev/null || echo "")"

# Python single-process scanner (EPIC-287 perf fix)
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

python3 - "$REPO_ROOT" "$BLACKLIST" "$BASELINE_COMMIT" "$@" <<'PYEOF'
import sys
import os
import re
import json

repo_root = sys.argv[1]
blacklist_path = sys.argv[2]
baseline_commit = sys.argv[3] if len(sys.argv) > 3 else ""
cmd = sys.argv[4] if len(sys.argv) > 4 else ""

with open(blacklist_path) as f:
    blacklist = json.load(f)

patterns = []
for cat in blacklist.get("blacklist", {}).values():
    for p in cat.get("patterns", []):
        patterns.append(re.compile(p["regex"]))

# Meta exempt
meta_exempt = {".jargon-blacklist.json", ".jargon-baseline.json", "EPIC-225", "check-jargon"}

def is_meta(rel):
    return any(ex in rel for ex in meta_exempt)

def scan_file(path):
    hits = []
    try:
        with open(path) as f:
            for i, line in enumerate(f, 1):
                for pat in patterns:
                    if pat.search(line):
                        hits.append((i, line.rstrip(), pat.pattern))
                        break
    except:
        pass
    return hits

# Get file list
if cmd == "--staged":
    import subprocess
    result = subprocess.run(["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
                          capture_output=True, text=True, cwd=repo_root)
    files = [l.strip() for l in result.stdout.splitlines() if re.search(r'\.(md|sh|ts|rs)$', l)]
    files = [f for f in files if f]
elif cmd == "--all":
    import subprocess
    result = subprocess.run(["git", "ls-tree", "-r", "--name-only", "HEAD"],
                          capture_output=True, text=True, cwd=repo_root)
    files = [l.strip() for l in result.stdout.splitlines()
             if re.search(r'\.(md|sh|ts|rs)$', l)
             and not l.startswith("node_modules/")
             and not l.startswith("rust/target/")
             and not l.startswith("_archived/")]
else:
    files = [cmd] if cmd and os.path.isfile(os.path.join(repo_root, cmd)) else []

all_hits = []
for f in files:
    full_path = os.path.join(repo_root, f) if not f.startswith("/") else f
    if not os.path.isfile(full_path):
        continue
    if is_meta(f):
        continue
    for lineno, line, pat in scan_file(full_path):
        all_hits.append((f, lineno, pat, line))

if all_hits:
    for f, lineno, pat, line in all_hits[:20]:
        print(f"  {f}:{lineno} — {pat}")
        print(f"  > {line}")
    if len(all_hits) > 7:
        print(f"  ... ({len(all_hits) - 7} more)")
    print()
    print(f"FAIL: {len(all_hits)} jargon violation(s) (EPIC-225 fail-closed)")
    print("Fix: 查 jira/tickets/.jargon-blacklist.json → 'replace' 字段")
    if cmd == "--all":
        print()
        print(f"注: 全仓模式扫描到 {len(all_hits)} 历史违规.")
        print(f"    baseline = {baseline_commit}")
    sys.exit(1)

print("OK: 0 jargon violations")
sys.exit(0)
PYEOF

#!/usr/bin/env bash
# KALLAX check-jargon.sh — EPIC-225 + EPIC-287
# Performance: Python single-process scan for --all mode (<2s vs 22s+ bash loop)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"
[ -z "$REPO_ROOT" ] && REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --show-toplevel 2>/dev/null || pwd)"
BLACKLIST="${REPO_ROOT}/jira/tickets/.jargon-blacklist.json"

[ ! -f "$BLACKLIST" ] && { echo "FAIL: blacklist not found: $BLACKLIST" >&2; exit 1; }

BASELINE_JSON="${REPO_ROOT}/jira/tickets/.jargon-baseline.json"
BASELINE_COMMIT="$(jq -r '.baseline_commit // ""' "$BASELINE_JSON" 2>/dev/null || echo "")"

# Extract patterns to temp file
PATTERNS_FILE="$(mktemp)"
trap 'rm -f "$PATTERNS_FILE"' EXIT
jq -r '.blacklist | to_entries[] | .value.patterns[] | .regex' "$BLACKLIST" > "$PATTERNS_FILE"

cmd="${1:-}"
[ $# -gt 0 ] && shift

case "$cmd" in
  --staged)
    python3 - "$PATTERNS_FILE" staged "$REPO_ROOT" << 'PYEOF'
import sys, os, re, subprocess

patterns_file = sys.argv[1]
mode = sys.argv[2]
repo_root = sys.argv[3]

with open(patterns_file) as f:
    patterns = [l.strip() for l in f if l.strip()]
compiled = [(re.compile(p), p) for p in patterns]

excludes = {".jargon-blacklist.json", ".jargon-baseline.json", "EPIC-225", "check-jargon"}
valid_exts = {".md", ".sh", ".ts", ".rs"}

result = subprocess.run(["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
                        capture_output=True, text=True)
files = [f.strip() for f in result.stdout.split('\n') if f.strip()]

hits = []
for f in files:
    if not any(f.endswith(ext) for ext in valid_exts):
        continue
    if any(e in f for e in excludes):
        continue
    full = os.path.join(repo_root, f)
    if not os.path.isfile(full) or os.path.getsize(full) == 0:
        continue
    try:
        with open(full, "r", errors="ignore") as fp:
            for lineno, line in enumerate(fp, 1):
                for cre, pat in compiled:
                    if cre.search(line):
                        hits.append(f"  {f}:{lineno} — {pat}\n  > {line.rstrip()}")
                        break
    except Exception:
        pass

if hits:
    for h in hits[:7]: print(h, end="")
    if len(hits) > 7: print(f"  ... (还有 {len(hits) - 7} 个)")
    print("")
    sys.exit(1)
sys.exit(0)
PYEOF
    exit_code=$?
    if [ $exit_code -eq 1 ]; then
      echo "FAIL: jargon violation(s) in staged changes (EPIC-225 fail-closed)"
    fi
    exit $exit_code
    ;;

  --all)
    # EPIC-287: git ls-tree is 5x faster than git ls-files
    python3 - "$PATTERNS_FILE" all "$REPO_ROOT" << 'PYEOF'
import sys, os, re, subprocess

patterns_file = sys.argv[1]
mode = sys.argv[2]
repo_root = sys.argv[3]

with open(patterns_file) as f:
    patterns = [l.strip() for l in f if l.strip()]
compiled = [(re.compile(p), p) for p in patterns]

excludes = {".jargon-blacklist.json", ".jargon-baseline.json", "EPIC-225", "check-jargon"}
valid_exts = {".md", ".sh", ".ts", ".rs"}

# git ls-tree is 5x faster than git ls-files
result = subprocess.run(["git", "ls-tree", "-r", "HEAD", "--name-only"],
                        capture_output=True, text=True)
files = [f.strip() for f in result.stdout.split('\n') if f.strip() and f.endswith(('.md', '.sh', '.ts', '.rs'))]

hits = []
for f in files:
    if any(e in f for e in excludes):
        continue
    full = os.path.join(repo_root, f)
    if not os.path.isfile(full) or os.path.getsize(full) == 0:
        continue
    try:
        with open(full, "r", errors="ignore") as fp:
            for lineno, line in enumerate(fp, 1):
                for cre, pat in compiled:
                    if cre.search(line):
                        hits.append(f"  {f}:{lineno} — {pat}\n  > {line.rstrip()}")
                        break
    except Exception:
        pass

if hits:
    for h in hits[:7]: print(h, end="")
    if len(hits) > 7: print(f"  ... (还有 {len(hits) - 7} 个)")
    print("")
    sys.exit(1)
sys.exit(0)
PYEOF
    exit_code=$?
    if [ $exit_code -eq 1 ]; then
      echo ""
      echo "FAIL: jargon violation(s) (EPIC-225 fail-closed)"
      echo "Fix: 查 jira/tickets/.jargon-blacklist.json → 'replace' 字段"
      echo ""
      echo "注: 全仓模式扫描到 4056 备案历史违规 (跟 EPIC-223 1:1)."
      echo "    baseline = $BASELINE_COMMIT (历史划线, 新增强制)"
      echo "    主公 2026-08-08 拍板 C 方案: 历史不追溯, 代码 (19 self-heal) 真修."
    fi
    exit $exit_code
    ;;

  "")
    echo "Usage: $0 <path>|--staged|--all" >&2
    exit 1
    ;;

  *)
    [ ! -f "$cmd" ] && { echo "FAIL: not a file: $cmd" >&2; exit 1; }
    rel="${cmd#$REPO_ROOT/}"
    for e in ".jargon-blacklist.json" ".jargon-baseline.json" "EPIC-225" "check-jargon"; do
      [[ "$rel" == *"$e"* ]] && { echo "OK: 0 jargon violations"; exit 0; }
    done
    combined=$(tr '\n' '|' < "$PATTERNS_FILE" | sed 's/|$//')
    matches=$(grep -nE "$combined" "$cmd" 2>/dev/null || true)
    if [ -n "$matches" ]; then
      echo "$matches" | head -7
      exit 1
    fi
    ;;
esac

echo "OK: 0 jargon violations"
exit 0

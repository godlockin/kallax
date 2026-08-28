#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  printf 'usage: %s EPIC-ID [--commit SHA]\n' "$0" >&2
  exit 2
fi

EPIC_ID="$1"
COMMIT_ARG=""
if [[ $# -eq 3 ]]; then
  if [[ "$2" != "--commit" ]]; then
    printf 'usage: %s EPIC-ID [--commit SHA]\n' "$0" >&2
    exit 2
  fi
  COMMIT_ARG="$3"
elif [[ $# -eq 2 ]]; then
  printf 'usage: %s EPIC-ID [--commit SHA]\n' "$0" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

exec python3 - "$REPO_ROOT" "$EPIC_ID" "$COMMIT_ARG" <<'PY'
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

repo_root = Path(sys.argv[1])
epic_id = sys.argv[2]
commit_arg = sys.argv[3] or "HEAD"
started = time.monotonic()

def git(*args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo_root), *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return result.stdout.strip()

commit_sha = git("rev-parse", f"{commit_arg}^{{commit}}")
changed = git("diff-tree", "--root", "--no-commit-id", "--name-only", "-r", commit_sha)
files_changed = len(changed.splitlines()) if changed else 0

# Collector never runs tests. If caller leaves its optional sidecar log, record it;
# absent logs are valid evidence and produce zero bytes.
sidecar_log = repo_root / "jira" / "tickets" / ".evidence" / f"{epic_id}.test.log"
test_output_byte = sidecar_log.stat().st_size if sidecar_log.is_file() else 0

output = {
    "epic_id": epic_id,
    "commit_sha": commit_sha,
    "files_changed": files_changed,
    "test_output_byte": test_output_byte,
    "wall_clock_sec": round(time.monotonic() - started, 3),
    "exit_code": 0,
    "collected_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
}
output_path = repo_root / "jira" / "tickets" / ".evidence" / f"{epic_id}.json"
output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
print(json.dumps(output, separators=(",", ":")))
PY

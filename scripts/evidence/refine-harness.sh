#!/usr/bin/env bash
# Generate a human-review proposal from accumulated evidence.
set -euo pipefail

usage() {
  printf 'usage: %s --analyze [--dry-run]\n' "$0" >&2
}

analyze=0
dry_run=0
for arg in "$@"; do
  case "$arg" in
    --analyze) analyze=1 ;;
    --dry-run) dry_run=1 ;;
    *) usage; exit 2 ;;
  esac
done
[ "$analyze" -eq 1 ] || { usage; exit 2; }

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
evidence_dir="$repo_root/jira/tickets/.evidence"
pool_file="$repo_root/scripts/binding/lib/expert-pool.sh"
proposal="$repo_root/confluence/decisions/evidence-refine-$(date +%Y-%m).md"

REPO_ROOT="$repo_root" EVIDENCE_DIR="$evidence_dir" POOL_FILE="$pool_file" PROPOSAL="$proposal" DRY_RUN="$dry_run" \
python3 - <<'PY'
import json
import os
import re
from collections import Counter
from datetime import date
from pathlib import Path

root = Path(os.environ["REPO_ROOT"])
evidence_dir = Path(os.environ["EVIDENCE_DIR"])
pool_file = Path(os.environ["POOL_FILE"])
proposal = Path(os.environ["PROPOSAL"])
dry_run = os.environ["DRY_RUN"] == "1"

records = []
errors = []
for path in sorted(evidence_dir.glob("*.json")):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"{path.name}: {exc}")
        continue
    if not isinstance(value, dict):
        errors.append(f"{path.name}: top-level JSON must be object")
        continue
    records.append((path.name, value))

pool_text = pool_file.read_text(encoding="utf-8")
match = re.search(r"ALLOWED_EXPERTS=\(\s*(.*?)\s*\)", pool_text, re.S)
configured = re.findall(r"[A-Za-z][A-Za-z0-9:_-]*", match.group(1)) if match else []
configured_set = set(configured)

def expert_values(value):
    found = []
    for key in ("experts", "expert_pool", "activated_experts", "assigned_experts", "expert_activation"):
        item = value.get(key)
        if isinstance(item, str):
            found.append(item)
        elif isinstance(item, list):
            found.extend(x for x in item if isinstance(x, str))
        elif isinstance(item, dict):
            found.extend(str(x) for x in item if isinstance(x, str))
    return found

counts = Counter()
for _, value in records:
    counts.update(expert_values(value))
unknown = sorted(name for name in counts if name not in configured_set and not name.startswith("custom:"))
underused = sorted((name, count) for name, count in counts.items() if count < 2)
unused = sorted(configured_set - set(counts))

lines = [
    f"# Evidence refinement proposal — {date.today():%Y-%m}", "",
    "> Human review required. This report never edits expert-pool.sh or expert-resolver.sh.", "",
    "## 1. 累计 evidence 总览", "",
    f"- Evidence files: {len(records)}",
    f"- Expert observations: {sum(counts.values())}",
    f"- Distinct observed experts: {len(counts)}",
    f"- Invalid files skipped: {len(errors)}",
    "",
    "| Expert | Observations |",
    "|---|---:|",
]
lines.extend(f"| `{name}` | {count} |" for name, count in sorted(counts.items()))
if not counts:
    lines.append("| _none_ | 0 |")
lines += ["", "## 2. expert-pool 配置对比", "", f"- Configured experts: {len(configured)}", f"- Observed experts configured: {len(set(counts) & configured_set)}", f"- Observed names outside configuration: {len(unknown)}", ""]
lines += ["| Category | Experts |", "|---|---|", f"| Configured but not observed | {', '.join(f'`{x}`' for x in unused) or '_none_'} |", f"| Observed but not configured | {', '.join(f'`{x}`' for x in unknown) or '_none_'} |", ""]
lines += ["## 3. gap > 阈值项", "", "Threshold: observed expert count below 2, or observed name absent from configured pool.", ""]
if underused:
    lines.extend(f"- `{name}`: {count} observation(s), below threshold 2." for name, count in underused)
if unknown:
    lines.extend(f"- `{name}`: observed but absent from current pool; verify spelling or intentional custom namespace." for name in unknown)
if not underused and not unknown:
    lines.append("- None detected.")
lines += ["", "## 4. 建议 refinement (人审, 0 自动改)", "", "1. Human reviewer validates evidence provenance and expert-name spelling.", "2. Human reviewer decides whether recurring gaps warrant an expert-pool proposal.", "3. Apply any approved change manually in a separate reviewed change; this harness performs no configuration mutation.", ""]
if errors:
    lines += ["### Parse warnings", ""]
    lines.extend(f"- {error}" for error in errors)
    lines.append("")
content = "\n".join(lines)
if dry_run:
    print(f"DRY_RUN proposal={proposal} evidence={len(records)}")
else:
    proposal.parent.mkdir(parents=True, exist_ok=True)
    proposal.write_text(content + "\n", encoding="utf-8")
    print(f"WROTE proposal={proposal} evidence={len(records)}")
PY

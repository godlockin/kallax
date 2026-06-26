#!/usr/bin/env bash
# scripts/verify/validate-json-schema.sh — JSON Schema validator for jira/ JSON files
#
# EPIC-015-D: JSON Schema 定义与验证 — phase/epic/ticket/state
#
# Validates:
#   1. jira/phases/phase_index.json          → phase-schema.json (index variant)
#   2. jira/phases/{PHASE-NNN}/phase.json    → phase-schema.json (single variant)
#   3. jira/epics/epic_index.json            → epic-schema.json (index variant)
#   4. jira/epics/{EPIC-NNN}/epic.json       → epic-schema.json (single variant)
#   5. jira/tickets/{TICKET-ID}/ticket.json  → ticket-schema.json
#
# 跟 v2.7.4 D5 secondary status schema 1:1 验证 (pending/deferred/failed)
# 跟 "翻篇&精进" 战略 联合 0 简单 记录 — schemas are single source of truth
#
# Usage:
#   bash scripts/verify/validate-json-schema.sh          # validate all
#   bash scripts/verify/validate-json-schema.sh --strict # exit 1 on any failure
#   bash scripts/verify/validate-json-schema.sh --quiet  # only show summary
#
# Exit codes:
#   0 = all valid
#   1 = at least one file failed validation
#   2 = setup error (missing dependency / schema)

set -uo pipefail

# Self-guard: EPIC-053-C BE-10 — 拒 [[:space:]] 数组模式 (bash 5.x 不兼容)
_awd_guard_ok=1
_awk_awd=$(awk '
    BEGIN { in_a = 0; d = 0 }
    {
        line = $0
        gsub(/\$\(\(/, "", line)
        gsub(/\$\(/, "", line)
        if (in_a == 0) {
            if (match(line, /[A-Za-z_][A-Za-z0-9_]*[ ]*(\+)?=\(/)) { in_a = 1; d = 1 }
        } else {
            d += gsub(/\(/, "x", line) - gsub(/\)/, "x", line)
            if (match(line, /\[\[:space:\]\]/)) { exit 1 }
            if (d <= 0) in_a = 0
        }
    }
' "$0" 2>/dev/null) || _awd_guard_ok=0
if [ "$_awd_guard_ok" -eq 0 ]; then
    echo "BE-10 模式复发: [[:space:]] 在数组模式. 用 \\s 替代." >&2
    exit 2
fi
unset _awd_guard_ok _awk_awd

# Resolve repo root (worktree-aware: walk up until we find jira/schemas/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
while [ "$REPO_ROOT" != "/" ]; do
    if [ -d "$REPO_ROOT/jira/schemas" ]; then
        break
    fi
    REPO_ROOT="$(dirname "$REPO_ROOT")"
done

if [ ! -d "$REPO_ROOT/jira/schemas" ]; then
    echo "ERROR: jira/schemas/ not found from $SCRIPT_DIR" >&2
    exit 2
fi

SCHEMA_DIR="$REPO_ROOT/jira/schemas"

# Check Python + jsonschema dependency
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 required for schema validation" >&2
    exit 2
fi

if ! python3 -c "import jsonschema" 2>/dev/null; then
    echo "ERROR: Python jsonschema module required (pip install jsonschema)" >&2
    exit 2
fi

# Args
STRICT=0
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --quiet) QUIET=1 ;;
        --help|-h)
            sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown arg: $arg" >&2
            exit 2
            ;;
    esac
done

# Build inline Python validator with all 4 schemas inlined as dict for $ref resolution.
# This avoids RefResolver store complexity (the schemas cross-reference each other
# via "state-schema.json#/definitions/..." URIs).
VALIDATOR_OUTPUT=$(python3 - "$SCHEMA_DIR" <<'PYEOF'
import json
import sys
from pathlib import Path
from jsonschema import Draft7Validator
from jsonschema.exceptions import ValidationError

schema_dir = Path(sys.argv[1])

# Load all 4 schemas into a shared store, keyed by filename so $ref works.
schemas = {}
for name in ("state-schema.json", "ticket-schema.json", "epic-schema.json", "phase-schema.json"):
    path = schema_dir / name
    if not path.exists():
        print(f"FATAL: missing schema {path}", file=sys.stderr)
        sys.exit(2)
    with path.open() as f:
        schemas[name] = json.load(f)

def make_validator(schema):
    # Build a referencing.Registry with all 4 schemas so $ref like
    # "state-schema.json#/definitions/foo" resolves correctly.
    try:
        from referencing import Registry, Resource
        from referencing.jsonschema import DRAFT7
        resources = []
        for name, sch in schemas.items():
            resource = Resource.from_contents(sch, default_specification=DRAFT7)
            resources.append((name, resource))
        registry = Registry().with_resources(resources)
        return Draft7Validator(schema, registry=registry)
    except ImportError:
        # Fallback: RefResolver (jsonschema <4.18 style)
        from jsonschema import RefResolver
        store = {"file:": schemas}
        resolver = RefResolver(base_uri="", referrer=schema, store=store)
        return Draft7Validator(schema, resolver=resolver)

repo_root = schema_dir.parent.parent  # jira/schemas → jira → repo root
jira_dir = repo_root / "jira"

targets = []  # (file_path, schema_name, description)

# Phase index
pi = jira_dir / "phases" / "phase_index.json"
if pi.exists():
    targets.append((pi, "phase-schema.json", "phase_index.json"))

# Per-phase detail
for phase_dir in (jira_dir / "phases").iterdir():
    if not phase_dir.is_dir():
        continue
    pf = phase_dir / "phase.json"
    if pf.exists():
        targets.append((pf, "phase-schema.json", f"phases/{phase_dir.name}/phase.json"))

# Epic index
ei = jira_dir / "epics" / "epic_index.json"
if ei.exists():
    targets.append((ei, "epic-schema.json", "epic_index.json"))

# Per-epic detail
for epic_dir in (jira_dir / "epics").iterdir():
    if not epic_dir.is_dir() or epic_dir.name.startswith("_"):
        continue
    ef = epic_dir / "epic.json"
    if ef.exists():
        targets.append((ef, "epic-schema.json", f"epics/{epic_dir.name}/epic.json"))

# Tickets
for ticket_dir in (jira_dir / "tickets").iterdir():
    if not ticket_dir.is_dir() or ticket_dir.name.startswith("_"):
        continue
    tf = ticket_dir / "ticket.json"
    if tf.exists():
        targets.append((tf, "ticket-schema.json", f"tickets/{ticket_dir.name}/ticket.json"))

total = len(targets)
passed = 0
failed = 0
errors_detail = []

for path, schema_name, desc in targets:
    try:
        with path.open() as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        failed += 1
        errors_detail.append((desc, f"JSON parse error: {e}"))
        continue

    validator = make_validator(schemas[schema_name])
    errs = list(validator.iter_errors(data))
    if errs:
        failed += 1
        # Cap at 3 errors per file for readability
        msg = "; ".join(
            f"{'/'.join(str(p) for p in e.absolute_path) or '<root>'}: {e.message}"
            for e in errs[:3]
        )
        if len(errs) > 3:
            msg += f" (+{len(errs) - 3} more)"
        errors_detail.append((desc, msg))
    else:
        passed += 1

print(f"=== validate-json-schema.sh (EPIC-015-D) ===")
print(f"Schema dir: {schema_dir}")
print(f"Total files: {total}")
print(f"PASS: {passed}/{total}")
print(f"FAIL: {failed}/{total}")
if errors_detail:
    print(f"")
    print(f"Failures:")
    for desc, msg in errors_detail:
        print(f"  ✗ {desc}")
        print(f"      {msg}")

sys.exit(1 if failed > 0 else 0)
PYEOF
)
VALIDATOR_RC=$?

if [ "$QUIET" -eq 1 ]; then
    # Quiet mode: only summary (skip failure detail list)
    echo "$VALIDATOR_OUTPUT" | grep -E "^(Schema dir|Total files|PASS|FAIL)"
else
    echo "$VALIDATOR_OUTPUT"
fi

if [ "$VALIDATOR_RC" -ne 0 ]; then
    if [ "$STRICT" -eq 1 ]; then
        exit 1
    fi
    exit 1
fi

exit 0
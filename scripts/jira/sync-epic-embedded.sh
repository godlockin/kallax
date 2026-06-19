#!/usr/bin/env bash
# scripts/jira/sync-epic-embedded.sh — Sync epic.json embedded ticket status from ticket.json
# v2.7.4 D5, 跟 Rule 5 DRY 联合 (single source of truth: ticket.json), 跟"反讽" 联合 治根
# 跟 v2.7.1 5 EPIC 同步 模式 一致, 跟 EPIC-058 + EPIC-060 deferred 模式 联合
set -euo pipefail

EPICS_DIR="jira/epics"
TICKETS_DIR="jira/tickets"

# Run full sync via python (handles embedded=None, actual=None, embedded=mismatch all cases)
python3 - "$EPICS_DIR" "$TICKETS_DIR" <<'PYEOF'
import json
import os
import sys

EPICS_DIR, TICKETS_DIR = sys.argv[1], sys.argv[2]

fixed = 0
scanned = 0
for epic_name in sorted(os.listdir(EPICS_DIR)):
    if not epic_name.startswith("EPIC-"):
        continue
    path = f"{EPICS_DIR}/{epic_name}/epic.json"
    if not os.path.isfile(path):
        continue
    with open(path) as f:
        epic = json.load(f)
    if "tickets" not in epic:
        continue
    changed = False
    for embedded in epic["tickets"]:
        scanned += 1
        tid = embedded.get("id")
        if not tid:
            continue
        actual_path = f"{TICKETS_DIR}/{tid}/ticket.json"
        if not os.path.isfile(actual_path):
            continue
        with open(actual_path) as f:
            actual = json.load(f)
        actual_status = actual.get("status")
        embedded_status = embedded.get("status")
        if actual_status is None:
            # ticket.json missing status — set both to "ready" (default)
            actual["status"] = "ready"
            with open(actual_path, "w") as f:
                json.dump(actual, f, indent=2, ensure_ascii=False)
                f.write("\n")
            actual_status = "ready"
        if embedded_status != actual_status:
            embedded["status"] = actual_status
            changed = True
            print(f"  FIXED: {tid}: -> {actual_status}")
            fixed += 1
    if changed:
        with open(path, "w") as f:
            json.dump(epic, f, indent=2, ensure_ascii=False)
            f.write("\n")

print(f"\nScanned {scanned} embedded tickets")
print(f"Fixed {fixed} desync(s)")
PYEOF

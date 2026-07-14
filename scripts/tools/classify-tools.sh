#!/usr/bin/env python3
# scripts/tools/classify-tools.sh — OpenAI 3-class taxonomy classifier (EPIC-119-B)
#
# Reads all KALLAX slash commands, classifies into Data/Action/Orchestration.
# Python fallback for macOS bash 3.2 (no associative arrays).
#
# Usage:
#   bash scripts/tools/classify-tools.sh [--format markdown|json|table]
#   bash scripts/tools/classify-tools.sh --verify

import sys
import os
import json
import argparse
from pathlib import Path

TOOL_CLASS = {
    # Data (read-only context retrieval)
    "kallax-status": "data",
    "kallax-board": "data",
    "kallax-list": "data",
    "kallax-instances": "data",
    "kallax-check-progress": "data",
    "kallax-review-analysis": "data",
    "kallax-analyze": "data",
    "kallax metrics:sprint": "data",
    # Action (write operations)
    "kallax-claim": "action",
    "kallax-submit-pr": "action",
    "kallax-merge": "action",
    "kallax-init": "action",
    "kallax-start": "action",
    "kallax-mode": "action",
    "kallax-role": "action",
    "kallax-task": "action",
    "kallax-save": "action",
    "kallax-resume": "action",
    "kallax-takeover": "action",
    "kallax-onramp": "action",
    "kallax-office-hours": "action",
    "kallax-skill": "action",
    "kallax-help": "action",
    # Orchestration (agent as tool for other agents)
    "kallax-expert": "orchestration",
    "kallax-panel": "orchestration",
    "kallax-ask": "orchestration",
    "kallax-review-pr": "orchestration",
    "kallax-review-merge": "orchestration",
    "kallax-verify-pr": "orchestration",
    "kallax-phase-review": "orchestration",
}

COMMANDS_DIR = Path.home() / ".claude" / "commands"

def find_commands():
    """Find all kallax command files."""
    if not COMMANDS_DIR.exists():
        return []
    return sorted([f.stem for f in COMMANDS_DIR.glob("kallax-*.sh")])


def classify_all():
    """Classify all commands found vs registered."""
    commands = find_commands()
    classified = {name: TOOL_CLASS.get(name, None) for name in commands}
    return classified


def output_markdown(classified):
    for cls in ["data", "action", "orchestration"]:
        label = cls.capitalize()
        desc = {
            "data": "read-only context retrieval",
            "action": "write operations",
            "orchestration": "agent as tool for other agents"
        }[cls]
        print(f"## {label} ({desc})")
        print()
        print("| Command | Class |")
        print("|---------|-------|")
        for name, c in sorted(classified.items()):
            if c == cls:
                print(f"| `/{name}` | {c} |")
        print()


def output_json(classified):
    results = [{"command": n, "class": c or "unclassified"} for n, c in sorted(classified.items())]
    print(json.dumps(results, indent=2))


def output_table(classified):
    print(f"{'Command':<35} {'Class'}")
    print(f"{'-------':<35} {'-----'}")
    for name, c in sorted(classified.items()):
        print(f"/{name:<33} {c or 'UNCLASSIFIED'}")


def main():
    parser = argparse.ArgumentParser(description="Classify KALLAX tools into OpenAI 3-class taxonomy")
    parser.add_argument("--format", choices=["markdown", "json", "table"], default="markdown")
    parser.add_argument("--verify", action="store_true", help="Return non-zero if any unclassified")
    args = parser.parse_args()

    classified = classify_all()
    unclassified = [n for n, c in classified.items() if c is None]

    if unclassified:
        for name in unclassified:
            print(f"WARN: unclassified: {name}", file=sys.stderr)

    if args.format == "markdown":
        output_markdown(classified)
    elif args.format == "json":
        output_json(classified)
    else:
        output_table(classified)

    sys.exit(1 if (args.verify and unclassified) else 0)


if __name__ == "__main__":
    main()

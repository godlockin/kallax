#!/usr/bin/env bash
# KALLAX check-jargon.sh — EPIC-225 + EPIC-286 + EPIC-287-C
# Python single-process scanner. Exit 0=PASS, 1=FAIL.
set -euo pipefail

REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
BLACKLIST="$REPO_ROOT/jira/tickets/.jargon-blacklist.json"
BASELINE="$REPO_ROOT/jira/tickets/.jargon-baseline.json"
SCOPE_CACHE="$REPO_ROOT/jira/tickets/.scope-commits.json"

if [ ! -f "$BLACKLIST" ]; then
  echo "FAIL: blacklist not found: $BLACKLIST" >&2
  exit 1
fi

XY_PASS_PATTERN='[0-9]+/[0-9]+\s+(PASS|passed)'

python3 - "$REPO_ROOT" "$BLACKLIST" "$BASELINE" "$SCOPE_CACHE" "$XY_PASS_PATTERN" "${1:-}" <<'PYEOF'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

repo_root, blacklist_path, baseline_path, scope_path, xy_pattern, mode = sys.argv[1:]
root = Path(repo_root)

class ScanError(Exception):
    pass

def run_git(args, *, check=True):
    clean_env = os.environ.copy()
    clean_env.pop("GIT_DIR", None)
    clean_env.pop("GIT_WORK_TREE", None)
    result = subprocess.run(["git", "-C", repo_root, *args], text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            env=clean_env)
    if check and result.returncode != 0:
        raise ScanError(f"git {' '.join(args)} failed (exit={result.returncode}): {result.stderr.strip()}")
    return result

def load_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise ScanError(f"cannot read JSON {path}: {exc}") from exc

try:
    blacklist = load_json(blacklist_path)
    patterns = []
    for category in blacklist.get("blacklist", {}).values():
        for item in category.get("patterns", []):
            try:
                patterns.append((item["regex"], re.compile(item["regex"])))
            except (KeyError, re.error) as exc:
                raise ScanError(f"invalid blacklist pattern: {exc}") from exc

    baseline_data = load_json(baseline_path) if os.path.exists(baseline_path) else {}
    baseline_commit = baseline_data.get("baseline_commit", "")
    baseline_valid = bool(baseline_commit) and run_git(["cat-file", "-e", f"{baseline_commit}^{{commit}}"], check=False).returncode == 0
    if baseline_commit and not baseline_valid:
        raise ScanError(f"invalid baseline_commit: {baseline_commit}")

    head = run_git(["rev-parse", "HEAD"]).stdout.strip()
    extensions = re.compile(r"\.(md|sh|ts|rs)$")
    excluded = re.compile(r"^(?:node_modules|rust/target|_archived)/")

    def is_meta(rel):
        base = os.path.basename(rel)
        if base in {".jargon-blacklist.json", ".jargon-baseline.json", ".scope-commits.json"}:
            return True
        return (
            rel == "scripts/hooks/check-jargon.sh"
            or rel == "CLAUDE.md"
            or rel == ".claude/rules/immutable-scripts.md"
            or rel.startswith("tests/integration/check-jargon-")
            or rel.startswith("tests/integration/epic-225-jargon-")
            or rel.startswith("tests/integration/epic-250-jargon-")
            or rel.startswith("confluence/decisions/EPIC-225")
            or rel.startswith("jira/tickets/.jargon-")
        )

    def tracked_files():
        result = run_git(["ls-files", "-z"])
        return [item for item in result.stdout.split("\0") if item and extensions.search(item) and not excluded.search(item)]

    scope_status = "not applicable"
    if mode == "--staged":
        result = run_git(["diff", "--cached", "--name-only", "--diff-filter=ACMR"])
        files = [item for item in result.stdout.splitlines() if extensions.search(item) and not excluded.search(item)]
    elif mode == "--all":
        files = tracked_files()
        try:
            cache = load_json(scope_path)
            if not isinstance(cache, dict):
                raise ValueError("cache root is not an object")
            commits = cache.get("commits")
            cache_head = cache.get("generated_head")
            cache_baseline = cache.get("baseline_commit")
            if not isinstance(commits, dict) or not commits or cache_head != head or cache_baseline != baseline_commit:
                raise ValueError("stale or malformed metadata")
            if any(not isinstance(names, list) or not names for names in commits.values()):
                raise ValueError("cache commit values are empty or not lists")
            cached_files = {file_name for names in commits.values() for file_name in names}
            if any(
                not isinstance(file_name, str)
                or not file_name
                or os.path.isabs(file_name)
                or "\x00" in file_name
                or ".." in Path(file_name).parts
                for file_name in cached_files
            ):
                raise ValueError("cache contains invalid relative paths")
            files = [item for item in files if item in cached_files]
            if not files:
                raise ValueError("cache selects zero tracked scanner files")
            scope_status = f"loaded ({len(files)} files)"
        except (ScanError, OSError, json.JSONDecodeError, ValueError, KeyError, AttributeError) as exc:
            # Cache is an optimization only. Correctness fallback is always git ls-files.
            scope_status = f"fallback git ls-files ({exc})"
            files = tracked_files()
    elif mode:
        requested = mode if os.path.isabs(mode) else mode
        files = [requested] if os.path.isfile(requested if os.path.isabs(requested) else os.path.join(repo_root, requested)) else []
    else:
        raise ScanError("usage: check-jargon.sh <path>|--staged|--all")

    xy_pass = re.compile(xy_pattern)

    def evidence(lines, line_number):
        start = max(0, line_number - 1 - 10)
        end = min(len(lines), line_number + 10)
        return any(re.search(r"(`(?:bash|npx|cargo|npm|git|python3) |^\s*\$ |exit=[0-9]|RC=[0-9]|rc=[0-9])", line) for line in lines[start:end])

    changed_lines_cache = {}
    batch_changed_lines = {}
    batch_diff_ready = False
    if mode == "--all" and baseline_valid:
        batch_diff = run_git(["diff", "--unified=0", f"{baseline_commit}..HEAD", "--", *files], check=False)
        if batch_diff.returncode != 0:
            raise ScanError(f"batch baseline diff failed (exit={batch_diff.returncode}): {batch_diff.stderr.strip()}")
        current_file = None
        for diff_line in batch_diff.stdout.splitlines():
            if diff_line.startswith("+++ b/"):
                current_file = diff_line[6:]
                batch_changed_lines.setdefault(current_file, set())
                continue
            if current_file is None:
                continue
            match = re.match(r"^@@ .* \+(\d+)(?:,(\d+))? @@", diff_line)
            if match:
                start = int(match.group(1))
                count = int(match.group(2) or "1")
                batch_changed_lines[current_file].update(range(start, start + count))
        batch_diff_ready = True

    def baseline_changed_lines(rel):
        if not baseline_valid:
            return None
        if batch_diff_ready:
            return batch_changed_lines.get(rel, set())
        if rel in changed_lines_cache:
            return changed_lines_cache[rel]
        baseline_path = f"{baseline_commit}:{rel}"
        baseline_exists = run_git(["cat-file", "-e", baseline_path], check=False).returncode == 0
        if not baseline_exists:
            changed_lines_cache[rel] = None
            return None
        diff = run_git(["diff", "--unified=0", f"{baseline_commit}...HEAD", "--", rel], check=False)
        if diff.returncode != 0:
            raise ScanError(f"git diff failed for {rel} (exit={diff.returncode}): {diff.stderr.strip()}")
        changed = set()
        for diff_line in diff.stdout.splitlines():
            match = re.match(r"^@@ .* \+(\d+)(?:,(\d+))? @@", diff_line)
            if not match:
                continue
            start = int(match.group(1))
            count = int(match.group(2) or "1")
            changed.update(range(start, start + count))
        changed_lines_cache[rel] = changed
        return changed

    def historical_line(rel, line_number):
        changed = baseline_changed_lines(rel)
        return changed is not None and line_number not in changed

    hits = []
    for rel in files:
        display_rel = os.path.relpath(rel, repo_root) if os.path.isabs(rel) else rel
        if is_meta(display_rel):
            continue
        path = Path(rel) if os.path.isabs(rel) else root / rel
        try:
            with open(path, encoding="utf-8", errors="strict") as handle:
                lines = handle.readlines()
        except (OSError, UnicodeError) as exc:
            raise ScanError(f"cannot read {rel}: {exc}") from exc
        for line_number, line in enumerate(lines, 1):
            if xy_pass.search(line) and evidence(lines, line_number):
                continue
            for pattern_text, pattern in patterns:
                if not pattern.search(line):
                    continue
                if xy_pass.search(line) and evidence(lines, line_number):
                    continue
                if historical_line(display_rel, line_number):
                    continue
                hits.append((display_rel, line_number, pattern_text, line.rstrip("\n")))
                break

    for rel, line_number, pattern_text, line in hits[:20]:
        print(f"  {rel}:{line_number} — {pattern_text}")
        print(f"  > {line}")
    if hits:
        if len(hits) > 20:
            print(f"  ... ({len(hits) - 20} more)")
        print(f"\nFAIL: {len(hits)} jargon violation(s) (EPIC-225 fail-closed)")
        print("Fix: 查 jira/tickets/.jargon-blacklist.json → 'replace' 字段")
        if mode == "--all":
            print(f"baseline = {baseline_commit}")
            print(f"EPIC-287-C scope cache: {scope_status}")
        sys.exit(1)

    if mode == "--all":
        print(f"EPIC-287-C scope cache: {scope_status}")
    print("OK: 0 jargon violations")
except ScanError as exc:
    print(f"FAIL: {exc}", file=sys.stderr)
    sys.exit(1)
PYEOF

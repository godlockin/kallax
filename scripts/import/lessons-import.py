#!/usr/bin/env python3
# scripts/import/lessons-import.py — Cross-project lessons migration
# EPIC-038-C: 跨项目 lessons 迁移 (Q5 闭环, 经验教训迁移 75%→90%)
#
# Imports lessons from other KALLAX instances / projects into the current
# confluence/memory/lessons/ knowledge base.  Source lessons may be in
# other git worktrees, other clones, or external paths.
#
# Modes (subcommand):
#   import <source_path> [--target <dst>] [--prefix <p>] [--dry-run]
#       Copy lessons files from source_path to local target (default:
#       confluence/memory/lessons/), adding optional prefix to filenames.
#   export <dst_path> [--source <src>] [--prefix <p>]
#       Export local lessons (or a subset by prefix) to a destination dir.
#   merge <source_path> [--target <dst>] [--strategy <strategy>]
#       Merge lessons from source into target using one of:
#         - skip    : skip if file exists (default)
#         - newer   : replace if source mtime > target mtime
#         - always  : always overwrite
#   diff <source_path> [--target <dst>]
#       Print files that differ between source and target (by content hash).
#   self-check
#       Validate script + verify patterns.
#   --help / -h
#
# Exit codes:
#   0 = success
#   1 = operation failure
#   2 = usage error
#
# Rule alignment:
#   - Rule 8: L4 python scripts must exist before ticket close
#   - Rule 9 KPI 精确: counts 用 len() (0 估数, 跟 EPIC-037-A kpi-audit 联合)
#   - Rule 12 质量 ensure: 5 维度 audit (import/export/merge/diff/self-check)
#   - Q5 L4 角色规范: import/export 是知识迁移, 不改原项目代码
from __future__ import annotations

import argparse
import dataclasses
import hashlib
import os
import shutil
import sys
from pathlib import Path
from typing import Iterable

EXIT_OK = 0
EXIT_FAIL = 1
EXIT_USAGE = 2

DEFAULT_SOURCE_SUBDIR = "confluence/memory/lessons"
VALID_STRATEGIES = ("skip", "newer", "always")


@dataclasses.dataclass
class ImportResult:
    imported: int = 0
    skipped: int = 0
    failed: int = 0
    errors: list[str] = dataclasses.field(default_factory=list)

    @property
    def total(self) -> int:
        return self.imported + self.skipped + self.failed


def script_dir() -> Path:
    return Path(__file__).resolve().parent


def kallax_root() -> Path:
    return script_dir().parent.parent


def default_target() -> Path:
    return kallax_root() / "confluence" / "memory" / "lessons"


def file_hash(path: Path) -> str:
    h = hashlib.sha256()
    try:
        h.update(path.read_bytes())
    except OSError:
        return ""
    return h.hexdigest()


def iter_lessons(source: Path) -> Iterable[Path]:
    """Yield lesson files (.md) under source directory."""
    if not source.exists():
        return
    if source.is_file():
        if source.suffix == ".md":
            yield source
        return
    for p in sorted(source.rglob("*.md")):
        if p.is_file():
            yield p


def normalize_prefix(prefix: str) -> str:
    if not prefix:
        return ""
    prefix = prefix.strip().strip("-_")
    return f"{prefix}-" if prefix else ""


def cmd_import(args: argparse.Namespace) -> int:
    source = Path(args.source).resolve()
    target = Path(args.target).resolve() if args.target else default_target()
    prefix = normalize_prefix(args.prefix or "")
    dry_run = bool(args.dry_run)

    if not source.exists():
        print(f"ERROR: source not found: {source}", file=sys.stderr)
        return EXIT_USAGE

    target.mkdir(parents=True, exist_ok=True)
    result = ImportResult()

    print(f"import: source={source}")
    print(f"import: target={target}")
    print(f"import: prefix='{prefix}', dry_run={dry_run}")

    for src in iter_lessons(source):
        dst_name = f"{prefix}{src.name}" if prefix else src.name
        dst = target / dst_name
        if dst.exists():
            result.skipped += 1
            print(f"  [SKIP] {dst_name} (exists)")
            continue
        try:
            if dry_run:
                print(f"  [DRY] would copy {src.name} -> {dst_name}")
                continue
            shutil.copy2(src, dst)
            result.imported += 1
            print(f"  [IMPORT] {src.name} -> {dst_name}")
        except OSError as e:
            result.failed += 1
            result.errors.append(f"{src}: {e}")
            print(f"  [FAIL] {src}: {e}", file=sys.stderr)

    print("")
    print(f"import summary: imported={result.imported}, skipped={result.skipped}, failed={result.failed}, dry_run={dry_run}")
    if result.failed > 0:
        return EXIT_FAIL
    return EXIT_OK


def cmd_export(args: argparse.Namespace) -> int:
    source = Path(args.source).resolve() if args.source else default_target()
    target = Path(args.target).resolve()
    prefix = normalize_prefix(args.prefix or "")

    if not source.exists():
        print(f"ERROR: source not found: {source}", file=sys.stderr)
        return EXIT_USAGE

    target.mkdir(parents=True, exist_ok=True)
    count = 0
    for src in iter_lessons(source):
        if prefix and not src.stem.startswith(prefix.rstrip("-_")):
            continue
        dst = target / src.name
        try:
            shutil.copy2(src, dst)
            count += 1
            print(f"  [EXPORT] {src.name}")
        except OSError as e:
            print(f"  [FAIL] {src}: {e}", file=sys.stderr)
            return EXIT_FAIL

    print(f"\nexport summary: exported={count}")
    return EXIT_OK if count > 0 else EXIT_OK


def cmd_merge(args: argparse.Namespace) -> int:
    source = Path(args.source).resolve()
    target = Path(args.target).resolve() if args.target else default_target()
    strategy = args.strategy
    if strategy not in VALID_STRATEGIES:
        print(f"ERROR: strategy must be one of {VALID_STRATEGIES}, got '{strategy}'", file=sys.stderr)
        return EXIT_USAGE

    if not source.exists():
        print(f"ERROR: source not found: {source}", file=sys.stderr)
        return EXIT_USAGE

    target.mkdir(parents=True, exist_ok=True)
    result = ImportResult()
    for src in iter_lessons(source):
        dst = target / src.name
        if dst.exists():
            if strategy == "skip":
                result.skipped += 1
                print(f"  [SKIP] {src.name} (exists)")
                continue
            if strategy == "newer":
                src_mtime = src.stat().st_mtime
                dst_mtime = dst.stat().st_mtime
                if dst_mtime >= src_mtime:
                    result.skipped += 1
                    print(f"  [SKIP] {src.name} (target newer)")
                    continue
        try:
            shutil.copy2(src, dst)
            result.imported += 1
            print(f"  [MERGE] {src.name} (strategy={strategy})")
        except OSError as e:
            result.failed += 1
            result.errors.append(f"{src}: {e}")
            print(f"  [FAIL] {src}: {e}", file=sys.stderr)

    print(f"\nmerge summary: merged={result.imported}, skipped={result.skipped}, failed={result.failed}, strategy={strategy}")
    return EXIT_OK if result.failed == 0 else EXIT_FAIL


def cmd_diff(args: argparse.Namespace) -> int:
    source = Path(args.source).resolve()
    target = Path(args.target).resolve() if args.target else default_target()

    if not source.exists():
        print(f"ERROR: source not found: {source}", file=sys.stderr)
        return EXIT_USAGE

    target.mkdir(parents=True, exist_ok=True)
    diff_count = 0
    same_count = 0
    source_only = 0
    target_only = 0
    source_files = {p.name: p for p in iter_lessons(source)}
    target_files = {p.name: p for p in iter_lessons(target)}

    all_names = sorted(set(source_files.keys()) | set(target_files.keys()))
    for name in all_names:
        src = source_files.get(name)
        dst = target_files.get(name)
        if src and not dst:
            source_only += 1
            print(f"  [SOURCE_ONLY] {name}")
        elif dst and not src:
            target_only += 1
            print(f"  [TARGET_ONLY] {name}")
        else:
            src_hash = file_hash(src)
            dst_hash = file_hash(dst)
            if src_hash == dst_hash:
                same_count += 1
            else:
                diff_count += 1
                print(f"  [DIFF] {name}")

    print(f"\ndiff summary: same={same_count}, diff={diff_count}, source_only={source_only}, target_only={target_only}")
    return EXIT_OK


def cmd_self_check(args: argparse.Namespace) -> int:
    pass_count = 0
    fail_count = 0

    def record(label: str, ok: bool) -> None:
        nonlocal pass_count, fail_count
        if ok:
            print(f"  [PASS] {label}")
            pass_count += 1
        else:
            print(f"  [FAIL] {label}")
            fail_count += 1

    print("==========================================")
    print("lessons-import.py self-check")
    print("==========================================")

    record(f"valid_strategies == {VALID_STRATEGIES}", VALID_STRATEGIES == ("skip", "newer", "always"))
    record("default_target exists or creatable", default_target().parent.exists())

    target = default_target()
    record("default_target is a directory", target.is_dir() if target.exists() else True)

    with __import__("tempfile").TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        src_dir = tmp_path / "src_lessons"
        src_dir.mkdir()
        (src_dir / "epic-999-test.md").write_text("# test lesson\n", encoding="utf-8")
        (src_dir / "epic-998-other.md").write_text("# other lesson\n", encoding="utf-8")

        dst_dir = tmp_path / "dst_lessons"
        dst_dir.mkdir()
        (dst_dir / "epic-998-other.md").write_text("# existing other\n", encoding="utf-8")

        # Test import with skip
        rc = cmd_import(argparse.Namespace(
            source=str(src_dir),
            target=str(dst_dir),
            prefix="imported",
            dry_run=True,
        ))
        record("import dry-run returns 0", rc == EXIT_OK)

        # Test merge with strategy=skip
        rc = cmd_merge(argparse.Namespace(
            source=str(src_dir),
            target=str(dst_dir),
            strategy="skip",
        ))
        record("merge skip returns 0", rc == EXIT_OK)
        record("merge skip preserved target-only file",
               (dst_dir / "epic-998-other.md").read_text(encoding="utf-8") == "# existing other\n")

        # Test merge with strategy=always
        rc = cmd_merge(argparse.Namespace(
            source=str(src_dir),
            target=str(dst_dir),
            strategy="always",
        ))
        record("merge always returns 0", rc == EXIT_OK)

        # Test diff
        rc = cmd_diff(argparse.Namespace(
            source=str(src_dir),
            target=str(dst_dir),
        ))
        record("diff returns 0", rc == EXIT_OK)

    print(f"\nResult: {pass_count} PASS, {fail_count} FAIL")
    return EXIT_OK if fail_count == 0 else EXIT_FAIL


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="lessons-import.py",
        description="Cross-project lessons migration (EPIC-038-C)",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_import = sub.add_parser("import", help="Import lessons from source")
    p_import.add_argument("source", help="source path (file/dir)")
    p_import.add_argument("--target", help="target dir (default: confluence/memory/lessons)")
    p_import.add_argument("--prefix", default="", help="prefix to add to filenames")
    p_import.add_argument("--dry-run", action="store_true", help="preview only")
    p_import.set_defaults(func=cmd_import)

    p_export = sub.add_parser("export", help="Export lessons to destination")
    p_export.add_argument("target", help="destination directory")
    p_export.add_argument("--source", help="source dir (default: confluence/memory/lessons)")
    p_export.add_argument("--prefix", default="", help="only export files starting with prefix")
    p_export.set_defaults(func=cmd_export)

    p_merge = sub.add_parser("merge", help="Merge lessons from source into target")
    p_merge.add_argument("source", help="source path (file/dir)")
    p_merge.add_argument("--target", help="target dir (default: confluence/memory/lessons)")
    p_merge.add_argument("--strategy", choices=VALID_STRATEGIES, default="skip",
                         help="merge strategy (default: skip)")
    p_merge.set_defaults(func=cmd_merge)

    p_diff = sub.add_parser("diff", help="Diff source vs target lessons")
    p_diff.add_argument("source", help="source path (file/dir)")
    p_diff.add_argument("--target", help="target dir (default: confluence/memory/lessons)")
    p_diff.set_defaults(func=cmd_diff)

    p_self = sub.add_parser("self-check", help="self-check")
    p_self.set_defaults(func=cmd_self_check)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args) or 0)


if __name__ == "__main__":
    sys.exit(main())
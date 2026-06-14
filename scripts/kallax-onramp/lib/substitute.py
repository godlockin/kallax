#!/usr/bin/env python3
"""KALLAX Onramp template substitute helper (B3 修复, security hardened).

跟 security review 建议 联合:
- argv + JSON file 传值 (不字符串插值)
- 净化 input (basename regex)
- str.replace (literal, no regex metachars)

Usage: python3 substitute.py <template_file> <substitutions.json>
"""
import json
import re
import sys
from pathlib import Path


def sanitize_key(key: str) -> str:
    """Allow only safe placeholder keys: [a-z0-9_]+"""
    if not re.match(r"^[a-z0-9_]+$", key):
        raise ValueError(f"Unsafe placeholder key: {key!r}")
    return key


def sanitize_value(value: str) -> str:
    """Strip control chars, limit length."""
    if not isinstance(value, str):
        value = str(value)
    # Strip control chars except whitespace
    value = re.sub(r"[\x00-\x08\x0b-\x0c\x0e-\x1f\x7f]", "", value)
    # Limit length
    if len(value) > 100_000:
        value = value[:100_000]
    return value


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: substitute.py <template_file> <substitutions.json>", file=sys.stderr)
        return 2

    template_path = Path(sys.argv[1])
    substitutions_path = Path(sys.argv[2])

    if not template_path.is_file():
        print(f"ERROR: template not found: {template_path}", file=sys.stderr)
        return 2

    if not substitutions_path.is_file():
        print(f"ERROR: substitutions not found: {substitutions_path}", file=sys.stderr)
        return 2

    # Read template (literal)
    content = template_path.read_text(encoding="utf-8")

    # Read substitutions (JSON)
    raw = substitutions_path.read_text(encoding="utf-8")
    try:
        substitutions = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON: {e}", file=sys.stderr)
        return 2

    if not isinstance(substitutions, dict):
        print("ERROR: substitutions must be a JSON object", file=sys.stderr)
        return 2

    # Apply substitutions (literal str.replace, no regex)
    for key, value in substitutions.items():
        safe_key = sanitize_key(key)
        safe_value = sanitize_value(value)
        placeholder = "{{" + safe_key + "}}"
        content = content.replace(placeholder, safe_value)

    # Write back atomically (跟 Rule 17 联合)
    out_path = template_path
    tmp_path = out_path.with_suffix(out_path.suffix + ".tmp")
    tmp_path.write_text(content, encoding="utf-8")
    tmp_path.replace(out_path)

    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
index-md-to-sqlite.py — Parse .kallax/experts/extended/INDEX.md → inject into SQLite
EPIC-034-D R1 实施: Binary 读 INDEX.md 同步 + 6 generated 真激活 (Rule 14 升级触发)

Source: Performer cross-EPIC root cause (EPIC-034-C R1): Rust binary 早用 SQLite
(libsqlite3-sys), 跟 INDEX.md (markdown YAML) 双轨脱节. 此脚本桥接.

Strategy:
  1. Parse INDEX.md (markdown YAML frontmatter per expert)
  2. Create experts table in SQLite if missing
  3. Insert/upsert each expert (id, name_cn, role, emoji, tier, domain, trigger)
  4. Report count

Conductor corrective integration under 主公 explicit 授权
(Rule 11 v2.1 + Rule 1 boundary event 2026-06-12)
"""
import os
import re
import sqlite3
import sys
from pathlib import Path

KALLAX_ROOT = Path(os.environ.get("KALLAX_ROOT", ".kallax"))
INDEX_MD = KALLAX_ROOT / "experts" / "extended" / "INDEX.md"
# KALLAX_DB_PATH: 测试用 env var 覆盖默认 DB 路径
_env_db = os.environ.get("KALLAX_DB_PATH")
if _env_db:
    DB_PATH = Path(_env_db)
else:
    DB_PATH = (KALLAX_ROOT / "node" / ".kallax" / "data" / "kallax.db").resolve()


def parse_index_md(path: Path):
    """Parse INDEX.md into list of expert dicts.

    INDEX.md 格式 (per expert, delimited by ---):
      ---
      id: eket.extended.001
      name_cn: 法务顾问
      role: 首席法律顾问
      emoji: ⚖️
      tier: extended
      domain: consulting
      trigger: 法务顾问|合同审查|...
    """
    if not path.exists():
        print(f"ERROR: {path} not found", file=sys.stderr)
        return []

    text = path.read_text(encoding="utf-8")
    # Split on --- boundaries
    blocks = re.split(r"^---\s*$", text, flags=re.MULTILINE)

    experts = []
    for block in blocks:
        if not block.strip():
            continue
        expert = {}
        for line in block.strip().split("\n"):
            m = re.match(r"^(\w+):\s*(.*)$", line.strip())
            if m:
                key, val = m.group(1), m.group(2).strip()
                expert[key] = val
        if "id" in expert:
            experts.append(expert)
    return experts


def ensure_experts_table(conn: sqlite3.Connection):
    conn.execute("""
        CREATE TABLE IF NOT EXISTS experts (
            id TEXT PRIMARY KEY,
            name_cn TEXT,
            role TEXT,
            emoji TEXT,
            tier TEXT,
            domain TEXT,
            trigger TEXT,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()


def upsert_experts(conn: sqlite3.Connection, experts: list):
    inserted = 0
    updated = 0
    for e in experts:
        existing = conn.execute(
            "SELECT id FROM experts WHERE id = ?", (e.get("id"),)
        ).fetchone()
        if existing:
            updated += 1
        else:
            inserted += 1
        conn.execute(
            """INSERT OR REPLACE INTO experts (id, name_cn, role, emoji, tier, domain, trigger, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)""",
            (
                e.get("id"),
                e.get("name_cn", ""),
                e.get("role", ""),
                e.get("emoji", ""),
                e.get("tier", ""),
                e.get("domain", ""),
                e.get("trigger", ""),
            ),
        )
    conn.commit()
    return inserted, updated


def main():
    print(f"=== INDEX.md → SQLite export (EPIC-034-D) ===")
    print(f"INDEX: {INDEX_MD}")
    print(f"DB:    {DB_PATH}")

    if not INDEX_MD.exists():
        print(f"ERROR: INDEX.md not found at {INDEX_MD}", file=sys.stderr)
        return 2

    if not DB_PATH.parent.exists():
        print(f"ERROR: DB parent dir not found: {DB_PATH.parent}", file=sys.stderr)
        return 2

    experts = parse_index_md(INDEX_MD)
    print(f"Parsed {len(experts)} experts from INDEX.md")

    conn = sqlite3.connect(str(DB_PATH))
    try:
        ensure_experts_table(conn)
        inserted, updated = upsert_experts(conn, experts)
        total = conn.execute("SELECT COUNT(*) FROM experts").fetchone()[0]
        print(f"Inserted: {inserted}, Updated: {updated}, Total in DB: {total}")

        # 验证 6 generated 真存在
        generated_count = conn.execute(
            "SELECT COUNT(*) FROM experts WHERE id LIKE 'kallax.generated.%'"
        ).fetchone()[0]
        print(f"kallax.generated.* in DB: {generated_count}")

        if generated_count < 6:
            print(f"ERROR: expected >= 6 generated experts, got {generated_count}", file=sys.stderr)
            return 1
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())

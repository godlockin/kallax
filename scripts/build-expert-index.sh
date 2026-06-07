#!/bin/bash
# build-expert-index.sh — Build SQLite FTS5 + vec index from expert markdown files
# Usage: scripts/build-expert-index.sh [--rebuild]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$REPO_ROOT/.kallax/data"
DB_PATH="$DATA_DIR/expert_index.db"

REBUILD=false
if [[ "${1:-}" == "--rebuild" ]]; then
  REBUILD=true
fi

mkdir -p "$DATA_DIR"

# Check dependencies
if ! command -v sqlite3 &> /dev/null; then
  echo "ERROR: sqlite3 not found" >&2
  exit 1
fi

# Initialize database
if [[ "$REBUILD" == true ]] && [[ -f "$DB_PATH" ]]; then
  rm -f "$DB_PATH"
fi

# Create tables
sqlite3 "$DB_PATH" <<'EOF'
CREATE TABLE IF NOT EXISTS expert (
  id TEXT PRIMARY KEY,
  name_cn TEXT NOT NULL,
  role TEXT NOT NULL,
  emoji TEXT NOT NULL DEFAULT '',
  domain TEXT NOT NULL DEFAULT 'other',
  tier TEXT NOT NULL DEFAULT 'default',
  description TEXT,
  trigger TEXT,
  file_path TEXT NOT NULL
);

CREATE VIRTUAL TABLE IF NOT EXISTS expert_fts USING fts5(
  id,
  description,
  trigger,
  content='expert',
  tokenize='unicode61'
);

CREATE TABLE IF NOT EXISTS expert_vec (
  id TEXT PRIMARY KEY,
  embedding BLOB,
  FOREIGN KEY (id) REFERENCES expert(id)
);

CREATE INDEX IF NOT EXISTS idx_expert_domain ON expert(domain);
CREATE INDEX IF NOT EXISTS idx_expert_tier ON expert(tier);
CREATE INDEX IF NOT EXISTS idx_expert_trigger ON expert(trigger);
EOF

# Parse expert markdown files
parse_expert_file() {
  local file="$1"
  local tier="${2:-default}"

  # Extract frontmatter fields using grep
  local id name_cn name role emoji domain description trigger

  id=$(grep -m1 '^id:' "$file" | sed 's/^id: *//' | tr -d '\r')
  name_cn=$(grep -m1 '^name_cn:' "$file" | sed 's/^name_cn: *//' | tr -d '\r')
  name=$(grep -m1 '^name:' "$file" | sed 's/^name: *//' | tr -d '\r')
  role=$(grep -m1 '^role:' "$file" | sed 's/^role: *//' | tr -d '\r')
  emoji=$(grep -m1 '^emoji:' "$file" | sed 's/^emoji: *//' | tr -d '\r')
  domain=$(grep -m1 '^domain:' "$file" | sed 's/^domain: *//' | tr -d '\r')
  description=$(grep -m1 '^description:' "$file" | sed 's/^description: *//' | tr -d '\r')
  trigger=$(grep -m1 '^trigger:' "$file" | sed 's/^trigger: *//' | tr -d '\r')

  # Fallback: use name if name_cn is empty
  if [[ -z "$name_cn" ]] && [[ -n "$name" ]]; then
    name_cn="$name"
  fi

  # Default values for missing fields
  emoji="${emoji:-}"
  domain="${domain:-other}"
  description="${description:-}"
  trigger="${trigger:-}"

  if [[ -z "$id" ]]; then
    return 1
  fi

  echo "INSERT OR REPLACE INTO expert (id, name_cn, role, emoji, domain, tier, description, trigger, file_path) VALUES ("
  echo "  '$id', '$name_cn', '$role', '$emoji', '$domain', '$tier', '$description', '$trigger', '$file'"
  echo ");"
}

# Index default experts
DEFAULT_DIR="$REPO_ROOT/.kallax/experts/default"
if [[ -d "$DEFAULT_DIR" ]]; then
  for md_file in "$DEFAULT_DIR"/*.md; do
    if [[ -f "$md_file" ]]; then
      sql=$(parse_expert_file "$md_file" "default")
      if [[ -n "$sql" ]]; then
        sqlite3 "$DB_PATH" "$sql"
      fi
    fi
  done
fi

# Index extended experts (both individual files and consolidated INDEX.md)
EXTENDED_DIR="$REPO_ROOT/.kallax/experts/extended"
if [[ -d "$EXTENDED_DIR" ]]; then
  # First process individual .md files (skip INDEX.md)
  for md_file in "$EXTENDED_DIR"/*.md; do
    if [[ -f "$md_file" ]] && [[ "$md_file" != "$EXTENDED_DIR/INDEX.md" ]]; then
      sql=$(parse_expert_file "$md_file" "extended")
      if [[ -n "$sql" ]]; then
        sqlite3 "$DB_PATH" "$sql"
      fi
    fi
  done

  # Then process consolidated INDEX.md using Python
  INDEX_FILE="$EXTENDED_DIR/INDEX.md"
  if [[ -f "$INDEX_FILE" ]] && command -v python3 &> /dev/null; then
    # Write Python script to temp file first
    PYTHON_SCRIPT=$(mktemp)
    cat > "$PYTHON_SCRIPT" <<'PYEOF'
import re
import sys

index_file = sys.argv[1]
with open(index_file, 'r') as f:
    content = f.read()

blocks = re.split(r'(?:^|\n)---\n', content)

for block in blocks:
    if len(block) < 10:
        continue

    id_match = re.search(r'^id:\s*(.+?)\s*$', block, re.MULTILINE)
    name_cn_match = re.search(r'^name_cn:\s*(.+?)\s*$', block, re.MULTILINE)
    role_match = re.search(r'^role:\s*(.+?)\s*$', block, re.MULTILINE)
    emoji_match = re.search(r'^emoji:\s*(.+?)\s*$', block, re.MULTILINE)
    domain_match = re.search(r'^domain:\s*(.+?)\s*$', block, re.MULTILINE)
    desc_match = re.search(r'^description:\s*(.+?)\s*$', block, re.MULTILINE)
    trigger_match = re.search(r'^trigger:\s*(.+?)\s*$', block, re.MULTILINE)

    id = id_match.group(1).strip() if id_match else ''
    if not id:
        continue

    name_cn = name_cn_match.group(1).strip() if name_cn_match else ''
    role = role_match.group(1).strip() if role_match else ''
    emoji = emoji_match.group(1).strip() if emoji_match else ''
    domain = domain_match.group(1).strip() if domain_match else ''
    description = desc_match.group(1).strip() if desc_match else ''
    trigger = trigger_match.group(1).strip() if trigger_match else ''

    name_cn = name_cn.replace("'", "''")
    role = role.replace("'", "''")
    description = description.replace("'", "''")
    trigger = trigger.replace("'", "''")

    print(f"INSERT OR REPLACE INTO expert (id, name_cn, role, emoji, domain, tier, description, trigger, file_path) VALUES ('{id}', '{name_cn}', '{role}', '{emoji}', '{domain}', 'extended', '{description}', '{trigger}', '{index_file}');")
PYEOF

    python3 "$PYTHON_SCRIPT" "$INDEX_FILE" > /tmp/extended_experts.sql
    rm -f "$PYTHON_SCRIPT"

    if [[ -f /tmp/extended_experts.sql ]] && [[ -s /tmp/extended_experts.sql ]]; then
      sqlite3 "$DB_PATH" < /tmp/extended_experts.sql
      rm -f /tmp/extended_experts.sql
    fi
  fi
fi

# Rebuild FTS index - drop and recreate to avoid corruption
sqlite3 "$DB_PATH" <<'EOF'
DROP TABLE IF EXISTS expert_fts;
CREATE VIRTUAL TABLE expert_fts USING fts5(
  id,
  description,
  trigger,
  content='expert',
  tokenize='unicode61'
);
INSERT INTO expert_fts(id, description, trigger)
SELECT id, description, trigger FROM expert WHERE description IS NOT NULL OR trigger IS NOT NULL;
EOF

# Get stats
DEFAULT_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM expert WHERE tier='default';")
EXTENDED_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM expert WHERE tier='extended';")
TOTAL_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM expert;")

echo "Expert index built successfully:"
echo "  - Default experts: $DEFAULT_COUNT"
echo "  - Extended experts: $EXTENDED_COUNT"
echo "  - Total: $TOTAL_COUNT"
echo "  - Database: $DB_PATH"
echo "  - FTS5 table: expert_fts"
echo "  - Vector table: expert_vec (empty, populated by semantic-embed.py)"
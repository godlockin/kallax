#!/usr/bin/env bash
# KALLAX SQLite Backup — automated DB backup with rotation
set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
DB_PATH="${PROJECT_ROOT}/.kallax/data/kallax.db"
BACKUP_DIR="${PROJECT_ROOT}/.kallax/backups"
RETENTION_DAYS="${2:-30}"

echo "=== KALLAX SQLite Backup ==="

# Check DB exists
if [ ! -f "$DB_PATH" ]; then
  echo "No database found at $DB_PATH"
  exit 0
fi

# Create backup dir
mkdir -p "$BACKUP_DIR"

# Generate backup filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/kallax_${TIMESTAMP}.db"

# Perform backup using sqlite3 .backup command
if command -v sqlite3 &>/dev/null; then
  sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE'"
  echo "Backup created: $BACKUP_FILE"
else
  # Fallback: checkpoint WAL first, then copy
  if command -v node &>/dev/null && [ -f "$PROJECT_ROOT/node_modules/better-sqlite3/build/Release/better_sqlite3.node" ]; then
    npx tsx -e "
      import Database from 'better-sqlite3';
      const db = new Database('$DB_PATH');
      db.pragma('wal_checkpoint(TRUNCATE)');
      db.close();
    " 2>/dev/null || true
  fi

  # Also try sqlite3 CLI for checkpoint (if available but .backup isn't)
  if command -v sqlite3 &>/dev/null; then
    sqlite3 "$DB_PATH" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
  fi

  cp "$DB_PATH" "$BACKUP_FILE"
  echo "Backup created (copy): $BACKUP_FILE"

  # Warn if WAL files exist (indicating uncheckpointed data)
  if [ -f "${DB_PATH}-wal" ]; then
    echo "WARNING: WAL file ${DB_PATH}-wal still exists after checkpoint." >&2
    echo "Backup may be stale. Install sqlite3 CLI for reliable backups." >&2
  fi
fi

# Compress
gzip -f "$BACKUP_FILE"
echo "Compressed: ${BACKUP_FILE}.gz"

# Show size
BACKUP_SIZE=$(du -h "${BACKUP_FILE}.gz" 2>/dev/null | cut -f1)
echo "Size: ${BACKUP_SIZE}"

# Rotate old backups
OLD_COUNT=$(find "$BACKUP_DIR" -name "*.gz" -mtime "+${RETENTION_DAYS}" 2>/dev/null | wc -l | tr -d ' ')
if [ "$OLD_COUNT" -gt 0 ]; then
  echo "Removing ${OLD_COUNT} backup(s) older than ${RETENTION_DAYS} days..."
  find "$BACKUP_DIR" -name "*.gz" -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null
fi

# List current backups
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "*.gz" 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "Total backups: ${BACKUP_COUNT}"
echo "Backup dir: ${BACKUP_DIR}"

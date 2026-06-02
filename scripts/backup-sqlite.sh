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
  # Fallback: copy with WAL checkpoint
  cp "$DB_PATH" "$BACKUP_FILE"
  echo "Backup created (copy): $BACKUP_FILE"
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

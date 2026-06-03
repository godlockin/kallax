#!/usr/bin/env bash
# KALLAX Log Rotation — compress and archive old logs
# Compresses .kallax/logs/ files older than 7 days
# Usage: ./scripts/log-rotate.sh [--dry-run] [--age 7]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/.kallax/logs"
DRY_RUN=false
AGE_DAYS=7

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --age=*) AGE_DAYS="${arg#*=}" ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
pass()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo "=== KALLAX Log Rotation ==="
echo "  Log dir: ${LOG_DIR}"
echo "  Age threshold: ${AGE_DAYS} days"
echo "  Dry run: ${DRY_RUN}"
echo ""

[ -d "$LOG_DIR" ] || { info "Log directory does not exist — creating"; mkdir -p "$LOG_DIR"; }

# Find uncompressed log files older than AGE_DAYS
OLD_LOGS=$(find "$LOG_DIR" -type f \( -name '*.log' -o -name '*.txt' -o -name '*.out' \) -mtime +"${AGE_DAYS}" 2>/dev/null || true)
COMPRESSED_COUNT=0
SKIPPED_COUNT=0
FREED_BYTES=0

if [ -z "$OLD_LOGS" ]; then
  info "No uncompressed log files older than ${AGE_DAYS} days found."
else
  echo "$OLD_LOGS" | while read -r f; do
    ORIG_SIZE=$(stat -f%z "$f" 2>/dev/null || echo 0)
    if [ "$DRY_RUN" = true ]; then
      info "[DRY RUN] Would compress: ${f} ($(numfmt --to=iec "${ORIG_SIZE}" 2>/dev/null || echo "${ORIG_SIZE}B"))"
    else
      gzip "$f"
      pass "Compressed: ${f}.gz ($(numfmt --to=iec "${ORIG_SIZE}" 2>/dev/null || echo "${ORIG_SIZE}B") -> saved)"
      COMPRESSED_COUNT=$((COMPRESSED_COUNT + 1))
      FREED_BYTES=$((FREED_BYTES + ORIG_SIZE))
    fi
  done
fi

# Remove gz files older than 30 days (archived long enough)
OLD_GZ=$(find "$LOG_DIR" -type f -name '*.gz' -mtime +30 2>/dev/null || true)
if [ -n "$OLD_GZ" ]; then
  echo "$OLD_GZ" | while read -r f; do
    if [ "$DRY_RUN" = true ]; then
      info "[DRY RUN] Would delete old archive: ${f}"
    else
      rm -f "$f"
      warn "Deleted old archive: ${f}"
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
  done
fi

echo ""
info "Compressed: ${COMPRESSED_COUNT} file(s)"
info "Deleted (old archives): ${SKIPPED_COUNT} file(s)"
[ "$FREED_BYTES" -gt 0 ] && info "Space freed: $(numfmt --to=iec "${FREED_BYTES}" 2>/dev/null || echo "${FREED_BYTES}B")"
echo ""
pass "Log rotation ${DRY_RUN:+dry-run }complete"

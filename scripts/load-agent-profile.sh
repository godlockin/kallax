#!/usr/bin/env bash
# KALLAX Load Agent Profile — load and display agent configuration
set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")}"
KALLAX_DIR="${PROJECT_ROOT}/.kallax"

echo "=== KALLAX Agent Profile ==="
echo ""

# 1. Instance config
INSTANCE_CFG="${KALLAX_DIR}/state/instance_config.yml"
if [ -f "$INSTANCE_CFG" ]; then
  echo "--- Instance Config ---"
  cat "$INSTANCE_CFG"
  echo ""
else
  echo "WARN: No instance config at $INSTANCE_CFG"
fi

# 2. Role detection
ROLE="unknown"
if [ -f "$INSTANCE_CFG" ]; then
  ROLE=$(grep -E "^role:" "$INSTANCE_CFG" 2>/dev/null | awk '{print $2}' | tr -d ' "' || echo "unknown")
fi
echo "Role: $ROLE"

# 3. Load profile by role
if [ "$ROLE" = "conductor" ]; then
  PROFILE_FILE="${KALLAX_DIR}/config/process.yml"
elif [ "$ROLE" = "performer" ]; then
  PROFILE_FILE="${KALLAX_DIR}/config/tasks.yml"
else
  PROFILE_FILE="${KALLAX_DIR}/config.yml"
fi

if [ -f "$PROFILE_FILE" ]; then
  echo ""
  echo "--- Profile Config (${PROFILE_FILE}) ---"
  head -60 "$PROFILE_FILE"
fi

# 4. Active instances from database
DB_PATH="${KALLAX_DIR}/data/kallax.db"
if [ -f "$DB_PATH" ] && command -v sqlite3 &>/dev/null; then
  echo ""
  echo "--- Active Instances ---"
  sqlite3 -header -column "$DB_PATH" <<-SQL
    SELECT id, role, status, capabilities,
           ROUND((? - last_heartbeat) / 60000.0, 0) AS idle_min
    FROM instances WHERE status IN ('active', 'busy', 'idle')
    ORDER BY last_heartbeat DESC;
SQL
fi

# 5. Load environment variables
ENV_FILE="${PROJECT_ROOT}/.env"
if [ -f "$ENV_FILE" ]; then
  echo ""
  echo "--- Environment Variables (from .env) ---"
  grep -v '^#' "$ENV_FILE" | grep -v '^\s*$' || echo "(none)"
fi

echo ""
echo "Profile loaded. Role: $ROLE"

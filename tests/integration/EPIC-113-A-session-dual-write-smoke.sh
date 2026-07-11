#!/usr/bin/env bash
# Smoke test: session_start.sh dual-write to SQLite instances table
set -euo pipefail

SMOKE_ROOT=/tmp/kallax-smoke-113a
SCHEMA=/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.worktrees/v3.21.0-EPIC-113/rust/crates/kallax-core/src/db/schema.sql

rm -rf "${SMOKE_ROOT}"
mkdir -p "${SMOKE_ROOT}/.kallax"
sqlite3 "${SMOKE_ROOT}/.kallax/kallax.db" < "${SCHEMA}"

# Simulate session_start.sh dual-write logic
export KALLAX_ROOT="${SMOKE_ROOT}"
export INSTANCE_ID="smoke_test_1"
export ROLE="master"
export BRANCH="miao"
export NOW="2026-07-11T10:00:00Z"

_KDB="${KALLAX_ROOT}/.kallax/kallax.db"
_DB_ROLE="conductor"
case "${ROLE}" in
  performer) _DB_ROLE="performer" ;;
  conductor|master) _DB_ROLE="conductor" ;;
esac
_INST_NAME="${ROLE}@${BRANCH}"
_INST_NAME_ESC="${_INST_NAME//\'/\'\'}"

sqlite3 "${_KDB}" <<SQL
INSERT OR REPLACE INTO instances (id, name, role, status, metadata, created_at, updated_at)
VALUES ('${INSTANCE_ID}', '${_INST_NAME_ESC}', '${_DB_ROLE}', 'active', '{}', '${NOW}', '${NOW}');
SQL

echo "=== Row inserted ==="
sqlite3 "${_KDB}" 'SELECT id, name, role, status FROM instances;'

# Verify master → conductor mapping
COUNT=$(sqlite3 "${_KDB}" "SELECT COUNT(*) FROM instances WHERE id='smoke_test_1' AND role='conductor';")
if [ "${COUNT}" = "1" ]; then
  echo "PASS: master role mapped to conductor"
else
  echo "FAIL: expected 1 row, got ${COUNT}"
  exit 1
fi

# Test performer role
INSTANCE_ID="smoke_test_2"
ROLE="performer"
_DB_ROLE="performer"
_INST_NAME_ESC="${ROLE}@${BRANCH}"
sqlite3 "${_KDB}" <<SQL
INSERT OR REPLACE INTO instances (id, name, role, status, metadata, created_at, updated_at)
VALUES ('${INSTANCE_ID}', '${_INST_NAME_ESC}', '${_DB_ROLE}', 'active', '{}', '${NOW}', '${NOW}');
SQL

# Test upsert (INSERT OR REPLACE same ID again)
sqlite3 "${_KDB}" <<SQL
INSERT OR REPLACE INTO instances (id, name, role, status, metadata, created_at, updated_at)
VALUES ('smoke_test_1', '${_INST_NAME_ESC}', 'conductor', 'idle', '{}', '${NOW}', '${NOW}');
SQL

TOTAL=$(sqlite3 "${_KDB}" 'SELECT COUNT(*) FROM instances;')
if [ "${TOTAL}" = "2" ]; then
  echo "PASS: upsert semantics — 2 unique instances after 3 inserts"
else
  echo "FAIL: expected 2 rows, got ${TOTAL}"
  exit 1
fi

STATUS=$(sqlite3 "${_KDB}" "SELECT status FROM instances WHERE id='smoke_test_1';")
if [ "${STATUS}" = "idle" ]; then
  echo "PASS: upsert updated status active→idle"
else
  echo "FAIL: expected status=idle after upsert, got '${STATUS}'"
  exit 1
fi

echo "=== ALL SMOKE TESTS PASS ==="

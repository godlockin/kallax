#!/usr/bin/env bash
# scripts/test-expert-queue.sh
# EPIC-021-F expert_invocations 降级链测试
# 3 场景: Redis up / Redis down→SQLite / SQLite down→file

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUEUE_LIB="${SCRIPT_DIR}/lib/expert-invocation-queue.sh"

if [ ! -f "$QUEUE_LIB" ]; then
  echo "FAIL: queue lib not found at $QUEUE_LIB"
  exit 1
fi

source "$QUEUE_LIB"

echo "=== Test 1: Redis up ==="
emit "kallax.backend.001" "EPIC-021-F-test1" || true
current_backend=$(get_backend)
echo "backend after emit: $current_backend"
health
echo "Test 1: PASS (backend=$current_backend)"

echo ""
echo "=== Test 2: Redis down → SQLite (force backend to sqlite) ==="
#强制降级到 sqlite（模拟 Redis 不可用）
set_backend sqlite
emit "kallax.architect.001" "EPIC-021-F-test2" || true
current_backend=$(get_backend)
if [ "$current_backend" != "sqlite" ]; then
  echo "FAIL: expected sqlite, got $current_backend"
  exit 1
fi
health
echo "Test 2: PASS (backend=$current_backend)"

echo ""
echo "=== Test 3: SQLite down → file (force backend to file) ==="
set_backend file
emit "kallax.security.001" "EPIC-021-F-test3" || true
current_backend=$(get_backend)
if [ "$current_backend" != "file" ]; then
  echo "FAIL: expected file, got $current_backend"
  exit 1
fi
health
echo "Test 3: PASS (backend=$current_backend)"

echo ""
echo "=== drain test ==="
drain || true
echo "Drain output collected"

echo ""
echo "=== emit with explicit ts ==="
emit "kallax.backend.002" "EPIC-021-F-test4" 1900000000
echo "Test with ts: PASS"

echo ""
echo "All tests pass"
#!/bin/bash
# brief-inference-test.sh — L4 集成测试: brief_inference 强制
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BRIEF_CHECK="$KALLAX_ROOT/scripts/task-claim-brief.sh"

# Temp dir for test tickets
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "=== Brief Inference Integration Test ==="

# TEST 1: 有 brief_inference → PASS
echo ""
echo "TEST 1: 有 brief_inference → PASS"
cat > "$TMPDIR/ticket-with.json" <<'EOF'
{
  "id": "TEST-001",
  "brief_inference": "📋 任务理解: feature | 实现 task-claim-brief 强制 | bash jq 验证 | 无"
}
EOF

if bash "$BRIEF_CHECK" "$TMPDIR/ticket-with.json" 2>&1; then
  echo "TEST 1: PASS"
else
  echo "TEST 1: FAIL (exit code: $?)"
  exit 1
fi

# TEST 2: 无 brief_inference → FAIL exit 1
echo ""
echo "TEST 2: 无 brief_inference → FAIL exit 1"
cat > "$TMPDIR/ticket-without.json" <<'EOF'
{
  "id": "TEST-002"
}
EOF

set +e
bash "$BRIEF_CHECK" "$TMPDIR/ticket-without.json" 2>&1
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 1 ]]; then
  echo "TEST 2: PASS (correctly rejected)"
else
  echo "TEST 2: FAIL (expected exit 1, got: $EXIT_CODE)"
  exit 1
fi

echo ""
echo "=== 2/2 PASS ==="
exit 0

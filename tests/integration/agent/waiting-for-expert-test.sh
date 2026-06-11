#!/bin/bash
# waiting-for-expert-test.sh — 5 测试覆盖
# L4: 匹配失败触发 + 写 JSON + 写 inbox + 重试优先 + remove
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPT="${PROJECT_ROOT}/scripts/agent/waiting-for-expert.sh"

# 动态测试目录（每次运行不同）
TEST_DIR="${PROJECT_ROOT}/.kallax/test-waiting-for-expert-$$"

# 清理函数
cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# setup — 初始化测试环境
setup() {
  mkdir -p "$TEST_DIR/.kallax/state" "$TEST_DIR/.kallax/inbox"
  export KALLAX_ROOT="$TEST_DIR"
}

# teardown — 清理测试环境
teardown() {
  rm -rf "$TEST_DIR"
}

# TESTS

test_append_writes_json() {
  echo "=== TEST: append_writes_json ==="
  setup

  bash "$SCRIPT" append "TICKET-001" "backend" || { echo "FAIL: append exit non-zero"; teardown; return 1; }

  local json="${TEST_DIR}/.kallax/state/waiting-for-expert.json"
  if [[ ! -f "$json" ]]; then
    echo "FAIL: waiting-for-expert.json not created"
    teardown; return 1
  fi

  local tid
  tid=$(jq -r 'keys[0]' "$json" 2>/dev/null)
  if [[ "$tid" != "TICKET-001" ]]; then
    echo "FAIL: expected TICKET-001, got '$tid'"
    teardown; return 1
  fi

  local retries
  retries=$(jq -r '."TICKET-001".retries' "$json" 2>/dev/null)
  if [[ "$retries" != "1" ]]; then
    echo "FAIL: expected retries=1, got '$retries'"
    teardown; return 1
  fi

  echo "PASS: append_writes_json"
  teardown; return 0
}

test_retries_increment() {
  echo "=== TEST: retries_increment ==="
  setup

  bash "$SCRIPT" append "TICKET-002" "frontend"
  bash "$SCRIPT" append "TICKET-002" "frontend"
  bash "$SCRIPT" append "TICKET-002" "frontend"

  local json="${TEST_DIR}/.kallax/state/waiting-for-expert.json"
  local retries
  retries=$(jq -r '."TICKET-002".retries' "$json" 2>/dev/null)
  if [[ "$retries" != "3" ]]; then
    echo "FAIL: expected retries=3, got '$retries'"
    teardown; return 1
  fi

  echo "PASS: retries_increment"
  teardown; return 0
}

test_inbox_file_created() {
  echo "=== TEST: inbox_file_created ==="
  setup

  bash "$SCRIPT" append "TICKET-003" "security"

  local inbox="${TEST_DIR}/.kallax/inbox/need-expert-TICKET-003.md"
  if [[ ! -f "$inbox" ]]; then
    echo "FAIL: inbox file not created at $inbox"
    teardown; return 1
  fi

  if ! grep -q "TICKET: TICKET-003" "$inbox"; then
    echo "FAIL: inbox missing ticket id"
    teardown; return 1
  fi

  if ! grep -q "Required Expertise: security" "$inbox"; then
    echo "FAIL: inbox missing required expertise"
    teardown; return 1
  fi

  echo "PASS: inbox_file_created"
  teardown; return 0
}

test_priority_ordering() {
  echo "=== TEST: priority_ordering ==="
  setup

  bash "$SCRIPT" append "TICKET-LOW" "pm"
  bash "$SCRIPT" append "TICKET-MID" "pm"
  bash "$SCRIPT" append "TICKET-MID" "pm"
  bash "$SCRIPT" append "TICKET-HIGH" "pm"
  bash "$SCRIPT" append "TICKET-HIGH" "pm"
  bash "$SCRIPT" append "TICKET-HIGH" "pm"

  local output
  output=$(bash "$SCRIPT" list)

  local first
  first=$(echo "$output" | head -1)
  if [[ "$first" != "TICKET-HIGH" ]]; then
    echo "FAIL: expected TICKET-HIGH first (most retries), got '$first'"
    teardown; return 1
  fi

  echo "PASS: priority_ordering"
  teardown; return 0
}

test_remove_from_waiting() {
  echo "=== TEST: remove_from_waiting ==="
  setup

  bash "$SCRIPT" append "TICKET-REMOVE" "backend"
  bash "$SCRIPT" append "TICKET-KEEP" "frontend"

  bash "$SCRIPT" remove "TICKET-REMOVE"

  local json="${TEST_DIR}/.kallax/state/waiting-for-expert.json"
  if jq -e '."TICKET-REMOVE"' "$json" >/dev/null 2>&1; then
    echo "FAIL: TICKET-REMOVE should be deleted"
    teardown; return 1
  fi

  if ! jq -e '."TICKET-KEEP"' "$json" >/dev/null 2>&1; then
    echo "FAIL: TICKET-KEEP should still exist"
    teardown; return 1
  fi

  echo "PASS: remove_from_waiting"
  teardown; return 0
}

# RUN ALL TESTS
echo "Running waiting-for-expert tests..."
echo ""

failed=0

test_append_writes_json || failed=$((failed + 1))
test_retries_increment || failed=$((failed + 1))
test_inbox_file_created || failed=$((failed + 1))
test_priority_ordering || failed=$((failed + 1))
test_remove_from_waiting || failed=$((failed + 1))

echo ""
echo "=== Summary: $((5 - failed))/5 PASS ==="
exit $failed
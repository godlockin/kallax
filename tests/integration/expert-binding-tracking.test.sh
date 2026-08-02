#!/usr/bin/env bash
# tests/integration/expert-binding-tracking.test.sh — EPIC-157 binding tracker tests
#
# 6 cases (per AC7):
#   1. suggest 写入 suggested_expert
#   2. actual 一致 → validate OK
#   3. actual 偏离无 reason → 拒绝 (exit 1)
#   4. actual 偏离有 reason → validate OK
#   5. legacy ticket (无 expert_binding) → validate 跳过 exit 0
#   6. validate-all 跑过所有 ticket 不破
#
# 依赖: bash 4+, jq
# 退出: 0 = all PASS, 1 = FAIL

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINDING="${KALLAX_ROOT}/scripts/binding/binding-tracker.sh"
TEST_TICKETS_DIR="${KALLAX_ROOT}/tests/integration/fixtures/binding-tracking"
TICKET_EPIC="EPIC-9999"  # 用 ephemeral id 避免污染真实 jira/tickets
TICKET_FILE="${TEST_TICKETS_DIR}/${TICKET_EPIC}/ticket.json"
LEGACY_EPIC="EPIC-9998"
LEGACY_FILE="${TEST_TICKETS_DIR}/${LEGACY_EPIC}/ticket.json"

PASS=0
FAIL=0

assert_eq() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name (got '$actual')"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

setup_test_ticket() {
  mkdir -p "$(dirname "$TICKET_FILE")"
  cat > "$TICKET_FILE" <<'EOF'
{
  "ticket_id": "EPIC-9999",
  "epic": "EPIC-9999",
  "title": "test ticket for binding tracker",
  "status": "in_progress",
  "priority": "P2",
  "type": "feature",
  "created_at": "2026-08-02",
  "description": "ephemeral test fixture"
}
EOF
  mkdir -p "$(dirname "$LEGACY_FILE")"
  cat > "$LEGACY_FILE" <<'EOF'
{
  "ticket_id": "EPIC-9998",
  "epic": "EPIC-9998",
  "title": "legacy ticket without expert_binding",
  "status": "done",
  "priority": "P3",
  "type": "chore",
  "created_at": "2026-01-01",
  "description": "legacy — should be skipped"
}
EOF
}

cleanup() {
  rm -rf "$TEST_TICKETS_DIR"
}

# 临时把 TEST_TICKETS_DIR 注入 binding-tracker.sh 通过环境变量
export KALLAX_BINDING_TICKETS_DIR="$TEST_TICKETS_DIR"

# Case 1: suggest 写入
echo "Case 1: suggest writes suggested_expert"
setup_test_ticket
KALLAX_TICKETS_DIR="$TEST_TICKETS_DIR" \
  KALLAX_BINDING_TICKETS_DIR="$TEST_TICKETS_DIR" \
  bash -c "
    bash '$BINDING' suggest $TICKET_EPIC --expert backend
  " > /tmp/binding-c1.log 2>&1
GOT_SUGGESTED="$(jq -r '.expert_binding.suggested_expert // empty' "$TICKET_FILE")"
assert_eq "suggest writes backend" "backend" "$GOT_SUGGESTED"

# Case 2: actual 一致 → validate OK
echo ""
echo "Case 2: actual same as suggested → validate OK"
KALLAX_TICKETS_DIR="$TEST_TICKETS_DIR" \
  bash "$BINDING" actual $TICKET_EPIC --expert backend > /tmp/binding-c2.log 2>&1
EXIT_C2=$?
assert_eq "actual same exit code" "0" "$EXIT_C2"
KALLAX_TICKETS_DIR="$TEST_TICKETS_DIR" \
  bash "$BINDING" validate $TICKET_EPIC > /tmp/binding-c2v.log 2>&1
EXIT_C2V=$?
assert_eq "validate same exit code" "0" "$EXIT_C2V"

# Case 3: actual 偏离无 reason → 拒绝
echo ""
echo "Case 3: actual divergent without reason → reject"
KALLAX_TICKETS_DIR="$TEST_TICKETS_DIR" \
  bash "$BINDING" actual $TICKET_EPIC --expert frontend > /tmp/binding-c3.log 2>&1
EXIT_C3=$?
assert_eq "divergent no-reason rejected" "1" "$EXIT_C3"
grep -q "binding_change_reason required\|--reason required" /tmp/binding-c3.log
GREP_C3=$?
assert_eq "error mentions reason" "0" "$GREP_C3"

# Case 4: actual 偏离有 reason → OK
echo ""
echo "Case 4: actual divergent with reason → OK"
KALLAX_TICKETS_DIR="$TEST_TICKETS_DIR" \
  bash "$BINDING" actual $TICKET_EPIC --expert frontend --reason "scope covers both" > /tmp/binding-c4.log 2>&1
EXIT_C4=$?
assert_eq "divergent with reason exit code" "0" "$EXIT_C4"
GOT_REASON="$(jq -r '.expert_binding.binding_change_reason // empty' "$TICKET_FILE")"
assert_eq "reason persisted" "scope covers both" "$GOT_REASON"

# Case 5: legacy ticket 无 expert_binding → validate 跳过
echo ""
echo "Case 5: legacy ticket skipped"
KALLAX_TICKETS_DIR="$TEST_TICKETS_DIR" \
  bash "$BINDING" validate $LEGACY_EPIC > /tmp/binding-c5.log 2>&1
EXIT_C5=$?
assert_eq "legacy validate exit code" "0" "$EXIT_C5"
grep -q "legacy-no-binding" /tmp/binding-c5.log
GREP_C5=$?
assert_eq "legacy label shown" "0" "$GREP_C5"

# Case 6: validate-all 不破
echo ""
echo "Case 6: validate-all survives all tickets"
KALLAX_TICKETS_DIR="$TEST_TICKETS_DIR" \
  bash "$BINDING" validate-all --dir "$TEST_TICKETS_DIR" > /tmp/binding-c6.log 2>&1
EXIT_C6=$?
# Exit code may be 1 if any failed, but should not be 2 (user error) or fail catastrophically
if [ "$EXIT_C6" -le 1 ]; then
  echo "  PASS: validate-all exit in {0,1} (got $EXIT_C6)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: validate-all crashed (exit $EXIT_C6)"
  FAIL=$((FAIL + 1))
fi
grep -q "Binding Validation Summary\|Expert Binding Report" /tmp/binding-c6.log
GREP_C6=$?
assert_eq "validate-all summary printed" "0" "$GREP_C6"

# Case 7: path traversal rejected (per push security review MEDIUM finding)
echo ""
echo "Case 7: path traversal in ticket_id rejected"
KALLAX_TICKETS_DIR="$TEST_TICKETS_DIR" \
  bash "$BINDING" validate "../../etc/passwd" > /tmp/binding-c7.log 2>&1
EXIT_C7=$?
# Path-traversal rejection may exit 1 (FAIL) or 2 (user error) — both
# correctly reject; we accept either as a pass.
if [ "$EXIT_C7" -eq 1 ] || [ "$EXIT_C7" -eq 2 ]; then
  echo "  PASS: traversal rejected exit (got $EXIT_C7)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: traversal not rejected (exit $EXIT_C7)"
  FAIL=$((FAIL + 1))
fi
KALLAX_TICKETS_DIR="$TEST_TICKETS_DIR" \
  bash "$BINDING" validate "EPIC-9999/../etc" > /tmp/binding-c7b.log 2>&1
EXIT_C7B=$?
if [ "$EXIT_C7B" -eq 1 ] || [ "$EXIT_C7B" -eq 2 ]; then
  echo "  PASS: traversal rejected exit (slash) (got $EXIT_C7B)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: traversal (slash) not rejected (exit $EXIT_C7B)"
  FAIL=$((FAIL + 1))
fi

cleanup

echo ""
echo "================================================"
echo "Expert Binding Tracking Tests: $PASS passed, $FAIL failed"
echo "================================================"
if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
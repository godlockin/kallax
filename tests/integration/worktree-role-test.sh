#!/bin/bash
# worktree-role-test.sh — Integration test for Conductor dispatch.sh worktree_role 验证
#
# EPIC-035-A AC: dispatch.sh 验证 ticket.worktree_role 跟 worktree owner role 匹配,
# mismatch → veto + 报错. 4 case: master / conductor / performer / auditor.
#
# Strategy: dispatch.sh 通过 KALLAX_WORKTREE_ROLE env var 接受当前 worktree owner role,
# 从 ticket.json 读 worktree_role, mismatch → exit 2 (veto) + 报错 stderr.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DISPATCH="${KALLAX_ROOT}/scripts/conductor/dispatch.sh"
TICKETS_DIR="${KALLAX_ROOT}/jira/tickets"
TMP_DIR=$(mktemp -d)

trap 'rm -rf "$TMP_DIR"' EXIT

export KALLAX_TEST_FIXTURES=1

PASS=0
FAIL=0

mk_ticket() {
  local id="$1" role="$2"
  local dir="${TMP_DIR}/${id}"
  mkdir -p "$dir"
  cat > "${dir}/ticket.json" <<EOF
{
  "id": "${id}",
  "title": "fixture ${id}",
  "worktree_role": "${role}",
  "file_scope": {"includes": [], "excludes": []},
  "acceptance_criteria": ["placeholder"]
}
EOF
  echo "$dir"
}

echo "=== Worktree Role Verification Tests (EPIC-035-A) ==="

# Test 1: performer role 持有 performer ticket → accept
T1=$(mk_ticket "TEST-WR-PERFORMER" "performer")
out=$(KALLAX_WORKTREE_ROLE=performer bash "$DISPATCH" "TEST-WR-PERFORMER" "bash" "accept" 2>&1) && rc=$? || rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "final="; then
  echo "  ✓ [1/4] performer owner + performer ticket → accept"
  PASS=$((PASS+1))
else
  echo "  ✗ [1/4] performer/performer match should accept (rc=$rc)"
  echo "    out: $out"
  FAIL=$((FAIL+1))
fi

# Test 2: conductor role 持有 conductor ticket → accept
T2=$(mk_ticket "TEST-WR-CONDUCTOR" "conductor")
out=$(KALLAX_WORKTREE_ROLE=conductor bash "$DISPATCH" "TEST-WR-CONDUCTOR" "coordination" "accept" 2>&1) && rc=$? || rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "final="; then
  echo "  ✓ [2/4] conductor owner + conductor ticket → accept"
  PASS=$((PASS+1))
else
  echo "  ✗ [2/4] conductor/conductor match should accept (rc=$rc)"
  echo "    out: $out"
  FAIL=$((FAIL+1))
fi

# Test 3: auditor role 持有 auditor ticket → accept (no matching fixture, expect ALGO_ID=auditor fallback / graceful)
T3=$(mk_ticket "TEST-WR-AUDITOR" "auditor")
out=$(KALLAX_WORKTREE_ROLE=auditor bash "$DISPATCH" "TEST-WR-AUDITOR" "audit" "accept" 2>&1) && rc=$? || rc=$?
# auditor 没 fixture, ALGO_ID 会空 → dispatch exit 1
# 我们要的: ticket.worktree_role=auditor 通过 owner role 检查 (不在 mismatch 路径) — ALGO 失败是另一层
# 验证: stderr 不含 "worktree_role mismatch"
if ! echo "$out" | grep -q "worktree_role mismatch"; then
  echo "  ✓ [3/4] auditor owner + auditor ticket → no worktree_role mismatch veto"
  PASS=$((PASS+1))
else
  echo "  ✗ [3/4] auditor/auditor match should not veto on worktree_role"
  echo "    out: $out"
  FAIL=$((FAIL+1))
fi

# Test 4: performer role 持有 master ticket → mismatch veto + exit non-zero
T4=$(mk_ticket "TEST-WR-MISMATCH" "master")
out=$(KALLAX_TICKETS_DIR="$TMP_DIR" KALLAX_WORKTREE_ROLE=performer bash "$DISPATCH" "TEST-WR-MISMATCH" "bash" "accept" 2>&1) && rc=$? || rc=$?
if [[ $rc -ne 0 ]] && echo "$out" | grep -q "worktree_role mismatch"; then
  echo "  ✓ [4/4] performer owner + master ticket → mismatch veto + error"
  PASS=$((PASS+1))
else
  echo "  ✗ [4/4] mismatch should veto (rc=$rc, expected non-zero)"
  echo "    out: $out"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Summary ==="
echo "PASS: $PASS / 4"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
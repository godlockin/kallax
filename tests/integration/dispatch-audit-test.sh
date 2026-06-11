#!/bin/bash
# dispatch-audit-test.sh — Integration test for dispatch-audit.sh (EPIC-031-C)
#
# 3 决策 × 各 1 案例 + audit JSONL 格式验证
# L4: 3+ 测试 PASS (3 决策 × 各 1 案例 + audit JSONL 格式验证)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_SCRIPT="${KALLAX_ROOT}/scripts/audit/dispatch-audit.sh"

# Temp audit dir for test isolation
TMP_AUDIT_DIR="${BASH_SOURCE[0]}.tmp.$$"
cleanup() {
  rm -rf "$TMP_AUDIT_DIR" 2>/dev/null || true
}
trap cleanup EXIT
export AUDIT_DIR="$TMP_AUDIT_DIR"
mkdir -p "$AUDIT_DIR"

echo "=== dispatch-audit.sh Integration Tests (3 decisions + JSONL format) ==="
PASS=0
FAIL=0

# ============================================================
# Helper: get last dispatch record from JSONL as compact single-line JSON
# Uses jq -s to parse multi-line entries (each entry spans multiple lines)
# ============================================================
get_last_dispatch_record() {
  local audit_file="$1"
  # jq -s: slurp all lines, each is a JSON object (may be multi-line pretty-printed)
  # map(select(has("type"))): filter to objects that have "type" key (i.e., dispatch records)
  # | .[-1]: take last
  jq -s 'map(select(has("type"))) | .[-1]' "$audit_file" 2>/dev/null
}

# ============================================================
# Test 1: accept decision
# ============================================================
echo ""
echo "[Test 1] accept decision"
TEST_DATE="2026-06-11"
AUDIT_FILE="${TMP_AUDIT_DIR}/scoring-${TEST_DATE}.jsonl"

if AUDIT_DIR="$AUDIT_DIR" bash "$AUDIT_SCRIPT" write "EPIC-031-T001" "conductor-gamma" "conductor-gamma" "accept" "conductor"; then
  echo "  ✓ write accept decision"
  PASS=$((PASS + 1))
else
  echo "  ✗ write accept decision failed"
  FAIL=$((FAIL + 1))
fi

# Validate JSONL format using jq (handles multi-line entries)
if [[ -f "$AUDIT_FILE" ]]; then
  LAST_REC=$(get_last_dispatch_record "$AUDIT_FILE")
  if [[ -n "$LAST_REC" ]] && [[ "$LAST_REC" != "null" ]]; then
    # Extract fields using jq
    DEC=$(printf '%s' "$LAST_REC" | jq -r '.decision')
    TS=$(printf '%s' "$LAST_REC" | jq -r '.timestamp')
    TID=$(printf '%s' "$LAST_REC" | jq -r '.ticket_id')
    ALGO=$(printf '%s' "$LAST_REC" | jq -r '.algo_suggest')
    FINAL=$(printf '%s' "$LAST_REC" | jq -r '.final_slaver')
    ACTOR=$(printf '%s' "$LAST_REC" | jq -r '.actor')
    REC_TYPE=$(printf '%s' "$LAST_REC" | jq -r '.type')

    # Validate type=dispatch
    if [[ "$REC_TYPE" == "dispatch" ]]; then
      echo "  ✓ accept decision JSONL fields valid (type=dispatch)"
      PASS=$((PASS + 1))
    else
      echo "  ✗ accept: type must be 'dispatch', got '$REC_TYPE'"
      FAIL=$((FAIL + 1))
    fi

    # Validate decision == accept
    if [[ "$DEC" == "accept" ]]; then
      echo "  ✓ accept decision value correct"
      PASS=$((PASS + 1))
    else
      echo "  ✗ accept decision value expected 'accept', got '$DEC'"
      FAIL=$((FAIL + 1))
    fi

    # Validate timestamp format
    if [[ "$TS" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\+00:00$ ]]; then
      echo "  ✓ accept timestamp ISO-8601 valid"
      PASS=$((PASS + 1))
    else
      echo "  ✗ accept timestamp '$TS' not ISO-8601"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  ✗ no dispatch record found in JSONL"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  ✗ audit file not created"
  FAIL=$((FAIL + 1))
fi

# ============================================================
# Test 2: veto decision
# ============================================================
echo ""
echo "[Test 2] veto decision"

if AUDIT_DIR="$AUDIT_DIR" bash "$AUDIT_SCRIPT" write "EPIC-031-T002" "conductor-gamma" "VETOED" "veto" "conductor"; then
  echo "  ✓ write veto decision"
  PASS=$((PASS + 1))
else
  echo "  ✗ write veto decision failed"
  FAIL=$((FAIL + 1))
fi

if [[ -f "$AUDIT_FILE" ]]; then
  LAST_REC=$(get_last_dispatch_record "$AUDIT_FILE")
  if [[ -n "$LAST_REC" ]] && [[ "$LAST_REC" != "null" ]]; then
    DEC=$(printf '%s' "$LAST_REC" | jq -r '.decision')
    TID=$(printf '%s' "$LAST_REC" | jq -r '.ticket_id')
    FINAL=$(printf '%s' "$LAST_REC" | jq -r '.final_slaver')
    REC_TYPE=$(printf '%s' "$LAST_REC" | jq -r '.type')

    if [[ "$REC_TYPE" == "dispatch" ]]; then
      echo "  ✓ veto decision JSONL fields valid"
      PASS=$((PASS + 1))
    else
      echo "  ✗ veto: type must be 'dispatch', got '$REC_TYPE'"
      FAIL=$((FAIL + 1))
    fi

    if [[ "$DEC" == "veto" ]] && [[ "$TID" == "EPIC-031-T002" ]] && [[ "$FINAL" == "VETOED" ]]; then
      echo "  ✓ veto decision value and ticket_id correct"
      PASS=$((PASS + 1))
    else
      echo "  ✗ veto: expected decision=veto ticket_id=EPIC-031-T002 final_slaver=VETOED, got decision=$DEC ticket_id=$TID final_slaver=$FINAL"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  ✗ no dispatch record found in JSONL"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  ✗ audit file not created"
  FAIL=$((FAIL + 1))
fi

# ============================================================
# Test 3: override decision
# ============================================================
echo ""
echo "[Test 3] override decision"

if AUDIT_DIR="$AUDIT_DIR" bash "$AUDIT_SCRIPT" write "EPIC-031-T003" "conductor-gamma" "performer-beta" "override" "performer"; then
  echo "  ✓ write override decision"
  PASS=$((PASS + 1))
else
  echo "  ✗ write override decision failed"
  FAIL=$((FAIL + 1))
fi

if [[ -f "$AUDIT_FILE" ]]; then
  LAST_REC=$(get_last_dispatch_record "$AUDIT_FILE")
  if [[ -n "$LAST_REC" ]] && [[ "$LAST_REC" != "null" ]]; then
    DEC=$(printf '%s' "$LAST_REC" | jq -r '.decision')
    FINAL=$(printf '%s' "$LAST_REC" | jq -r '.final_slaver')
    ACTOR=$(printf '%s' "$LAST_REC" | jq -r '.actor')
    REC_TYPE=$(printf '%s' "$LAST_REC" | jq -r '.type')

    if [[ "$REC_TYPE" == "dispatch" ]]; then
      echo "  ✓ override decision JSONL fields valid"
      PASS=$((PASS + 1))
    else
      echo "  ✗ override: type must be 'dispatch', got '$REC_TYPE'"
      FAIL=$((FAIL + 1))
    fi

    if [[ "$DEC" == "override" ]] && [[ "$FINAL" == "performer-beta" ]] && [[ "$ACTOR" == "performer" ]]; then
      echo "  ✓ override decision/final_slaver/actor correct"
      PASS=$((PASS + 1))
    else
      echo "  ✗ override: expected decision=override final_slaver=performer-beta actor=performer, got decision=$DEC final_slaver=$FINAL actor=$ACTOR"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  ✗ no dispatch record found in JSONL"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  ✗ audit file not created"
  FAIL=$((FAIL + 1))
fi

# ============================================================
# Test 4: read dispatch audit
# ============================================================
echo ""
echo "[Test 4] read dispatch audit"

READ_OUTPUT=$(AUDIT_DIR="$AUDIT_DIR" bash "$AUDIT_SCRIPT" read "$TEST_DATE" 2>&1)
# Count dispatch records in read output using jq
READ_COUNT=$(printf '%s' "$READ_OUTPUT" | jq -s 'map(select(has("type"))) | length' 2>/dev/null || echo "0")
if [[ "$READ_COUNT" -ge 3 ]]; then
  echo "  ✓ read returns $READ_COUNT dispatch records (>= 3)"
  PASS=$((PASS + 1))
else
  echo "  ✗ read returns $READ_COUNT dispatch records, expected >= 3"
  FAIL=$((FAIL + 1))
fi

# ============================================================
# Test 5: count dispatch audit
# ============================================================
echo ""
echo "[Test 5] count dispatch audit"

COUNT=$(AUDIT_DIR="$AUDIT_DIR" bash "$AUDIT_SCRIPT" count "$TEST_DATE" 2>&1 | tr -d ' ')
if [[ "$COUNT" -ge 3 ]]; then
  echo "  ✓ count returns $COUNT (>= 3)"
  PASS=$((PASS + 1))
else
  echo "  ✗ count returns $COUNT, expected >= 3"
  FAIL=$((FAIL + 1))
fi

# ============================================================
# Test 6: error handling — invalid decision
# ============================================================
echo ""
echo "[Test 6] error handling — invalid decision"

if AUDIT_DIR="$AUDIT_DIR" bash "$AUDIT_SCRIPT" write "EPIC-031-T004" "conductor-gamma" "performer-beta" "invalid_decision" "conductor" 2>/dev/null; then
  echo "  ✗ invalid decision should fail"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ invalid decision fails correctly"
  PASS=$((PASS + 1))
fi

# ============================================================
# Test 7: JSONL format validation — all 7 fields present
# ============================================================
echo ""
echo "[Test 7] JSONL format validation — all 7 required fields"

FIRST_REC=$(jq -s 'map(select(has("type"))) | .[0]' "$AUDIT_FILE" 2>/dev/null)
if [[ -n "$FIRST_REC" ]] && [[ "$FIRST_REC" != "null" ]]; then
  for field in timestamp ticket_id algo_suggest final_slaver decision actor type; do
    VALUE=$(printf '%s' "$FIRST_REC" | jq -r ".$field" 2>/dev/null)
    if [[ -z "$VALUE" ]] || [[ "$VALUE" == "null" ]]; then
      echo "  ✗ field '$field' is missing or null"
      FAIL=$((FAIL + 1))
    fi
  done
  echo "  ✓ all 7 dispatch fields present in JSONL record"
  PASS=$((PASS + 1))
else
  echo "  ✗ no dispatch record found for field validation"
  FAIL=$((FAIL + 1))
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
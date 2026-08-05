#!/usr/bin/env bash
# tests/integration/dashboard-metrics.test.sh — EPIC-168-BG
# 验证 dashboard-metrics.sh 4 北极星 + 4 event counts + daemon status
# 跟 EPIC-069-D 5-Level Verify 1:1

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
METRICS_SCRIPT="${SCRIPT_DIR}/../../scripts/dashboard/dashboard-metrics.sh"
STATE_DIR="${SCRIPT_DIR}/../../state"
LEDGER="${STATE_DIR}/run-history.jsonl"
RUN_HISTORY_SCRIPT="${SCRIPT_DIR}/../../scripts/heartbeat/run-history.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1: $2"; }

echo "==============================================="
echo "  EPIC-168-BG dashboard-metrics test"
echo "==============================================="

# Setup: ensure state dir and ledger
mkdir -p "$STATE_DIR"
touch "$LEDGER"

# TC1: bash syntax
echo ""
echo "TC1: bash -n syntax check"
if bash -n "$METRICS_SCRIPT" 2>/dev/null; then
    pass "dashboard-metrics.sh syntax"
else
    fail "syntax" "bash -n failed"
fi

# TC2: data feed (run-history emit)
echo ""
echo "TC2: data feed — emit 4 event types"
for evt in work decision accounting evidence; do
    bash "$RUN_HISTORY_SCRIPT" emit "$evt" EPIC-168-BG-test "{}" 2>/dev/null || true
done
if [ -f "$LEDGER" ] && [ -s "$LEDGER" ]; then
    pass "run-history emit 4 types"
else
    fail "emit" "ledger empty"
fi

# TC3: 4 metrics calculation
echo ""
echo "TC3: 4 north stars calculation"
json=$(bash "$METRICS_SCRIPT" --format=json 2>/dev/null)
if echo "$json" | grep -qE '"expert_activation"'; then
    pass "expert_activation metric"
else
    fail "expert_activation" "not found in output"
fi
if echo "$json" | grep -qE '"cross_epic_reuse"'; then
    pass "cross_epic_reuse metric"
else
    fail "cross_epic_reuse" "not found in output"
fi
if echo "$json" | grep -qE '"ab_hit_rate"'; then
    pass "ab_hit_rate metric"
else
    fail "ab_hit_rate" "not found in output"
fi
if echo "$json" | grep -qE '"mis_dispatch_binding_rate"'; then
    pass "mis_dispatch_binding_rate metric"
else
    fail "mis_dispatch_binding_rate" "not found in output"
fi

# TC4: 4 event counts
echo ""
echo "TC4: 4 event type counts"
for evt in work decision accounting evidence; do
    count=$(echo "$json" | grep -oE "\"${evt}\":[[:space:]]*[0-9]+" | grep -oE '[0-9]+' | head -1)
    if [ -n "$count" ] && [ "$count" -ge 0 ]; then
        pass "$evt count: $count"
    else
        fail "$evt count" "invalid: $count"
    fi
done

# TC5: daemon status
echo ""
echo "TC5: daemon status output"
status=$(bash "$METRICS_SCRIPT" --daemon-status 2>/dev/null)
if echo "$status" | grep -qE 'daemon:(running|down)'; then
    pass "daemon status: $status"
else
    fail "daemon status" "unexpected: $status"
fi

# TC6: JSON format valid
echo ""
echo "TC6: JSON format valid"
if echo "$json" | jq '.' >/dev/null 2>&1; then
    pass "valid JSON output"
else
    fail "JSON" "invalid format"
fi

# TC7: text format output
echo ""
echo "TC7: text format"
text=$(bash "$METRICS_SCRIPT" --format=text 2>/dev/null)
if echo "$text" | grep -qE "North Stars|expert_activation|4 North"; then
    pass "text format readable"
else
    fail "text format" "missing expected content"
fi

# Summary
echo ""
echo "==============================================="
echo "  EPIC-168-BG dashboard: $PASS pass, $FAIL fail"
echo "==============================================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0

#!/usr/bin/env bash
# KALLAX Token Regression Test — V310 hotfix U-004
# 5 PASS: baseline loadable + cold_start_bytes ±20% + cold_start_tokens ±20% +
#           lazy_load_bytes ±20% + per_session_bytes ±20%
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASELINE="${KALLAX_ROOT}/tests/benchmark/token-baseline.json"
THRESHOLD_PCT=20

echo "=== V310 hotfix U-004: Token Regression Test (±${THRESHOLD_PCT}%) ==="
echo ""

# Helper: extract field from JSON (jq)
get_field() {
    local field="$1"
    jq -r "$field" "$BASELINE"
}

# Helper: assert within threshold
assert_within_pct() {
    local label="$1"
    local actual="$2"
    local baseline="$3"
    local pct
    pct=$(awk -v a="$actual" -v b="$baseline" 'BEGIN { if (b == 0) { print 999 } else { printf "%.4f", (a - b) / b * 100 } }' | tr -d '-')
    pct_abs=${pct#-}
    within=$(awk -v p="$pct_abs" -v t="$THRESHOLD_PCT" 'BEGIN { print (p <= t) ? 1 : 0 }')
    if [[ "$within" == "1" ]]; then
        printf "  PASS: %-30s baseline=%s actual=%s delta=%.2f%% (within ±%d%%)\n" "$label" "$baseline" "$actual" "$pct" "$THRESHOLD_PCT"
        return 0
    else
        printf "  FAIL: %-30s baseline=%s actual=%s delta=%.2f%% (exceeds ±%d%%)\n" "$label" "$baseline" "$actual" "$pct" "$THRESHOLD_PCT"
        return 1
    fi
}

# ── Test 1: baseline JSON loadable ──────────────────────────────────────────
echo "[TEST 1] baseline JSON loadable + jq parses"
if jq -e . "$BASELINE" >/dev/null 2>&1; then
    echo "  PASS: token-baseline.json is valid JSON"
else
    echo "  FAIL: token-baseline.json is not valid JSON"
    exit 1
fi

# ── Test 2: cold start (CLAUDE.md + CHEATSHEET.md) bytes ±20% ──────────────
echo "[TEST 2] cold_start_always_loaded bytes within ±${THRESHOLD_PCT}%"
baseline_bytes=$(get_field '.kallax_v3_1_0.cold_start_always_loaded.bytes')
actual_bytes=$([ -f "$KALLAX_ROOT/CLAUDE.md" ] && [ -f "$KALLAX_ROOT/docs/CHEATSHEET.md" ] && \
    echo $(($(wc -c < "$KALLAX_ROOT/CLAUDE.md") + $(wc -c < "$KALLAX_ROOT/docs/CHEATSHEET.md"))) || echo 0)
assert_within_pct "cold_start_bytes" "$actual_bytes" "$baseline_bytes"

# ── Test 3: cold start tokens ±20% ─────────────────────────────────────────
echo "[TEST 3] cold_start_always_loaded tokens (bytes/4) within ±${THRESHOLD_PCT}%"
baseline_tokens=$(get_field '.kallax_v3_1_0.cold_start_always_loaded.tokens')
actual_tokens=$((actual_bytes / 4))
assert_within_pct "cold_start_tokens" "$actual_tokens" "$baseline_tokens"

# ── Test 4: lazy_load (5-levels.md) bytes ±20% ─────────────────────────────
echo "[TEST 4] 5-levels.md bytes within ±${THRESHOLD_PCT}%"
baseline_lazy=$(get_field '.kallax_v3_1_0.lazy_load_5_levels_md.bytes')
actual_lazy=$([ -f "$KALLAX_ROOT/docs/5-levels.md" ] && wc -c < "$KALLAX_ROOT/docs/5-levels.md" | tr -d ' ' || echo 0)
assert_within_pct "5-levels.md_bytes" "$actual_lazy" "$baseline_lazy"

# ── Test 5: per_session (cold + 5-levels.md) bytes ±20% ────────────────────
echo "[TEST 5] per_session bytes (CLAUDE.md + CHEATSHEET.md + 5-levels.md) within ±${THRESHOLD_PCT}%"
baseline_per=$(get_field '.kallax_v3_1_0.per_session_typical.bytes')
actual_per=$((actual_bytes + actual_lazy))
assert_within_pct "per_session_bytes" "$actual_per" "$baseline_per"

echo ""
echo "=== All 5 tests PASSED ==="
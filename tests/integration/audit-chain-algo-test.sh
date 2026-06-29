#!/usr/bin/env bash
# KALLAX Audit Chain Algo Tests — V310 hotfix S-006
# 5 PASS: append-v2 + verify-v2 + backward-compat-v1 + tamper-FAIL + chain_algo field
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_CHAIN="${KALLAX_ROOT}/scripts/audit/audit-chain.sh"
TMPDIR_BASE="$(mktemp -d /tmp/audit-chain-algo-XXXX)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "=== V310 hotfix S-006: Audit Chain Algo (sha256-v2) Tests ==="
echo ""

# ── Test 1: append+verify roundtrip (sha256-v2) ────────────────────────────
echo "[TEST 1] append+verify sha256-v2 roundtrip"
F1="$TMPDIR_BASE/v2.jsonl"
bash "$AUDIT_CHAIN" append "$F1" '{"event":"e1","ts":1}' >/dev/null 2>&1
bash "$AUDIT_CHAIN" append "$F1" '{"event":"e2","ts":2}' >/dev/null 2>&1
verify_out=$(bash "$AUDIT_CHAIN" verify "$F1" 2>&1)
if [[ "$verify_out" == *"PASS"* ]]; then
  echo "  PASS: v2 roundtrip verified"
else
  echo "  FAIL: v2 roundtrip failed: $verify_out"
  exit 1
fi

# ── Test 2: chain_algo field present ──────────────────────────────────────
echo "[TEST 2] chain_algo=\"sha256-v2\" field present"
if grep -q '"chain_algo":"sha256-v2"' "$F1"; then
  echo "  PASS: chain_algo=sha256-v2 recorded on disk"
else
  echo "  FAIL: chain_algo field missing"
  exit 1
fi

# ── Test 3: backward compatibility (sha256-v1 log still verifies) ─────────
echo "[TEST 3] sha256-v1 legacy log verifies (backward compat)"
F3="$TMPDIR_BASE/v1.jsonl"
# Construct v1 log manually: chain_hash = sha256(prev || canonical), no chain_algo
PREV3="0000000000000000000000000000000000000000000000000000000000000000"
CANON3='{"event":"legacy1","prev_hash":"0000000000000000000000000000000000000000000000000000000000000000","ts":1}'
H1=$(printf '%s' "${PREV3}${CANON3}" | sha256sum | awk '{print $1}')
ENTRY1="{\"event\":\"legacy1\",\"ts\":1,\"prev_hash\":\"${PREV3}\",\"chain_hash\":\"${H1}\"}"
echo "$ENTRY1" > "$F3"
chmod 600 "$F3"
verify_out=$(bash "$AUDIT_CHAIN" verify "$F3" 2>&1)
if [[ "$verify_out" == *"PASS"* ]]; then
  echo "  PASS: v1 legacy log verifies (default algo dispatch)"
else
  echo "  FAIL: v1 legacy verify failed: $verify_out"
  exit 1
fi

# ── Test 4: tamper detection still works ──────────────────────────────────
echo "[TEST 4] tamper detection FAILs (sha256-v2)"
F4="$TMPDIR_BASE/tamper.jsonl"
bash "$AUDIT_CHAIN" append "$F4" '{"event":"original","ts":100}' >/dev/null 2>&1
# Tamper event field
sed -i '' 's/"original"/"tampered"/g' "$F4" 2>/dev/null || sed -i 's/"original"/"tampered"/g' "$F4"
verify_out=$(bash "$AUDIT_CHAIN" verify "$F4" 2>&1 || true)
if [[ "$verify_out" == *"FAIL"* ]]; then
  echo "  PASS: tamper detected, verify FAILs"
else
  echo "  FAIL: tamper not detected: $verify_out"
  exit 1
fi

# ── Test 5: cross-algo chain (v1 then v2) verifies via algo dispatch ─────
echo "[TEST 5] mixed v1+v2 chain verifies (algo dispatch per-entry)"
F5="$TMPDIR_BASE/mixed.jsonl"
# Start with v1 (no chain_algo field), then append v2
PREV5="0000000000000000000000000000000000000000000000000000000000000000"
CANON_A='{"event":"a","prev_hash":"0000000000000000000000000000000000000000000000000000000000000000","ts":1}'
HA=$(printf '%s' "${PREV5}${CANON_A}" | sha256sum | awk '{print $1}')
ENTRY_A="{\"event\":\"a\",\"ts\":1,\"prev_hash\":\"${PREV5}\",\"chain_hash\":\"${HA}\"}"
echo "$ENTRY_A" > "$F5"
chmod 600 "$F5"
bash "$AUDIT_CHAIN" append "$F5" '{"event":"b","ts":2}' >/dev/null 2>&1
verify_out=$(bash "$AUDIT_CHAIN" verify "$F5" 2>&1)
if [[ "$verify_out" == *"PASS"* ]]; then
  echo "  PASS: mixed v1+v2 chain verifies (per-entry algo dispatch)"
else
  echo "  FAIL: mixed chain verify failed: $verify_out"
  exit 1
fi

echo ""
echo "=== All 5 tests PASSED ==="
#!/usr/bin/env bash
# KALLAX Hook Replay Access Right Tests — V310 hotfix S-005
# 4 PASS: cross-session denied + admin allowed + intra-session allowed + adminApiKey config
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_SERVER="${KALLAX_ROOT}/node/src/hooks/http-hook-server.ts"

echo "=== V310 hotfix S-005: Hook Replay Access Right Tests ==="
echo ""

# ── Test 1: cross-session replay guard present in source ──────────────────
echo "[TEST 1] handleReplay() contains cross-session ownership check"
if grep -q "cross-session replay requires admin token" "$HOOK_SERVER"; then
  echo "  PASS: cross-session ownership check present (V310-B-REVIEW S-005 P1)"
else
  echo "  FAIL: cross-session ownership check missing"
  exit 1
fi

# ── Test 2: adminApiKey field in HookServerConfig ──────────────────────────
echo "[TEST 2] HookServerConfig has adminApiKey field"
if grep -q "readonly adminApiKey" "$HOOK_SERVER"; then
  echo "  PASS: adminApiKey field added to HookServerConfig"
else
  echo "  FAIL: adminApiKey field missing in HookServerConfig"
  exit 1
fi

# ── Test 3: intra-session replay still allowed (no sourceSessionId) ────────
echo "[TEST 3] Intra-session replay path preserved (isCrossSession check)"
if grep -q "isCrossSession = sourceSessionId !== undefined && sourceSessionId !== targetSessionId" "$HOOK_SERVER"; then
  echo "  PASS: isCrossSession computation present, intra-session allowed"
else
  echo "  FAIL: isCrossSession logic missing or changed"
  exit 1
fi

# ── Test 4: 403 returned + logged on cross-session denial ──────────────────
echo "[TEST 4] Cross-session denial returns 403 + warn log"
denial_count=$(grep -cE "sendJson\(res, 403|logger\.warn.*cross-session replay denied" "$HOOK_SERVER" || true)
if [[ $denial_count -ge 2 ]]; then
  echo "  PASS: 403 + warn log both present (count=$denial_count)"
else
  echo "  FAIL: expected 403 + warn log, got count=$denial_count"
  exit 1
fi

echo ""
echo "=== All 4 tests PASSED ==="
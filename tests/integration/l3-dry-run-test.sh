#!/usr/bin/env bash
# tests/integration/l3-dry-run-test.sh — TDD tests for L3 dry-run (武器 2 v3.1.0)
#
# 验证 4 expert 备案 评审 L3 dry-run:
#   Case 1: TICKET-DRY-1 — 4 expert 备案 (PASS) → L3 PASS (rc=0)
#   Case 2: TICKET-DRY-2 — 3 expert 备案 (缺 security) → L3 ERROR (rc=2)
#   Case 3: TICKET-DRY-3 — dry-run mode → 4 expert 自动 PASS (rc=0)
#   Case 4: TICKET-DRY-4 — 4 expert 备案 (1 FAIL: security) → L3 FAIL (rc=1)
#
# Rule 9 KPI X/Y 格式: 4/4 = 100.0% PASS (no estimate, exact)
# 跟 scripts/verify/level-3.sh v3.1.0 实做 1:1 联合
# 跟 W4 check-epic-4-piece.sh schema 一致 (缺文件 → exit 2)

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly VERIFY_DIR="$KALLAX_ROOT/scripts/verify"
readonly REVIEW_DIR="$KALLAX_ROOT/.kallax/reviews"

echo "=========================================="
echo "L3 dry-run Integration Tests (4/4)"
echo "武器 2 (v3.1.0) — 4 expert 备案 评审"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=4

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# cleanup helper — 在所有 case 之前 + 每个 case 之后 清理
cleanup_reviews() {
    rm -rf "$REVIEW_DIR/TICKET-DRY-1" "$REVIEW_DIR/TICKET-DRY-2" \
           "$REVIEW_DIR/TICKET-DRY-3" "$REVIEW_DIR/TICKET-DRY-4" 2>/dev/null || true
}

# -------------------------------------------------------
# Case 1: TICKET-DRY-1 — 4 expert 备案 PASS → L3 PASS
# -------------------------------------------------------
echo ">>> Case 1: TICKET-DRY-1 — 4 expert 备案 PASS → L3 PASS (rc=0)"
cleanup_reviews
mkdir -p "$REVIEW_DIR/TICKET-DRY-1"

cat > "$REVIEW_DIR/TICKET-DRY-1/architect.json" <<'EOF'
{"expert":"architect","status":"PASS","rationale":"边界清晰, 接口契约稳定"}
EOF
cat > "$REVIEW_DIR/TICKET-DRY-1/backend.json" <<'EOF'
{"expert":"backend","status":"PASS","rationale":"索引合理, Result<T,E> 强制"}
EOF
cat > "$REVIEW_DIR/TICKET-DRY-1/frontend.json" <<'EOF'
{"expert":"frontend","status":"PASS","rationale":"组件单一职责, LCP<2.5s"}
EOF
cat > "$REVIEW_DIR/TICKET-DRY-1/security.json" <<'EOF'
{"expert":"security","status":"PASS","rationale":"无注入, 凭据隔离"}
EOF

set +e
OUT=$(bash "$VERIFY_DIR/level-3.sh" TICKET-DRY-1 2>&1)
RC=$?
set -e
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -qE "L3 Summary: 4 PASS.*0 FAIL.*0 ERROR" && echo "$OUT" | grep -qE "RESULT: PASS"; then
    pass "4 expert 备案全 PASS → L3 PASS (rc=0, raw stdout: $(echo "$OUT" | grep RESULT | head -1))"
else
    fail "TICKET-DRY-1 expect rc=0 PASS, got rc=$RC"
    echo "$OUT" | tail -10 | sed 's/^/      /'
fi
echo ""

# -------------------------------------------------------
# Case 2: TICKET-DRY-2 — 缺 security.json → L3 ERROR (rc=2)
# -------------------------------------------------------
echo ">>> Case 2: TICKET-DRY-2 — 缺 security.json → L3 ERROR (rc=2)"
cleanup_reviews
mkdir -p "$REVIEW_DIR/TICKET-DRY-2"

cat > "$REVIEW_DIR/TICKET-DRY-2/architect.json" <<'EOF'
{"expert":"architect","status":"PASS","rationale":"OK"}
EOF
cat > "$REVIEW_DIR/TICKET-DRY-2/backend.json" <<'EOF'
{"expert":"backend","status":"PASS","rationale":"OK"}
EOF
cat > "$REVIEW_DIR/TICKET-DRY-2/frontend.json" <<'EOF'
{"expert":"frontend","status":"PASS","rationale":"OK"}
EOF
# security.json INTENTIONALLY missing

set +e
OUT=$(bash "$VERIFY_DIR/level-3.sh" TICKET-DRY-2 2>&1)
RC=$?
set -e
if [ "$RC" -eq 2 ] && echo "$OUT" | grep -qE "security review missing" && echo "$OUT" | grep -qE "RESULT: ERROR"; then
    pass "缺 security.json → L3 ERROR (rc=2, 跟 W4 schema 一致)"
else
    fail "TICKET-DRY-2 expect rc=2 ERROR, got rc=$RC"
    echo "$OUT" | tail -10 | sed 's/^/      /'
fi
echo ""

# -------------------------------------------------------
# Case 3: TICKET-DRY-3 — dry-run → 4 expert 自动 PASS
# -------------------------------------------------------
echo ">>> Case 3: TICKET-DRY-3 — dry-run mode → 4 expert 自动 PASS (rc=0)"
cleanup_reviews
mkdir -p "$REVIEW_DIR/TICKET-DRY-3"
# NO expert JSON files — dry-run 应自动 PASS

set +e
OUT=$(bash "$VERIFY_DIR/level-3.sh" TICKET-DRY-3 --dry-run 2>&1)
RC=$?
set -e
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -qE "DRY_RUN: 1" && echo "$OUT" | grep -qE "RESULT: PASS" && echo "$OUT" | grep -qE "4 PASS.*0 FAIL.*0 ERROR"; then
    pass "dry-run → 4 expert 自动 PASS (rc=0, placeholder OK)"
else
    fail "TICKET-DRY-3 expect dry-run rc=0 PASS, got rc=$RC"
    echo "$OUT" | tail -10 | sed 's/^/      /'
fi
echo ""

# -------------------------------------------------------
# Case 4: TICKET-DRY-4 — 1 FAIL (security) → L3 FAIL (rc=1)
# -------------------------------------------------------
echo ">>> Case 4: TICKET-DRY-4 — 1 FAIL (security) → L3 FAIL (rc=1)"
cleanup_reviews
mkdir -p "$REVIEW_DIR/TICKET-DRY-4"

cat > "$REVIEW_DIR/TICKET-DRY-4/architect.json" <<'EOF'
{"expert":"architect","status":"PASS","rationale":"OK"}
EOF
cat > "$REVIEW_DIR/TICKET-DRY-4/backend.json" <<'EOF'
{"expert":"backend","status":"PASS","rationale":"OK"}
EOF
cat > "$REVIEW_DIR/TICKET-DRY-4/frontend.json" <<'EOF'
{"expert":"frontend","status":"PASS","rationale":"OK"}
EOF
cat > "$REVIEW_DIR/TICKET-DRY-4/security.json" <<'EOF'
{"expert":"security","status":"FAIL","rationale":"P0 阻塞: SQL 注入风险"}
EOF

set +e
OUT=$(bash "$VERIFY_DIR/level-3.sh" TICKET-DRY-4 2>&1)
RC=$?
set -e
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -qE "security review=FAIL" && echo "$OUT" | grep -qE "RESULT: FAIL"; then
    pass "security FAIL → L3 FAIL (rc=1, 区分 ERROR/FAIL)"
else
    fail "TICKET-DRY-4 expect rc=1 FAIL, got rc=$RC"
    echo "$OUT" | tail -10 | sed 's/^/      /'
fi
echo ""

# Final cleanup
cleanup_reviews

# Summary
echo "=========================================="
echo "L3 dry-run Test Summary: $PASS_COUNT PASS, $FAIL_COUNT FAIL (of $TOTAL)"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT: FAIL — 武器 2 L3 dry-run not ready"
    exit 1
fi
echo "RESULT: PASS — 武器 2 L3 dry-run ready (4 expert 备案评审)"
exit 0

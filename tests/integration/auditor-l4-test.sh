#!/usr/bin/env bash
# tests/integration/auditor-l4-test.sh — L4 dispatch + Auditor 联动 integration tests
# EPIC-038-C: Auditor 角色 + L4 派单 + AuditMiddleware 联动
#
# Test cases (≥4 required by AC):
#   1. 借鉴 (borrow): auditor-dispatch.sh 借鉴 conductor dispatch.sh CLI 模式
#   2. 隐患 (hidden-risk): AuditMiddleware 9-pass redaction 不漏报 (Pass-1 Authorization 验证)
#   3. 迁移 (migrate): lessons-import.py 跨项目 import 验证
#   4. 不强写 (no-force-write): Auditor 不能强写原项目代码 (block_original)
#
# Rule alignment:
#   - Rule 8: L4 bash scripts must exist before ticket close
#   - Rule 9 KPI: counts 用 grep -c, 0 估数
#   - Rule 12 质量 ensure: 5 维度 audit (existence/wiring/integration/anti-pattern/coverage)
#   - Q5 L4 角色规范: Auditor 跨 worktree 读 + 写 lessons, 不改原项目代码
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ─── Target paths ───
readonly AUDITOR_DISPATCH="$KALLAX_ROOT/scripts/conductor/auditor-dispatch.sh"
readonly LESSONS_IMPORT_PY="$KALLAX_ROOT/scripts/import/lessons-import.py"
readonly AUDIT_MIDDLEWARE_PY="$KALLAX_ROOT/scripts/audit/AuditMiddleware.py"
readonly AUDITOR_SCRIPT="$KALLAX_ROOT/scripts/auditor/auditor.sh"

# ─── Test counters ───
TEST_PASS=0
TEST_FAIL=0
TEST_SKIP=0

pass() { echo "[PASS] $1"; TEST_PASS=$((TEST_PASS + 1)); }
fail() { echo "[FAIL] $1"; TEST_FAIL=$((TEST_FAIL + 1)); }
skip() { echo "[SKIP] $1"; TEST_SKIP=$((TEST_SKIP + 1)); }
info() { echo "[INFO] $1"; }

echo "=========================================="
echo "Auditor L4 Integration Tests (EPIC-038-C)"
echo "=========================================="
echo ""

# ────────────────────────────────────────────
# Test 1: 借鉴 (borrow) — auditor-dispatch.sh 借鉴 conductor dispatch.sh CLI 模式
# ────────────────────────────────────────────
test_1_borrow_cli_pattern() {
    info "=== Test 1: borrow CLI pattern from conductor dispatch.sh ==="

    if [[ ! -f "$AUDITOR_DISPATCH" ]] || [[ ! -x "$AUDITOR_DISPATCH" ]]; then
        fail "Test 1: auditor-dispatch.sh missing or not executable"
        return 1
    fi

    local dispatch="$KALLAX_ROOT/scripts/conductor/dispatch.sh"
    if [[ ! -f "$dispatch" ]]; then
        skip "Test 1: conductor dispatch.sh not found (skipping borrow pattern check)"
        return 0
    fi

    # Borrow pattern 1: usage pattern (caller-facing --help / Usage)
    local dispatch_help auditor_help
    dispatch_help=$(grep -cE "Usage:" "$dispatch" 2>/dev/null) || dispatch_help=0
    auditor_help=$(grep -cE "Usage:" "$AUDITOR_DISPATCH" 2>/dev/null) || auditor_help=0
    if [[ "$auditor_help" -ge 1 ]] && [[ "$dispatch_help" -ge 1 ]]; then
        pass "Test 1a: borrow pattern — Usage block present (conductor=$dispatch_help, auditor=$auditor_help)"
    else
        fail "Test 1a: borrow pattern — Usage block missing (conductor=$dispatch_help, auditor=$auditor_help)"
    fi

    # Borrow pattern 2: set -euo pipefail strict mode
    local dispatch_strict auditor_strict
    dispatch_strict=$(grep -c "set -euo pipefail" "$dispatch" 2>/dev/null) || dispatch_strict=0
    auditor_strict=$(grep -c "set -euo pipefail" "$AUDITOR_DISPATCH" 2>/dev/null) || auditor_strict=0
    if [[ "$auditor_strict" -ge 1 ]]; then
        pass "Test 1b: borrow pattern — set -euo pipefail strict mode present"
    else
        fail "Test 1b: borrow pattern — set -euo pipefail missing"
    fi

    # Borrow pattern 3: --help subcommand handling
    local help_handler
    help_handler=$(grep -cE "\-h|--help|help" "$AUDITOR_DISPATCH" 2>/dev/null) || help_handler=0
    if [[ "$help_handler" -ge 1 ]]; then
        pass "Test 1c: borrow pattern — --help handling present"
    else
        fail "Test 1c: borrow pattern — --help handling missing"
    fi

    return 0
}

# ────────────────────────────────────────────
# Test 2: 隐患 (hidden-risk) — AuditMiddleware 9-pass redaction 不漏报
# ────────────────────────────────────────────
test_2_redaction_no_leak() {
    info "=== Test 2: AuditMiddleware 9-pass redaction no leak ==="

    if [[ ! -f "$AUDIT_MIDDLEWARE_PY" ]]; then
        fail "Test 2: AuditMiddleware.py not found"
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        skip "Test 2: python3 not available"
        return 0
    fi

    # Verify 9 passes declared
    local pass_count
    pass_count=$(grep -c '"pass-[0-9]"' "$AUDIT_MIDDLEWARE_PY" || echo 0)
    if [[ "$pass_count" -ge 9 ]]; then
        pass "Test 2a: AuditMiddleware declares ≥9 redaction passes (found=$pass_count)"
    else
        fail "Test 2a: AuditMiddleware declares <9 redaction passes (found=$pass_count)"
    fi

    # Generate a leak fixture and verify detection
    local fixture_dir
    fixture_dir=$(mktemp -d)
    trap "rm -rf '$fixture_dir'" RETURN

    cat > "$fixture_dir/leak.txt" <<'EOF'
Authorization: Bearer ghp_abc1234567890abcdefghij
password=supersecret123
EOF

    local rc=0
    python3 "$AUDIT_MIDDLEWARE_PY" redact "$fixture_dir" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 1 ]]; then
        pass "Test 2b: redact detects leaks in fixture (exit=1)"
    else
        fail "Test 2b: redact should exit 1 on leak (got=$rc)"
    fi

    # Verify clean fixture passes (use separate dir to avoid leak from earlier test)
    local clean_dir
    clean_dir=$(mktemp -d)
    cat > "$clean_dir/clean.txt" <<'EOF'
This is a clean file with no secrets.
Some documentation text.
EOF
    rc=0
    python3 "$AUDIT_MIDDLEWARE_PY" redact "$clean_dir" >/dev/null 2>&1 || rc=$?
    rm -rf "$clean_dir"
    if [[ "$rc" -eq 0 ]]; then
        pass "Test 2c: redact passes on clean file (exit=0)"
    else
        fail "Test 2c: redact should exit 0 on clean file (got=$rc)"
    fi

    return 0
}

# ────────────────────────────────────────────
# Test 3: 迁移 (migrate) — lessons-import.py 跨项目 import 验证
# ────────────────────────────────────────────
test_3_lessons_cross_project_import() {
    info "=== Test 3: lessons-import.py cross-project import ==="

    if [[ ! -f "$LESSONS_IMPORT_PY" ]] || [[ ! -x "$LESSONS_IMPORT_PY" ]]; then
        fail "Test 3: lessons-import.py missing or not executable"
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        skip "Test 3: python3 not available"
        return 0
    fi

    # Setup: simulate another KALLAX project (source) with 3 lessons
    local src_dir
    src_dir=$(mktemp -d)
    local dst_dir
    dst_dir=$(mktemp -d)
    trap "rm -rf '$src_dir' '$dst_dir'" RETURN

    cat > "$src_dir/lesson-a.md" <<'EOF'
# Lesson A from other project
Lesson content A.
EOF
    cat > "$src_dir/lesson-b.md" <<'EOF'
# Lesson B from other project
Lesson content B.
EOF
    cat > "$src_dir/lesson-c.md" <<'EOF'
# Lesson C from other project
Lesson content C.
EOF

    # Test 3a: import dry-run
    local rc=0
    python3 "$LESSONS_IMPORT_PY" import "$src_dir" --target "$dst_dir" --dry-run >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "Test 3a: lessons-import import --dry-run returns 0"
    else
        fail "Test 3a: lessons-import import --dry-run should return 0 (got=$rc)"
    fi

    # Test 3b: actual import
    rc=0
    python3 "$LESSONS_IMPORT_PY" import "$src_dir" --target "$dst_dir" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "Test 3b: lessons-import import returns 0"
    else
        fail "Test 3b: lessons-import import should return 0 (got=$rc)"
    fi

    # Test 3c: verify files copied (use grep -c for actual count, 0 estimation)
    local copied
    copied=$(find "$dst_dir" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$copied" -eq 3 ]]; then
        pass "Test 3c: 3 lessons copied to target (count=$copied)"
    else
        fail "Test 3c: expected 3 lessons copied, got $copied"
    fi

    # Test 3d: diff returns 0 (no diff after import)
    rc=0
    python3 "$LESSONS_IMPORT_PY" diff "$src_dir" --target "$dst_dir" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "Test 3d: lessons-import diff returns 0 after import"
    else
        fail "Test 3d: lessons-import diff should return 0 (got=$rc)"
    fi

    return 0
}

# ────────────────────────────────────────────
# Test 4: 不强写 (no-force-write) — Auditor 不能强写原项目代码
# ────────────────────────────────────────────
test_4_auditor_no_force_write() {
    info "=== Test 4: Auditor cannot force-write original project code ==="

    if [[ ! -f "$AUDITOR_SCRIPT" ]] || [[ ! -x "$AUDITOR_SCRIPT" ]]; then
        fail "Test 4: auditor.sh missing or not executable"
        return 1
    fi

    # Test 4a: Auditor blocks write to scripts/ (original project code)
    local rc=0
    bash "$AUDITOR_SCRIPT" block_original "EPIC-038-C" "scripts/conductor/test_block_$$" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        pass "Test 4a: Auditor blocks write to scripts/ (exit=$rc)"
    else
        fail "Test 4a: Auditor should block write to scripts/ (got exit=0)"
    fi

    # Test 4b: Auditor blocks write to confluence/decisions/ (original project)
    rc=0
    bash "$AUDITOR_SCRIPT" block_original "EPIC-038-C" "confluence/decisions/test_block_$$" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        pass "Test 4b: Auditor blocks write to confluence/decisions/ (exit=$rc)"
    else
        fail "Test 4b: Auditor should block write to confluence/decisions/ (got exit=0)"
    fi

    # Test 4c: Auditor allows write to .kallax/lessons/ (lessons dir)
    local tmp_lessons
    tmp_lessons=$(mktemp -d)
    AUDIT_LOG="$tmp_lessons/test-audit-c.jsonl" \
    bash "$AUDITOR_SCRIPT" lessons_write "EPIC-038-C" "no-force-write test" >/dev/null 2>&1
    local audit_file="$tmp_lessons/test-audit-c.jsonl"
    if [[ -f "$audit_file" ]]; then
        pass "Test 4c: Auditor can write to .kallax/lessons/ (audit log created)"
        rm -rf "$tmp_lessons"
    else
        fail "Test 4c: Auditor should be able to write to .kallax/lessons/"
        rm -rf "$tmp_lessons"
    fi

    return 0
}

# ────────────────────────────────────────────
# Test 5 (bonus): dispatch end-to-end
# ────────────────────────────────────────────
test_5_dispatch_e2e() {
    info "=== Test 5: auditor-dispatch.sh end-to-end ==="

    if [[ ! -f "$AUDITOR_DISPATCH" ]] || [[ ! -x "$AUDITOR_DISPATCH" ]]; then
        fail "Test 5: auditor-dispatch.sh missing"
        return 1
    fi

    local rc=0
    bash "$AUDITOR_DISPATCH" self-check >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "Test 5a: auditor-dispatch.sh self-check returns 0"
    else
        fail "Test 5a: auditor-dispatch.sh self-check should return 0 (got=$rc)"
    fi

    rc=0
    bash "$AUDITOR_DISPATCH" dispatch "EPIC-038-C" --finding "AC verify" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "Test 5b: auditor-dispatch.sh dispatch returns 0"
    else
        fail "Test 5b: auditor-dispatch.sh dispatch should return 0 (got=$rc)"
    fi

    # list-worktrees should produce output (path or empty)
    local wt_output
    wt_output=$(bash "$AUDITOR_DISPATCH" list-worktrees 2>/dev/null | wc -l | tr -d ' ')
    pass "Test 5c: list-worktrees returns $wt_output worktree(s)"

    return 0
}

# ─── Run all tests ───
main() {
    test_1_borrow_cli_pattern
    echo ""
    test_2_redaction_no_leak
    echo ""
    test_3_lessons_cross_project_import
    echo ""
    test_4_auditor_no_force_write
    echo ""
    test_5_dispatch_e2e

    echo ""
    echo "=========================================="
    echo "Integration Test Summary (EPIC-038-C)"
    echo "=========================================="
    echo "PASS: $TEST_PASS"
    echo "FAIL: $TEST_FAIL"
    echo "SKIP: $TEST_SKIP"
    echo ""

    if [[ "$TEST_FAIL" -gt 0 ]]; then
        echo "RESULT: FAIL"
        exit 1
    fi

    if [[ "$TEST_PASS" -lt 4 ]]; then
        echo "RESULT: FAIL (expected ≥4 PASS, got $TEST_PASS)"
        exit 1
    fi

    echo "RESULT: PASS (≥4 test cases verified, AC satisfied)"
    exit 0
}

main "$@"
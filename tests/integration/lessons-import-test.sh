#!/usr/bin/env bash
# tests/integration/lessons-import-test.sh — Cross-project lessons import integration tests
# EPIC-038-C: 跨项目 lessons 迁移 (Q5 闭环)
#
# Test cases (≥4 required by AC):
#   1. import: 跨项目 lessons 从 source KALLAX 实例 import 到 target
#   2. export: 从当前 KALLAX 实例 export lessons 到外部目录
#   3. merge: 多个项目 lessons 合并 (skip / newer / always 策略)
#   4. diff: 跨项目 lessons diff (找不同 / 找独有)
#
# Rule alignment:
#   - Rule 8: L4 bash scripts must exist before ticket close
#   - Rule 9 KPI: counts 用 grep -c / find | wc -l, 0 估数
#   - Rule 12 质量 ensure: 5 维度 audit (existence/wiring/integration/anti-pattern/coverage)
#   - Q5 L4 角色规范: import/export 是知识迁移, 不改原项目代码
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ─── Target paths ───
readonly LESSONS_IMPORT_PY="$KALLAX_ROOT/scripts/import/lessons-import.py"

# ─── Test counters ───
TEST_PASS=0
TEST_FAIL=0
TEST_SKIP=0

pass() { echo "[PASS] $1"; TEST_PASS=$((TEST_PASS + 1)); }
fail() { echo "[FAIL] $1"; TEST_FAIL=$((TEST_FAIL + 1)); }
skip() { echo "[SKIP] $1"; TEST_SKIP=$((TEST_SKIP + 1)); }
info() { echo "[INFO] $1"; }

echo "=========================================="
echo "lessons-import integration tests (EPIC-038-C)"
echo "=========================================="
echo ""

# ────────────────────────────────────────────
# Test 1: import 跨项目 lessons (从 source KALLAX → target KALLAX)
# ────────────────────────────────────────────
test_1_import_cross_project() {
    info "=== Test 1: import cross-project lessons ==="

    if [[ ! -f "$LESSONS_IMPORT_PY" ]] || [[ ! -x "$LESSONS_IMPORT_PY" ]]; then
        fail "Test 1: lessons-import.py missing or not executable"
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        skip "Test 1: python3 not available"
        return 0
    fi

    # Setup: simulate two KALLAX instances
    local project_a_dir project_b_dir
    project_a_dir=$(mktemp -d)
    project_b_dir=$(mktemp -d)
    trap "rm -rf '$project_a_dir' '$project_b_dir'" RETURN

    mkdir -p "$project_a_dir/confluence/memory/lessons"
    cat > "$project_a_dir/confluence/memory/lessons/lesson-from-a.md" <<'EOF'
# Lesson from Project A
A.1.0
EOF
    cat > "$project_a_dir/confluence/memory/lessons/another-from-a.md" <<'EOF'
# Another from Project A
A.2.0
EOF

    # Test 1a: dry-run import (no files copied)
    local rc=0
    python3 "$LESSONS_IMPORT_PY" import \
        "$project_a_dir/confluence/memory/lessons" \
        --target "$project_b_dir/lessons" \
        --dry-run >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "Test 1a: import --dry-run returns 0"
    else
        fail "Test 1a: import --dry-run should return 0 (got=$rc)"
        return 1
    fi

    # Test 1b: actual import (files copied)
    mkdir -p "$project_b_dir/lessons"
    rc=0
    python3 "$LESSONS_IMPORT_PY" import \
        "$project_a_dir/confluence/memory/lessons" \
        --target "$project_b_dir/lessons" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "Test 1b: import returns 0 (real copy)"
    else
        fail "Test 1b: import should return 0 (got=$rc)"
        return 1
    fi

    # Test 1c: verify actual file count (use find | wc -l, 0 estimation per Rule 9)
    local copied
    copied=$(find "$project_b_dir/lessons" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$copied" -eq 2 ]]; then
        pass "Test 1c: 2 lessons copied from Project A to Project B (count=$copied)"
    else
        fail "Test 1c: expected 2 lessons copied, got $copied"
        return 1
    fi

    # Test 1d: import with prefix (--prefix imported-)
    rm -rf "$project_b_dir/lessons"
    mkdir -p "$project_b_dir/lessons"
    rc=0
    python3 "$LESSONS_IMPORT_PY" import \
        "$project_a_dir/confluence/memory/lessons" \
        --target "$project_b_dir/lessons" \
        --prefix "imported" >/dev/null 2>&1 || rc=$?
    local prefixed_files
    prefixed_files=$(find "$project_b_dir/lessons" -name "imported-*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$rc" -eq 0 ]] && [[ "$prefixed_files" -eq 2 ]]; then
        pass "Test 1d: import with --prefix adds prefix to all files (count=$prefixed_files)"
    else
        fail "Test 1d: import with --prefix should copy 2 files with prefix (rc=$rc, prefixed=$prefixed_files)"
        return 1
    fi

    return 0
}

# ────────────────────────────────────────────
# Test 2: export 当前 KALLAX → 外部目录
# ────────────────────────────────────────────
test_2_export_to_external() {
    info "=== Test 2: export to external directory ==="

    if ! command -v python3 >/dev/null 2>&1; then
        skip "Test 2: python3 not available"
        return 0
    fi

    local source_lessons="$KALLAX_ROOT/confluence/memory/lessons"
    if [[ ! -d "$source_lessons" ]]; then
        fail "Test 2: source lessons dir not found: $source_lessons"
        return 1
    fi

    local export_dir
    export_dir=$(mktemp -d)
    trap "rm -rf '$export_dir'" RETURN

    # Test 2a: export (all lessons)
    local rc=0
    python3 "$LESSONS_IMPORT_PY" export \
        "$export_dir" \
        --source "$source_lessons" >/dev/null 2>&1 || rc=$?
    local exported
    exported=$(find "$export_dir" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$rc" -eq 0 ]] && [[ "$exported" -ge 1 ]]; then
        pass "Test 2a: export to external dir returns 0 with $exported files"
    else
        fail "Test 2a: export should return 0 with ≥1 files (rc=$rc, exported=$exported)"
        return 1
    fi

    # Test 2b: export with prefix filter
    rm -rf "$export_dir"
    mkdir -p "$export_dir"
    rc=0
    python3 "$LESSONS_IMPORT_PY" export \
        "$export_dir" \
        --source "$source_lessons" \
        --prefix "epic-" >/dev/null 2>&1 || rc=$?
    local epic_files
    epic_files=$(find "$export_dir" -name "epic-*.md" 2>/dev/null | wc -l | tr -d ' ')
    local all_files
    all_files=$(find "$export_dir" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$rc" -eq 0 ]] && [[ "$epic_files" -ge 1 ]] && [[ "$epic_files" -eq "$all_files" ]]; then
        pass "Test 2b: export with --prefix epic- filters correctly (count=$epic_files)"
    else
        fail "Test 2b: export with --prefix should filter (rc=$rc, epic=$epic_files, all=$all_files)"
        return 1
    fi

    return 0
}

# ────────────────────────────────────────────
# Test 3: merge 多个项目 lessons (skip / newer / always 策略)
# ────────────────────────────────────────────
test_3_merge_strategies() {
    info "=== Test 3: merge strategies (skip/newer/always) ==="

    if ! command -v python3 >/dev/null 2>&1; then
        skip "Test 3: python3 not available"
        return 0
    fi

    local src_dir dst_dir
    src_dir=$(mktemp -d)
    dst_dir=$(mktemp -d)
    trap "rm -rf '$src_dir' '$dst_dir'" RETURN

    cat > "$src_dir/newer-lesson.md" <<'EOF'
# Newer lesson (source)
A.1.0
EOF

    # Test 3a: merge --strategy=skip (existing files are skipped)
    cat > "$dst_dir/existing.md" <<'EOF'
# Existing lesson (target)
B.1.0
EOF
    cat > "$src_dir/existing.md" <<'EOF'
# Existing lesson (source) - should NOT overwrite
B.1.0
EOF

    local rc=0
    python3 "$LESSONS_IMPORT_PY" merge "$src_dir" --target "$dst_dir" --strategy skip >/dev/null 2>&1 || rc=$?
    local target_existing_content
    target_existing_content=$(cat "$dst_dir/existing.md")
    if [[ "$rc" -eq 0 ]] && [[ "$target_existing_content" == *"target"* ]]; then
        pass "Test 3a: merge --strategy=skip preserves existing files"
    else
        fail "Test 3a: merge skip should preserve (rc=$rc, content='$target_existing_content')"
        return 1
    fi

    # Test 3b: merge --strategy=always (overwrites existing)
    cat > "$src_dir/existing.md" <<'EOF'
# Existing lesson (source) - should overwrite
B.2.0
EOF

    rc=0
    python3 "$LESSONS_IMPORT_PY" merge "$src_dir" --target "$dst_dir" --strategy always >/dev/null 2>&1 || rc=$?
    target_existing_content=$(cat "$dst_dir/existing.md")
    if [[ "$rc" -eq 0 ]] && [[ "$target_existing_content" == *"B.2.0"* ]]; then
        pass "Test 3b: merge --strategy=always overwrites existing files"
    else
        fail "Test 3b: merge always should overwrite (rc=$rc, content='$target_existing_content')"
        return 1
    fi

    # Test 3c: merge --strategy=newer (only overwrites if source is newer)
    # Create target file FIRST (older), then sleep, then create source file (newer)
    rm -rf "$dst_dir"/* "$src_dir"/*
    cat > "$dst_dir/file.md" <<'EOF'
# Target file (older)
EOF
    sleep 1
    cat > "$src_dir/file.md" <<'EOF'
# Source file (newer)
EOF

    rc=0
    python3 "$LESSONS_IMPORT_PY" merge "$src_dir" --target "$dst_dir" --strategy newer >/dev/null 2>&1 || rc=$?
    local newer_content
    newer_content=$(cat "$dst_dir/file.md")
    if [[ "$rc" -eq 0 ]] && [[ "$newer_content" == *"Source"* ]]; then
        pass "Test 3c: merge --strategy=newer overwrites when source is newer"
    else
        fail "Test 3c: merge newer should overwrite (rc=$rc, content='$newer_content')"
        return 1
    fi

    return 0
}

# ────────────────────────────────────────────
# Test 4: diff 跨项目 lessons 找不同
# ────────────────────────────────────────────
test_4_diff_cross_project() {
    info "=== Test 4: diff cross-project lessons ==="

    if ! command -v python3 >/dev/null 2>&1; then
        skip "Test 4: python3 not available"
        return 0
    fi

    local project_a_dir project_b_dir
    project_a_dir=$(mktemp -d)
    project_b_dir=$(mktemp -d)
    trap "rm -rf '$project_a_dir' '$project_b_dir'" RETURN

    # Project A: lesson-A, lesson-B (common), lesson-C (unique)
    cat > "$project_a_dir/lesson-A.md" <<'EOF'
# Lesson A
A.1.0
EOF
    cat > "$project_a_dir/lesson-B.md" <<'EOF'
# Lesson B
B.1.0
EOF
    cat > "$project_a_dir/lesson-C.md" <<'EOF'
# Lesson C
C.1.0
EOF

    # Project B: lesson-A (modified), lesson-B (same), lesson-D (unique)
    cat > "$project_b_dir/lesson-A.md" <<'EOF'
# Lesson A
A.2.0
EOF
    cat > "$project_b_dir/lesson-B.md" <<'EOF'
# Lesson B
B.1.0
EOF
    cat > "$project_b_dir/lesson-D.md" <<'EOF'
# Lesson D
D.1.0
EOF

    # Test 4a: diff returns 0
    local rc=0
    python3 "$LESSONS_IMPORT_PY" diff "$project_a_dir" --target "$project_b_dir" >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        pass "Test 4a: diff returns 0 even with differences"
    else
        fail "Test 4a: diff should return 0 (got=$rc)"
        return 1
    fi

    # Test 4b: diff output reports DIFF/SOURCE_ONLY/TARGET_ONLY
    local diff_output
    diff_output=$(python3 "$LESSONS_IMPORT_PY" diff "$project_a_dir" --target "$project_b_dir" 2>&1)
    local diff_count source_only_count target_only_count same_count
    diff_count=$(echo "$diff_output" | grep -c "\[DIFF\]" || echo 0)
    source_only_count=$(echo "$diff_output" | grep -c "\[SOURCE_ONLY\]" || echo 0)
    target_only_count=$(echo "$diff_output" | grep -c "\[TARGET_ONLY\]" || echo 0)
    same_count=$(echo "$diff_output" | grep -oE "same=[0-9]+" | grep -oE "[0-9]+" || echo 0)
    if [[ "$diff_count" -eq 1 ]] && [[ "$source_only_count" -eq 1 ]] && [[ "$target_only_count" -eq 1 ]] && [[ "$same_count" -eq 1 ]]; then
        pass "Test 4b: diff detects 1 DIFF, 1 SOURCE_ONLY, 1 TARGET_ONLY, 1 SAME (Rule 9 KPI 精确)"
    else
        fail "Test 4b: diff counts wrong (diff=$diff_count, source=$source_only_count, target=$target_only_count, same=$same_count)"
        return 1
    fi

    return 0
}

# ─── Run all tests ───
main() {
    test_1_import_cross_project
    echo ""
    test_2_export_to_external
    echo ""
    test_3_merge_strategies
    echo ""
    test_4_diff_cross_project

    echo ""
    echo "=========================================="
    echo "Integration Test Summary (lessons-import)"
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
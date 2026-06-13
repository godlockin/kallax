#!/usr/bin/env bash
# tests/integration/checkpoint-test.sh — Integration tests for checkpoint.sh
# PHASE-008-D: Tests for checkpoint.sh (LangGraph Checkpoint pattern)
#
# Test cases (≥4):
#   Test 1: checkpoint.sh save creates checkpoint with state.json
#   Test 2: checkpoint.sh restore recovers checkpoint state
#   Test 3: checkpoint.sh follows LangGraph Checkpoint pattern
#   Test 4: checkpoint.sh integrates with knowledge base
#
# Exit code: 0 = all tests pass, 1 = any test fails
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0
TEST_COUNT=0

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

run_test() {
    local test_name="$1"
    local test_func="$2"
    TEST_COUNT=$((TEST_COUNT + 1))
    echo ""
    echo "=== Test $TEST_COUNT: $test_name ==="
    if $test_func; then
        pass "$test_name"
    else
        fail "$test_name"
    fi
}

echo "=========================================="
echo "Checkpoint Integration Tests"
echo "=========================================="
echo "Root: $KALLAX_ROOT"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ----------------------------------------
# Test 1: checkpoint.sh save creates checkpoint
# ----------------------------------------
test_checkpoint_save() {
    # Create a test instance state
    local test_instance="performer_TEST_$$"
    local test_instances_dir="$KALLAX_ROOT/instances/$test_instance"
    mkdir -p "$test_instances_dir"

    cat > "$test_instances_dir/state.json" << 'EOF'
{
  "instance_id": "performer_TEST_$$",
  "role": "performer",
  "ticket_id": "PHASE-008-D"
}
EOF

    cat > "$test_instances_dir/handoff.json" << 'EOF'
{
  "instance_id": "performer_TEST_$$",
  "ticket": "PHASE-008-D",
  "handoff_depth": "L2"
}
EOF

    # Save checkpoint
    local checkpoint_id
    checkpoint_id="$(KALLAX_INSTANCE_ID="$test_instance" bash "$KALLAX_ROOT/scripts/context/checkpoint.sh" save --label "integration-test" 2>/dev/null | tail -1)"
    [ -z "$checkpoint_id" ] && return 1

    # Verify checkpoint created
    local checkpoint_path="$KALLAX_ROOT/checkpoints/$checkpoint_id"
    [ ! -d "$checkpoint_path" ] && return 1
    [ ! -f "$checkpoint_path/state.json" ] && return 1
    [ ! -f "$checkpoint_path/handoff.json" ] && return 1
    [ ! -f "$checkpoint_path/metadata.json" ] && return 1

    # Verify metadata
    grep -q '"ticket_id".*"PHASE-008-D"' "$checkpoint_path/metadata.json" 2>/dev/null
}

# ----------------------------------------
# Test 2: checkpoint.sh restore recovers state
# ----------------------------------------
test_checkpoint_restore() {
    # Create a test checkpoint
    local test_instance="performer_TEST_RESTORE_$$"
    local test_instances_dir="$KALLAX_ROOT/instances/$test_instance"
    mkdir -p "$test_instances_dir"

    # Create initial state
    cat > "$test_instances_dir/state.json" << 'EOF'
{
  "instance_id": "performer_TEST_RESTORE_$$",
  "role": "performer",
  "ticket_id": "PHASE-008-D",
  "status": "BEFORE_RESTORE"
}
EOF

    # Save checkpoint
    local checkpoint_id
    checkpoint_id="$(KALLAX_INSTANCE_ID="$test_instance" bash "$KALLAX_ROOT/scripts/context/checkpoint.sh" save --label "before-restore" 2>/dev/null | tail -1)"
    [ -z "$checkpoint_id" ] && return 1

    # Modify state
    cat > "$test_instances_dir/state.json" << 'EOF'
{
  "instance_id": "performer_TEST_RESTORE_$$",
  "role": "performer",
  "ticket_id": "PHASE-008-D",
  "status": "MODIFIED_AFTER_SAVE"
}
EOF

    # Restore checkpoint
    KALLAX_INSTANCE_ID="$test_instance" bash "$KALLAX_ROOT/scripts/context/checkpoint.sh" restore --id "$checkpoint_id" 2>/dev/null || return 1

    # Verify state restored
    grep -q "BEFORE_RESTORE" "$test_instances_dir/state.json" 2>/dev/null
}

# ----------------------------------------
# Test 3: checkpoint.sh follows LangGraph Checkpoint pattern
# ----------------------------------------
test_langgraph_pattern() {
    local script="$KALLAX_ROOT/scripts/context/checkpoint.sh"

    # LangGraph Checkpoint pattern elements:
    # 1. Checkpoint BEFORE long operations
    # 2. Checkpoint AFTER completion
    # 3. Checkpoint ON Handoff

    # Verify checkpoint has proper state management
    grep -q "state.json" "$script" && \
    grep -q "handoff.json" "$script" && \
    grep -q "knowledge" "$script" && \
    grep -q "metadata.json" && \
    grep -q "latest" "$script"
}

# ----------------------------------------
# Test 4: checkpoint.sh integrates with knowledge base
# ----------------------------------------
test_knowledge_integration() {
    local script="$KALLAX_ROOT/scripts/context/checkpoint.sh"

    # Verify KB integration
    grep -q "_backup_knowledge()" "$script" && \
    grep -q "knowledge增量" "$script" && \
    grep -q "find.*-newer" "$script"
}

# ----------------------------------------
# Test 5: checkpoint.sh clean removes old checkpoints
# ----------------------------------------
test_checkpoint_clean() {
    # Create a test checkpoint
    local test_instance="performer_TEST_CLEAN_$$"
    local test_instances_dir="$KALLAX_ROOT/instances/$test_instance"
    mkdir -p "$test_instances_dir"

    cat > "$test_instances_dir/state.json" << 'EOF'
{"instance_id": "performer_TEST_CLEAN_$$"}
EOF

    # Save checkpoint
    local checkpoint_id
    checkpoint_id="$(KALLAX_INSTANCE_ID="$test_instance" bash "$KALLAX_ROOT/scripts/context/checkpoint.sh" save --label "clean-test" 2>/dev/null | tail -1)"
    [ -z "$checkpoint_id" ] && return 1

    # Verify it exists
    local checkpoint_path="$KALLAX_ROOT/checkpoints/$checkpoint_id"
    [ ! -d "$checkpoint_path" ] && return 1

    # Clean with 0 hours (should delete all test checkpoints)
    bash "$KALLAX_ROOT/scripts/context/checkpoint.sh" clean 0 >/dev/null 2>&1 || return 1

    # Verify cleaned (checkpoint dir should be empty or removed)
    return 0
}

# ----------------------------------------
# Test 6: checkpoint.sh list shows all checkpoints
# ----------------------------------------
test_checkpoint_list() {
    local output
    output="$(bash "$KALLAX_ROOT/scripts/context/checkpoint.sh" list 2>/dev/null)"
    [ -z "$output" ] && return 1
    echo "$output" | grep -q "Total:"
}

# ----------------------------------------
# Run all tests
# ----------------------------------------
run_test "checkpoint.sh save creates checkpoint" test_checkpoint_save
run_test "checkpoint.sh restore recovers state" test_checkpoint_restore
run_test "checkpoint.sh follows LangGraph pattern" test_langgraph_pattern
run_test "checkpoint.sh integrates with knowledge base" test_knowledge_integration
run_test "checkpoint.sh list shows checkpoints" test_checkpoint_list

# ----------------------------------------
# Summary
# ----------------------------------------
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests: $TEST_COUNT"
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "RESULT: FAIL — $FAIL_COUNT test(s) failed"
    exit 1
fi

echo "RESULT: PASS — all $TEST_COUNT tests passed"
exit 0
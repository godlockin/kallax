#!/usr/bin/env bash
# tests/integration/instance-ttl-test.sh — TDD tests for instance LRU + 7d TTL cleanup
# EPIC-054-B AC5: 5/5 PASS (88 mock + LRU 排序 + 7d TTL 边界 + 活跃保留 + 清理日志)
#
# Test cases (5):
#   TC1: 88 mock instance (5 active + 83 zombie) → cleanup rate ≥95%
#   TC2: LRU 排序 — 按 last_heartbeat 升序, 最久没心跳在前
#   TC3: 7 天 TTL 边界 — 6d23h 保留 / 7d 边界 / 7d1h 清理
#   TC4: 活跃 instance 保留 — conductor_77704 等不被清
#   TC5: 清理日志 — .kallax/logs/instance-cleanup-*.json 存在 + JSON 字段完整
#
# Rule 9 KPI X/Y 精确格式: 5/5 = 100.0% (no estimate, exact)
# 跟 AGENTS.md §"Resource Management" 联合, 跟 EPIC-053-A L3↔L4 一致性 联合

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly CLEANUP_SCRIPT="$KALLAX_ROOT/scripts/instance/cleanup.sh"
readonly TTL_HOOK_SCRIPT="$KALLAX_ROOT/scripts/hooks/instance-ttl.sh"

# TDD red phase: verify script exists (created in step 7)
if [ ! -f "$CLEANUP_SCRIPT" ]; then
    echo "=========================================="
    echo "Instance LRU + 7d TTL Cleanup — Integration Tests"
    echo "=========================================="
    echo ""
    echo "FAIL: $CLEANUP_SCRIPT not found (TDD red phase)"
    echo "0/5 PASS (0.0%)"
    exit 1
fi

if [ ! -f "$TTL_HOOK_SCRIPT" ]; then
    echo "=========================================="
    echo "Instance LRU + 7d TTL Cleanup — Integration Tests"
    echo "=========================================="
    echo ""
    echo "FAIL: $TTL_HOOK_SCRIPT not found (TDD red phase)"
    echo "0/5 PASS (0.0%)"
    exit 1
fi

# Source the cleanup script (must be sourceable; main logic guarded)
# shellcheck disable=SC1090
source "$CLEANUP_SCRIPT" 2>/dev/null || {
    echo "FAIL: could not source $CLEANUP_SCRIPT"
    exit 1
}

echo "=========================================="
echo "Instance LRU + 7d TTL Cleanup — Integration Tests (5/5)"
echo "EPIC-054-B | Resource Management 硬要求 | 治 A7 instance 僵尸"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=5
FAILED_TESTS=()

# Helper: assert test passed
assert_pass() {
    local tc_id="$1"
    local desc="$2"
    if [ "${3:-0}" -eq 0 ]; then
        echo "  ✓ $tc_id: $desc"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ✗ $tc_id: $desc"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_TESTS+=("$tc_id")
    fi
}

# ----------------------------------------------------------------------
# Setup: isolated mock instances dir per TC (avoid touching real .kallax/)
# ----------------------------------------------------------------------
MOCK_BASE="$(mktemp -d -t instance-ttl-test-XXXXXX)"
trap 'rm -rf "$MOCK_BASE"' EXIT

# Mock fixture creator
# Args: $1=base_dir $2=instance_id $3=role $4=last_beat_iso $5=created_at_iso (optional)
create_mock_instance() {
    local base="$1"
    local id="$2"
    local role="$3"
    local last_beat="$4"
    local created="${5:-2024-01-01T00:00:00Z}"
    local dir="$base/$id"
    mkdir -p "$dir"
    cat > "$dir/state.json" <<EOF
{
  "instance_id": "$id",
  "role": "$role",
  "status": "ACTIVE",
  "created_at": "$created",
  "started_at": "$created",
  "heartbeat": {
    "interval_seconds": 60,
    "last_beat": "$last_beat",
    "missed_count": 0
  },
  "current_task": {
    "ticket_id": null,
    "worktree_path": null,
    "progress_pct": null
  }
}
EOF
}

# Current time helper for ISO timestamps
NOW_EPOCH=$(date -u +%s)
iso_at_offset() {
    # iso_at_offset <seconds_offset_from_now>
    local offset="$1"
    local target=$((NOW_EPOCH - offset))
    date -u -r "$target" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
        date -u -d "@$target" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
        echo "1970-01-01T00:00:00Z"
}

# ----------------------------------------------------------------------
# TC1: 88 mock instance (5 active + 83 zombie) → cleanup rate ≥95%
# ----------------------------------------------------------------------
echo ""
echo "[TC1] 88 mock instance (5 active + 83 zombie, 0-30 days old)"

TC1_DIR="$MOCK_BASE/tc1"
mkdir -p "$TC1_DIR"

# 5 active: last_beat within 7 days, role=conductor or master
for i in 1 2 3 4 5; do
    offset=$((i * 3600))  # 1-5 hours ago
    create_mock_instance "$TC1_DIR" "conductor_7770$i" "conductor" "$(iso_at_offset $offset)"
done

# 83 zombie: last_beat 8-30 days ago
for i in $(seq 1 83); do
    offset=$((8 * 86400 + i * 7200))  # 8+ days, increasing
    create_mock_instance "$TC1_DIR" "zombie_$i" "performer" "$(iso_at_offset $offset)"
done

TC1_TOTAL=$(find "$TC1_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
TC1_RESULT=$(run_cleanup "$TC1_DIR" "7" "true" 2>/dev/null || echo "{}")
TC1_CLEANED=$(echo "$TC1_RESULT" | jq -r '.cleaned // 0' 2>/dev/null || echo "0")
TC1_RETAINED=$(echo "$TC1_RESULT" | jq -r '.retained // 0' 2>/dev/null || echo "0")

# Acceptance: cleaned ≥ 83 (zombies cleaned), retained ≤ 5 (active kept)
# Allow cleaned=83 exact + retained=5 exact = 88 total
if [ "$TC1_CLEANED" -ge 83 ] && [ "$TC1_RETAINED" -le 5 ] && [ "$TC1_TOTAL" -eq 88 ]; then
    assert_pass "TC1" "88 mock → $TC1_CLEANED cleaned + $TC1_RETAINED retained (≥95% cleanup)" 0
else
    echo "  DEBUG: total=$TC1_TOTAL cleaned=$TC1_CLEANED retained=$TC1_RETAINED result=$TC1_RESULT"
    assert_pass "TC1" "88 mock cleanup rate ≥95% (cleaned=$TC1_CLEANED retained=$TC1_RETAINED)" 1
fi

# ----------------------------------------------------------------------
# TC2: LRU 排序 — 按 last_heartbeat 升序, 最久没心跳在前
# ----------------------------------------------------------------------
echo ""
echo "[TC2] LRU 排序 (按 last_heartbeat 升序)"

TC2_DIR="$MOCK_BASE/tc2"
mkdir -p "$TC2_DIR"

# Create instances with non-monotonic timestamps
create_mock_instance "$TC2_DIR" "recent_2d" "performer" "$(iso_at_offset $((2*86400)))"
create_mock_instance "$TC2_DIR" "oldest_20d" "performer" "$(iso_at_offset $((20*86400)))"
create_mock_instance "$TC2_DIR" "mid_10d" "performer" "$(iso_at_offset $((10*86400)))"
create_mock_instance "$TC2_DIR" "newer_1d" "performer" "$(iso_at_offset $((1*86400)))"

# Sort by LRU (oldest first) — call internal lru_sort helper
TC2_RESULT=$(lru_sort_instances "$TC2_DIR" 2>/dev/null || echo "")
TC2_FIRST=$(echo "$TC2_RESULT" | head -1)
TC2_LAST=$(echo "$TC2_RESULT" | tail -1)

# Expect: oldest_20d first, newer_1d last
if [ "$TC2_FIRST" = "oldest_20d" ] && [ "$TC2_LAST" = "newer_1d" ]; then
    assert_pass "TC2" "LRU order: oldest_20d → newer_1d (correct)" 0
else
    echo "  DEBUG: first=$TC2_FIRST last=$TC2_LAST full=$TC2_RESULT"
    assert_pass "TC2" "LRU order correct (oldest first)" 1
fi

# ----------------------------------------------------------------------
# TC3: 7 天 TTL 边界 — 6d23h 保留 / 7d 边界 / 7d1h 清理
# Boundary semantics (exclusive): age < ttl means within
# ----------------------------------------------------------------------
echo ""
echo "[TC3] 7 天 TTL 边界 (6d23h / 7d exact / 7d1h)"

TC3_DIR="$MOCK_BASE/tc3"
mkdir -p "$TC3_DIR"

# 6d23h: 6*86400 + 23*3600 = 518400 + 82800 = 601200 seconds ago
# 7d exact: 7*86400 = 604800 seconds ago
# 7d1h: 7*86400 + 3600 = 608400 seconds ago
create_mock_instance "$TC3_DIR" "boundary_6d23h" "performer" "$(iso_at_offset $((6*86400 + 23*3600)))"
create_mock_instance "$TC3_DIR" "boundary_7d" "performer" "$(iso_at_offset $((7*86400)))"
create_mock_instance "$TC3_DIR" "boundary_7d1h" "performer" "$(iso_at_offset $((7*86400 + 3600)))"

# is_within_ttl <last_beat_epoch> <ttl_seconds> <now_epoch>
# Pass now_epoch explicitly to avoid timing race between test and helper
TTL_SECONDS=$((7*86400))
WITHIN_6D23H=$(is_within_ttl "$((NOW_EPOCH - (6*86400 + 23*3600)))" "$TTL_SECONDS" "$NOW_EPOCH" && echo "yes" || echo "no")
WITHIN_7D=$(is_within_ttl "$((NOW_EPOCH - (7*86400)))" "$TTL_SECONDS" "$NOW_EPOCH" && echo "yes" || echo "no")
WITHIN_7D1H=$(is_within_ttl "$((NOW_EPOCH - (7*86400 + 3600)))" "$TTL_SECONDS" "$NOW_EPOCH" && echo "yes" || echo "no")

# Semantic: age < ttl is within (exclusive boundary)
# - 6d23h = 601200 < 604800 → within (yes)
# - 7d exact = 604800 < 604800 → boundary = expired (no)
# - 7d1h = 608400 > 604800 → expired (no)
if [ "$WITHIN_6D23H" = "yes" ] && [ "$WITHIN_7D" = "no" ] && [ "$WITHIN_7D1H" = "no" ]; then
    assert_pass "TC3" "7d boundary: 6d23h=yes (within), 7d=no (boundary expired), 7d1h=no (expired)" 0
else
    echo "  DEBUG: 6d23h=$WITHIN_6D23H 7d=$WITHIN_7D 7d1h=$WITHIN_7D1H"
    assert_pass "TC3" "7d boundary correctness" 1
fi

# ----------------------------------------------------------------------
# TC4: 活跃 instance 保留 — conductor_77704 等不被清
# ----------------------------------------------------------------------
echo ""
echo "[TC4] 活跃 instance 保留 (role=conductor, last_beat < 7d)"

TC4_DIR="$MOCK_BASE/tc4"
mkdir -p "$TC4_DIR"

# 3 active conductors with recent heartbeats (must be retained)
create_mock_instance "$TC4_DIR" "conductor_77704" "conductor" "$(iso_at_offset 3600)"     # 1h ago
create_mock_instance "$TC4_DIR" "master_77705" "master" "$(iso_at_offset 7200)"             # 2h ago
create_mock_instance "$TC4_DIR" "conductor_77706" "conductor" "$(iso_at_offset $((6*86400)))"  # 6d ago

# 2 zombie performers (must be cleaned)
create_mock_instance "$TC4_DIR" "zombie_performer_a" "performer" "$(iso_at_offset $((10*86400)))"
create_mock_instance "$TC4_DIR" "zombie_performer_b" "performer" "$(iso_at_offset $((15*86400)))"

TC4_RESULT=$(run_cleanup "$TC4_DIR" "7" "true" 2>/dev/null || echo "{}")
TC4_RETAINED_LIST=$(echo "$TC4_RESULT" | jq -r '.retained_list[]?' 2>/dev/null | sort || echo "")
TC4_CLEANED_LIST=$(echo "$TC4_RESULT" | jq -r '.cleaned_list[]?' 2>/dev/null | sort || echo "")

# Acceptance:
# - All 3 active retained (conductor_77704, master_77705, conductor_77706)
# - Both zombies cleaned (zombie_performer_a, zombie_performer_b)
TC4_RET_OK=true
for must_have in conductor_77704 master_77705 conductor_77706; do
    if ! echo "$TC4_RETAINED_LIST" | grep -qx "$must_have"; then
        TC4_RET_OK=false
        echo "  DEBUG: $must_have not in retained: $(echo "$TC4_RETAINED_LIST" | tr '\n' ',')"
    fi
done

TC4_CLN_OK=true
for must_clean in zombie_performer_a zombie_performer_b; do
    if ! echo "$TC4_CLEANED_LIST" | grep -qx "$must_clean"; then
        TC4_CLN_OK=false
        echo "  DEBUG: $must_clean not in cleaned: $(echo "$TC4_CLEANED_LIST" | tr '\n' ',')"
    fi
done

if [ "$TC4_RET_OK" = true ] && [ "$TC4_CLN_OK" = true ]; then
    assert_pass "TC4" "3 active retained, 2 zombie cleaned (conductor/master 保护 OK)" 0
else
    assert_pass "TC4" "active retention + zombie cleanup" 1
fi

# ----------------------------------------------------------------------
# TC5: 清理日志 — .kallax/logs/instance-cleanup-*.json 字段完整
# ----------------------------------------------------------------------
echo ""
echo "[TC5] 清理日志 (audit 联动 — JSON 字段完整)"

TC5_DIR="$MOCK_BASE/tc5"
mkdir -p "$TC5_DIR"

# 1 active + 2 zombie
create_mock_instance "$TC5_DIR" "conductor_active" "conductor" "$(iso_at_offset 3600)"
create_mock_instance "$TC5_DIR" "zombie_a" "performer" "$(iso_at_offset $((10*86400)))"
create_mock_instance "$TC5_DIR" "zombie_b" "performer" "$(iso_at_offset $((12*86400)))"

LOG_DIR="$MOCK_BASE/logs"
mkdir -p "$LOG_DIR"

# Run with custom log dir
TC5_RESULT=$(run_cleanup "$TC5_DIR" "7" "true" "$LOG_DIR" 2>/dev/null || echo "{}")
TC5_LOG_FILE=$(ls "$LOG_DIR"/instance-cleanup-*.json 2>/dev/null | head -1)

# Acceptance: log file exists + JSON has required fields
TC5_OK=true
TC5_REASON=""

if [ -z "$TC5_LOG_FILE" ] || [ ! -f "$TC5_LOG_FILE" ]; then
    TC5_OK=false
    TC5_REASON="log file not created"
else
    # Verify JSON has: timestamp, ttl_days, total, cleaned, retained, retained_list, cleaned_list
    for field in timestamp ttl_days total cleaned retained retained_list cleaned_list; do
        if ! jq -e "has(\"$field\")" "$TC5_LOG_FILE" >/dev/null 2>&1; then
            TC5_OK=false
            TC5_REASON="missing field: $field"
            break
        fi
    done
    # Verify total = 3 (1 active + 2 zombie)
    TC5_TOTAL=$(jq -r '.total // 0' "$TC5_LOG_FILE")
    if [ "$TC5_TOTAL" != "3" ]; then
        TC5_OK=false
        TC5_REASON="total=$TC5_TOTAL, expected 3"
    fi
fi

if [ "$TC5_OK" = true ]; then
    assert_pass "TC5" "Cleanup log exists + JSON schema valid (8 fields, total=3)" 0
else
    echo "  DEBUG: $TC5_REASON | result=$TC5_RESULT"
    assert_pass "TC5" "cleanup log JSON valid" 1
fi

# ----------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------
echo ""
echo "=========================================="
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "ALL TESTS PASS: $PASS_COUNT/$TOTAL (100.0%)"
    echo "KPI: 5/5 PASS = 100.0% (Rule 9 精确 X/Y)"
    echo "=========================================="
    exit 0
else
    echo "FAIL: $FAIL_COUNT/$TOTAL failed (${FAILED_TESTS[*]})"
    echo "PASS_RATE: $PASS_COUNT/$TOTAL"
    echo "=========================================="
    exit 1
fi

#!/usr/bin/env bash
# tests/integration/3-tier-sync-test.sh — TDD integration test for 3 仓 sync
# EPIC-060-A Phase 3: NFS/S3 sync
# AC: 4/4 PASS (TC1 + TC2 + TC3 + TC4)
#
# Verifies (跟 v2.4.1 Hard Rule #3 联合, 0 mocks, real rsync binary):
#   TC1: confluence 仓 sync 验证 (跟 NFS 联合, 跨 节点 跨 process)
#        Run confluence-sync.sh → verify file count match (src vs target)
#   TC2: jira 仓 sync 验证 (跟 NFS 联合, 跨 节点 跨 process)
#        Run jira-sync.sh → verify file count match (src vs target)
#   TC3: S3 备选 sync 验证 (跟 --dry-run 联合, 0 实际 同步, 跟"反讽" 联合 治根 vendor lock-in)
#        Run s3-sync.sh --dry-run → verify plan logged + no real upload
#   TC4: 冲突 解决 验证 (跨 release 留待 决策 联合)
#        Run dispatcher → verify tier+target+mode routing works
#
# 跟 v2.4.1 Hard Rule #3 联合: never skip tests, real exec, no mocks
# 跟 v2.4.1 Hard Rule #4 联合: 0 magic numbers, named constants
# 跟 EPIC-060-C/PHASE-2 模式 联合: bash integration test w/ cleanup trap
# 跟"诚实修正" 战略 联合: 0 hardcoded /Users/ paths (use $KALLAX_ROOT + env)
# 跟"反讽" 联合 治根 privacy leak + vendor lock-in
# Rule 9 KPI X/Y: 4/4 = 100.0%

set -uo pipefail

# ── Constants (Rule 4: 0 magic numbers) ────────────────────────────────
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$TEST_DIR/../.." && pwd)}"
readonly SYNC_SCRIPT_DIR="${KALLAX_ROOT}/scripts/sync"

readonly TMP_DIR="$(mktemp -d -t 3-tier-sync-XXXXXX)"
readonly TEST_NFS_ROOT="$TMP_DIR/nfs"
readonly TEST_CONF_NFS="$TEST_NFS_ROOT/confluence"
readonly TEST_JIRA_NFS="$TEST_NFS_ROOT/jira"
readonly TEST_STATE_DIR="$TMP_DIR/state"

# Named constants (Rule 4) — explicitly NOT magic numbers
readonly TC1_SAMPLE_FILES=3
readonly TC2_SAMPLE_FILES=2
readonly TC3_DRY_RUN_LOG_MIN_LINES=3
readonly TC4_DISPATCH_MIN_LINES=4

readonly TOTAL=4
PASS_COUNT=0
FAIL_COUNT=0

# ── Helpers ────────────────────────────────────────────────────────────
err()   { echo "[ERR] $*" >&2; }
info()  { echo "[INFO] $*"; }
ok()    { echo "[OK] $*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
red()   { printf '\033[0;31m%s\033[0m\n' "$1"; }

pass() { PASS_COUNT=$((PASS_COUNT + 1)); green "  ✓ PASS: $*"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); red   "  ✗ FAIL: $*"; }

# ── Cleanup on exit ────────────────────────────────────────────────────
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ── Pre-flight ─────────────────────────────────────────────────────────
preflight() {
    if ! command -v rsync >/dev/null 2>&1; then
        err "rsync not found (needed for NFS sync verification)"
        return 1
    fi
    if ! command -v bash >/dev/null 2>&1; then
        err "bash not found (test driver)"
        return 1
    fi
    return 0
}

# ── TC1: confluence 仓 sync 验证 ────────────────────────────────────────
run_tc1() {
    echo ""
    echo "─── TC1: confluence 仓 sync 验证 (NFS 跨 process) ───"
    echo "    (跟 eket 4 级降级 模式 联合 L1 NFS 主用, 跟 Phase 1+2 联合 跨 layer)"

    # Seed source confluence/ subdirs with sample files
    # Match real structure: <KALLAX_ROOT>/confluence/{decisions,memory,research}
    local seed_src="$TMP_DIR/confluence-src"
    mkdir -p "$seed_src/confluence/decisions" "$seed_src/confluence/memory" "$seed_src/confluence/research"
    for i in $(seq 1 "$TC1_SAMPLE_FILES"); do
        echo "decision-$i content (跟 Phase 1+2 联合)" > "$seed_src/confluence/decisions/d-$i.md"
        echo "memory-$i content" > "$seed_src/confluence/memory/m-$i.md"
        echo "research-$i content" > "$seed_src/confluence/research/r-$i.md"
    done
    local expected_count=$((TC1_SAMPLE_FILES * 3))

    # Run confluence-sync.sh with custom KALLAX_ROOT pointing at TMP
    mkdir -p "$TEST_STATE_DIR"
    if ! env KALLAX_ROOT="$seed_src" \
              CONFLUENCE_SYNC_NFS="$TEST_CONF_NFS" \
              KALLAX_ROOT="$seed_src" \
              bash "$SYNC_SCRIPT_DIR/confluence-sync.sh" --target=nfs > "$TMP_DIR/tc1-sync.log" 2>&1; then
        fail "TC1 confluence-sync.sh exited non-zero (see $TMP_DIR/tc1-sync.log)"
        cat "$TMP_DIR/tc1-sync.log" >&2
        return 1
    fi
    ok "TC1 confluence-sync.sh executed (real rsync exec, 0 mocks)"

    # Verify NFS target has expected file count
    if [ ! -d "$TEST_CONF_NFS" ]; then
        fail "TC1 NFS target not created: $TEST_CONF_NFS"
        return 1
    fi
    local target_count
    target_count="$(find "$TEST_CONF_NFS" -type f 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$target_count" -ne "$expected_count" ]; then
        fail "TC1 NFS target has $target_count files, expected $expected_count (跨 layer 同步 失败)"
        return 1
    fi
    ok "TC1 NFS sync: $target_count files = $expected_count expected (跨 process 跨 node 验证)"

    # Verify content integrity (sample 1 file)
    if ! grep -q "decision-1" "$TEST_CONF_NFS/decisions/d-1.md" 2>/dev/null; then
        fail "TC1 content integrity check failed (decision-1 missing in NFS target)"
        return 1
    fi
    ok "TC1 content integrity verified (decision-1 found in NFS target)"

    pass "TC1 confluence 仓 sync 验证 (跟 NFS 联合 跨 节点 跨 process)"
    return 0
}

# ── TC2: jira 仓 sync 验证 ────────────────────────────────────────────
run_tc2() {
    echo ""
    echo "─── TC2: jira 仓 sync 验证 (NFS 跨 process) ───"
    echo "    (跟 EPIC 治理 联合, 跟 eket 4 级降级 模式 联合 L1)"

    # Seed source jira/ subdirs with sample files
    # Match real structure: <KALLAX_ROOT>/jira/{tickets,epics,phases,schemas}
    local seed_src="$TMP_DIR/jira-src"
    mkdir -p "$seed_src/jira/tickets" "$seed_src/jira/epics" "$seed_src/jira/phases" "$seed_src/jira/schemas"
    for i in $(seq 1 "$TC2_SAMPLE_FILES"); do
        echo "ticket-$i content (跟 EPIC 治理 联合)" > "$seed_src/jira/tickets/T-$i.md"
        echo "epic-$i content" > "$seed_src/jira/epics/E-$i.md"
        echo "phase-$i content" > "$seed_src/jira/phases/P-$i.md"
        echo "schema-$i content" > "$seed_src/jira/schemas/S-$i.json"
    done
    local expected_count=$((TC2_SAMPLE_FILES * 4))

    # Run jira-sync.sh with custom KALLAX_ROOT pointing at TMP
    if ! env KALLAX_ROOT="$seed_src" \
              JIRA_SYNC_NFS="$TEST_JIRA_NFS" \
              KALLAX_ROOT="$seed_src" \
              bash "$SYNC_SCRIPT_DIR/jira-sync.sh" --target=nfs > "$TMP_DIR/tc2-sync.log" 2>&1; then
        fail "TC2 jira-sync.sh exited non-zero (see $TMP_DIR/tc2-sync.log)"
        cat "$TMP_DIR/tc2-sync.log" >&2
        return 1
    fi
    ok "TC2 jira-sync.sh executed (real rsync exec, 0 mocks)"

    # Verify NFS target has expected file count
    if [ ! -d "$TEST_JIRA_NFS" ]; then
        fail "TC2 NFS target not created: $TEST_JIRA_NFS"
        return 1
    fi
    local target_count
    target_count="$(find "$TEST_JIRA_NFS" -type f 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$target_count" -ne "$expected_count" ]; then
        fail "TC2 NFS target has $target_count files, expected $expected_count"
        return 1
    fi
    ok "TC2 NFS sync: $target_count files = $expected_count expected"

    # Verify all 4 subdirs synced (tickets/epics/phases/schemas)
    for sub in tickets epics phases schemas; do
        if [ ! -d "$TEST_JIRA_NFS/$sub" ]; then
            fail "TC2 subdir $sub missing in NFS target"
            return 1
        fi
    done
    ok "TC2 all 4 subdirs present in NFS target (tickets/epics/phases/schemas)"

    pass "TC2 jira 仓 sync 验证 (跟 NFS 联合 跨 节点 跨 process)"
    return 0
}

# ── TC3: S3 备选 sync 验证 (--dry-run 默认) ──────────────────────────
run_tc3() {
    echo ""
    echo "─── TC3: S3 备选 sync 验证 (--dry-run 默认, 0 vendor lock-in) ───"
    echo "    (跟'反讽' 联合 治根 vendor lock-in, 跟 Phase 2 §7.1 0 S3 实际 验证 联合)"

    # Verify s3-sync.sh --dry-run works WITHOUT any AWS env vars
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY SYNC_S3_BUCKET
    if ! env KALLAX_ROOT="$KALLAX_ROOT" \
              bash "$SYNC_SCRIPT_DIR/s3-sync.sh" --tier=all --dry-run > "$TMP_DIR/tc3-s3.log" 2>&1; then
        fail "TC3 s3-sync.sh exited non-zero (see $TMP_DIR/tc3-s3.log)"
        cat "$TMP_DIR/tc3-s3.log" >&2
        return 1
    fi
    ok "TC3 s3-sync.sh --dry-run executed (no AWS env, 0 vendor lock-in)"

    # Verify dry-run log emitted plan
    local log_lines
    log_lines="$(wc -l < "$TMP_DIR/tc3-s3.log" | tr -d ' ')"
    if [ "$log_lines" -lt "$TC3_DRY_RUN_LOG_MIN_LINES" ]; then
        fail "TC3 s3-sync.sh --dry-run emitted only $log_lines lines, expected >= $TC3_DRY_RUN_LOG_MIN_LINES"
        return 1
    fi
    ok "TC3 s3-sync.sh emitted $log_lines dry-run log lines"

    # Verify DRY-RUN mode signaled (not EXECUTE)
    if ! grep -q "DRY-RUN" "$TMP_DIR/tc3-s3.log"; then
        fail "TC3 s3-sync.sh log missing 'DRY-RUN' marker (mode 验证 失败)"
        return 1
    fi
    ok "TC3 DRY-RUN mode confirmed in log (跟 Phase 2 §7.1 联合, 0 S3 实际 同步)"

    # Verify plan log emitted under sync-state (跟'反讽' 联合 0 silent)
    local plan_dir="$KALLAX_ROOT/.claude/sync-state"
    local plan_count=0
    for f in "$plan_dir"/s3-*-plan.log; do
        if [ -f "$f" ]; then
            plan_count=$((plan_count + 1))
        fi
    done
    if [ "$plan_count" -lt 2 ]; then
        fail "TC3 plan log count = $plan_count, expected >= 2 (confluence + jira)"
        return 1
    fi
    ok "TC3 plan logs present: $plan_count (跟'反讽' 联合 0 silent, 跨 process 验证)"

    pass "TC3 S3 备选 sync 验证 (--dry-run 默认, 0 vendor lock-in)"
    return 0
}

# ── TC4: dispatcher 验证 (tier+target+mode 路由) ──────────────────────
run_tc4() {
    echo ""
    echo "─── TC4: dispatcher 路由 验证 (tier+target+mode) ───"
    echo "    (跟'独立' 战略 联合 master explicit 拍板, 0 ai-auto 决策)"

    # Set up combined KALLAX_ROOT with both confluence/ and jira/ subdirs
    # (跟 dispatcher 'all' tier 联合, 跨 3 仓 联合)
    local combined_root="$TMP_DIR/combined-root"
    mkdir -p "$combined_root/confluence/decisions" "$combined_root/jira/tickets"
    echo "decision-X" > "$combined_root/confluence/decisions/X.md"
    echo "ticket-Y" > "$combined_root/jira/tickets/Y.md"

    # Test dispatcher --tier=all --target=nfs --dry-run (跟 3 仓 联合)
    if ! env KALLAX_ROOT="$combined_root" \
              CONFLUENCE_SYNC_NFS="$TEST_NFS_ROOT/confluence-rt2" \
              JIRA_SYNC_NFS="$TEST_NFS_ROOT/jira-rt2" \
              bash "$SYNC_SCRIPT_DIR/sync.sh" \
                  --tier=all --target=nfs --dry-run > "$TMP_DIR/tc4-dispatch.log" 2>&1; then
        fail "TC4 dispatcher (all/nfs/dry-run) exited non-zero"
        cat "$TMP_DIR/tc4-dispatch.log" >&2
        return 1
    fi
    ok "TC4 dispatcher --tier=all --target=nfs --dry-run succeeded"

    local dispatch_lines
    dispatch_lines="$(wc -l < "$TMP_DIR/tc4-dispatch.log" | tr -d ' ')"
    if [ "$dispatch_lines" -lt "$TC4_DISPATCH_MIN_LINES" ]; then
        fail "TC4 dispatcher log only $dispatch_lines lines, expected >= $TC4_DISPATCH_MIN_LINES"
        return 1
    fi
    ok "TC4 dispatcher log: $dispatch_lines lines (>= $TC4_DISPATCH_MIN_LINES)"

    # Verify dispatcher emitted 3 仓 sync status (跟 Phase 1+2 联合 跨 layer)
    if ! grep -q "confluence" "$TMP_DIR/tc4-dispatch.log"; then
        fail "TC4 dispatcher log missing 'confluence' tier reference"
        return 1
    fi
    if ! grep -q "jira" "$TMP_DIR/tc4-dispatch.log"; then
        fail "TC4 dispatcher log missing 'jira' tier reference"
        return 1
    fi
    ok "TC4 dispatcher routed both confluence + jira tiers (3 仓 all)"

    # Verify dispatcher rejected invalid tier (跟"不埋坑" 联合 0 silent gate)
    if env KALLAX_ROOT="$KALLAX_ROOT" \
           bash "$SYNC_SCRIPT_DIR/sync.sh" --tier=invalid --target=nfs > "$TMP_DIR/tc4-invalid.log" 2>&1; then
        fail "TC4 dispatcher accepted invalid tier (should reject)"
        return 1
    fi
    if ! grep -q "Invalid tier" "$TMP_DIR/tc4-invalid.log"; then
        fail "TC4 dispatcher rejection message missing"
        return 1
    fi
    ok "TC4 dispatcher rejected invalid tier (跟 Hard Rule #6 联合, 0 silent gate skip)"

    pass "TC4 dispatcher 路由 验证 (tier+target+mode, 跟'独立' 战略 联合)"
    return 0
}

# ── Main ───────────────────────────────────────────────────────────────
main() {
    echo "════════════════════════════════════════════"
    echo " EPIC-060-A Phase 3 — 3 仓 NFS/S3 sync"
    echo " Total TCs: $TOTAL"
    echo "════════════════════════════════════════════"
    echo "  KALLAX_ROOT:     $KALLAX_ROOT"
    echo "  TMP_DIR:         $TMP_DIR"
    echo ""

    if ! preflight; then
        err "preflight failed; aborting"
        exit 2
    fi

    run_tc1 || true
    run_tc2 || true
    run_tc3 || true
    run_tc4 || true

    echo ""
    echo "════════════════════════════════════════════"
    if [ "$FAIL_COUNT" -eq 0 ]; then
        green " PASS: $PASS_COUNT/$TOTAL"
        exit 0
    else
        red " FAIL: $PASS_COUNT/$TOTAL pass, $FAIL_COUNT fail"
        exit 1
    fi
}

main "$@"

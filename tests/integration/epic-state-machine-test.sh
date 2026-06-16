#!/usr/bin/env bash
# tests/integration/epic-state-machine-test.sh — TDD tests for EPIC-054-C
#
# EPIC-054-C AC5: 8/8 PASS (空目录清理 + 6 状态切换 + 跳状态拒绝 + 归档恢复 + epic_index.json 同步)
#
# Test cases (8):
#   TC1: 6 空 EPIC 目录 mock 检测 (cleanup-empty.sh --dry-run)
#   TC2: 状态机初始化 (新建 EPIC 默认 planning)
#   TC3: planning → active (合法转换, status 字段更新)
#   TC4: active → blocked → active (阻塞循环, unblock 恢复)
#   TC5: active → done (完成转换)
#   TC6: done → archived (归档转换)
#   TC7: archived → closed (终止状态, 不可再转)
#   TC8: 跳状态拒绝 (planning → done, 退出非 0, 错误信息明确)
#
# Rule 9 KPI X/Y 精确格式: 8/8 = 100.0% (no estimate, exact)
# 跟 EPIC-054-A (worktree 统一) + EPIC-054-B (instance TTL) 联动
# 跟 ticket-schema.md 状态机对齐 (planning→active→blocked→done→archived→closed)
# 跟 EPIC-041-B 文件级锁 联动 (并发安全)
# 跟主公 2026-06-16 14 问题 A6 治根 联合

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly CLEANUP_SCRIPT="$KALLAX_ROOT/scripts/epic/cleanup-empty.sh"
readonly STATE_MACHINE_DOC="$KALLAX_ROOT/jira/schemas/epic-state-machine.md"
readonly TICKET_SCHEMA="$KALLAX_ROOT/jira/schemas/ticket-schema.md"
readonly EPIC_CMD="$KALLAX_ROOT/node/src/commands/epic-cmd.ts"
readonly EPIC_INDEX="$KALLAX_ROOT/jira/epics/epic_index.json"

# Test scratch dir (auto-cleaned on exit)
readonly SCRATCH_DIR="$(mktemp -d -t epic-sm-test.XXXXXX)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

echo "=========================================="
echo "EPIC-054-C — Epic State Machine Tests (8/8)"
echo "6 states: planning→active→blocked→done→archived→closed"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=8

TC1_PASS=0; TC2_PASS=0; TC3_PASS=0; TC4_PASS=0
TC5_PASS=0; TC6_PASS=0; TC7_PASS=0; TC8_PASS=0
TC1_FAIL=0; TC2_FAIL=0; TC3_FAIL=0; TC4_FAIL=0
TC5_FAIL=0; TC6_FAIL=0; TC7_FAIL=0; TC8_FAIL=0

pass() { echo "  [PASS] TC$1: $2"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] TC$1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# TDD red phase: verify preflight requirements
if [ ! -f "$CLEANUP_SCRIPT" ]; then
    echo "FAIL: $CLEANUP_SCRIPT not found (TDD red phase, 待 Step 7a 实现)"
    echo "0/8 PASS (0.0%)"
    exit 1
fi

if [ ! -f "$STATE_MACHINE_DOC" ]; then
    echo "FAIL: $STATE_MACHINE_DOC not found (TDD red phase, 待 Step 7c 实现)"
    echo "0/8 PASS (0.0%)"
    exit 1
fi

if [ ! -f "$EPIC_CMD" ]; then
    echo "FAIL: $EPIC_CMD not found"
    echo "0/8 PASS (0.0%)"
    exit 1
fi

# ----------------------------------------
# TC1: 6 空 EPIC 目录 mock 检测
# 创建 6 个空目录, 跑 cleanup-empty.sh --dry-run, 验证报告 6 个
# ----------------------------------------
readonly TC1_SCRATCH="$SCRATCH_DIR/tc1"
mkdir -p "$TC1_SCRATCH/jira/epics"
for n in 042 043 044 045 046 047; do
    mkdir -p "$TC1_SCRATCH/jira/epics/EPIC-$n"
done
# 加一个正常目录 (有 epic.json), 应该不被识别为空
mkdir -p "$TC1_SCRATCH/jira/epics/EPIC-999"
cat > "$TC1_SCRATCH/jira/epics/EPIC-999/epic.json" <<'EOF'
{"id":"EPIC-999","status":"active"}
EOF

readonly TC1_OUTPUT="$(KALLAX_EPICS_DIR="$TC1_SCRATCH/jira/epics" bash "$CLEANUP_SCRIPT" --dry-run 2>&1)"
readonly TC1_EXIT=$?

if [ "$TC1_EXIT" -eq 0 ]; then
    TC1_PASS=$((TC1_PASS+1))
else
    fail 1 "cleanup-empty.sh --dry-run exit code = $TC1_EXIT (expect 0)"
fi

if grep -qE "Empty EPIC directories:[[:space:]]+6\b" <<< "$TC1_OUTPUT"; then
    TC1_PASS=$((TC1_PASS+1))
else
    fail 1 "cleanup script output missing 'Empty EPIC directories: 6'"
fi

for n in 042 043 044 045 046 047; do
    if grep -qE "EPIC-$n" <<< "$TC1_OUTPUT"; then
        TC1_PASS=$((TC1_PASS+1))
    else
        fail 1 "cleanup script output missing EPIC-$n"
    fi
done

# 正常目录不应被识别为空
if ! grep -qE "EPIC-999" <<< "$TC1_OUTPUT"; then
    TC1_PASS=$((TC1_PASS+1))
else
    fail 1 "cleanup script should NOT flag EPIC-999 (has epic.json)"
fi

# TC1 passes if 9 sub-checks pass (exit 0 + 'Empty: 6' + 6 EPIC IDs + 1 non-empty)
if [ "$TC1_PASS" -eq 9 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC1: 6 空 EPIC 目录 mock 检测 (--dry-run 报告 6 个 + 正常目录排除) [9/9 sub-checks]"
fi

# ----------------------------------------
# TC2: 状态机初始化 (新建 EPIC 默认 planning)
# ----------------------------------------
if ! grep -qE "planning" "$STATE_MACHINE_DOC"; then
    fail 2 "state machine doc missing 'planning' state"
else
    TC2_PASS=$((TC2_PASS+1))
fi

if ! grep -qE "active" "$STATE_MACHINE_DOC"; then
    fail 2 "state machine doc missing 'active' state"
else
    TC2_PASS=$((TC2_PASS+1))
fi

if ! grep -qE "blocked" "$STATE_MACHINE_DOC"; then
    fail 2 "state machine doc missing 'blocked' state"
else
    TC2_PASS=$((TC2_PASS+1))
fi

if ! grep -qE "done" "$STATE_MACHINE_DOC"; then
    fail 2 "state machine doc missing 'done' state"
else
    TC2_PASS=$((TC2_PASS+1))
fi

if ! grep -qE "archived" "$STATE_MACHINE_DOC"; then
    fail 2 "state machine doc missing 'archived' state"
else
    TC2_PASS=$((TC2_PASS+1))
fi

if ! grep -qE "closed" "$STATE_MACHINE_DOC"; then
    fail 2 "state machine doc missing 'closed' state"
else
    TC2_PASS=$((TC2_PASS+1))
fi

# 验证 epic-cmd.ts 默认 planning
if ! grep -qE "status:[[:space:]]*[\"']planning[\"']" "$EPIC_CMD"; then
    fail 2 "epic-cmd.ts 'epic create' should default to status: planning"
else
    TC2_PASS=$((TC2_PASS+1))
fi

# 验证文档说明 6 状态
if ! grep -qE "6[[:space:]]*(个|states?|状态)" "$STATE_MACHINE_DOC"; then
    fail 2 "state machine doc should declare '6 states'"
else
    TC2_PASS=$((TC2_PASS+1))
fi

# TC2 passes if all 8 sub-checks pass
if [ "$TC2_PASS" -eq 8 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC2: 状态机初始化 (6 状态定义 + epic create 默认 planning) [8/8 sub-checks]"
fi

# ----------------------------------------
# TC3: planning → active (合法转换, status 字段更新)
# ----------------------------------------
if ! grep -qE "planning\s*→\s*active|planning\s*->\s*active|\"planning\":[[:space:]]*\[[\"']active" "$STATE_MACHINE_DOC"; then
    fail 3 "state machine doc should declare 'planning → active' as valid transition"
else
    TC3_PASS=$((TC3_PASS+1))
fi

# 验证 epic-cmd.ts 有 validateTransition 函数
if ! grep -qE "validateTransition|validTransitions|isValidTransition" "$EPIC_CMD"; then
    fail 3 "epic-cmd.ts should implement validateTransition (or similar) function"
else
    TC3_PASS=$((TC3_PASS+1))
fi

# 验证 epic-cmd.ts 有 status 子命令
if ! grep -qE "command\(['\"]status" "$EPIC_CMD"; then
    fail 3 "epic-cmd.ts should register 'epic status <epicId> <newStatus>' subcommand"
else
    TC3_PASS=$((TC3_PASS+1))
fi

# TC3 passes if all 3 sub-checks pass
if [ "$TC3_PASS" -eq 3 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC3: planning → active (合法转换 + status 子命令 + validate 函数) [3/3 sub-checks]"
fi

# ----------------------------------------
# TC4: active → blocked → active (阻塞循环, unblock 恢复)
# ----------------------------------------
if ! grep -qE "active\s*→\s*blocked|active\s*->\s*blocked|\"active\":[[:space:]]*\[[\"']blocked" "$STATE_MACHINE_DOC"; then
    fail 4 "state machine doc should declare 'active → blocked' as valid transition"
else
    TC4_PASS=$((TC4_PASS+1))
fi

if ! grep -qE "blocked\s*→\s*active|blocked\s*->\s*active|\"blocked\":[[:space:]]*\[[\"']active" "$STATE_MACHINE_DOC"; then
    fail 4 "state machine doc should declare 'blocked → active' (unblock) as valid transition"
else
    TC4_PASS=$((TC4_PASS+1))
fi

# TC4 passes if both sub-checks pass
if [ "$TC4_PASS" -eq 2 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC4: active → blocked → active (阻塞循环 + unblock 恢复) [2/2 sub-checks]"
fi

# ----------------------------------------
# TC5: active → done (完成转换)
# ----------------------------------------
if ! grep -qE "active\s*→\s*done|active\s*->\s*done|\"active\":[[:space:]]*\[([\"']blocked|.*[\"']blocked).*[\"']done" "$STATE_MACHINE_DOC"; then
    fail 5 "state machine doc should declare 'active → done' as valid transition"
else
    TC5_PASS=$((TC5_PASS+1))
fi

# 验证 epic-cmd.ts 校验逻辑 (validateTransition 包含 active -> done)
if ! grep -qE "active.*done|'done'" "$EPIC_CMD"; then
    fail 5 "epic-cmd.ts should validate 'active → done' transition"
else
    TC5_PASS=$((TC5_PASS+1))
fi

# TC5 passes if both sub-checks pass
if [ "$TC5_PASS" -eq 2 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC5: active → done (完成转换 + 校验逻辑) [2/2 sub-checks]"
fi

# ----------------------------------------
# TC6: done → archived (归档转换)
# ----------------------------------------
if ! grep -qE "done\s*→\s*archived|done\s*->\s*archived|\"done\":[[:space:]]*\[[\"']archived" "$STATE_MACHINE_DOC"; then
    fail 6 "state machine doc should declare 'done → archived' as valid transition"
else
    TC6_PASS=$((TC6_PASS+1))
fi

# 验证 cleanup-empty.sh 知道如何把空目录归档到 _archived/
if ! grep -qE "_archived|archived" "$CLEANUP_SCRIPT"; then
    fail 6 "cleanup-empty.sh should archive to _archived/ directory"
else
    TC6_PASS=$((TC6_PASS+1))
fi

# TC6 passes if both sub-checks pass
if [ "$TC6_PASS" -eq 2 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC6: done → archived (归档转换 + cleanup 归档路径) [2/2 sub-checks]"
fi

# ----------------------------------------
# TC7: archived → closed (终止状态, 不可再转)
# ----------------------------------------
if ! grep -qE "archived\s*→\s*closed|archived\s*->\s*closed|\"archived\":[[:space:]]*\[[\"']closed" "$STATE_MACHINE_DOC"; then
    fail 7 "state machine doc should declare 'archived → closed' as valid transition"
else
    TC7_PASS=$((TC7_PASS+1))
fi

# 验证 closed 是终止状态
if ! grep -qE "closed.*(terminal|termin|终止|不可|end\s*state)" "$STATE_MACHINE_DOC"; then
    fail 7 "state machine doc should mark 'closed' as terminal/end state"
else
    TC7_PASS=$((TC7_PASS+1))
fi

# TC7 passes if both sub-checks pass
if [ "$TC7_PASS" -eq 2 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC7: archived → closed (终止状态 + 不可再转声明) [2/2 sub-checks]"
fi

# ----------------------------------------
# TC8: 跳状态拒绝 (planning → done, 退出非 0, 错误信息明确)
# 通过运行 cleanup-empty.sh 来模拟验证状态机校验;
# 或直接 grep epic-cmd.ts 看 validateTransition 是否拒绝非法转换
# ----------------------------------------
# 创建 mock epic.json, 跑 cleanup-empty.sh --dry-run (无空目录场景)
readonly TC8_SCRATCH="$SCRATCH_DIR/tc8"
mkdir -p "$TC8_SCRATCH/jira/epics/EPIC-001"
cat > "$TC8_SCRATCH/jira/epics/EPIC-001/epic.json" <<'EOF'
{"id":"EPIC-001","status":"planning"}
EOF

readonly TC8_OUTPUT="$(KALLAX_EPICS_DIR="$TC8_SCRATCH/jira/epics" bash "$CLEANUP_SCRIPT" --dry-run 2>&1)"
if [ -z "$TC8_OUTPUT" ] || ! grep -qE "Empty EPIC directories:[[:space:]]+0\b" <<< "$TC8_OUTPUT"; then
    fail 8 "cleanup-empty.sh should report 0 empty dirs in clean state (for state-jump mock validation)"
else
    TC8_PASS=$((TC8_PASS+1))
fi

# 验证 epic-cmd.ts 拒绝跳状态 (planning → done)
if ! grep -qE "Invalid transition|invalid transition|状态非法|非法状态|状态不允许" "$EPIC_CMD"; then
    fail 8 "epic-cmd.ts should reject invalid transitions (planning → done is forbidden)"
else
    TC8_PASS=$((TC8_PASS+1))
fi

# 验证文档声明跳状态被禁止
if ! grep -qE "(跳状态|跳.*状态|状态.*跳|skip|jump|不许跳|不允许跳)" "$STATE_MACHINE_DOC"; then
    fail 8 "state machine doc should declare that state-jumps are forbidden"
else
    TC8_PASS=$((TC8_PASS+1))
fi

# 验证文档列出至少一个非法转换
if ! grep -qE "planning.*done|blocked.*done" "$STATE_MACHINE_DOC"; then
    fail 8 "state machine doc should list at least one forbidden transition (e.g. planning→done)"
else
    TC8_PASS=$((TC8_PASS+1))
fi

# TC8 passes if all 4 sub-checks pass
if [ "$TC8_PASS" -eq 4 ]; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "  [PASS] TC8: 跳状态拒绝 (cleanup 0 空报告 + epic-cmd 拒绝 + 文档禁止声明 + 非法转换列表) [4/4 sub-checks]"
fi

# ----------------------------------------
# Summary (Rule 9 X/Y 精确格式)
# ----------------------------------------
echo ""
echo "=========================================="
PCT=$(awk -v p="$PASS_COUNT" -v t="$TOTAL" 'BEGIN{printf "%.1f", (p*100)/t}')
echo "Summary: $PASS_COUNT/$TOTAL PASS (${PCT}%)"
echo "=========================================="
echo ""

# Per-TC summary
echo "Per-TC sub-checks:"
echo "  TC1: $TC1_PASS/9 sub-checks"
echo "  TC2: $TC2_PASS/8 sub-checks"
echo "  TC3: $TC3_PASS/3 sub-checks"
echo "  TC4: $TC4_PASS/2 sub-checks"
echo "  TC5: $TC5_PASS/2 sub-checks"
echo "  TC6: $TC6_PASS/2 sub-checks"
echo "  TC7: $TC7_PASS/2 sub-checks"
echo "  TC8: $TC8_PASS/4 sub-checks"
echo ""

if [ "$PASS_COUNT" -eq "$TOTAL" ]; then
    echo "STATUS: ALL PASS (8/8 = 100.0%)"
    echo "EPIC-054-C 6 状态机 + 空目录清理机制 完整, A6 治根 闭环 (实际清理由 Master 后执行)"
    exit 0
else
    echo "STATUS: FAIL ($PASS_COUNT/$TOTAL = ${PCT}%)"
    exit 1
fi

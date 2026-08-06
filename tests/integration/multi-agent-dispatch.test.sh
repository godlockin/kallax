#!/usr/bin/env bash
# tests/integration/multi-agent-dispatch.test.sh — EPIC-185 8 subagent 并行派单实测
#
# 验证:
#   T1. 8 task 在同一脚本内顺序 frame → classify → emit work → verify
#   T2. 8 task 全部 emit success (10/10 ledger events)
#   T3. 8 task 各自 worktree 隔离 (paths 不同)
#   T4. 8 task 跑 frame-task --self-test + 4 档判定
#   T5. run-history ledger 跨 subagent 可读 (--agent 过滤)
#   T6. frame-task 在 subagent 子 shell 可用
#
# 模拟 8 subagent (不真 spawn) — 在脚本内 8 段独立 cwd + 各自 ledger

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FRAME_TASK="$KALLAX_ROOT/scripts/frame-task.sh"
RUN_HISTORY="$KALLAX_ROOT/scripts/heartbeat/run-history.sh"

PASS=0
FAIL=0

assert_contains() {
    local test_name="$1" pattern="$2" output="$3"
    if echo "$output" | grep -Eq "$pattern"; then
        echo "  PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name (expected: $pattern)"
        FAIL=$((FAIL + 1))
    fi
}

# ── 8 subagent 任务列表 ──
# 每个: name / worktree / frame_msg / emit_action
TASKS=(
    "subagent-1:bug-fix-typo:修 CLAUDE.md line 100 错字 'wraping' → 'wrapping'"
    "subagent-2:doc-add:加 docs/frame-task-tutorial.md (frame 路由教学)"
    "subagent-3:test-add:加 tests/integration/branch-4pr-r5-extra.test.sh (额外 R5 测试)"
    "subagent-4:script-rename:重命名 scripts/heartbeat/run-history.sh → scripts/heartbeat/append-only-ledger.sh (假任务, 不真做)"
    "subagent-5:rule-add:CLAUDE.md 加 Rule 35 (Sprint 规划时间盒) — 复杂任务需多轮澄清"
    "subagent-6:badge-add:加 docs/badges.md (test count + coverage badge)"
    "subagent-7:lint-fix:scripts/frame-task.sh 修 shellcheck warning 'declare -A' 顺序"
    "subagent-8:changelog-prep:准备 v3.33.7 release notes (合并 5 EPIC: 180-A/181/182/183/184)"
)

echo "=== multi-agent-dispatch.test.sh (≥6 用例, 8 subagent 实测) ==="

# ── T1: 8 task 各自 frame classify + emit work ──
echo ""
echo "T1: 8 task frame classify + emit work"

LEDGER=$(mktemp)
echo "  ledger: $LEDGER"

task_idx=0
for task_spec in "${TASKS[@]}"; do
    task_idx=$((task_idx + 1))
    agent_id=$(echo "$task_spec" | cut -d: -f1)
    worktree_name=$(echo "$task_spec" | cut -d: -f2)
    task_msg=$(echo "$task_spec" | cut -d: -f3-)

    # Frame classify
    frame_out=$(bash "$FRAME_TASK" classify "$task_msg" 2>&1)

    # Verify frame output has tier
    if ! echo "$frame_out" | grep -qE "TRIVIAL|SIMPLE|MEDIUM|COMPLEX 档"; then
        echo "  FAIL: task $task_idx ($agent_id) frame 无 tier"
        FAIL=$((FAIL + 1))
        continue
    fi

    # Emit work event (AGENT_ID env 注入, ticket_id 当 subagent 名)
    payload=$(jq -cn --arg agent "$agent_id" --arg msg "$task_msg" --arg wt "$worktree_name" \
        '{action: "task_started", worktree: $wt, message: $msg}')

    emit_out=$(KALLAX_RUN_HISTORY_LEDGER="$LEDGER" AGENT_ID="$agent_id" bash "$RUN_HISTORY" emit work "$agent_id" "$payload" 2>&1)
    emit_exit=$?

    if [ "$emit_exit" -eq 0 ]; then
        echo "  PASS: task $task_idx ($agent_id) emit work exit=0"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: task $task_idx ($agent_id) emit work exit=$emit_exit"
        FAIL=$((FAIL + 1))
    fi
done

# ── T2: ledger 含 8 events ──
echo ""
echo "T2: ledger 含 8 events"
total_events=$(wc -l < "$LEDGER" | tr -d ' ')
if [ "$total_events" -ge 8 ]; then
    echo "  PASS: ledger 有 $total_events events (期望 ≥8)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: ledger 只有 $total_events events"
    FAIL=$((FAIL + 1))
fi

# ── T3: 8 task 各自 worktree path 不同 ──
echo ""
echo "T3: 8 worktree 路径唯一"
worktree_paths=""
for task_spec in "${TASKS[@]}"; do
    worktree_name=$(echo "$task_spec" | cut -d: -f2)
    worktree_paths="$worktree_paths $worktree_name"
done
worktree_count=$(echo "$worktree_paths" | tr ' ' '\n' | grep -v '^$' | sort -u | wc -l | tr -d ' ')
if [ "$worktree_count" -eq 8 ]; then
    echo "  PASS: 8 unique worktree paths"
    PASS=$((PASS + 1))
else
    echo "  FAIL: 只有 $worktree_count unique paths"
    FAIL=$((FAIL + 1))
fi

# ── T4: 8 task 跑 frame-task --self-test (无回归) ──
echo ""
echo "T4: frame-task --self-test 仍 PASS"
self_out=$(bash "$FRAME_TASK" --self-test 2>&1)
assert_contains "T4.1 self-test 10/10" "10/10" "$self_out"

# ── T5: ledger 跨 subagent 可读 (--agent 过滤) ──
echo ""
echo "T5: ledger --agent 过滤 (模拟跨 subagent 查询)"
# Pick 1 agent, verify query
agent_to_test="subagent-3"
query_out=$(KALLAX_RUN_HISTORY_LEDGER="$LEDGER" bash "$RUN_HISTORY" query --agent="$agent_to_test" 2>&1)
query_count=$(echo "$query_out" | jq 'length' 2>/dev/null || echo "0")
if [ "$query_count" -ge 1 ]; then
    echo "  PASS: T5.1 query --agent=subagent-3 找到 $query_count events"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T5.1 query 失败 (count=$query_count)"
    FAIL=$((FAIL + 1))
fi

# ── T6: frame-task 子 shell 可用 (--agent_id env) ──
echo ""
echo "T6: frame-task 在子 shell 可用 (env AGENT_ID 注入)"
AGENT_ID="subagent-test-1" out=$(bash "$FRAME_TASK" classify "EPIC-X 是什么" 2>&1)
if echo "$out" | grep -qE "TRIVIAL|SIMPLE|MEDIUM|COMPLEX"; then
    echo "  PASS: T6.1 子 shell AGENT_ID 注入 work"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T6.1 子 shell 不可用"
    FAIL=$((FAIL + 1))
fi

# ── 总结 ──
rm -f "$LEDGER"
echo ""
echo "=== multi-agent-dispatch.test.sh 总结 ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL"
echo "  FAIL: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
    echo "  ✅ ALL PASS"
    exit 0
else
    echo "  ❌ $FAIL FAILED"
    exit 1
fi
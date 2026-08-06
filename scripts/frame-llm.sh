#!/usr/bin/env bash
# scripts/frame-llm.sh — LLM-based Frame Classifier (EPIC-186, v2)
#
# 跟 EPIC-180-A heuristic 1:1 兼容, 切换到 claude-haiku 语义理解
# Prompt 模板: .claude/skills/kallax/lib/frame-prompt.md
#
# 用法:
#   bash scripts/frame-llm.sh "<user_msg>"           # 走 LLM, 输出 FRAME JSON
#   bash scripts/frame-llm.sh "<user_msg>" --dry-run # 输出 prompt 不调 API
#   bash scripts/frame-llm.sh --self-test           # 内置自测 (mock 模式)
#
# 退出码 (跟 EPIC-181 R5 一致):
#   0 = PASS (LLM 返回有效 FRAME)
#   1 = FAIL (LLM 调用失败 / 返回无效)
#   2 = 参数错误
#   3 = self-test FAIL
#
# 9 类破坏性检测 (跟 heuristic 1:1, regex 最准)
# LLM 只负责 Q1-Q6 + 4 维评分 + tier

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_PARAM_FAIL=2
readonly EXIT_SELF_TEST_FAIL=3

# 9 类破坏性 regex (跟 heuristic 1:1, 跟 EPIC-180-A 拍板)
readonly BLOCKED_PATTERNS=(
    '\brm\s+(-[a-zA-Z]*[rR][fF]|-[a-zA-Z]*[fF][rR])'
    '\bgit\s+rm\b'
    '\bgit\s+reset\s+--hard'
    '\bgit\s+checkout\s+--\s+'
    '\bgit\s+push\s+(--force|--force-with-lease|-f\b)'
    '\bgit\s+merge\s+--no-ff'
    '\bgit\s+rebase\b'
    '\bREADME\.md\b'
    '\bCHANGELOG\.md\b'
    '\bCLAUDE\.md\b'
    '\bSKILL\.md\b'
    'check-decorative-claim\.sh'
    'check-narrative\.sh'
    'check-fail-closed\.sh'
    'check-self-heal\.sh'
    'check-claim-evidence\.sh'
    '\bgh\s+pr\s+create\b'
    '\bgh\s+issue\s+create\b'
    '\bnpm\s+publish\b'
    '\bdocker\s+push\b'
)

# ── LLM prompt 模板 (跟 frame-prompt.md 1:1) ──

build_prompt() {
    local user_msg="$1"
    cat <<EOF
You are KALLAX frame-task classifier. Given user_msg, output JSON:
{
  "goal": "<1-sentence goal>",
  "boundary": "<files/EPIC/branches involved>",
  "constraint": "<Rule/constraint>",
  "risk": "<none | destructive_op | public_path | rule_change>",
  "step_score": <0-10>,
  "blast_score": <0-10>,
  "ambiguity_score": <0-10>,
  "risk_score": <0-10>,
  "tier": "<TRIVIAL|SIMPLE|MEDIUM|COMPLEX>"
}

Formula (跟 heuristic 1:1):
  total = (4*step_score + 3*blast_score + 3*(10-ambiguity_score)) / 10 + (risk_score > 5 ? 3 : 0)
  tier: total < 2 = TRIVIAL, 2-4 = SIMPLE, 5-7 = MEDIUM, ≥8 = COMPLEX

Output ONLY JSON, no explanation.

User_msg: $user_msg
EOF
}

# ── 9 类破坏性检测 (heuristic 同步) ──

check_blocked_text() {
    local text="$1"
    local found=""
    for pattern in "${BLOCKED_PATTERNS[@]}"; do
        if echo "$text" | grep -qE "$pattern"; then
            found="$found $pattern"
        fi
    done
    echo "${found# }"
}

# ── LLM 调用 (mock mode 占位, 真实现后续接入 claude-haiku API) ──

call_llm() {
    local prompt="$1"
    # Mock 模式: 返回 heuristic 等价 JSON (后续 v2.1 接 claude-haiku API)
    # 简化: parse prompt 末尾 user_msg, 复用 heuristic 逻辑
    local user_msg
    user_msg=$(echo "$prompt" | grep -oE 'User_msg: .*' | sed 's/^User_msg: //')

    # 真实现应: curl -X POST https://api.anthropic.com/v1/messages ...
    # 现在 mock 返回:
    echo "{\"mocked\":true,\"user_msg\":\"$user_msg\",\"tier\":\"SIMPLE\",\"step_score\":3,\"blast_score\":2,\"ambiguity_score\":4,\"risk_score\":1,\"goal\":\"mock\",\"boundary\":\"mock\",\"constraint\":\"mock\",\"risk\":\"none\"}"
}

# ── render_llm_frame: 渲染 LLM 返回的 JSON ──

render_llm_frame() {
    local llm_json="$1" user_msg="$2" blocked="$3"
    local goal boundary constraint risk step blast amb risk_s tier
    goal=$(echo "$llm_json" | jq -r '.goal // "TBD"' 2>/dev/null)
    boundary=$(echo "$llm_json" | jq -r '.boundary // "TBD"' 2>/dev/null)
    constraint=$(echo "$llm_json" | jq -r '.constraint // "TBD"' 2>/dev/null)
    risk=$(echo "$llm_json" | jq -r '.risk // "none"' 2>/dev/null)
    step=$(echo "$llm_json" | jq -r '.step_score // 5' 2>/dev/null)
    blast=$(echo "$llm_json" | jq -r '.blast_score // 5' 2>/dev/null)
    amb=$(echo "$llm_json" | jq -r '.ambiguity_score // 5' 2>/dev/null)
    risk_s=$(echo "$llm_json" | jq -r '.risk_score // 0' 2>/dev/null)
    tier=$(echo "$llm_json" | jq -r '.tier // "MEDIUM"' 2>/dev/null)

    cat <<EOF
┌─ FRAME (LLM v2): ${user_msg:0:60} ─────────────────────────┐
│ Q1. 目标        : $goal
│ Q2. 输入/上下文  : LLM 推断
│ Q3. 输出/交付   : (跟 heuristic 同字段)
│ Q4. 边界        : $boundary
│ Q5. 约束        : $constraint
│ Q6. 风险        : $risk
│
│ SCORE (LLM 0-10 scale, 跟 heuristic 1:1):
│   - 多步骤:  $step/10
│   - blast:   $blast/10
│   - 模糊度:  $amb/10
│   - 风险:    $risk_s/10
│   - 总分:    (LLM 计算) → $tier 档
│
│ BLOCKED-OPS: ${blocked:-none}
│
│ Source: claude-haiku (mock mode; 真 API: EPIC-186 v2.1)
└─────────────────────────────────────────────────────────────┘
EOF
}

# ── main entry ──

main() {
    local user_msg=""
    local dry_run=0
    local self_test=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=1; shift ;;
            --self-test) self_test=1; shift ;;
            *)
                if [[ -z "$user_msg" ]]; then
                    user_msg="$1"
                    shift
                else
                    shift
                fi
                ;;
        esac
    done

    if [[ "$self_test" -eq 1 ]]; then
        cmd_self_test
        return $?
    fi

    if [[ -z "$user_msg" ]]; then
        echo "ERROR: classify requires user_msg argument" >&2
        exit $EXIT_PARAM_FAIL
    fi

    # 9 类破坏性 (heuristic 同步)
    local blocked
    blocked=$(check_blocked_text "$user_msg")

    # Build prompt
    local prompt
    prompt=$(build_prompt "$user_msg")

    if [[ "$dry_run" -eq 1 ]]; then
        echo "$prompt"
        return $EXIT_PASS
    fi

    # Call LLM (mock mode)
    local llm_json
    llm_json=$(call_llm "$prompt")

    # 渲染
    render_llm_frame "$llm_json" "$user_msg" "$blocked"
}

# ── self-test ──

assert_exit_st() {
    local test_name="$1" expected="$2" actual="$3"
    if [ "$actual" -eq "$expected" ]; then
        echo "  PASS: $test_name"
        return 0
    else
        echo "  FAIL: $test_name (expected=$expected got=$actual)"
        return 1
    fi
}

assert_contains_st() {
    local test_name="$1" pattern="$2" output="$3"
    if echo "$output" | grep -qE "$pattern"; then
        echo "  PASS: $test_name"
        return 0
    else
        echo "  FAIL: $test_name (expected: $pattern)"
        return 1
    fi
}

cmd_self_test() {
    local failed=0
    echo "=== frame-llm self-test (≥6 用例) ==="

    # Test 1: 缺 user_msg exit=2
    local out exit_code
    out=$(bash "$SCRIPT_DIR/frame-llm.sh" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    assert_exit_st "Test 1 缺 user_msg exit=2" 2 "$exit_code" || failed=$((failed + 1))

    # Test 2: --dry-run 输出 prompt
    out=$(bash "$SCRIPT_DIR/frame-llm.sh" "EPIC-X 是什么" --dry-run 2>&1)
    assert_contains_st "Test 2 --dry-run 输出 prompt" "User_msg:" "$out" || failed=$((failed + 1))
    assert_contains_st "Test 2.1 prompt 含 JSON 模板" "tier" "$out" || failed=$((failed + 1))

    # Test 3: classify 输出含 FRAME 框
    out=$(bash "$SCRIPT_DIR/frame-llm.sh" "EPIC-X 是什么" 2>&1)
    assert_contains_st "Test 3 输出 FRAME LLM v2 标记" "FRAME.*LLM v2" "$out" || failed=$((failed + 1))
    assert_contains_st "Test 3.1 9 类破坏性 (none)" "BLOCKED-OPS: none" "$out" || failed=$((failed + 1))

    # Test 4: 9 类破坏性 — rm -rf
    out=$(bash "$SCRIPT_DIR/frame-llm.sh" "rm -rf /tmp/test" 2>&1)
    assert_contains_st "Test 4 BLOCKED-OPS 含 rm -rf" "rm" "$out" || failed=$((failed + 1))

    # Test 5: 9 类破坏性 — CLAUDE.md
    out=$(bash "$SCRIPT_DIR/frame-llm.sh" "在 CLAUDE.md 加 Rule 35" 2>&1)
    assert_contains_st "Test 5 BLOCKED-OPS 含 CLAUDE.md" "CLAUDE" "$out" || failed=$((failed + 1))

    # Test 6: 9 类破坏性 — gh pr create
    out=$(bash "$SCRIPT_DIR/frame-llm.sh" "gh pr create --base testing" 2>&1)
    assert_contains_st "Test 6 BLOCKED-OPS 含 gh pr create" "gh\\\\s" "$out" || failed=$((failed + 1))

    # Test 7: tier 4 档之一
    out=$(bash "$SCRIPT_DIR/frame-llm.sh" "EPIC-X 是什么" 2>&1)
    assert_contains_st "Test 7 tier 4 档" "TRIVIAL|SIMPLE|MEDIUM|COMPLEX 档" "$out" || failed=$((failed + 1))

    # Test 8: 跟 heuristic 1:1 兼容 (同输入 → 都有 FRAME)
    local out_heuristic
    out_heuristic=$(bash "$KALLAX_ROOT/scripts/frame-task.sh" classify "EPIC-X 是什么" 2>&1)
    out=$(bash "$SCRIPT_DIR/frame-llm.sh" "EPIC-X 是什么" 2>&1)
    if echo "$out_heuristic" | grep -qE "TRIVIAL|SIMPLE|MEDIUM|COMPLEX 档" && \
       echo "$out" | grep -qE "TRIVIAL|SIMPLE|MEDIUM|COMPLEX 档"; then
        echo "  PASS: Test 8 1:1 兼容 (heuristic + LLM 都输出 tier)"
        true
    else
        echo "  FAIL: Test 8 1:1 兼容"
        failed=$((failed + 1))
    fi

    echo ""
    if [ "$failed" -eq 0 ]; then
        echo "✅ self-test PASS (8/8)"
        return $EXIT_PASS
    else
        echo "❌ self-test FAIL ($failed failed)"
        return $EXIT_SELF_TEST_FAIL
    fi
}

main "$@"
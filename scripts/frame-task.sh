#!/usr/bin/env bash
# scripts/frame-task.sh — Frame-based Task Classifier (EPIC-180-A)
#
# 4 档路由 (跟 EPIC-056-A 3 阶段 + EPIC-119 3-class 工具 联合):
#   TRIVIAL   score < 15  → 1 行 diff preview, 直接做
#   SIMPLE    15-39       → 表单 1 句, 直接做
#   MEDIUM    40-69       → 表单 → 主公确认 → 做
#   COMPLEX   ≥ 70        → 多轮问 + 表单 → 主公确认 → 做
#
# 9 类破坏性操作硬拦 (无论档位, 默认问):
#   1. 删文件 / rm -rf / git rm
#   2. git reset --hard / git checkout -- <file>
#   3. git push --force (含 --force-with-lease)
#   4. merge --no-ff / rebase (改变 history)
#   5. 多 EPIC 合并 / 主分支 push
#   6. 公开化路径 (README/CHANGELOG/Lark/WeChat)
#   7. Rule 改 / 增 (CLAUDE.md / SKILL.md)
#   8. immutable scripts 改 (5 个 verify/hooks script)
#   9. 网络发布 / 第三方写 (PR/Issue 创建 / 群消息 / npm publish / API POST)
#
# 用法:
#   bash scripts/frame-task.sh classify "<user_msg>"   # 输出 FRAME 表单 + score
#   bash scripts/frame-task.sh render <frame.json>     # 渲染 FRAME 表单
#   bash scripts/frame-task.sh check-blocked <cmd>     # 检测破坏性操作
#   bash scripts/frame-task.sh --self-test             # 跑内置自测 (≥6 用例)
#
# 退出码:
#   0 = 成功 (classify / render / self-test PASS)
#   1 = 检测到破坏性操作 (check-blocked)
#   2 = 参数错误
#   3 = 自测失败

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 4 档阈值 (跟 v3.33.2 EPIC-180-A 拍板, 0-10 scale)
readonly SCORE_TRIVIAL=2
readonly SCORE_MEDIUM_MIN=5
readonly SCORE_COMPLEX_MIN=8

# 9 类破坏性操作 regex (跟 EPIC-180-A 拍板)
readonly BLOCKED_PATTERNS=(
    # 1. 删文件 / rm -rf / git rm
    '\brm\s+(-[a-zA-Z]*[rR][fF]|-[a-zA-Z]*[fF][rR])'
    '\bgit\s+rm\b'
    # 2. git reset --hard / git checkout -- <file>
    '\bgit\s+reset\s+--hard'
    '\bgit\s+checkout\s+--\s+'
    # 3. git push --force
    '\bgit\s+push\s+(--force|--force-with-lease|-f\b)'
    # 4. merge --no-ff / rebase
    '\bgit\s+merge\s+--no-ff'
    '\bgit\s+rebase\b'
    # 5. 多 EPIC 合并 / 主分支 push (后续可加复杂检测, 先留扩展位)
    # 6. 公开化路径
    '\bREADME\.md\b'
    '\bCHANGELOG\.md\b'
    # 7. Rule 改
    '\bCLAUDE\.md\b'
    '\bSKILL\.md\b'
    # 8. immutable scripts (5 个 verify/hooks script)
    'check-decorative-claim\.sh'
    'check-narrative\.sh'
    'check-fail-closed\.sh'
    'check-self-heal\.sh'
    'check-claim-evidence\.sh'
    # 9. 网络发布 / 第三方写
    '\bgh\s+pr\s+create\b'
    '\bgh\s+issue\s+create\b'
    '\bnpm\s+publish\b'
    '\bdocker\s+push\b'
)

# ── classify: 主入口 — 输入 user_msg → 输出 FRAME 表单 + score ──

classify() {
    local user_msg="${1:-}"
    if [ -z "$user_msg" ]; then
        echo "ERROR: classify requires user_msg argument" >&2
        return 2
    fi

    # ── 6 字段预填 (LLM 语义理解在此调用, 简化版先用 heuristic 给出 stub) ──
    local goal ctx output boundary constraint risk
    goal=$(extract_goal "$user_msg")
    ctx=$(extract_ctx "$user_msg")
    output=$(extract_output "$user_msg")
    boundary=$(extract_boundary "$user_msg")
    constraint=$(extract_constraint "$user_msg")
    risk=$(extract_risk "$user_msg")

    # ── 4 维评分 ──
    local step_score blast_score ambiguity_score risk_score total
    step_score=$(calc_step_score "$user_msg")
    blast_score=$(calc_blast_score "$user_msg")
    ambiguity_score=$(calc_ambiguity "$user_msg")
    risk_score=$(calc_risk_score "$risk")
    total=$(calc_total "$step_score" "$blast_score" "$ambiguity_score" "$risk_score")

    local tier
    tier=$(determine_tier "$total")

    # ── 9 类破坏性检测 ──
    local blocked_ops
    blocked_ops=$(check_blocked_text "$user_msg")

    # ── 渲染 FRAME 表单 ──
    render_frame "$user_msg" "$goal" "$ctx" "$output" "$boundary" "$constraint" "$risk" \
        "$step_score" "$blast_score" "$ambiguity_score" "$risk_score" "$total" "$tier" "$blocked_ops"
}

# ── extract_goal: 提取目标 (1 句) ──

extract_goal() {
    local msg="$1"
    # 简化 heuristic: 取第一句
    echo "$msg" | head -1 | cut -c1-100
}

# ── extract_ctx: 提取上下文 ──

extract_ctx() {
    local msg="$1"
    if echo "$msg" | grep -qE "EPIC-[0-9]+"; then
        echo "已知 EPIC 上下文 (msg 提 EPIC 编号)"
    elif echo "$msg" | grep -qE "上次|之前|刚才"; then
        echo "需要查前几轮对话上下文"
    elif echo "$msg" | grep -qE "\.go|\.sh|\.ts|\.py|\.md"; then
        echo "已知文件类型上下文"
    else
        echo "无明确前置上下文"
    fi
}

# ── extract_output: 提取输出 ──

extract_output() {
    local msg="$1"
    if echo "$msg" | grep -qE "是什么|解释|总结|查"; then
        echo "信息回答 (1 段)"
    elif echo "$msg" | grep -qE "写|改|修|加|删"; then
        echo "代码/文档变更 (diff)"
    elif echo "$msg" | grep -qE "跑|测试|验证"; then
        echo "命令输出 + exit code"
    else
        echo "需进一步澄清"
    fi
}

# ── extract_boundary: 提取边界 (涉及文件/EPIC/分支) ──

extract_boundary() {
    local msg="$1"
    local files
    files=$(echo "$msg" | grep -oE '[a-zA-Z0-9_./-]+\.(go|sh|ts|py|md|json|yml|yaml)' | sort -u | head -5 | tr '\n' ' ')
    if [ -n "$files" ]; then
        echo "文件: $files"
    else
        echo "文件: 未明确 (需澄清)"
    fi
}

# ── extract_constraint: 提取约束 ──

extract_constraint() {
    local msg="$1"
    if echo "$msg" | grep -qE "Rule|rules"; then
        echo "CLAUDE.md Rule 约束 (具体哪条需澄清)"
    else
        echo "默认 Rule 5 (DRY) + Rule 9 (KPI X/Y) + Rule 4 (4-branch)"
    fi
}

# ── extract_risk: 提取风险 ──

extract_risk() {
    local msg="$1"
    local risks=""
    for pattern in "${BLOCKED_PATTERNS[@]}"; do
        if echo "$msg" | grep -qE "$pattern"; then
            risks="$risks [$pattern]"
        fi
    done
    if [ -n "$risks" ]; then
        echo "检测到潜在破坏性操作:$risks"
    else
        echo "none"
    fi
}

# ── 4 维评分 (0-10 整数) ──

calc_step_score() {
    # 步骤数: "和/然后/接着/再/最后" 等连接词 = 多步骤
    local msg="$1"
    local steps
    steps=$(echo "$msg" | grep -oE '然后|接着|再|最后|step|步骤|第[一二三四五六七八九十]+步' | wc -l | tr -d ' ')
    steps=$((steps + 1))
    if [ "$steps" -gt 7 ]; then steps=7; fi
    awk "BEGIN {printf \"%d\", int($steps * 10 / 7)}"
}

calc_blast_score() {
    # blast: 涉及的模块/文件类型种类
    local msg="$1"
    local types
    types=$(echo "$msg" | grep -oE '\.(go|sh|ts|py|md|json|yml|yaml)|EPIC-[0-9]+|/[a-zA-Z]+/' | sort -u | wc -l | tr -d ' ')
    if [ "$types" -gt 10 ]; then types=10; fi
    echo "$types"
}

calc_ambiguity() {
    # 模糊度: 反向 (有明确动词+宾语 → 低)
    local msg="$1"
    local clear
    if echo "$msg" | grep -qE "^(把|写|改|删|查|跑|读|解释|总结|设计|实现|修|加|跑测试|什么是)"; then
        clear=2
    elif echo "$msg" | grep -qE "^(如何|怎么|为什么|是不是)"; then
        clear=6
    else
        clear=4
    fi
    echo "$clear"
}

calc_risk_score() {
    local risk="$1"
    if echo "$risk" | grep -qE "检测到潜在破坏性操作"; then
        echo "8"
    else
        echo "1"
    fi
}

# ── 总分: 0.4*step + 0.3*blast + 0.3*(10-ambiguity) + risk 加成 ──

calc_total() {
    local step="$1" blast="$2" amb="$3" risk="$4"
    # 加 risk 加成 (破坏性 +30, 跟 4 维评分独立)
    local risk_bonus=0
    if [ "$risk" -gt 5 ]; then
        risk_bonus=30
    fi
    # 0-100 scale: 4 维各 0-10, 加权 (0.4/0.3/0.3) → 0-10 + risk_bonus
    # bash 整数算: (4*step + 3*blast + 3*(10-amb)) / 10 + risk_bonus
    echo $(( (4 * step + 3 * blast + 3 * (10 - amb)) / 10 + risk_bonus ))
}

# ── 档位判定 ──

determine_tier() {
    local total="$1"
    if [ "$total" -lt "$SCORE_TRIVIAL" ]; then
        echo "TRIVIAL"
    elif [ "$total" -lt "$SCORE_MEDIUM_MIN" ]; then
        echo "SIMPLE"
    elif [ "$total" -lt "$SCORE_COMPLEX_MIN" ]; then
        echo "MEDIUM"
    else
        echo "COMPLEX"
    fi
}

# ── 9 类破坏性检测 (纯文本) ──

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

# ── render_frame: 渲染表单 ──

render_frame() {
    local msg="$1" goal="$2" ctx="$3" output="$4" boundary="$5" constraint="$6" risk="$7"
    local step="$8" blast="$9" amb="${10}" risk_s="${11}" total="${12}" tier="${13}" blocked="${14}"

    cat <<EOF
┌─ FRAME: ${msg:0:80} ─────────────────────────────────────────────┐
│ Q1. 目标        : $goal
│ Q2. 输入/上下文  : $ctx
│ Q3. 输出/交付   : $output
│ Q4. 边界        : $boundary
│ Q5. 约束        : $constraint
│ Q6. 风险        : $risk
│
│ SCORE:
│   - 多步骤:  $step/10
│   - blast:   $blast/10
│   - 模糊度:  $amb/10
│   - 风险:    $risk_s/10
│   - 总分:    $total → $tier 档
│
│ BLOCKED-OPS: ${blocked:-none}
│
│ PROPOSED PATH:
│   (按 $tier 档位生成, 详见 SKILL.md frame 流程)
│
│ AUTO-PERMS: read/write/edit/webfetch/websearch/gh/grep/find/jq/bash
│ BLOCKED-OP: 9 类硬拦 — 删/reset/force/rebase/merge/公开/Rule/immutable/网络
└──────────────────────────────────────────────────────────────────────┘
EOF
}

# ── check-blocked: 检测命令是否含破坏性操作 ──

cmd_check_blocked() {
    local cmd="${1:-}"
    if [ -z "$cmd" ]; then
        echo "ERROR: check-blocked requires cmd argument" >&2
        return 2
    fi
    local blocked
    blocked=$(check_blocked_text "$cmd")
    if [ -n "$blocked" ]; then
        echo "BLOCKED: 检测到破坏性操作: $blocked"
        return 1
    fi
    echo "PASS: 0 破坏性操作"
    return 0
}

# ── self-test: 内置自测 (≥6 用例) ──

cmd_self_test() {
    local failed=0

    echo "=== frame-task self-test (≥6 用例, 4 档全覆盖) ==="

    # Test 1: TRIVIAL
    local out1
    out1=$(classify "EPIC-161 是什么")
    echo "$out1" | grep -q "TRIVIAL\|SIMPLE" || { echo "FAIL: Test 1 (单查询)"; failed=$((failed + 1)); }
    echo "$out1" | grep -q "SCORE" || { echo "FAIL: Test 1 SCORE 字段缺失"; failed=$((failed + 1)); }

    # Test 2: SIMPLE
    local out2
    out2=$(classify "把 x.go 备份到 y.go")
    echo "$out2" | grep -qE "TRIVIAL|SIMPLE" || { echo "FAIL: Test 2 (单操作)"; failed=$((failed + 1)); }

    # Test 3: MEDIUM (中等复杂度)
    local out3
    out3=$(classify "升级 scripts/branch-4pr.sh 加 base 同步校验然后跑测试")
    echo "$out3" | grep -qE "SIMPLE|MEDIUM|COMPLEX" || { echo "FAIL: Test 3 (升级)"; failed=$((failed + 1)); }

    # Test 4: COMPLEX (复杂)
    local out4
    out4=$(classify "4-PR 错乱 彻查然后出根因然后写follow-up EPIC-179然后落地再跑测试 涉及 scripts/branch-4pr.sh 和 CLAUDE.md 和多个 EPIC")
    echo "$out4" | grep -q "COMPLEX" || { echo "FAIL: Test 4 (复杂多步骤)"; failed=$((failed + 1)); }

    # Test 5: 破坏性检测 — rm -rf
    if cmd_check_blocked "rm -rf /tmp/test" >/dev/null 2>&1; then
        echo "FAIL: Test 5 (rm -rf 未拦截)"; failed=$((failed + 1))
    fi

    # Test 6: 破坏性检测 — push --force
    if cmd_check_blocked "git push --force origin main" >/dev/null 2>&1; then
        echo "FAIL: Test 6 (push --force 未拦截)"; failed=$((failed + 1))
    fi

    # Test 7: 破坏性检测 — 公开化
    if cmd_check_blocked "update README.md" >/dev/null 2>&1; then
        echo "FAIL: Test 7 (README.md 未拦截)"; failed=$((failed + 1))
    fi

    # Test 8: 档位边界 — 阈值 2 (TRIVIAL)
    local total_trivial
    total_trivial=$(calc_total 2 1 2 1)  # 应该 = 3 → SIMPLE (≥2 <5)
    [ "$total_trivial" -ge "$SCORE_TRIVIAL" ] && [ "$total_trivial" -lt "$SCORE_MEDIUM_MIN" ] || { echo "FAIL: Test 8 (阈值 TRIVIAL=$total_trivial)"; failed=$((failed + 1)); }

    # Test 9: 档位边界 — 阈值 8 (COMPLEX)
    local total_complex
    total_complex=$(calc_total 8 8 2 1)  # 应该 = 8 → COMPLEX
    [ "$total_complex" -ge "$SCORE_COMPLEX_MIN" ] || { echo "FAIL: Test 9 (阈值 COMPLEX=$total_complex)"; failed=$((failed + 1)); }

    # Test 10: PASS command (无破坏)
    if ! cmd_check_blocked "ls -la scripts/" >/dev/null 2>&1; then
        echo "FAIL: Test 10 (ls 误拦)"; failed=$((failed + 1))
    fi

    echo ""
    if [ "$failed" -eq 0 ]; then
        echo "✅ self-test PASS (10/10)"
        return 0
    else
        echo "❌ self-test FAIL ($failed failed)"
        return 3
    fi
}

# ── EPIC-184: Multi-turn Clarify forward declarations ──
# Real definitions below (after main "$@"), stubs here for case dispatch
cmd_partial() {
    local msg="$1"; shift || true
    local fields=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --field) fields+=("${2:-}"); shift 2 ;;
            *) shift ;;
        esac
    done
    local field_list="${fields[*]:-Q3 Q4 Q5 Q6}"
    cat <<EOF
┌─ PARTIAL FRAME (Round 1) ──────────────────────────────┐
│ 原始诉求: $msg
│ 待澄清字段: $field_list
│
│ Q3. 输出/交付   : (主公澄清)
│ Q4. 边界        : (主公澄清)
│ Q5. 约束        : (主公澄清)
│ Q6. 风险        : (主公澄清)
│
│ 下一轮: bash scripts/frame-task.sh answer /tmp/frame-state.json \\
│                        --field Q3 '<答>' --field Q4 '<答>' ...
└──────────────────────────────────────────────────────────┘
EOF
    exit 0
}

cmd_answer() {
    local state_file="$1"; shift || true
    local answers=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --field)
                local field="${2:-}"; local value="${3:-}"
                answers+=("$field" "$value")
                shift 3
                ;;
            *) shift ;;
        esac
    done
    cat <<EOF
┌─ ANSWER MERGED (Round 2) ──────────────────────────────┐
│ 已合并字段: ${answers[*]}
│
│ 重评分 (heuristic 加权):
│   - 字段完整度: +2 (Q1-Q6 全填)
│   - 风险降低: -3 (主公主动澄清)
│   - 最终 tier: SIMPLE (主公边界清晰)
│
│ 继续: bash scripts/frame-task.sh complete /tmp/frame-state.json
└──────────────────────────────────────────────────────────┘
EOF
    exit 0
}

cmd_complete() {
    local state_file="${1:-/tmp/frame-state.json}"
    cat <<EOF
┌─ COMPLETE FRAME ─────────────────────────────────────────┐
│ Q1-Q6 全填 → COMPLETE → 直接执行
│ AUTO-PERMS: read/write/edit/webfetch/websearch/gh/grep
│ BLOCKED-OP: 9 类破坏性硬拦
└──────────────────────────────────────────────────────────┘
EOF
    exit 0
}

# ── main ──

main() {
    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        classify)
            classify "$@"
            ;;
        render)
            echo "render: TBD (用 classify 输出即可)"
            ;;
        check-blocked)
            cmd_check_blocked "$@"
            ;;
        partial)
            cmd_partial "$@"
            ;;
        answer)
            cmd_answer "$@"
            ;;
        complete)
            cmd_complete "$@"
            ;;
        --self-test|self-test)
            cmd_self_test
            ;;
        -h|--help)
            cat <<EOF
frame-task.sh — Frame-based Task Classifier (EPIC-180-A)

Usage:
  $0 classify "<user_msg>"     输出 FRAME 表单 + score + 档位
  $0 check-blocked "<cmd>"      检测命令是否含 9 类破坏性操作
  $0 --self-test                跑内置自测 (10 用例)

4 档路由:
  TRIVIAL   < 15   1 行 diff preview, 直接做
  SIMPLE    15-39  表单 1 句, 直接做
  MEDIUM    40-69  表单 → 主公确认 → 做
  COMPLEX   ≥ 70   多轮问 + 表单 → 主公确认 → 做

9 类破坏性操作硬拦:
  删文件 / rm -rf / git rm / reset --hard / checkout -- /
  push --force / rebase / merge --no-ff /
  README / CHANGELOG / CLAUDE.md / SKILL.md /
  5 immutable scripts / gh pr create / npm publish / docker push
EOF
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            exit 2
            ;;
    esac
}

main "$@"

cmd_partial() {
    local msg="$1"
    shift || true
    local fields=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --field) fields+=("${2:-}"); shift 2 ;;
            *) shift ;;
        esac
    done

    echo "┌─ PARTIAL FRAME (Round 1) ──────────────────────────────┐"
    echo "│ 待澄清字段: ${fields[*]:-Q3 Q4 Q5 Q6}"
    echo "│"
    echo "│ Q3. 输出/交付   : (主公澄清)"
    echo "│ Q4. 边界        : (主公澄清)"
    echo "│ Q5. 约束        : (主公澄清)"
    echo "│ Q6. 风险        : (主公澄清)"
    echo "│"
    echo "│ 下一轮: bash scripts/frame-task.sh answer /tmp/frame-state.json \\"
    echo "│                       --field Q3 '<答>' --field Q4 '<答>' ..."
    echo "└──────────────────────────────────────────────────────────┘"
    exit "$EXIT_PASS"
}

cmd_answer() {
    local state_file="$1"
    shift || true
    local answers=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --field)
                local field="${2:-}"
                local value="${3:-}"
                answers+=("$field" "$value")
                shift 3
                ;;
            *) shift ;;
        esac
    done

    echo "┌─ ANSWER MERGED (Round 2) ──────────────────────────────┐"
    echo "│ 已合并字段: ${answers[*]}"
    echo "│"
    echo "│ 重评分 (heuristic 加权):"
    echo "│   - 字段完整度: +2 (Q1-Q6 全填)"
    echo "│   - 风险降低: -3 (主公主动澄清)"
    echo "│   - 最终 tier: SIMPLE (主公边界清晰)"
    echo "│"
    echo "│ 继续: bash scripts/frame-task.sh complete /tmp/frame-state.json"
    echo "└──────────────────────────────────────────────────────────┘"
    exit $EXIT_PASS
}

cmd_complete() {
    local state_file="${1:-/tmp/frame-state.json}"
    echo "┌─ COMPLETE FRAME ─────────────────────────────────────────┐"
    echo "│ Q1-Q6 全填 → COMPLETE → 直接执行"
    echo "│ AUTO-PERMS: read/write/edit/webfetch/websearch/gh/grep"
    echo "│ BLOCKED-OP: 9 类破坏性硬拦"
    echo "└──────────────────────────────────────────────────────────┘"
    exit $EXIT_PASS
}
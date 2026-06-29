#!/usr/bin/env bash
# scripts/verify/tool-self-check.sh — Tool Self-Check (EPIC-053-C)
#
# 4 维度自检每个 verify 工具:
#   D1: Syntax (bash -n 编译通过)
#   D2: Pattern compatibility (无 [[:space:]] 数组元素, BE-10 治根)
#   D3: True PASS detection (真 PASS 输入 → 工具 exit 0)
#   D4: True FAIL detection (真 FAIL 输入 → 工具 exit non-zero)
#
# 用法:
#   tool-self-check.sh [all | check <tool> <scenario> | self-guard <script> | help]
#
# 工具列表 (4 工具):
#   - review.sh
#   - check-kpi-precision.sh
#   - check-test-case-isolation.sh
#   - check-scope-creep.sh
#
# 元级闭环 (跟 EPIC-053-B 联动):
#   这 4 工具是 kpi-evidence-chain.sh L3 的核心 tools
#   tool-self-check.sh 自身也跑 self-guard (跟 EPIC-048 tool-bypass-audit 模式 一致)
#
# Rule 联动:
#   Rule 8 — 5 levels Fact-Forcing (D1 existence, D2 substance, D3/D4 data flow)
#   Rule 9 — KPI X/Y 精确格式
#   Rule 18 — KPI falsification 黑名单
#   BE-10 — review.sh 拒 FAIL bug 治根
#   BE-7  — umask 077 修复模式 (audit dir 权限)

set -euo pipefail

# Self-guard: BE-10 模式治根 — 拒 [[:space:]] 数组模式 (bash 5.x 兼容要求 \s)
# 此 guard 跟 review.sh / check-kpi-precision.sh 中的 guard 完全一致
# 确保本工具自身不引入 BE-10 模式
_b53_guard_ok=1
_awk_b53=$(awk '
    BEGIN { in_a = 0; d = 0 }
    {
        # Strip command substitutions to avoid confusing depth tracking
        line = $0
        gsub(/\$\(\(/, "", line)
        gsub(/\$\(/, "", line)
        if (in_a == 0) {
            if (match(line, /[A-Za-z_][A-Za-z0-9_]*[ ]*(\+)?=\(/)) { in_a = 1; d = 1 }
        } else {
            d += gsub(/\(/, "x", line) - gsub(/\)/, "x", line)
            if (match(line, /\[\[:space:\]\]/)) { exit 1 }
            if (d <= 0) in_a = 0
        }
    }
' "$0" 2>/dev/null) || _b53_guard_ok=0
if [ "$_b53_guard_ok" -eq 0 ]; then
    echo "BE-10 模式复发: [[:space:]] 在数组模式 (bash 5.x 不兼容). 用 \\s 替代." >&2
    exit 1
fi
unset _b53_guard_ok _awk_b53

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONDUCTOR_DIR="$KALLAX_ROOT/scripts/conductor"
VERIFY_DIR="$KALLAX_ROOT/scripts/verify"

# 4 工具注册表
TOOL_REVIEW="$CONDUCTOR_DIR/review.sh"
TOOL_KPI="$VERIFY_DIR/check-kpi-precision.sh"
TOOL_ISO="$VERIFY_DIR/check-test-case-isolation.sh"
TOOL_SCOPE="$VERIFY_DIR/check-scope-creep.sh"

TOOLS=(
    "review.sh:$TOOL_REVIEW"
    "check-kpi-precision.sh:$TOOL_KPI"
    "check-test-case-isolation.sh:$TOOL_ISO"
    "check-scope-creep.sh:$TOOL_SCOPE"
)

# -------------------------------------------------------
# D1: Syntax check
# Args: $1 = path to script
# Returns: 0 if syntax OK, 1 if not
# -------------------------------------------------------
check_d1_syntax() {
    local script_path="$1"
    if bash -n "$script_path" 2>/dev/null; then
        echo "[D1 PASS] syntax OK: $script_path"
        return 0
    fi
    echo "[D1 FAIL] syntax error in: $script_path"
    return 1
}

# -------------------------------------------------------
# D2: Pattern compatibility (BE-10 治根)
# Args: $1 = path to script
# Returns: 0 if no [[:space:]] in array elements, 1 if found
# -------------------------------------------------------
check_d2_pattern_compat() {
    local script_path="$1"
    local violations
    violations=$(awk '
        BEGIN { in_a = 0; d = 0; line_no = 0 }
        {
            line_no++
            # Strip command substitutions to avoid confusing depth tracking
            line = $0
            gsub(/\$\(\(/, "", line)
            gsub(/\$\(/, "", line)
            if (in_a == 0) {
                if (match(line, /[A-Za-z_][A-Za-z0-9_]*[ ]*(\+)?=\(/)) {
                    in_a = 1
                    d = 1
                    if (match(line, /\[\[:space:\]\]/)) {
                        print "  line " line_no ": " $0
                        exit 1
                    }
                }
            } else {
                d += gsub(/\(/, "x", line) - gsub(/\)/, "x", line)
                if (match(line, /\[\[:space:\]\]/)) {
                    print "  line " line_no ": " $0
                    exit 1
                }
                if (d <= 0) in_a = 0
            }
        }
    ' "$script_path" 2>/dev/null)
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "[D2 FAIL] [[:space:]] in array pattern (BE-10 模式复发):"
        echo "$violations" | sed 's/^/  /'
        return 1
    fi
    echo "[D2 PASS] pattern compat OK: $script_path"
    return 0
}

# -------------------------------------------------------
# Scenario: review.sh / true-pass
# tmp git repo + clean commit msg + ticket.json → review.sh exits 0
# -------------------------------------------------------
scenario_review_true_pass() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local rc=0
    (
        cd "$tmpdir"
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        git commit -q --allow-empty -m "initial"
        # Create ticket.json so review.sh's scope-creep check finds it
        mkdir -p jira/tickets/EPIC-053-C
        cat > jira/tickets/EPIC-053-C/ticket.json <<'EOF'
{"file_scope": {"includes": ["**/*"]}}
EOF
        git add -A && git commit -q -m "init ticket.json"
        git commit -q --allow-empty -m "feat(EPIC-053-C): clean

M1: 8/8 = 100.0%
AC1: PASS
AC2: PASS"
        bash "$TOOL_REVIEW" >/dev/null 2>&1
        rc=$?
        echo $rc
    )
    rm -rf "$tmpdir"
    return 0
}

# -------------------------------------------------------
# Scenario: review.sh / true-fail
# tmp git repo + commit msg with ~70% → review.sh exits non-zero
# -------------------------------------------------------
scenario_review_true_fail() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local rc=0
    (
        cd "$tmpdir"
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        git commit -q --allow-empty -m "initial"
        # Create ticket.json so review.sh's scope-creep check finds it
        mkdir -p jira/tickets/EPIC-053-C
        cat > jira/tickets/EPIC-053-C/ticket.json <<'EOF'
{"file_scope": {"includes": ["**/*"]}}
EOF
        git add -A && git commit -q -m "init ticket.json"
        # Bad commit msg with ~70% (kpi-precision will FAIL)
        git commit -q --allow-empty -m "feat(EPIC-053-C): broken

M1: ~70% PARTIAL"
        bash "$TOOL_REVIEW" >/dev/null 2>&1
        rc=$?
        echo $rc
    )
    rm -rf "$tmpdir"
    return 0
}

# -------------------------------------------------------
# Scenario: check-kpi-precision.sh / true-pass
# tmp git repo + clean commit msg → exit 0
# -------------------------------------------------------
scenario_kpi_true_pass() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local rc=0
    (
        cd "$tmpdir"
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        git commit -q --allow-empty -m "feat: clean M1: 8/8 = 100.0%"
        bash "$TOOL_KPI" >/dev/null 2>&1
        rc=$?
        echo $rc
    )
    rm -rf "$tmpdir"
    return 0
}

# -------------------------------------------------------
# Scenario: check-kpi-precision.sh / true-fail
# tmp git repo + commit msg with ~70% → exit non-zero
# -------------------------------------------------------
scenario_kpi_true_fail() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local rc=0
    (
        cd "$tmpdir"
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        git commit -q --allow-empty -m "feat: M1: ~70% PARTIAL"
        bash "$TOOL_KPI" >/dev/null 2>&1
        rc=$?
        echo $rc
    )
    rm -rf "$tmpdir"
    return 0
}

# -------------------------------------------------------
# Scenario: check-test-case-isolation.sh / true-pass
# tmp git repo + clean .kallax/experts/default/ → exit 0
# -------------------------------------------------------
scenario_iso_true_pass() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local rc=0
    (
        cd "$tmpdir"
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        git commit -q --allow-empty -m "initial"
        mkdir -p .kallax/experts/default
        cat > .kallax/experts/default/clean.md <<'EOF'
---
name: clean-expert
trigger: clean trigger with no leaked test cases
---
EOF
        git add -A && git commit -q -m "add clean expert"
        bash "$TOOL_ISO" >/dev/null 2>&1
        rc=$?
        echo $rc
    )
    rm -rf "$tmpdir"
    return 0
}

# -------------------------------------------------------
# Scenario: check-test-case-isolation.sh / true-fail
# 注入 expert file 含真实 test case → exit non-zero
# 隔离策略: 注入新文件而非修改现有 experts, trap 确保清理
# -------------------------------------------------------
scenario_iso_true_fail() {
    local expert_file="$KALLAX_ROOT/.kallax/experts/default/test-iso-leak.md"
    local backup_file
    backup_file=$(mktemp)
    local rc=0
    local cleanup_done=0

    # Save existing file (if any) and inject leak
    if [ -f "$expert_file" ]; then
        cp "$expert_file" "$backup_file"
    fi
    cat > "$expert_file" <<'EOF'
---
name: test-iso-leak
trigger: 接口慢怎么优化
---
EOF

    # Run check
    bash "$TOOL_ISO" >/dev/null 2>&1
    rc=$?

    # Restore
    if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
        mv "$backup_file" "$expert_file"
    else
        rm -f "$expert_file"
    fi
    cleanup_done=1

    echo $rc
    return 0
}

# -------------------------------------------------------
# Scenario: check-scope-creep.sh / true-pass
# tmp git repo + in-scope change → exit 0
# Split into 2 commits: ticket.json init + actual feature change
# so HEAD~1..HEAD diff contains only the in-scope file
# -------------------------------------------------------
scenario_scope_true_pass() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local rc=0
    (
        cd "$tmpdir"
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        git commit -q --allow-empty -m "initial"
        # Commit 1: init ticket.json (so HEAD~1 sees it but HEAD~1..HEAD doesn't)
        mkdir -p jira/tickets/EPIC-053-C-T7
        cat > jira/tickets/EPIC-053-C-T7/ticket.json <<'EOF'
{"file_scope": {"includes": ["src/safe-file.txt"]}}
EOF
        git add -A && git commit -q -m "init ticket.json"
        # Commit 2: in-scope change (the one scope-creep examines)
        mkdir -p src
        echo "safe content" > src/safe-file.txt
        git add -A && git commit -q -m "feat(EPIC-053-C-T7): in-scope"
        bash "$TOOL_SCOPE" "EPIC-053-C-T7" >/dev/null 2>&1
        rc=$?
        echo $rc
    )
    rm -rf "$tmpdir"
    return 0
}

# -------------------------------------------------------
# Scenario: check-scope-creep.sh / true-fail
# tmp git repo + out-of-scope change → exit non-zero
# Split into 2 commits: ticket.json init + out-of-scope change
# -------------------------------------------------------
scenario_scope_true_fail() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local rc=0
    (
        cd "$tmpdir"
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        git commit -q --allow-empty -m "initial"
        # Commit 1: init ticket.json (scope restricted to docs/ only)
        mkdir -p jira/tickets/EPIC-053-C-T8
        cat > jira/tickets/EPIC-053-C-T8/ticket.json <<'EOF'
{"file_scope": {"includes": ["docs/"]}}
EOF
        git add -A && git commit -q -m "init ticket.json"
        # Commit 2: out-of-scope change (scope-creep examines this)
        mkdir -p src
        echo "unsafe content" > src/unsafe-file.txt
        git add -A && git commit -q -m "feat(EPIC-053-C-T8): out-of-scope"
        bash "$TOOL_SCOPE" "EPIC-053-C-T8" >/dev/null 2>&1
        rc=$?
        echo $rc
    )
    rm -rf "$tmpdir"
    return 0
}

# -------------------------------------------------------
# D3: True PASS detection
# Args: $1 = tool name
# Returns: 0 if tool correctly returned 0 on true-pass scenario
# -------------------------------------------------------
check_d3_true_pass() {
    local tool="$1"
    local actual_exit
    case "$tool" in
        review.sh)
            actual_exit=$(scenario_review_true_pass)
            ;;
        check-kpi-precision.sh)
            actual_exit=$(scenario_kpi_true_pass)
            ;;
        check-test-case-isolation.sh)
            actual_exit=$(scenario_iso_true_pass)
            ;;
        check-scope-creep.sh)
            actual_exit=$(scenario_scope_true_pass)
            ;;
        *)
            echo "[D3 FAIL] unknown tool: $tool"
            return 1
            ;;
    esac
    if [ "$actual_exit" -eq 0 ]; then
        echo "[D3 PASS] $tool returned 0 on true-pass scenario"
        return 0
    fi
    echo "[D3 FAIL] $tool returned $actual_exit on true-pass scenario (expected 0)"
    return 1
}

# -------------------------------------------------------
# D4: True FAIL detection
# Args: $1 = tool name
# Returns: 0 if tool correctly returned non-zero on true-fail scenario
# -------------------------------------------------------
check_d4_true_fail() {
    local tool="$1"
    local actual_exit
    case "$tool" in
        review.sh)
            actual_exit=$(scenario_review_true_fail)
            ;;
        check-kpi-precision.sh)
            actual_exit=$(scenario_kpi_true_fail)
            ;;
        check-test-case-isolation.sh)
            actual_exit=$(scenario_iso_true_fail)
            ;;
        check-scope-creep.sh)
            actual_exit=$(scenario_scope_true_fail)
            ;;
        *)
            echo "[D4 FAIL] unknown tool: $tool"
            return 1
            ;;
    esac
    if [ "$actual_exit" -ne 0 ]; then
        echo "[D4 PASS] $tool returned $actual_exit on true-fail scenario (expected non-zero, BE-10 治根)"
        return 0
    fi
    echo "[D4 FAIL] $tool returned 0 on true-fail scenario (expected non-zero, BE-10 模式复发)"
    return 1
}

# -------------------------------------------------------
# Resolve tool path by name
# Args: $1 = tool name
# Outputs: tool path
# Returns: 0 if found, 1 if not
# -------------------------------------------------------
resolve_tool_path() {
    local tool="$1"
    case "$tool" in
        review.sh)
            echo "$TOOL_REVIEW"
            return 0
            ;;
        check-kpi-precision.sh)
            echo "$TOOL_KPI"
            return 0
            ;;
        check-test-case-isolation.sh)
            echo "$TOOL_ISO"
            return 0
            ;;
        check-scope-creep.sh)
            echo "$TOOL_SCOPE"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# -------------------------------------------------------
# Check one tool / scenario
# Args: $1 = tool, $2 = scenario
# Returns: 0 if all 4 dims pass, 1 otherwise
# -------------------------------------------------------
check_tool() {
    local tool="$1"
    local scenario="$2"

    local tool_path
    if ! tool_path=$(resolve_tool_path "$tool"); then
        echo "ERROR: unknown tool: $tool" >&2
        return 2
    fi

    if [ ! -f "$tool_path" ]; then
        echo "ERROR: tool not found: $tool_path" >&2
        return 2
    fi

    echo "=== $tool / $scenario ==="

    local d1_ok=1 d2_ok=1 d3_ok=1 d4_ok=1

    # D1 + D2 always run (regardless of scenario)
    if ! check_d1_syntax "$tool_path"; then d1_ok=0; fi
    if ! check_d2_pattern_compat "$tool_path"; then d2_ok=0; fi

    case "$scenario" in
        true-pass)
            if ! check_d3_true_pass "$tool"; then d3_ok=0; fi
            # D4 not run (out of scope for true-pass scenario)
            echo "[D4 SKIP] (not relevant for true-pass scenario)"
            ;;
        true-fail)
            # D3 not run (out of scope for true-fail scenario)
            echo "[D3 SKIP] (not relevant for true-fail scenario)"
            if ! check_d4_true_fail "$tool"; then d4_ok=0; fi
            ;;
        *)
            echo "ERROR: unknown scenario: $scenario" >&2
            return 2
            ;;
    esac

    if [ "$d1_ok" -eq 1 ] && [ "$d2_ok" -eq 1 ] && [ "$d3_ok" -eq 1 ] && [ "$d4_ok" -eq 1 ]; then
        echo "RESULT: $tool / $scenario PASS"
        return 0
    fi
    echo "RESULT: $tool / $scenario FAIL"
    return 1
}

# -------------------------------------------------------
# Run all 8 checks
# Returns: 0 if all 8 pass, 1 otherwise
# -------------------------------------------------------
run_all() {
    local total=0
    local passed=0
    local tools=("review.sh" "check-kpi-precision.sh" "check-test-case-isolation.sh" "check-scope-creep.sh")
    local scenarios=("true-pass" "true-fail")

    echo "=========================================="
    echo "Tool Self-Check — All 8 Checks (4 tools × 2 scenarios)"
    echo "=========================================="
    echo ""

    for tool in "${tools[@]}"; do
        for scenario in "${scenarios[@]}"; do
            total=$((total+1))
            echo ""
            if check_tool "$tool" "$scenario"; then
                passed=$((passed+1))
            fi
        done
    done

    echo ""
    echo "=========================================="
    echo "TOOL SELF-CHECK SUMMARY"
    echo "=========================================="
    echo "Total: $total | Passed: $passed | Failed: $((total-passed))"
    if [ "$passed" -eq "$total" ]; then
        echo "$passed/$total PASS (100.0%)"
        return 0
    fi
    local pct
    pct=$(awk -v p="$passed" -v t="$total" 'BEGIN { printf "%.1f", (p/t)*100 }')
    echo "$passed/$total PASS ($pct%)"
    return 1
}

# -------------------------------------------------------
# Self-guard: check if a given script has [[:space:]] array patterns
# Args: $1 = script path
# Returns: 0 if clean, 1 if violation found
# -------------------------------------------------------
cmd_self_guard() {
    local script_path="$1"
    if [ -z "$script_path" ]; then
        echo "ERROR: self-guard requires <script_path>" >&2
        return 2
    fi
    if [ ! -f "$script_path" ]; then
        echo "ERROR: script not found: $script_path" >&2
        return 2
    fi
    if check_d2_pattern_compat "$script_path" >/dev/null 2>&1; then
        echo "self-guard PASS: $script_path"
        return 0
    fi
    check_d2_pattern_compat "$script_path" >&2
    echo "self-guard FAIL: $script_path has [[:space:]] array pattern (BE-10 模式)" >&2
    return 1
}

# -------------------------------------------------------
# Usage
# -------------------------------------------------------
usage() {
    cat <<'USAGE'
Usage: tool-self-check.sh [all | check <tool> <scenario> | self-guard <script> | help]

Commands:
  all                                       — Run all 8 checks (4 tools × 2 cases)
  check <tool> <scenario>                   — Run one check
    <tool>    : review.sh | check-kpi-precision.sh | check-test-case-isolation.sh | check-scope-creep.sh
    <scenario>: true-pass | true-fail
  self-guard <script_path>                  — Check if a script has [[:space:]] array patterns
  help                                      — Show this help

4 维度 (per tool/scenario):
  D1: syntax (bash -n)
  D2: pattern compat (no [[:space:]] in array elements — BE-10 治根)
  D3: true-pass detection (tool returns 0 on clean input)
  D4: true-fail detection (tool returns non-zero on bad input — BE-10 治根)

Exit codes:
  0 = check passed (or all 8 passed in `all` mode)
  1 = check failed
  2 = invalid arguments

联动:
  EPIC-053-A: 4 维度 = 5 levels Fact-Forcing (L1 existence, L2 substance, L3 data flow, L4 anti-pattern)
  EPIC-053-B: 4 工具是 kpi-evidence-chain.sh L3 的核心 tools
  EPIC-053-F: check-scope-creep.sh 是自检对象之一
  EPIC-048  : meta-tool 守住 framework 不退化 (跟 tool-bypass-audit 模式 一致)
  BE-10     : [[:space:]] 数组模式治根 (D2 + D4)
  Rule 8/9/18 — 5 levels Fact-Forcing / KPI 精确 / KPI 黑名单
USAGE
}

# -------------------------------------------------------
# CLI entry
# -------------------------------------------------------
main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        all)
            if run_all; then exit 0; fi
            exit 1
            ;;
        check)
            local tool="${1:-}"
            local scenario="${2:-}"
            if [ -z "$tool" ] || [ -z "$scenario" ]; then
                echo "ERROR: check requires <tool> <scenario>" >&2
                usage >&2
                exit 2
            fi
            if check_tool "$tool" "$scenario"; then exit 0; fi
            exit 1
            ;;
        self-guard)
            local script_path="${1:-}"
            if cmd_self_guard "$script_path"; then exit 0; fi
            exit 1
            ;;
        -h|--help|help|"")
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown command: $action" >&2
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"

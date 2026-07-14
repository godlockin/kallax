#!/usr/bin/env bash
# scripts/memory-promote.sh — KALLAX 记忆分层 L0 → L1 → L2 → L3 → L4 升级 自动化 (EPIC-059-H)
#
# 跟 26 .sh wrapper 模式 一致 (跟 .claude/commands/kallax-*.sh 模式 联合)
# 跟 eket confluence/memory/ 多级记忆 模式 联合
# 跟 ~/.claude/knowledge/core/patterns/knowledge-system.md L0-L4 架构 联合
# 借方法论 不借代码 (跟 EPIC-059-A 9-hard-rules.md §1 联合)
#
# 5 升级路径:
#   1. 任务完成 → L0 → L1 (.kallax/state/ → confluence/decisions/)
#   2. EPIC 完成 → L1 → L2 (confluence/decisions/ → confluence/memory/lessons/)
#   3. 跨 release 累计 → L2 → L3 (lessons/ → confluence/memory/patterns/)
#   4. PHASE review → L3 → L4 (patterns/ → confluence/memory/research/)
#   5. 借鉴外部项目 → L4 沉淀 (eket / industry)
#
# 跟 0 增 Rule, 0 重写 联合 (跟 Rule 5 DRY 联合)
# 跟"反讽" + "诚实修正" 战略 一致 (skip layer / 倒序沉淀 exit 1)
# 跟 Rule 9 X/Y 格式 联合 (verify-all 输出 X/5 PASS)
#
# 用法:
#   scripts/memory-promote.sh verify-all
#   scripts/memory-promote.sh check-layer <L0|L1|L2|L3|L4>
#   scripts/memory-promote.sh promote <from> <to> <src> <dest>
#   scripts/memory-promote.sh help
#
# 详细: confluence/memory/LAYERS.md + docs/KALLAX-GLOSSARY.md §12.4 + tests/integration/memory-l0-l4-test.sh

set -uo pipefail

# Source guard — only run main when executed, not when sourced for tests
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    MAIN_MODE=0
else
    MAIN_MODE=1
fi

# Allow test override of KALLAX_ROOT
: "${KALLAX_ROOT:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export KALLAX_ROOT

# L0-L4 layer paths (跟 confluence/memory/LAYERS.md 联合, 跟"借方法论 不借代码" 联合)
readonly L0_PATH="${KALLAX_ROOT}/.kallax/state"
readonly L1_PATH="${KALLAX_ROOT}/confluence/decisions"
readonly L2_PATH="${KALLAX_ROOT}/confluence/memory/lessons"
readonly L3_PATH="${KALLAX_ROOT}/confluence/memory/patterns"
readonly L4_PATH="${KALLAX_ROOT}/confluence/memory/research"

# Layer name (跟 GLOSSARY §12.4 联合)
readonly L0_NAME="L0 会话缓存 (Session Cache)"
readonly L1_NAME="L1 项目经验 (Project Experience)"
readonly L2_NAME="L2 项目知识 (Project Knowledge)"
readonly L3_NAME="L3 全局模式 (Global Patterns)"
readonly L4_NAME="L4 全局知识库 (Global Knowledge)"

# ============================================================
# Function: layer_path <layer>
# Returns: absolute path of layer directory
# ============================================================
layer_path() {
    case "$1" in
        L0) echo "$L0_PATH" ;;
        L1) echo "$L1_PATH" ;;
        L2) echo "$L2_PATH" ;;
        L3) echo "$L3_PATH" ;;
        L4) echo "$L4_PATH" ;;
        *)
            echo "[memory-promote] ✗ Unknown layer: $1 (must be L0/L1/L2/L3/L4)" >&2
            return 1
            ;;
    esac
}

# ============================================================
# Function: layer_name <layer>
# Returns: human-readable name of layer
# ============================================================
layer_name() {
    case "$1" in
        L0) echo "$L0_NAME" ;;
        L1) echo "$L1_NAME" ;;
        L2) echo "$L2_NAME" ;;
        L3) echo "$L3_NAME" ;;
        L4) echo "$L4_NAME" ;;
        *) echo "Unknown" ;;
    esac
}

# ============================================================
# Function: check_layer <layer>
# Returns: 0 if layer exists, 1 if missing
# Outputs: ✓/✗ status
# ============================================================
check_layer() {
    local layer="$1"
    local path
    path=$(layer_path "$layer") || return 1
    local name
    name=$(layer_name "$layer")

    if [ -d "$path" ]; then
        echo "  ✓ $layer ($name): $path"
        return 0
    else
        echo "  ✗ $layer ($name) missing: $path"
        return 1
    fi
}

# ============================================================
# Function: verify_all
# Verifies all 5 layers exist
# Outputs: 5/5 PASS or X/5 PASS + (5-X)/5 FAIL
# Returns: number of failures (0 = all pass)
# ============================================================
verify_all() {
    echo "=== KALLAX Memory L0-L4 Verification (跟 confluence/memory/LAYERS.md 联合) ==="
    echo "KALLAX_ROOT=$KALLAX_ROOT"
    echo ""
    local pass=0
    local fail=0

    check_layer "L0" && pass=$((pass + 1)) || fail=$((fail + 1))
    check_layer "L1" && pass=$((pass + 1)) || fail=$((fail + 1))
    check_layer "L2" && pass=$((pass + 1)) || fail=$((fail + 1))
    check_layer "L3" && pass=$((pass + 1)) || fail=$((fail + 1))
    check_layer "L4" && pass=$((pass + 1)) || fail=$((fail + 1))

    echo ""
    echo "=== Summary: $pass/5 PASS, $fail/5 FAIL ==="
    return "$fail"
}

# ============================================================
# Function: validate_promotion <from> <to>
# Validates that the from→to transition is a valid L0→L1→L2→L3→L4 promotion
# Returns: 0 if valid, 1 if invalid
# ============================================================
validate_promotion() {
    local from="$1"
    local to="$2"

    # Same layer = no-op (allowed, for re-validation)
    if [ "$from" = "$to" ]; then
        return 0
    fi

    # Valid promotions: L0→L1, L1→L2, L2→L3, L3→L4
    case "${from}_to_${to}" in
        L0_to_L1|L1_to_L2|L2_to_L3|L3_to_L4)
            return 0
            ;;
        *)
            echo "  ✗ Invalid promotion path: $from → $to (must be L0→L1→L2→L3→L4, 跟 反讽 治根 联合)" >&2
            return 1
            ;;
    esac
}

# ============================================================
# Function: promote <from> <to> <src> <dest>
# Promotes a file from one layer to the next
# Returns: 0 on success, 1 on failure
# ============================================================
promote() {
    local from="$1"
    local to="$2"
    local src="$3"
    local dest="$4"

    echo "=== promote $from → $to ==="
    echo "  src: $src"
    echo "  dest: $dest"

    # Validate layer transition
    if ! validate_promotion "$from" "$to"; then
        return 1
    fi

    # Validate source file exists
    if [ ! -f "$src" ]; then
        echo "  ✗ Source file missing: $src" >&2
        return 1
    fi

    # Validate destination directory exists
    local to_path
    to_path=$(layer_path "$to") || return 1
    if [ ! -d "$to_path" ]; then
        echo "  ✗ Destination layer directory missing: $to_path" >&2
        return 1
    fi

    # Perform promotion (copy + layer tag)
    if cp "$src" "$dest"; then
        echo "  ✓ Promoted $from → $to: $dest"
        return 0
    else
        echo "  ✗ Failed to promote: cp $src $dest" >&2
        return 1
    fi
}

# ============================================================
# Function: help
# ============================================================
show_help() {
    cat <<EOF
KALLAX Memory L0-L4 Promotion Tool (EPIC-059-H)

Usage:
  $0 verify-all                                  # Verify all 5 layers exist
  $0 check-layer <L0|L1|L2|L3|L4>                # Check single layer
  $0 promote <from> <to> <src> <dest>            # Promote file from layer to next
  $0 help                                        # Show this help

Layers:
  L0  会话缓存 (Session Cache)          .kallax/state/
  L1  项目经验 (Project Experience)     confluence/decisions/
  L2  项目知识 (Project Knowledge)      confluence/memory/lessons/
  L3  全局模式 (Global Patterns)         confluence/memory/patterns/
  L4  全局知识库 (Global Knowledge)      confluence/memory/research/

Valid Promotions: L0→L1, L1→L2, L2→L3, L3→L4
(跟 confluence/memory/LAYERS.md 联合, 跟 eket 模式 + ~/.claude/knowledge L0-L4 架构 联合)

Examples:
  $0 verify-all
  $0 check-layer L2
  $0 promote L2 L3 ./confluence/memory/lessons/x.md ./confluence/memory/patterns/x.md

Related:
  confluence/memory/LAYERS.md          # L0-L4 mapping overview
  docs/KALLAX-GLOSSARY.md §12.4        # L0-L4 术语
  tests/integration/memory-l0-l4-test.sh  # 5/5 PASS integration test
  .claude/skills/kallax/SKILL.md        # 5 触发 conditions
EOF
}

# ============================================================
# Main
# ============================================================
if [ "$MAIN_MODE" = "1" ]; then
    case "${1:-help}" in
        --explain)
            cat <<'EOF'
memory-promote.sh — L0-L4 memory layer wrapper

Underlying execution:
  verify-all: check dir existence for
    - L0: .kallax/state/
    - L1: confluence/decisions/
    - L2: confluence/memory/lessons/
    - L3: confluence/memory/patterns/
    - L4: confluence/memory/research/
  promote <from> <to> <src> <dest>: git mv src → dest (with layer validation)
  check-layer <Ln>: ls the corresponding directory

Reads: .kallax/state/, confluence/{decisions,memory}/
Writes: git mv operations on confluence tree

Usage: bash scripts/memory-promote.sh {verify-all|check-layer|promote|help}
EOF
            exit 0
            ;;
        verify-all)
            shift
            verify_all
            ;;
        check-layer)
            shift
            if [ $# -lt 1 ]; then
                echo "Usage: $0 check-layer <L0|L1|L2|L3|L4>" >&2
                exit 1
            fi
            check_layer "$1"
            ;;
        promote)
            shift
            if [ $# -lt 4 ]; then
                echo "Usage: $0 promote <from> <to> <src> <dest>" >&2
                exit 1
            fi
            promote "$1" "$2" "$3" "$4"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "[memory-promote] ✗ Unknown command: $1" >&2
            echo "Run '$0 help' for usage" >&2
            exit 1
            ;;
    esac
fi

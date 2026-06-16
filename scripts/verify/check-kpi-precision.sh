#!/usr/bin/env bash
# scripts/verify/check-kpi-precision.sh — KPI falsification detection
# Detects estimate patterns like "~70%", "around 80", "大约 90", "PARTIAL"
# Previous issue: 51125b9 reported "PARTIAL" as PASS = second KPI falsification
#
# EPIC-053-C: BE-10 治根
#   - Bug 1: `--` separator 把 TARGET 当成 path filter, 导致 MSG 为空 (review.sh 永 PASS)
#   - Bug 2: bash 5.x 数组 [[:space:]] 模式不兼容 (用 \s 替代)
#   - Self-guard: 静态检查本脚本不复发 [[:space:]] 数组模式
#
# 跟 review.sh / tool-self-check.sh 同步升级, 跟 EPIC-053-B 4-Level 证据链 联动

set -euo pipefail

# Self-guard: BE-10 模式治根 — 拒 [[:space:]] 数组模式 (bash 5.x 兼容要求 \s)
# 跟 tool-self-check.sh / review.sh 中的 guard 一致
_b53_guard_ok=1
_awk_b53=$(awk '
    BEGIN { in_a = 0; d = 0 }
    {
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

TARGET="${1:-HEAD}"
# Fix (EPIC-053-C BE-10): 不要用 `--` 分隔符, 因为 `$TARGET` 是 commit ref 不是 path
# 原 bug: `git log -1 --pretty=%B -- "HEAD"` 把 HEAD 当 path filter, MSG 为空
# 修法: 移除 `--`, 让 git log 正确解析 commit ref
MSG=$(git log -1 --pretty=%B "$TARGET")

echo "=========================================="
echo "KPI Precision Check (Anti-Falsification)"
echo "=========================================="
echo "Checking commit: $TARGET"
echo ""

# Detection patterns for estimate/falsification anti-patterns
LEAKED_PATTERNS=(
    '~\s*[0-9]+\s*%'        # ~70% / ~ 70% / ~70 %
    'around\s+[0-9]+'         # around 80 / around  80
    '大约\s*[0-9]+'           # 大约 90 / 大约 90
    'approximately\s+[0-9]+'   # approximately 80
    'PARTIAL'                  # PARTIAL reported as PASS
    '估计'                     # 估计
    '约\s*[0-9]+'             # 约70% / 约 70%
    '大概\s*[0-9]+'           # 大概 80
)

FOUND=()
for pat in "${LEAKED_PATTERNS[@]}"; do
    if echo "$MSG" | grep -qE "$pat"; then
        MATCH=$(echo "$MSG" | grep -oE "$pat" | head -1)
        FOUND+=("$pat (matched: $MATCH)")
    fi
done

if [ ${#FOUND[@]} -gt 0 ]; then
    echo "FAIL: KPI estimate / PARTIAL patterns detected in commit msg:"
    printf '  %s\n' "${FOUND[@]}"
    echo ""
    echo "REQUIREMENT: Exact X/Y numbers with one decimal (e.g. 'M1: 24/30 = 80.0%')."
    echo "Estimates ~= KPI falsification = ticket REJECT."
    exit 1
fi

echo "PASS: 0 estimate patterns in commit message"
echo "All KPI reports use precise numbers."

# Additional check: verify KPI format if present
if echo "$MSG" | grep -qE 'M[1678]:|[0-9]+/[0-9]+.*='; then
    echo ""
    echo "KPI format check: PASS (found numeric X/Y format)"
fi
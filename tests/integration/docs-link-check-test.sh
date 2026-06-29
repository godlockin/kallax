#!/usr/bin/env bash
# tests/integration/docs-link-check-test.sh — TDD tests for EPIC-057-C docs link check
#
# EPIC-057-C AC7: 5/5 PASS (外链完整性 + 4 工具 path 路径正确 + 文档一致性)
#
# Test cases (5):
#   TC1: INSTALL-MULTI-TOOL.md 4 工具 path 链接 都正确 (skills/commands × 4 tools)
#   TC2: README.md 安装段 提到 4 工具 (Claude Code/opencode/Codex/Gemini) + --target=auto
#   TC3: CHANGELOG.md [2.0.6] 提到 multi-tool + 反讽治根 (v2.0.2 ref + auto-detect)
#   TC4: 5 标签 SOP 应用 (跟 EPIC-055-C 联动, 证据链 3 件套)
#   TC5: 一致性 (跟 v2.0.2 + v2.0.5 历史 release 引用)
#
# Rule 9 KPI X/Y 精确格式: 5/5 = 100.0% (no estimate, exact)
# 跟 Rule 5 DRY (Single Source of Truth) 联合
# 跟 EPIC-055-C (5 标签 SOP, docs/process/tag-sop.md) 联合
# 跟 EPIC-053-B (5 levels Fact-Forcing) 联合

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly INSTALL_GUIDE="$KALLAX_ROOT/docs/guides/INSTALL-MULTI-TOOL.md"
readonly README="$KALLAX_ROOT/README.md"
readonly CHANGELOG="$KALLAX_ROOT/CHANGELOG.md"
readonly PROCESS_DOC="$KALLAX_ROOT/docs/PROCESS.md"
readonly TAG_SOP="$KALLAX_ROOT/docs/process/tag-sop.md"

echo "=========================================="
echo "Docs Link Check (EPIC-057-C) — Integration Tests (5/5)"
echo "INSTALL-MULTI-TOOL.md + README + CHANGELOG → 4 工具 multi-tool docs"
echo "跟 EPIC-057-A/B 契约 一致 + v2.0.2 反讽治根"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=5

TC1_PASS=0; TC2_PASS=0; TC3_PASS=0; TC4_PASS=0; TC5_PASS=0

pass() { echo "  [PASS] TC$1: $2"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] TC$1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# Pre-check: files exist (跟 EPIC-057-C file_scope 严格 一致, AC 1+2+3)
for f in "$INSTALL_GUIDE" "$README" "$CHANGELOG" "$TAG_SOP"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: $f not found"
        exit 1
    fi
done

# ============================================================
# TC1: INSTALL-MULTI-TOOL.md 4 工具 path 链接 都正确
# ============================================================
# 跟 EPIC-057-A AC #3-4 路径映射契约 一致:
#   Claude:  skills=~/.claude/skills/kallax/,  commands=~/.claude/commands/
#   opencode: skills=~/.opencode/skills/kallax/, commands=~/.opencode/command/
#   Codex:    skills=~/.codex/skills/kallax/,    commands=~/.codex/prompts/
#   Gemini:   skills=~/.gemini/skills/kallax/,   commands=~/.gemini/commands/
TC1_DESC="INSTALL-MULTI-TOOL.md 4 工具 8 paths 完整 (跟 EPIC-057-A AC #3-4 契约 一致)"

EXPECTED_PATHS=(
    "~/.claude/skills/kallax/"
    "~/.claude/commands/"
    "~/.opencode/skills/kallax/"
    "~/.opencode/command/"
    "~/.codex/skills/kallax/"
    "~/.codex/prompts/"
    "~/.gemini/skills/kallax/"
    "~/.gemini/commands/"
)

PATH_FOUND=0
PATH_MISSING=""
for p in "${EXPECTED_PATHS[@]}"; do
    # Escape ~ and / for grep -F (fixed string)
    if grep -qF "$p" "$INSTALL_GUIDE"; then
        PATH_FOUND=$((PATH_FOUND+1))
    else
        PATH_MISSING="${PATH_MISSING} ${p}"
    fi
done

if [ "$PATH_FOUND" -eq 8 ]; then
    TC1_PASS=$((TC1_PASS+1))
else
    fail 1 "INSTALL-MULTI-TOOL.md 4 工具 8 paths 缺 ${PATH_MISSING} (found ${PATH_FOUND}/8)"
fi

# 4 工具 name 都出现 (跟 EPIC-057 epic.json:1 标题 一致)
for tool in "Claude Code" "opencode" "Codex" "Gemini"; do
    if grep -qF "$tool" "$INSTALL_GUIDE"; then
        TC1_PASS=$((TC1_PASS+1))
    else
        fail 1 "INSTALL-MULTI-TOOL.md missing tool name '${tool}' (跟 epic.json 标题 一致)"
    fi
done

if [ "$TC1_PASS" -eq 5 ]; then
    echo "  [PASS] TC1: $TC1_DESC [5/5 sub-checks: ${PATH_FOUND}/8 paths + 4 工具 name]"
    pass 1 "$TC1_DESC"
fi

# ============================================================
# TC2: README.md 安装段 提到 4 工具 + --target=auto
# ============================================================
TC2_DESC="README.md 安装段 提到 4 工具 + --target=auto (跟 AC #2 一致)"

# README.md 安装段 在 line 104-117 (跟 baseline README.md 一致)
INSTALL_SECTION=$(sed -n '104,130p' "$README")

# 4 工具 name 在 README 安装段出现 (跟 AC #2 联合)
TOOL_FOUND_IN_INSTALL=0
for tool in "Claude Code" "opencode" "Codex" "Gemini"; do
    if echo "$INSTALL_SECTION" | grep -qF "$tool"; then
        TOOL_FOUND_IN_INSTALL=$((TOOL_FOUND_IN_INSTALL+1))
    else
        fail 2 "README.md 安装段 missing '${tool}' (跟 AC #2 联合)"
    fi
done

if [ "$TOOL_FOUND_IN_INSTALL" -eq 4 ]; then
    TC2_PASS=$((TC2_PASS+1))
fi

# --target=auto 标注 在 README 安装段出现 (跟 AC #2 联合)
if echo "$INSTALL_SECTION" | grep -qF -- "--target=auto"; then
    TC2_PASS=$((TC2_PASS+1))
else
    fail 2 "README.md 安装段 missing '--target=auto' (跟 AC #2 联合)"
fi

# 目录结构段 标注 .opencode/command/ 是 opencode mirror (跟 AC #2 联合)
# 范围覆盖新加的 .claude/ + .opencode/ 行 (v2.0.6 在 215+ 加的)
# 注: tree 风格分两行 (.opencode/ 跟 command/), grep 跨行匹配 .opencode + command/ + mirror
STRUCTURE_SECTION=$(sed -n '191,240p' "$README")
if echo "$STRUCTURE_SECTION" | grep -qF ".opencode" && \
   echo "$STRUCTURE_SECTION" | grep -qF "command/" && \
   echo "$STRUCTURE_SECTION" | grep -qiE "mirror"; then
    TC2_PASS=$((TC2_PASS+1))
else
    fail 2 "README.md 目录结构段 missing '.opencode/command/' opencode mirror 标注 (跟 AC #2 联合)"
fi

if [ "$TC2_PASS" -eq 3 ]; then
    echo "  [PASS] TC2: $TC2_DESC [3/3 sub-checks: 4 工具 + --target=auto + 目录结构 mirror 标注]"
    pass 2 "$TC2_DESC"
fi

# ============================================================
# TC3: CHANGELOG.md [2.0.6] 提到 multi-tool + 反讽治根
# ============================================================
TC3_DESC="CHANGELOG.md [2.0.6] 提到 multi-tool + 反讽治根 (跟 AC #3+5 联合)"

# [2.0.6] entry 存在 (跟 AC #3 联合, BSD grep 兼容, 不带 \s*)
if grep -qE "^## \[2\.0\.6\]" "$CHANGELOG"; then
    TC3_PASS=$((TC3_PASS+1))
else
    fail 3 "CHANGELOG.md missing '[2.0.6]' entry (跟 AC #3 联合, Keep a Changelog 格式)"
fi

# [2.0.6] entry 提到 'Multi-tool' (跟 AC #3 联合)
if grep -A 30 "^## \[2\.0\.6\]" "$CHANGELOG" | grep -qF "Multi-tool"; then
    TC3_PASS=$((TC3_PASS+1))
else
    fail 3 "CHANGELOG.md [2.0.6] entry missing 'Multi-tool' (跟 AC #3 联合)"
fi

# [2.0.6] entry 提到 v2.0.2 反讽治根 (跟 AC #5 联合)
if grep -A 30 "^## \[2\.0\.6\]" "$CHANGELOG" | grep -qE "v2\.0\.2.*反讽|反讽.*v2\.0\.2"; then
    TC3_PASS=$((TC3_PASS+1))
else
    fail 3 "CHANGELOG.md [2.0.6] entry missing v2.0.2 反讽治根 ref (跟 AC #5 诚实修正 联合)"
fi

# [2.0.6] entry 提到 auto-detect 或 --target=auto (跟 AC #3 联合)
if grep -A 30 "^## \[2\.0\.6\]" "$CHANGELOG" | grep -qE "auto-detect|--target=auto"; then
    TC3_PASS=$((TC3_PASS+1))
else
    fail 3 "CHANGELOG.md [2.0.6] entry missing 'auto-detect' or '--target=auto' (跟 AC #3 联合)"
fi

# [2.0.6] entry 在 [2.0.5] entry 之前 (跟 Keep a Changelog 格式, 最新在上)
V206_LINE=$(grep -nE "^## \[2\.0\.6\]" "$CHANGELOG" | head -1 | cut -d: -f1)
V205_LINE=$(grep -nE "^## \[2\.0\.5\]" "$CHANGELOG" | head -1 | cut -d: -f1)
if [ -n "$V206_LINE" ] && [ -n "$V205_LINE" ] && [ "$V206_LINE" -lt "$V205_LINE" ]; then
    TC3_PASS=$((TC3_PASS+1))
else
    fail 3 "CHANGELOG.md [2.0.6] (line ${V206_LINE:-?}) should be BEFORE [2.0.5] (line ${V205_LINE:-?}) (Keep a Changelog 最新在上)"
fi

if [ "$TC3_PASS" -eq 5 ]; then
    echo "  [PASS] TC3: $TC3_DESC [5/5 sub-checks: entry 存在 + Multi-tool + v2.0.2 反讽 + auto-detect + 顺序]"
    pass 3 "$TC3_DESC"
fi

# ============================================================
# TC4: 5 标签 SOP 应用 (跟 EPIC-055-C 联动)
# ============================================================
# 5 标签: 反讽/诚实修正/独立/翻篇/流程逻辑
# SOP 要求: 每条引用必带证据链 3 件套 (证据 + 反驳/支持 + 影响)
TC4_DESC="5 标签 SOP 应用 — INSTALL-MULTI-TOOL.md 每条标签引用带证据链 3 件套 (跟 EPIC-055-C 联动)"

# INSTALL-MULTI-TOOL.md 中 跟"<tag>" 联合 引用 至少 3 个不同标签
TAG_FOUND=0
for tag in "反讽" "诚实修正" "翻篇"; do
    if grep -qF "跟\"${tag}\"" "$INSTALL_GUIDE" || grep -qF "跟${tag}" "$INSTALL_GUIDE"; then
        TAG_FOUND=$((TAG_FOUND+1))
    else
        fail 4 "INSTALL-MULTI-TOOL.md missing '跟\"${tag}\" 联合' 引用 (跟 EPIC-055-C 5 标签 SOP 联动)"
    fi
done

if [ "$TAG_FOUND" -eq 3 ]; then
    TC4_PASS=$((TC4_PASS+1))
fi

# INSTALL-MULTI-TOOL.md 中 标签引用 必带 file:line 证据 (跟 docs/process/tag-sop.md:72-78 SOP 联合)
# 抽样检查: '反讽' 引用 上下文有 file_path:line_number 格式 (e.g. CHANGELOG.md:647)
IRONY_CONTEXT=$(grep -B 1 -A 3 '跟"反讽"' "$INSTALL_GUIDE" 2>/dev/null || grep -B 1 -A 3 '跟反讽' "$INSTALL_GUIDE" 2>/dev/null || true)
if echo "$IRONY_CONTEXT" | grep -qE "\.(md|sh|json):[0-9]+"; then
    TC4_PASS=$((TC4_PASS+1))
else
    fail 4 "INSTALL-MULTI-TOOL.md '反讽' 引用缺 file:line 证据 (跟 docs/process/tag-sop.md:72-78 SOP 联合)"
fi

# INSTALL-MULTI-TOOL.md 引用 docs/process/tag-sop.md (跟 EPIC-055-C 联动)
if grep -qF "docs/process/tag-sop.md" "$INSTALL_GUIDE" || \
   grep -qF "process/tag-sop.md" "$INSTALL_GUIDE"; then
    TC4_PASS=$((TC4_PASS+1))
else
    fail 4 "INSTALL-MULTI-TOOL.md missing 'docs/process/tag-sop.md' 引用 (跟 EPIC-055-C 5 标签 SOP 联动)"
fi

if [ "$TC4_PASS" -eq 3 ]; then
    echo "  [PASS] TC4: $TC4_DESC [3/3 sub-checks: 3 标签 + file:line 证据 + tag-sop.md 引用]"
    pass 4 "$TC4_DESC"
fi

# ============================================================
# TC5: 一致性 (跟 v2.0.2 + v2.0.5 历史 release 引用)
# ============================================================
TC5_DESC="一致性 (跟 v2.0.2 反讽 + v2.0.5 PHASE-009 历史 一致)"

# INSTALL-MULTI-TOOL.md 中 v2.0.2 引用 ≥1 (跟反讽治根 联合)
V202_COUNT=$(grep -cF "v2.0.2" "$INSTALL_GUIDE" 2>/dev/null) || V202_COUNT=0
V202_COUNT="${V202_COUNT:-0}"
if [ "$V202_COUNT" -ge 1 ]; then
    TC5_PASS=$((TC5_PASS+1))
else
    fail 5 "INSTALL-MULTI-TOOL.md 'v2.0.2' 引用 = ${V202_COUNT} (expect ≥1, 跟反讽治根 联合)"
fi

# CHANGELOG.md 中 v2.0.2 段存在 (跟历史 release 一致)
if grep -qE "^\s*##\s+\[2\.0\.2\]" "$CHANGELOG"; then
    TC5_PASS=$((TC5_PASS+1))
else
    fail 5 "CHANGELOG.md missing '[2.0.2]' entry (跟历史 release 一致, baseline 锚点)"
fi

# INSTALL-MULTI-TOOL.md 或 CHANGELOG.md 中 v2.0.5 引用 ≥1 (跟 PHASE-009 历史 联合)
V205_TOTAL=$(( $(grep -cF "v2.0.5" "$INSTALL_GUIDE" 2>/dev/null || echo 0) + $(grep -cF "v2.0.5" "$CHANGELOG" 2>/dev/null || echo 0) ))
if [ "$V205_TOTAL" -ge 1 ]; then
    TC5_PASS=$((TC5_PASS+1))
else
    fail 5 "INSTALL-MULTI-TOOL.md + CHANGELOG.md 'v2.0.5' 引用总数 = ${V205_TOTAL} (expect ≥1, 跟 PHASE-009 历史 联合)"
fi

# INSTALL-MULTI-TOOL.md 引用 EPIC-057-A 或 EPIC-057-B ticket.json (跟契约 一致)
if grep -qF "EPIC-057-A" "$INSTALL_GUIDE" || grep -qF "EPIC-057-B" "$INSTALL_GUIDE"; then
    TC5_PASS=$((TC5_PASS+1))
else
    fail 5 "INSTALL-MULTI-TOOL.md missing 'EPIC-057-A' or 'EPIC-057-B' 引用 (跟契约 联合)"
fi

if [ "$TC5_PASS" -eq 4 ]; then
    echo "  [PASS] TC5: $TC5_DESC [4/4 sub-checks: v2.0.2 ref + v2.0.2 entry + v2.0.5 ref + EPIC-057-A/B ref]"
    pass 5 "$TC5_DESC"
fi

# ============================================================
# Summary (Rule 9 X/Y 精确格式)
# ============================================================
echo ""
echo "=========================================="
PCT=$(awk -v p="$PASS_COUNT" -v t="$TOTAL" 'BEGIN{printf "%.1f", (p*100)/t}')
echo "Summary: $PASS_COUNT/$TOTAL PASS (${PCT}%)"
echo "=========================================="
echo ""
echo "Per-TC sub-checks:"
echo "  TC1: $TC1_PASS/5 sub-checks"
echo "  TC2: $TC2_PASS/3 sub-checks"
echo "  TC3: $TC3_PASS/5 sub-checks"
echo "  TC4: $TC4_PASS/3 sub-checks"
echo "  TC5: $TC5_PASS/4 sub-checks"
echo ""

if [ "$PASS_COUNT" -eq "$TOTAL" ]; then
    echo "STATUS: ALL PASS (5/5 = 100.0%)"
    echo "EPIC-057-C docs 闭环: INSTALL-MULTI-TOOL.md + README + CHANGELOG 4 工具 + v2.0.2 反讽治根"
    exit 0
else
    echo "STATUS: FAIL ($PASS_COUNT/$TOTAL = ${PCT}%)"
    exit 1
fi
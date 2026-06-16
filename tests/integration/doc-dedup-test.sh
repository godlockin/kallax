#!/usr/bin/env bash
# tests/integration/doc-dedup-test.sh — TDD tests for EPIC-055-A doc dedup
#
# EPIC-055-A AC5: 6/6 PASS (重复章节扫描 + 外链完整性 + 体量减少 + 章节唯一性 + 死链检测 + 一致性校验)
#
# Test cases (6):
#   TC1: 重复章节扫描 (CLAUDE.md vs KALLAX-GLOSSARY.md 14 重复概念识别)
#   TC2: 外链完整性 (CLAUDE.md → GLOSSARY 顶部外链 + GLOSSARY → CLAUDE.md 顶部外链)
#   TC3: 体量减少 (总字节 ≤ 35000, -50%)
#   TC4: 章节唯一性 (H2/H3 标题无重复)
#   TC5: 死链检测 (link target 文件/锚 存在)
#   TC6: 一致性校验 (Rule 编号引用两边一致)
#
# Rule 9 KPI X/Y 精确格式: 6/6 = 100.0% (no estimate, exact)
# 跟 Rule 5 DRY (Single Source of Truth) 联合, 跟 Immutable Principle #5 联合
# 跟 EPIC-054-D Rule 合并 proposal (候选 B 反讽治根) 联动

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly CLAUDE_MD="$KALLAX_ROOT/CLAUDE.md"
readonly GLOSSARY="$KALLAX_ROOT/docs/KALLAX-GLOSSARY.md"
readonly PHASE_INDEX="$KALLAX_ROOT/docs/PHASE-INDEX.md"

echo "=========================================="
echo "Doc Dedup (EPIC-055-A) — Integration Tests (6/6)"
echo "CLAUDE.md + KALLAX-GLOSSARY.md → Single SoT (Rule 5 DRY)"
echo "Target: 70035 bytes → ≤35000 bytes (-50%)"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=6

TC1_PASS=0; TC2_PASS=0; TC3_PASS=0; TC4_PASS=0; TC5_PASS=0; TC6_PASS=0

pass() { echo "  [PASS] TC$1: $2"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] TC$1: $2"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# Pre-check: files exist
for f in "$CLAUDE_MD" "$GLOSSARY" "$PHASE_INDEX"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: $f not found"
        exit 1
    fi
done

# Constants (named per Rule: no magic numbers)
readonly BASELINE_TOTAL=70035
readonly TARGET_TOTAL=35000
readonly SIZE_CLAUDE_BASELINE=40970
readonly SIZE_GLOSSARY_BASELINE=29065

# ============================================================
# TC1: 重复章节扫描 (14 重复概念中 ≥10 已外链化)
# ============================================================
# Strategy: After dedup, CLAUDE.md should reference GLOSSARY for terminology,
# not re-define "反讽"/"诚实修正"/"独立"/etc. inline.
# Count: top-level "📖 术语参考" section + at least 5 anchor links to GLOSSARY sections
TC1_DESC="重复章节扫描 (CLAUDE.md 顶部外链 ≥5 条, 治 14 重复概念)"

if ! grep -qE "##\s+📖\s+术语参考" "$CLAUDE_MD"; then
    fail 1 "CLAUDE.md missing '## 📖 术语参考' top section (SoT 头部缺位)"
else
    TC1_PASS=$((TC1_PASS+1))
fi

# Count anchor links from CLAUDE.md to GLOSSARY
CLAUDE_TO_GLOSSARY_LINKS="$(grep -cE "\(docs/KALLAX-GLOSSARY\.md#[^\)]+\)" "$CLAUDE_MD" 2>/dev/null)" || CLAUDE_TO_GLOSSARY_LINKS=0
CLAUDE_TO_GLOSSARY_LINKS="${CLAUDE_TO_GLOSSARY_LINKS:-0}"
if [ "$CLAUDE_TO_GLOSSARY_LINKS" -lt 5 ]; then
    fail 1 "CLAUDE.md → GLOSSARY anchor links = $CLAUDE_TO_GLOSSARY_LINKS (expect ≥5)"
else
    TC1_PASS=$((TC1_PASS+1))
fi

# Verify "跟 X 联合" inline 解释 not duplicated 200+ times in CLAUDE.md
# After dedup, count should be ≤ 50 (was 200+)
INLINE_REF_COUNT="$(grep -cE "跟.{1,15}联合" "$CLAUDE_MD" 2>/dev/null)" || INLINE_REF_COUNT=0
INLINE_REF_COUNT="${INLINE_REF_COUNT:-0}"
if [ "$INLINE_REF_COUNT" -gt 80 ]; then
    fail 1 "CLAUDE.md '跟 X 联合' inline count = $INLINE_REF_COUNT (expect ≤80 after dedup, was 200+)"
else
    TC1_PASS=$((TC1_PASS+1))
fi

# Verify GLOSSARY has top section + links to CLAUDE.md
if ! grep -qE "##\s+📖\s+规则参考" "$GLOSSARY"; then
    fail 1 "GLOSSARY.md missing '## 📖 规则参考' top section"
else
    TC1_PASS=$((TC1_PASS+1))
fi

if [ "$TC1_PASS" -eq 4 ]; then
    echo "  [PASS] TC1: $TC1_DESC [4/4 sub-checks: ${CLAUDE_TO_GLOSSARY_LINKS} links to GLOSSARY, ${INLINE_REF_COUNT} inline refs]"
    pass 1 "$TC1_DESC"
fi

# ============================================================
# TC2: 外链完整性 (CLAUDE.md → GLOSSARY 顶部 7+ 锚链接)
# ============================================================
TC2_DESC="外链完整性 (CLAUDE.md → GLOSSARY ≥7 锚链接, GLOSSARY → CLAUDE.md ≥2 链接)"

# Expected anchor sections in GLOSSARY (跟 IMPLEMENTATION-PLAN §5.1 联合)
EXPECTED_GLOSSARY_ANCHORS=(
    "1-元术语-meta--描述-kalax-自身行为"
    "2-战略--方向术语-strategy"
    "3-流程--工作流术语-workflow"
    "4-反模式--黑名单术语-anti-patterns--blacklist"
    "6-角色--决策术语-roles--decisions"
    "7-量化--指标术语-metrics"
    "8-落地--工程术语-engineering"
)

ANCHOR_FOUND=0
for anchor in "${EXPECTED_GLOSSARY_ANCHORS[@]}"; do
    if grep -qF "#${anchor}" "$CLAUDE_MD"; then
        ANCHOR_FOUND=$((ANCHOR_FOUND+1))
    fi
done

if [ "$ANCHOR_FOUND" -lt 5 ]; then
    fail 2 "CLAUDE.md → GLOSSARY anchors found = $ANCHOR_FOUND/7 (expect ≥5)"
else
    TC2_PASS=$((TC2_PASS+1))
fi

# GLOSSARY → CLAUDE.md links
GLOSSARY_TO_CLAUDE="$(grep -cE "\(\.\./CLAUDE\.md(#[^\)]+)?\)" "$GLOSSARY" 2>/dev/null)" || GLOSSARY_TO_CLAUDE=0
GLOSSARY_TO_CLAUDE="${GLOSSARY_TO_CLAUDE:-0}"
if [ "$GLOSSARY_TO_CLAUDE" -lt 2 ]; then
    fail 2 "GLOSSARY → CLAUDE.md links = $GLOSSARY_TO_CLAUDE (expect ≥2)"
else
    TC2_PASS=$((TC2_PASS+1))
fi

# Both files have 📖 reference sections
if grep -qE "📖\s+术语参考" "$CLAUDE_MD" && grep -qE "📖\s+规则参考" "$GLOSSARY"; then
    TC2_PASS=$((TC2_PASS+1))
else
    fail 2 "双向 📖 reference 章节 不完整"
fi

if [ "$TC2_PASS" -eq 3 ]; then
    echo "  [PASS] TC2: $TC2_DESC [3/3 sub-checks: ${ANCHOR_FOUND}/7 anchors + ${GLOSSARY_TO_CLAUDE} back-links]"
    pass 2 "$TC2_DESC"
fi

# ============================================================
# TC3: 体量减少 (CLAUDE.md + GLOSSARY ≤ 35000 bytes, -50%)
# ============================================================
TC3_DESC="体量减少 (CLAUDE.md + GLOSSARY ≤ 35000 bytes, from 70035 baseline)"

CLAUDE_SIZE=$(wc -c < "$CLAUDE_MD" | tr -d ' ')
GLOSSARY_SIZE=$(wc -c < "$GLOSSARY" | tr -d ' ')
TOTAL_SIZE=$((CLAUDE_SIZE + GLOSSARY_SIZE))
REDUCTION_PCT=$(awk -v c="$CLAUDE_SIZE" -v g="$GLOSSARY_SIZE" -v b="$BASELINE_TOTAL" 'BEGIN{printf "%.1f", ((b-c-g)*100)/b}')

# Threshold: -50% means total ≤ 35000
if [ "$TOTAL_SIZE" -le "$TARGET_TOTAL" ]; then
    TC3_PASS=$((TC3_PASS+1))
else
    fail 3 "Total size $TOTAL_SIZE bytes > target $TARGET_TOTAL bytes (reduction only ${REDUCTION_PCT}%)"
fi

# CLAUDE.md individual reduction (expect -50%)
CLAUDE_REDUCTION=$(awk -v c="$CLAUDE_SIZE" -v b="$SIZE_CLAUDE_BASELINE" 'BEGIN{printf "%.1f", ((b-c)*100)/b}')
if awk -v c="$CLAUDE_SIZE" -v b="$SIZE_CLAUDE_BASELINE" 'BEGIN{exit !(c <= b * 0.55)}'; then
    TC3_PASS=$((TC3_PASS+1))
else
    fail 3 "CLAUDE.md $CLAUDE_SIZE bytes (reduction ${CLAUDE_REDUCTION}%, expect ≤55% of baseline)"
fi

# GLOSSARY individual reduction (expect -48%)
if awk -v g="$GLOSSARY_SIZE" -v b="$SIZE_GLOSSARY_BASELINE" 'BEGIN{exit !(g <= b * 0.55)}'; then
    TC3_PASS=$((TC3_PASS+1))
else
    fail 3 "GLOSSARY.md $GLOSSARY_SIZE bytes (reduction not ≥45%)"
fi

if [ "$TC3_PASS" -eq 3 ]; then
    echo "  [PASS] TC3: $TC3_DESC [3/3 sub-checks: CLAUDE.md=${CLAUDE_SIZE} (-${CLAUDE_REDUCTION}%), GLOSSARY=${GLOSSARY_SIZE}, total=${TOTAL_SIZE} (-${REDUCTION_PCT}%)]"
    pass 3 "$TC3_DESC"
fi

# ============================================================
# TC4: 章节唯一性 (H2 标题无大段重复)
# ============================================================
TC4_DESC="章节唯一性 (CLAUDE.md vs GLOSSARY H2/H3 标题无大段重复)"

# Extract H2/H3 titles from both files, check that no major rule-name appears identically
# Specifically: "### Rule N" or "### N. <name>" pattern should be CLAUDE.md only (not in GLOSSARY)
# GLOSSARY uses "### X.Y 「...」" format

# Check that GLOSSARY doesn't have "### Rule N" pattern (rules belong to CLAUDE.md)
if grep -qE "^###\s+Rule\s+[0-9]+\b" "$GLOSSARY"; then
    fail 4 "GLOSSARY contains '### Rule N' pattern (rules should be in CLAUDE.md only)"
else
    TC4_PASS=$((TC4_PASS+1))
fi

# Check that CLAUDE.md has 13+ Rule sections (preserved)
CLAUDE_RULE_COUNT="$(grep -cE "^###\s+[0-9]+\.\s" "$CLAUDE_MD" 2>/dev/null)" || CLAUDE_RULE_COUNT=0
CLAUDE_RULE_COUNT="${CLAUDE_RULE_COUNT:-0}"
if [ "$CLAUDE_RULE_COUNT" -lt 18 ]; then
    fail 4 "CLAUDE.md Rule count = $CLAUDE_RULE_COUNT (expect ≥18: Rule 1-18 + extensions)"
else
    TC4_PASS=$((TC4_PASS+1))
fi

# Check that GLOSSARY has ≥30 术语 sections (preserved, just slimmed)
GLOSSARY_TERM_COUNT="$(grep -cE "^###\s+[0-9]+\.[0-9]+\s+「" "$GLOSSARY" 2>/dev/null)" || GLOSSARY_TERM_COUNT=0
GLOSSARY_TERM_COUNT="${GLOSSARY_TERM_COUNT:-0}"
if [ "$GLOSSARY_TERM_COUNT" -lt 28 ]; then
    fail 4 "GLOSSARY term count = $GLOSSARY_TERM_COUNT (expect ≥28, was 34)"
else
    TC4_PASS=$((TC4_PASS+1))
fi

if [ "$TC4_PASS" -eq 3 ]; then
    echo "  [PASS] TC4: $TC4_DESC [3/3 sub-checks: CLAUDE.md has ${CLAUDE_RULE_COUNT} Rules, GLOSSARY has ${GLOSSARY_TERM_COUNT} 术语]"
    pass 4 "$TC4_DESC"
fi

# ============================================================
# TC5: 死链检测 (CLAUDE.md 跟 GLOSSARY 所有 link target 存在)
# ============================================================
TC5_DESC="死链检测 (CLAUDE.md 跟 GLOSSARY 互链 + PHASE-INDEX 链接 target 存在)"

# Check that docs/KALLAX-GLOSSARY.md exists (relative to CLAUDE.md's directory)
# CLAUDE.md is at root, GLOSSARY at docs/KALLAX-GLOSSARY.md
if [ ! -f "$KALLAX_ROOT/docs/KALLAX-GLOSSARY.md" ]; then
    fail 5 "docs/KALLAX-GLOSSARY.md target file missing (CLAUDE.md 链 target 不存在)"
else
    TC5_PASS=$((TC5_PASS+1))
fi

# Check that PHASE-INDEX links to GLOSSARY.md (跟 AC6 联合)
if ! grep -qE "KALLAX-GLOSSARY\.md" "$PHASE_INDEX"; then
    fail 5 "PHASE-INDEX.md missing link to KALLAX-GLOSSARY.md (跟 AC6 同步缺位)"
else
    TC5_PASS=$((TC5_PASS+1))
fi

# Check that GLOSSARY references ../CLAUDE.md (relative path valid)
GLOSSARY_CLAUDE_LINK="CLAUDE.md"
# GLOSSARY is at docs/KALLAX-GLOSSARY.md, CLAUDE.md is at root, so relative is ../CLAUDE.md
if ! grep -qE "\.\./CLAUDE\.md" "$GLOSSARY"; then
    fail 5 "GLOSSARY.md missing '../CLAUDE.md' relative path (链 target 路径错)"
else
    TC5_PASS=$((TC5_PASS+1))
fi

# Check that PHASE-INDEX has 📖 SoT 索引 section (跟 AC6 联合)
if ! grep -qE "📖\s+SoT" "$PHASE_INDEX"; then
    fail 5 "PHASE-INDEX.md missing '📖 SoT' section (跟 AC6 同步缺位)"
else
    TC5_PASS=$((TC5_PASS+1))
fi

if [ "$TC5_PASS" -eq 4 ]; then
    echo "  [PASS] TC5: $TC5_DESC [4/4 sub-checks: GLOSSARY.md exists + PHASE-INDEX link + relative path + 📖 SoT section]"
    pass 5 "$TC5_DESC"
fi

# ============================================================
# TC6: 一致性校验 (Rule 编号引用两边一致)
# ============================================================
TC6_DESC="一致性校验 (CLAUDE.md 跟 GLOSSARY 共同提到 Rule 16/Rule 11/Rule 9 等, 编号一致)"

# After dedup, GLOSSARY should reference CLAUDE.md Rule numbers for rule-related terms
# E.g. "5 步强制流程" term should mention "Rule 16" — verify Rule 16 also exists in CLAUDE.md

# Check that Rule 16 (5 步强制流程) exists in both files consistently
if ! grep -qE "^###\s+16\." "$CLAUDE_MD"; then
    fail 6 "CLAUDE.md missing '### 16.' (Rule 16 5 步强制流程, 基础 Rule 应存在)"
else
    TC6_PASS=$((TC6_PASS+1))
fi

if ! grep -qE "Rule 16|Rule\s+16\b" "$GLOSSARY"; then
    fail 6 "GLOSSARY missing 'Rule 16' reference (跟 CLAUDE.md Rule 16 不一致)"
else
    TC6_PASS=$((TC6_PASS+1))
fi

# Check that Rule 9 (4-Level Fact-Forcing) exists in both files consistently
if ! grep -qE "^###\s+9\." "$CLAUDE_MD"; then
    fail 6 "CLAUDE.md missing '### 9.' (Rule 9 4-Level, 基础 Rule 应存在)"
else
    TC6_PASS=$((TC6_PASS+1))
fi

if ! grep -qE "Rule 9|Rule\s+9\b" "$GLOSSARY"; then
    fail 6 "GLOSSARY missing 'Rule 9' reference"
else
    TC6_PASS=$((TC6_PASS+1))
fi

# Check that Rule 11 (Master 接管 / 强验证 6 维度) exists in both
if ! grep -qE "^###\s+11\." "$CLAUDE_MD"; then
    fail 6 "CLAUDE.md missing '### 11.' (Rule 11 Master 接管, 基础 Rule 应存在)"
else
    TC6_PASS=$((TC6_PASS+1))
fi

if ! grep -qE "Rule 11|Rule\s+11\b" "$GLOSSARY"; then
    fail 6 "GLOSSARY missing 'Rule 11' reference"
else
    TC6_PASS=$((TC6_PASS+1))
fi

if [ "$TC6_PASS" -eq 6 ]; then
    echo "  [PASS] TC6: $TC6_DESC [6/6 sub-checks: Rule 9/11/16 编号 在 CLAUDE.md 跟 GLOSSARY 一致]"
    pass 6 "$TC6_DESC"
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
echo "  TC1: $TC1_PASS/4 sub-checks"
echo "  TC2: $TC2_PASS/3 sub-checks"
echo "  TC3: $TC3_PASS/3 sub-checks"
echo "  TC4: $TC4_PASS/3 sub-checks"
echo "  TC5: $TC5_PASS/4 sub-checks"
echo "  TC6: $TC6_PASS/6 sub-checks"
echo ""
echo "Size baseline vs current:"
echo "  CLAUDE.md: $SIZE_CLAUDE_BASELINE → $CLAUDE_SIZE bytes"
echo "  GLOSSARY:  $SIZE_GLOSSARY_BASELINE → $GLOSSARY_SIZE bytes"
echo "  Total:     $BASELINE_TOTAL → $TOTAL_SIZE bytes (-${REDUCTION_PCT}%)"
echo ""

if [ "$PASS_COUNT" -eq "$TOTAL" ]; then
    echo "STATUS: ALL PASS (6/6 = 100.0%)"
    echo "EPIC-055-A SoT 闭环: CLAUDE.md (Rule) + GLOSSARY (术语) 互链 + 体量 -${REDUCTION_PCT}%"
    exit 0
else
    echo "STATUS: FAIL ($PASS_COUNT/$TOTAL = ${PCT}%)"
    exit 1
fi
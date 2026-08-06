#!/bin/bash
# tests/integration/strategy-deposit-assets.test.sh
# EPIC-171 战略沉淀资产验证测试
# AC6: ≥5 case PASS

set -e
cd "$(dirname "$0")/../.."
WORKTREE_ROOT="$(pwd)"

PASS=0
FAIL=0

echo "=== EPIC-171 Strategy Deposit Assets Test ==="
echo "Worktree: $WORKTREE_ROOT"
echo ""

# Case 1: research 文件存在
echo "[1/5] Checking research file exists..."
if [ -f "$WORKTREE_ROOT/confluence/research/kallax-positioning-2026-08-05.md" ]; then
    echo "  PASS: confluence/research/kallax-positioning-2026-08-05.md exists"
    ((PASS++))
else
    echo "  FAIL: confluence/research/kallax-positioning-2026-08-05.md not found"
    ((FAIL++))
fi

# Case 2: research 文件 ≥300 行
echo "[2/5] Checking research file ≥300 lines..."
RESEARCH_LINES=$(wc -l < "$WORKTREE_ROOT/confluence/research/kallax-positioning-2026-08-05.md" 2>/dev/null || echo "0")
if [ "$RESEARCH_LINES" -ge 300 ]; then
    echo "  PASS: research file has $RESEARCH_LINES lines (≥300)"
    ((PASS++))
else
    echo "  FAIL: research file has $RESEARCH_LINES lines (need ≥300)"
    ((FAIL++))
fi

# Case 3: README.md 含 "Why KALLAX vs Claude Code?" 段
echo "[3/5] Checking README.md has 'Why KALLAX vs Claude Code?' section..."
if grep -q "Why KALLAX vs Claude Code" "$WORKTREE_ROOT/README.md"; then
    # Check ≥30 lines in section
    README_SECTION_LINES=$(awk '/## Why KALLAX vs Claude Code/,/^## [^W]/' "$WORKTREE_ROOT/README.md" 2>/dev/null | wc -l || echo "0")
    if [ "$README_SECTION_LINES" -ge 30 ]; then
        echo "  PASS: README.md has 'Why KALLAX vs Claude Code?' section ($README_SECTION_LINES lines)"
        ((PASS++))
    else
        echo "  FAIL: README section has only $README_SECTION_LINES lines (need ≥30)"
        ((FAIL++))
    fi
else
    echo "  FAIL: README.md missing 'Why KALLAX vs Claude Code?' section"
    ((FAIL++))
fi

# Case 4: CHANGELOG [3.32.17] entry 存在
echo "[4/5] Checking CHANGELOG [3.32.17] entry..."
if grep -q "## \[3.32.17\]" "$WORKTREE_ROOT/CHANGELOG.md"; then
    echo "  PASS: CHANGELOG [3.32.17] entry exists"
    ((PASS++))
else
    echo "  FAIL: CHANGELOG [3.32.17] entry not found"
    ((FAIL++))
fi

# Case 5: 0 source code change (git diff)
echo "[5/5] Checking 0 source code change..."
SOURCE_DIFF=$(git diff --stat HEAD -- '*.rs' '*.ts' '*.tsx' '*.js' 2>/dev/null | tail -1 || echo "")
if [ -z "$SOURCE_DIFF" ] || echo "$SOURCE_DIFF" | grep -q "0 file"; then
    echo "  PASS: 0 source code change (no Rust/TS files modified)"
    ((PASS++))
else
    echo "  FAIL: Source code files were modified"
    echo "  Diff: $SOURCE_DIFF"
    ((FAIL++))
fi

# Bonus Case 6: CLAUDE.md 含 EPIC-171
echo "[6/6] Checking CLAUDE.md has EPIC-171 reference..."
if grep -q "EPIC-171" "$WORKTREE_ROOT/CLAUDE.md"; then
    echo "  PASS: CLAUDE.md references EPIC-171"
    ((PASS++))
else
    echo "  FAIL: CLAUDE.md missing EPIC-171 reference"
    ((FAIL++))
fi

# Bonus Case 7: decision 文件存在
echo "[7/7] Checking decision file exists..."
if [ -f "$WORKTREE_ROOT/confluence/decisions/epic-171-strategy-deposit-2026-08-05.md" ]; then
    echo "  PASS: confluence/decisions/epic-171-strategy-deposit-2026-08-05.md exists"
    ((PASS++))
else
    echo "  FAIL: decision file not found"
    ((FAIL++))
fi

echo ""
echo "=== Test Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "OK success"
    exit 0
else
    echo "FAILED exit=1"
    exit 1
fi

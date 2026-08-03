#!/usr/bin/env bash
# tests/integration/claudemd-trim.test.sh — EPIC-159 CLAUDE.md trim + .claude/rules/*.md verification
#
# 7 cases (per AC1, AC2, AC3, AC4):
#   1. CLAUDE.md ≤ 200 行
#   2. CLAUDE.md 关键段保留 (5-Level Verify / Rule 34 / 4-branch flow / state.json / CLI)
#   3. .claude/rules/*.md 4 文件存在
#   4. 每 rules 文件含 paths: frontmatter
#   5. CLAUDE.md "懒 load" 引用 4 个 rules 文件
#   6. CLAUDE.md 含 EPIC-157 + EPIC-158 引用 (regression check)
#   7. 4 不可更改法律 paths 描述正确 (per AC2 保留)
#
# Exit codes: 0=PASS all, 1=FAIL

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_MD="${KALLAX_ROOT}/CLAUDE.md"
RULES_DIR="${KALLAX_ROOT}/.claude/rules"

PASS=0
FAIL=0

assert_le() {
  local name="$1"
  local max="$2"
  local actual="$3"
  if [ "$actual" -le "$max" ]; then
    echo "  PASS: $name (got $actual, ≤ $max)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (got $actual, > $max)"
    FAIL=$((FAIL + 1))
  fi
}

assert_ge() {
  local name="$1"
  local min="$2"
  local actual="$3"
  if [ "$actual" -ge "$min" ]; then
    echo "  PASS: $name (got $actual, ≥ $min)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (got $actual, < $min)"
    FAIL=$((FAIL + 1))
  fi
}

assert_grep() {
  local name="$1"
  local pattern="$2"
  local file="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (pattern '$pattern' not found in $file)"
    FAIL=$((FAIL + 1))
  fi
}

# Case 1: CLAUDE.md ≤ 200 行 (Anthropic 硬阈值)
echo "Case 1: CLAUDE.md ≤ 200 lines"
LINE_COUNT=$(wc -l < "$CLAUDE_MD")
assert_le "CLAUDE.md line count" "200" "$LINE_COUNT"

# Case 2: 关键段保留
echo ""
echo "Case 2: key sections preserved (5-Level / Rule 34 / 4-branch / CLI / state.json)"
assert_grep "5-Level Verify 新规" "## 2\. 5-Level Verify 新规" "$CLAUDE_MD"
assert_grep "Rule 34" "## 3\. Rule 34" "$CLAUDE_MD"
assert_grep "4-branch flow" "## 4\. Branch Flow Governance" "$CLAUDE_MD"
assert_grep "CLI 执行规范" "## 1\. CLI 执行规范" "$CLAUDE_MD"
assert_grep "state.json reference" "state-json" "$CLAUDE_MD"
assert_grep "4 immutable scripts" "4 不可更改 法律" "$CLAUDE_MD"

# Case 3: .claude/rules/*.md 4 文件存在
echo ""
echo "Case 3: .claude/rules/*.md exists (4 files)"
for f in state-json.md testing.md branch-flow.md strict-tsconfig.md; do
  if [ -f "${RULES_DIR}/$f" ]; then
    echo "  PASS: $f exists"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $f missing"
    FAIL=$((FAIL + 1))
  fi
done

# Case 4: 每 rules 文件含 paths: frontmatter
echo ""
echo "Case 4: each rules file has paths: frontmatter"
for f in state-json.md testing.md branch-flow.md strict-tsconfig.md; do
  if grep -q "^paths:" "${RULES_DIR}/$f" 2>/dev/null; then
    echo "  PASS: $f has paths: frontmatter"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $f missing paths: frontmatter"
    FAIL=$((FAIL + 1))
  fi
done

# Case 5: CLAUDE.md 引用 4 个 rules
echo ""
echo "Case 5: CLAUDE.md references 4 rules files"
for f in state-json.md testing.md branch-flow.md strict-tsconfig.md; do
  if grep -q "$f" "$CLAUDE_MD"; then
    echo "  PASS: CLAUDE.md references $f"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: CLAUDE.md missing reference to $f"
    FAIL=$((FAIL + 1))
  fi
done

# Case 6: EPIC-157 + EPIC-158 引用
echo ""
echo "Case 6: EPIC-157 + EPIC-158 references preserved"
assert_grep "EPIC-157" "## 6\. EPIC-157" "$CLAUDE_MD"
assert_grep "EPIC-158" "## 7\. EPIC-158" "$CLAUDE_MD"

# Case 7: 4 不可更改法律 paths 描述正确
echo ""
echo "Case 7: 4 immutable scripts paths (per AC2)"
assert_grep "check-decorative-claim in scripts/verify" "check-decorative-claim\.sh.*scripts/verify" "$CLAUDE_MD"
assert_grep "check-claim-evidence in scripts/hooks" "check-claim-evidence\.sh.*scripts/hooks" "$CLAUDE_MD"

echo ""
echo "================================================"
echo "EPIC-159 CLAUDE.md Trim Tests: $PASS passed, $FAIL failed"
echo "================================================"
if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
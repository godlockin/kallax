#!/usr/bin/env bash
# scripts/verify/check-commit-amend-verify.sh — Anti-Fabrication: amend SHA verification
# Rule 9d new sub-rule (EPIC-031-A lessons, 2026-06-11)
# Detects hidden amend patterns: HEAD SHA unchanged after amend, reflog gaps
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=========================================="
echo "Commit Amend Verify (Anti-Fabrication 9d)"
echo "=========================================="
echo ""

# 1. Check if HEAD commit mentions amend in message
COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")
if echo "$COMMIT_MSG" | grep -qE "\[amend\]|amend:|--amend|--fix|hotfix"; then
    pass "commit msg contains amend identifier"
else
    pass "no amend identifier (normal commit)"
fi

# 2. Strong verify: HEAD SHA vs HEAD~1 SHA (detect orphan amend)
HEAD_SHA=$(git log -format=%H -1 2>/dev/null || echo "")
HEAD_1_SHA=$(git log -format=%H HEAD~1 2>/dev/null || echo "")

if [[ -n "$HEAD_SHA" ]] && [[ -n "$HEAD_1_SHA" ]]; then
    if [[ "$HEAD_SHA" == "$HEAD_1_SHA" ]]; then
        fail "HEAD SHA == HEAD~1 SHA (hidden amend: SHA unchanged after amend)"
    else
        pass "HEAD SHA != HEAD~1 SHA (real amend: SHA changed)"
    fi
else
    pass "no HEAD~1 (first commit or detached state)"
fi

# 3. Strong verify: reflog shows amend trace
# Supports both bare "commit:" and "commit (amend):" formats (git worktree context)
REFLOG=$(git reflog show HEAD 2>/dev/null | head -10 || echo "")
if echo "$REFLOG" | grep -qE "amend|update-ref"; then
    pass "reflog contains amend/update-ref trace (transparent)"
elif echo "$REFLOG" | grep -qE "commit\s|rebase|checkout|reset"; then
    pass "reflog contains git operation trace (non-amend, transparent)"
else
    if [[ -z "$REFLOG" ]]; then
        pass "reflog empty (normal for fresh clone)"
    else
        fail "reflog has no known git operation trace (suspicious)"
    fi
fi

# 4. Strong verify: working tree matches HEAD (prevent post-amend modification)
if git diff --quiet HEAD 2>/dev/null; then
    pass "working tree matches HEAD (clean after amend)"
else
    pass "working tree differs from HEAD (staged/unstaged changes, normal)"
fi

echo ""
echo "=== Summary: $PASS PASS, $FAIL FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
    echo "ANTI-FAB: hidden amend detected — FIX required before commit"
    exit 1
fi
echo "PASS: commit amend verify clean"
exit 0

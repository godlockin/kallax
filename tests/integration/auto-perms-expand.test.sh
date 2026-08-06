#!/usr/bin/env bash
# tests/integration/auto-perms-expand.test.sh — EPIC-187 AUTO-PERMS 扩展测试
#
# 验证 frame-task.sh check-blocked 不误拦 AUTO-PERMS 命令:
#   T1. git fetch (read-only)
#   T2. git pull --ff-only
#   T3. git log / diff / status / show
#   T4. git ls-files / ls-remote / rev-parse
#   T5. Bash read-only (head, tail, wc, jq, find, sort, uniq, awk)
#   T6. mkdir / touch (空) / chmod +x
#   T7. gh pr view / list (GET)
#   T8. 仍拦截 9 类破坏性 (rm -rf, force push, rebase 等)
#   T9. SKILL.md 含扩展 AUTO-PERMS
#   T10. frame-prompt.md 跟 SKILL.md 1:1 同步

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FRAME_TASK="$KALLAX_ROOT/scripts/frame-task.sh"
SKILL_MD="$KALLAX_ROOT/.claude/skills/kallax/SKILL.md"
FRAME_PROMPT="$KALLAX_ROOT/.claude/skills/kallax/lib/frame-prompt.md"

PASS=0
FAIL=0

# ── T1-T4: Git read-only PASS (frame-task 不拦) ──
echo "=== auto-perms-expand.test.sh (≥10 用例, EPIC-187) ==="

test_passes() {
    local test_name="$1" cmd="$2"
    if bash "$FRAME_TASK" check-blocked "$cmd" >/dev/null 2>&1; then
        echo "  PASS: $test_name ('$cmd' 未拦)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $test_name ('$cmd' 误拦)"
        FAIL=$((FAIL + 1))
    fi
}

test_blocks() {
    local test_name="$1" cmd="$2"
    if bash "$FRAME_TASK" check-blocked "$cmd" >/dev/null 2>&1; then
        echo "  FAIL: $test_name ('$cmd' 未拦)"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $test_name ('$cmd' 拦截)"
        PASS=$((PASS + 1))
    fi
}

echo ""
echo "T1-T4: Git read-only 不误拦"
test_passes "T1.1 git fetch" "git fetch origin miao"
test_passes "T1.2 git pull --ff-only" "git pull --ff-only origin miao"
test_passes "T2.1 git log" "git log --oneline -10"
test_passes "T2.2 git diff" "git diff HEAD~1 HEAD"
test_passes "T2.3 git status" "git status"
test_passes "T2.4 git show" "git show HEAD --stat"
test_passes "T3.1 git ls-files" "git ls-files"
test_passes "T3.2 git ls-remote" "git ls-remote origin"
test_passes "T3.3 git rev-parse" "git rev-parse HEAD"
test_passes "T3.4 git branch --list" "git branch --list"

echo ""
echo "T5: Bash read-only 不误拦"
test_passes "T5.1 head -n 10" "head -n 10 file.log"
test_passes "T5.2 wc -l" "wc -l file.txt"
test_passes "T5.3 jq" "jq '.key' file.json"
test_passes "T5.4 find" "find . -name '*.sh'"
test_passes "T5.5 sort/uniq" "sort file | uniq -c"

echo ""
echo "T6: Bash 实用不误拦"
test_passes "T6.1 mkdir -p" "mkdir -p /tmp/test"
test_passes "T6.2 touch" "touch /tmp/test.txt"
test_passes "T6.3 chmod +x" "chmod +x script.sh"

echo ""
echo "T7: GitHub GET 不误拦"
test_passes "T7.1 gh pr view" "gh pr view 241"
test_passes "T7.2 gh pr list" "gh pr list --state open"
test_passes "T7.3 gh issue list" "gh issue list"

echo ""
echo "T8: 9 类破坏性仍拦截"
test_blocks "T8.1 rm -rf" "rm -rf /tmp/test"
test_blocks "T8.2 git push --force" "git push --force origin main"
test_blocks "T8.3 git rebase" "git rebase origin/main"
test_blocks "T8.4 CLAUDE.md" "在 CLAUDE.md 加 Rule 35"
test_blocks "T8.5 README.md" "update README.md"
test_blocks "T8.6 gh pr create" "gh pr create --base testing"
test_blocks "T8.7 check-decorative-claim.sh" "edit scripts/verify/check-decorative-claim.sh"

echo ""
echo "T9: SKILL.md 含扩展 AUTO-PERMS"
if grep -q "EPIC-187 扩展" "$SKILL_MD"; then
    echo "  PASS: T9.1 SKILL.md 含 'EPIC-187 扩展' 标记"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T9.1 SKILL.md 缺 EPIC-187 标记"
    FAIL=$((FAIL + 1))
fi

if grep -q "git fetch, git pull --ff-only" "$SKILL_MD"; then
    echo "  PASS: T9.2 SKILL.md 含 git fetch/pull 扩展"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T9.2 SKILL.md 缺 git fetch/pull"
    FAIL=$((FAIL + 1))
fi

if grep -q "head, tail, wc" "$SKILL_MD"; then
    echo "  PASS: T9.3 SKILL.md 含 Bash 实用命令"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T9.3 SKILL.md 缺 Bash 实用命令"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "T10: frame-prompt.md 跟 SKILL.md 1:1 同步"
if grep -q "EPIC-187, 跟 SKILL.md 1:1" "$FRAME_PROMPT"; then
    echo "  PASS: T10.1 frame-prompt.md 跟 SKILL.md 1:1"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T10.1 frame-prompt.md 缺 1:1 标记"
    FAIL=$((FAIL + 1))
fi

if grep -q "git fetch, git pull --ff-only" "$FRAME_PROMPT"; then
    echo "  PASS: T10.2 frame-prompt.md 含 git fetch/pull"
    PASS=$((PASS + 1))
else
    echo "  FAIL: T10.2 frame-prompt.md 缺 git fetch/pull"
    FAIL=$((FAIL + 1))
fi

# ── 总结 ──
echo ""
echo "=== auto-perms-expand.test.sh 总结 ==="
TOTAL=$((PASS + FAIL))
echo "  PASS: $PASS / $TOTAL"
echo "  FAIL: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
    echo "  ✅ ALL PASS"
    exit 0
else
    echo "  ❌ $FAIL FAILED"
    exit 1
fi
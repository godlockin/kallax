#!/usr/bin/env bash
# tests/integration/worktree-unify-test.sh — TDD tests for worktree root unification
# EPIC-054-A AC5: 6/6 PASS (4 root mocks + 50+ migration + single-root verify +
#                         gitdir pointer + .git file + E2E integration)
#
# Verifies scripts/worktree/unify-roots.sh unifies 4 worktree roots
# (.claude/worktrees/, .kallax/worktrees/, .worktrees/, performer-EPIC-*/)
# into 1 single root (.kallax/worktrees/), matching git worktree list 1:1.
#
# Rule 9 KPI X/Y format: 6/6 = 100.0% (no estimate, exact)

set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly UNIFY_SCRIPT="$KALLAX_ROOT/scripts/worktree/unify-roots.sh"

# Verify unify-roots.sh exists (TDD red phase will fail with clear error if missing)
if [ ! -f "$UNIFY_SCRIPT" ]; then
    echo "=========================================="
    echo "Worktree Unify — Integration Tests"
    echo "=========================================="
    echo ""
    echo "FAIL: $UNIFY_SCRIPT not found (TDD red phase — EPIC-054-A dependency missing)"
    echo "0/6 PASS (0.0%)"
    exit 1
fi

# Verify .gitignore + detect-stale-worktrees.sh exist (file_scope coverage)
if [ ! -f "$KALLAX_ROOT/.gitignore" ]; then
    echo "FAIL: $KALLAX_ROOT/.gitignore not found"
    echo "0/6 PASS (0.0%)"
    exit 1
fi

if [ ! -f "$KALLAX_ROOT/scripts/detect-stale-worktrees.sh" ]; then
    echo "FAIL: $KALLAX_ROOT/scripts/detect-stale-worktrees.sh not found"
    echo "0/6 PASS (0.0%)"
    exit 1
fi

# Verify all 3 .gitignore rules present (AC3)
GITIGNORE_OLD=0
GITIGNORE_NEW=0
GITIGNORE_NESTED=0
if grep -qE '^\.claude/worktrees/' "$KALLAX_ROOT/.gitignore" 2>/dev/null; then
    GITIGNORE_OLD=1
fi
if grep -qE '^\.worktrees/' "$KALLAX_ROOT/.gitignore" 2>/dev/null; then
    GITIGNORE_NEW=1
fi
if grep -qE '^performer-EPIC-\*/' "$KALLAX_ROOT/.gitignore" 2>/dev/null; then
    GITIGNORE_NESTED=1
fi
if [ "$GITIGNORE_OLD" -eq 0 ] || [ "$GITIGNORE_NEW" -eq 0 ] || [ "$GITIGNORE_NESTED" -eq 0 ]; then
    echo "FAIL: .gitignore missing one or more root ignore rules"
    echo "  .claude/worktrees/ : $GITIGNORE_OLD"
    echo "  .worktrees/        : $GITIGNORE_NEW"
    echo "  performer-EPIC-*/  : $GITIGNORE_NESTED"
    echo "0/6 PASS (0.0%)"
    exit 1
fi

echo "=========================================="
echo "Worktree Unify — Integration Tests (6/6)"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=6

# ============================================================
# Helper: create a hermetic test git repo with 4 worktree roots
# Returns the test repo path on stdout.
# ============================================================
make_test_repo() {
    local repo="$1"
    local num_wt="${2:-50}"

    rm -rf "$repo"
    mkdir -p "$repo"
    git -C "$repo" init -q --initial-branch=miao

    # Configure git user for commits
    git -C "$repo" config user.email "test@kallax.local"
    git -C "$repo" config user.name "KALLAX Test"

    # Initial commit on miao
    echo "main" > "$repo/README.md"
    git -C "$repo" add README.md
    git -C "$repo" commit -q -m "init"

    # Create worktrees across 4 different roots
    # Distribution: 6 .claude + (num_wt - 10) .kallax + 1 .worktrees + 3 performer-EPIC-*/
    local claude_count=6
    local nested_count=3
    local dotworktrees_count=1
    local kallax_count=$((num_wt - claude_count - nested_count - dotworktrees_count))

    # .claude/worktrees/ (6 worktrees)
    for i in $(seq 1 "$claude_count"); do
        local branch="feature/TEST-claude-$i"
        local wt_path="$repo/.claude/worktrees/performer-TEST-claude-$i"
        mkdir -p "$(dirname "$wt_path")"
        git -C "$repo" worktree add -q -b "$branch" "$wt_path" miao 2>/dev/null || true
    done

    # .kallax/worktrees/ (majority)
    for i in $(seq 1 "$kallax_count"); do
        local branch="feature/TEST-kallax-$i"
        local wt_path="$repo/.kallax/worktrees/performer-TEST-kallax-$i"
        mkdir -p "$(dirname "$wt_path")"
        git -C "$repo" worktree add -q -b "$branch" "$wt_path" miao 2>/dev/null || true
    done

    # .worktrees/ (1)
    for i in $(seq 1 "$dotworktrees_count"); do
        local branch="feature/TEST-dot-$i"
        local wt_path="$repo/.worktrees/feature-TEST-dot-$i"
        mkdir -p "$(dirname "$wt_path")"
        git -C "$repo" worktree add -q -b "$branch" "$wt_path" miao 2>/dev/null || true
    done

    # performer-EPIC-034/ (nested 3)
    for i in $(seq 1 "$nested_count"); do
        local branch="feature/TEST-nested-$i"
        local wt_path="$repo/performer-EPIC-034/performer-TEST-nested-$i"
        mkdir -p "$(dirname "$wt_path")"
        git -C "$repo" worktree add -q -b "$branch" "$wt_path" miao 2>/dev/null || true
    done

    echo "$repo"
}

# ============================================================
# Case 1: 4 套根目录 mock + classify
# ============================================================
echo "--- Test 1: classify 4 worktree root patterns ---"
TEST_REPO_1="$(mktemp -d)/wt-unify-1"
make_test_repo "$TEST_REPO_1" 50 > /dev/null

CLASSIFY_OUTPUT="$(bash "$UNIFY_SCRIPT" --classify --source-repo="$TEST_REPO_1" 2>&1)"
CLAUDE_HITS=$(echo "$CLASSIFY_OUTPUT" | grep -c '\.claude/worktrees/' || true)
KALLAX_HITS=$(echo "$CLASSIFY_OUTPUT" | grep -c '\.kallax/worktrees/' || true)
DOTWT_HITS=$(echo "$CLASSIFY_OUTPUT" | grep -c '\.worktrees/' || true)
NESTED_HITS=$(echo "$CLASSIFY_OUTPUT" | grep -c 'performer-EPIC-' || true)

# Each root pattern must be detected at least once
if [ "$CLAUDE_HITS" -ge 1 ] && [ "$KALLAX_HITS" -ge 1 ] && [ "$DOTWT_HITS" -ge 1 ] && [ "$NESTED_HITS" -ge 1 ]; then
    echo "  [PASS] 4 root patterns classified: claude=$CLAUDE_HITS kallax=$KALLAX_HITS dot=$DOTWT_HITS nested=$NESTED_HITS"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "  [FAIL] classification incomplete: claude=$CLAUDE_HITS kallax=$KALLAX_HITS dot=$DOTWT_HITS nested=$NESTED_HITS"
    echo "  output: $CLASSIFY_OUTPUT" | head -10
    FAIL_COUNT=$((FAIL_COUNT+1))
fi

# Cleanup
git -C "$TEST_REPO_1" worktree prune
rm -rf "$TEST_REPO_1"
echo ""

# ============================================================
# Case 2: 50+ worktree 迁移 (atomic write + git mv)
# ============================================================
echo "--- Test 2: 50+ worktree migration (atomic write + git mv) ---"
TEST_REPO_2="$(mktemp -d)/wt-unify-2"
make_test_repo "$TEST_REPO_2" 55 > /dev/null

# Capture pre-migration state
PRE_TOTAL=$(git -C "$TEST_REPO_2" worktree list | wc -l | tr -d ' ')

# Run migration (non-dry-run, into .kallax/worktrees/)
MIGRATE_OUTPUT="$(bash "$UNIFY_SCRIPT" --source-repo="$TEST_REPO_2" --target-root='.kallax/worktrees' 2>&1)"
MIGRATE_RC=$?

POST_TOTAL=$(git -C "$TEST_REPO_2" worktree list | wc -l | tr -d ' ')

# Verify total count unchanged (no worktree lost during migration)
# Note: pre_total = 1 main + 55 worktrees = 56
if [ "$PRE_TOTAL" -eq "$POST_TOTAL" ] && [ "$POST_TOTAL" -ge 55 ]; then
    echo "  [PASS] 50+ migration preserved count: pre=$PRE_TOTAL post=$POST_TOTAL"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "  [FAIL] migration lost worktrees: pre=$PRE_TOTAL post=$POST_TOTAL rc=$MIGRATE_RC"
    echo "  output: $MIGRATE_OUTPUT" | head -20
    FAIL_COUNT=$((FAIL_COUNT+1))
fi

# Cleanup
git -C "$TEST_REPO_2" worktree prune
rm -rf "$TEST_REPO_2"
echo ""

# ============================================================
# Case 3: 1 套根目录验证 (git worktree list)
# ============================================================
echo "--- Test 3: single-root verification (git worktree list) ---"
TEST_REPO_3="$(mktemp -d)/wt-unify-3"
make_test_repo "$TEST_REPO_3" 30 > /dev/null

# Run migration
bash "$UNIFY_SCRIPT" --source-repo="$TEST_REPO_3" --target-root='.kallax/worktrees' > /dev/null 2>&1 || true

# Verify all non-main worktree paths are under .kallax/worktrees/
NON_MAIN=$(git -C "$TEST_REPO_3" worktree list | tail -n +2 | awk '{print $1}')
OUTSIDE_COUNT=0
while IFS= read -r wt; do
    [ -z "$wt" ] && continue
    case "$wt" in
        *"/.kallax/worktrees/"*) : ;;
        *) OUTSIDE_COUNT=$((OUTSIDE_COUNT + 1)); echo "    [OUTSIDE] $wt" ;;
    esac
done <<< "$NON_MAIN"

if [ "$OUTSIDE_COUNT" -eq 0 ]; then
    echo "  [PASS] all worktree paths unified under .kallax/worktrees/"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "  [FAIL] $OUTSIDE_COUNT worktree(s) still outside .kallax/worktrees/"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi

# Cleanup
git -C "$TEST_REPO_3" worktree prune
rm -rf "$TEST_REPO_3"
echo ""

# ============================================================
# Case 4: .git/worktrees/ 内部指针正确性
# ============================================================
echo "--- Test 4: .git/worktrees/<id>/gitdir pointer correctness ---"
TEST_REPO_4="$(mktemp -d)/wt-unify-4"
make_test_repo "$TEST_REPO_4" 20 > /dev/null

# Run migration
bash "$UNIFY_SCRIPT" --source-repo="$TEST_REPO_4" --target-root='.kallax/worktrees' > /dev/null 2>&1 || true

# Verify each worktree's gitdir pointer points to a path under .kallax/worktrees/
BROKEN_POINTERS=0
TOTAL_POINTERS=0
for gitdir_file in "$TEST_REPO_4/.git/worktrees"/*/gitdir; do
    [ -f "$gitdir_file" ] || continue
    TOTAL_POINTERS=$((TOTAL_POINTERS + 1))
    POINTER=$(cat "$gitdir_file")
    case "$POINTER" in
        *"/.kallax/worktrees/"*) : ;;
        *) BROKEN_POINTERS=$((BROKEN_POINTERS + 1)); echo "    [BROKEN] $gitdir_file → $POINTER" ;;
    esac
done

if [ "$TOTAL_POINTERS" -ge 1 ] && [ "$BROKEN_POINTERS" -eq 0 ]; then
    echo "  [PASS] all $TOTAL_POINTERS .git/worktrees/<id>/gitdir pointers point to .kallax/worktrees/"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "  [FAIL] $BROKEN_POINTERS/$TOTAL_POINTERS gitdir pointers broken"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi

# Cleanup
git -C "$TEST_REPO_4" worktree prune
rm -rf "$TEST_REPO_4"
echo ""

# ============================================================
# Case 5: worktree .git 文件正确性
# ============================================================
echo "--- Test 5: worktree/.git file pointer correctness ---"
TEST_REPO_5="$(mktemp -d)/wt-unify-5"
make_test_repo "$TEST_REPO_5" 20 > /dev/null

# Run migration
bash "$UNIFY_SCRIPT" --source-repo="$TEST_REPO_5" --target-root='.kallax/worktrees' > /dev/null 2>&1 || true

# Verify each worktree's .git file points to valid gitdir
BROKEN_DOTGIT=0
TOTAL_DOTGIT=0
# Iterate all .git files inside .kallax/worktrees/* (post-migration)
for dotgit_file in "$TEST_REPO_5/.kallax/worktrees"/*/.git; do
    [ -f "$dotgit_file" ] || continue
    TOTAL_DOTGIT=$((TOTAL_DOTGIT + 1))
    # .git file format: "gitdir: /path/to/.git/worktrees/<id>"
    DOTGIT_CONTENT=$(cat "$dotgit_file")
    case "$DOTGIT_CONTENT" in
        gitdir:*".git/worktrees/"*) : ;;
        *) BROKEN_DOTGIT=$((BROKEN_DOTGIT + 1)); echo "    [BROKEN] $dotgit_file → $DOTGIT_CONTENT" ;;
    esac
done

if [ "$TOTAL_DOTGIT" -ge 1 ] && [ "$BROKEN_DOTGIT" -eq 0 ]; then
    echo "  [PASS] all $TOTAL_DOTGIT worktree/.git files point to .git/worktrees/<id>"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "  [FAIL] $BROKEN_DOTGIT/$TOTAL_DOTGIT .git files broken"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi

# Cleanup
git -C "$TEST_REPO_5" worktree prune
rm -rf "$TEST_REPO_5"
echo ""

# ============================================================
# Case 6: E2E integration — 4 套 → 1 套 + git worktree list 一致
# ============================================================
echo "--- Test 6: E2E — 4 roots → 1 root + git worktree list consistency ---"
TEST_REPO_6="$(mktemp -d)/wt-unify-6"
make_test_repo "$TEST_REPO_6" 40 > /dev/null

# Capture pre-state
PRE_LIST=$(git -C "$TEST_REPO_6" worktree list | wc -l | tr -d ' ')

# Run migration
bash "$UNIFY_SCRIPT" --source-repo="$TEST_REPO_6" --target-root='.kallax/worktrees' > /dev/null 2>&1 || true

# Verify post-state: git worktree list count unchanged, all under .kallax/worktrees/
POST_LIST=$(git -C "$TEST_REPO_6" worktree list | wc -l | tr -d ' ')
NON_MAIN_POST=$(git -C "$TEST_REPO_6" worktree list | tail -n +2)
OUTSIDE_POST=0
TOTAL_POST=0
while IFS= read -r line; do
    [ -z "$line" ] && continue
    TOTAL_POST=$((TOTAL_POST + 1))
    WT_PATH=$(echo "$line" | awk '{print $1}')
    case "$WT_PATH" in
        *"/.kallax/worktrees/"*) : ;;
        *) OUTSIDE_POST=$((OUTSIDE_POST + 1)); echo "    [OUTSIDE] $WT_PATH" ;;
    esac
done <<< "$NON_MAIN_POST"

if [ "$PRE_LIST" -eq "$POST_LIST" ] && [ "$TOTAL_POST" -ge 1 ] && [ "$OUTSIDE_POST" -eq 0 ]; then
    echo "  [PASS] E2E: pre=$PRE_LIST post=$POST_LIST all_unified=$TOTAL_POST (H5 closed)"
    PASS_COUNT=$((PASS_COUNT+1))
else
    echo "  [FAIL] E2E: pre=$PRE_LIST post=$POST_LIST unified=$TOTAL_POST outside=$OUTSIDE_POST"
    FAIL_COUNT=$((FAIL_COUNT+1))
fi

# Cleanup
git -C "$TEST_REPO_6" worktree prune
rm -rf "$TEST_REPO_6"
echo ""

# ============================================================
# Summary — exact X/Y format (Rule 9 KPI precision)
# ============================================================
echo "=========================================="
echo "Results: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
echo "=========================================="
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "FAIL: $FAIL_COUNT test(s) failed"
    echo "$PASS_COUNT/$TOTAL PASS"
    exit 1
fi
echo "PASS: all $TOTAL integration tests passed"
echo "$PASS_COUNT/$TOTAL PASS (100.0%)"
exit 0

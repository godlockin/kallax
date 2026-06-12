#!/bin/bash
# cross-worktree-dispatch-test.sh — Integration tests for cross-worktree-dispatch.sh
#
# Tests 6+ cases:
#   1. --help → usage + exit 0
#   2. list mode → lists source branches
#   3. dry-run → reports what would be done, no commits moved
#   4. no conflict → cherry-pick succeeds, exit 0
#   5. conflict → STOP + non-zero exit, no auto merge
#   6. invalid args → non-zero exit
#   7. source == target → error (no-op)
#
# Source: EPIC-036-A ticket.json AC

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DISPATCH="${KALLAX_ROOT}/scripts/conductor/cross-worktree-dispatch.sh"

echo "=== Cross-Worktree Dispatch Integration Tests ==="
PASS=0
FAIL=0

# Temp scratch area for fake source/target git repos
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Helper: create a bare upstream + 2 clones (source + target)
setup_repos() {
  local upstream="$SCRATCH/upstream.git"
  local source="$SCRATCH/source"
  local target="$SCRATCH/target"
  git init --bare "$upstream" >/dev/null 2>&1

  git clone "$upstream" "$source" >/dev/null 2>&1
  git -C "$source" config user.email "t@t.io"
  git -C "$source" config user.name "t"
  echo "base" > "$source/shared.txt"
  git -C "$source" add shared.txt
  git -C "$source" commit -m "base" >/dev/null 2>&1
  git -C "$source" push origin master:main >/dev/null 2>&1

  git clone "$upstream" "$target" >/dev/null 2>&1
  git -C "$target" config user.email "t@t.io"
  git -C "$target" config user.name "t"
  # Make sure target has a master tracking branch
  git -C "$target" branch --track master origin/main >/dev/null 2>&1 || true

  echo "$source $target $upstream"
}

pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

# ----------------------------------------------------------------
# Test 1: --help / no args → usage exit 0
# ----------------------------------------------------------------
echo ""
echo "[Test 1] Usage / --help"
if bash "$DISPATCH" --help >/dev/null 2>&1; then
  pass "--help returns exit 0"
else
  fail "--help should exit 0"
fi

OUT=$(bash "$DISPATCH" --help 2>&1 || true)
if echo "$OUT" | grep -q "Usage:"; then
  pass "--help shows Usage: line"
else
  fail "--help should show Usage: line (got: $OUT)"
fi

# ----------------------------------------------------------------
# Test 2: list mode → enumerates branches in upstream
# ----------------------------------------------------------------
echo ""
echo "[Test 2] list mode"
read src tgt up < <(setup_repos)
LIST=$(bash "$DISPATCH" --source "$src" --mode list 2>&1 || true)
if echo "$LIST" | grep -qE "branches|master"; then
  pass "list mode shows branch info"
else
  fail "list mode should show branches (got: $LIST)"
fi

# ----------------------------------------------------------------
# Test 3: dry-run → reports would-be cherry-picks, target HEAD unchanged
# ----------------------------------------------------------------
echo ""
echo "[Test 3] dry-run (no real cherry-pick)"
echo "src-only.txt" > "$src/feature.txt"
git -C "$src" add feature.txt
git -C "$src" commit -m "src feature" >/dev/null 2>&1
git -C "$src" push origin master:main >/dev/null 2>&1

BEFORE_SHA=$(git -C "$tgt" rev-parse HEAD)
DRY_OUT=$(bash "$DISPATCH" --source "$src" --target "$tgt" --mode dry-run 2>&1 || true)
AFTER_SHA=$(git -C "$tgt" rev-parse HEAD)
if [[ "$BEFORE_SHA" == "$AFTER_SHA" ]] && echo "$DRY_OUT" | grep -qE "DRY|dry|would|cherry"; then
  pass "dry-run leaves target untouched and reports plan"
else
  fail "dry-run should not change target HEAD (got: $DRY_OUT)"
fi

# ----------------------------------------------------------------
# Test 4: no conflict → cherry-pick succeeds, exit 0
# ----------------------------------------------------------------
echo ""
echo "[Test 4] no-conflict cherry-pick (exit 0)"
BEFORE_SHA=$(git -C "$tgt" rev-parse HEAD)
if bash "$DISPATCH" --source "$src" --target "$tgt" --mode cherry-pick >/dev/null 2>&1; then
  AFTER_SHA=$(git -C "$tgt" rev-parse HEAD)
  if [[ "$BEFORE_SHA" != "$AFTER_SHA" ]] && [[ -f "$tgt/feature.txt" ]]; then
    pass "cherry-pick succeeded, target advanced, feature.txt present"
  else
    fail "cherry-pick reported success but target HEAD unchanged or file missing"
  fi
else
  fail "cherry-pick with no conflict should exit 0"
fi

# ----------------------------------------------------------------
# Test 5: conflict → STOP + non-zero exit + no auto merge
# ----------------------------------------------------------------
echo ""
echo "[Test 5] conflict scenario (STOP + non-zero)"
read src2 tgt2 up2 < <(setup_repos)
# Both branches diverge on shared.txt
echo "src change" > "$src2/shared.txt"
git -C "$src2" add shared.txt
git -C "$src2" commit -m "src diverges" >/dev/null 2>&1
git -C "$src2" push origin master:main >/dev/null 2>&1

echo "tgt change" > "$tgt2/shared.txt"
git -C "$tgt2" add shared.txt
git -C "$tgt2" commit -m "tgt diverges" >/dev/null 2>&1

BEFORE_SHA=$(git -C "$tgt2" rev-parse HEAD)
# Bring target up to date so cherry-pick can attempt
git -C "$tgt2" merge --no-commit --no-ff origin/main >/dev/null 2>&1 || true
# Abort so we're back at HEAD
git -C "$tgt2" merge --abort 2>/dev/null || true
# Fetch
git -C "$tgt2" fetch origin >/dev/null 2>&1

set +e
CONFLICT_OUT=$(bash "$DISPATCH" --source "$src2" --target "$tgt2" --mode cherry-pick 2>&1)
CONFLICT_RC=$?
set -e
AFTER_SHA=$(git -C "$tgt2" rev-parse HEAD)
if [[ "$CONFLICT_RC" -ne 0 ]] && [[ "$BEFORE_SHA" == "$AFTER_SHA" ]]; then
  pass "conflict: non-zero exit + target HEAD unchanged (no auto-merge)"
else
  fail "conflict: should STOP+non-zero (rc=$CONFLICT_RC, before=$BEFORE_SHA, after=$AFTER_SHA)"
fi
if echo "$CONFLICT_OUT" | grep -qiE "conflict|stop|abort|merge"; then
  pass "conflict: output mentions conflict/stop"
else
  fail "conflict: output should mention conflict (got: $CONFLICT_OUT)"
fi

# ----------------------------------------------------------------
# Test 6: invalid args → non-zero exit
# ----------------------------------------------------------------
echo ""
echo "[Test 6] invalid arguments"
if bash "$DISPATCH" --source "/nonexistent/path/xyz" --mode cherry-pick >/dev/null 2>&1; then
  fail "invalid source path should fail"
else
  pass "invalid source path → non-zero exit"
fi

# ----------------------------------------------------------------
# Test 7: source == target → error
# ----------------------------------------------------------------
echo ""
echo "[Test 7] source == target"
if bash "$DISPATCH" --source "$src" --target "$src" --mode cherry-pick >/dev/null 2>&1; then
  fail "source == target should be rejected"
else
  pass "source == target rejected"
fi

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0

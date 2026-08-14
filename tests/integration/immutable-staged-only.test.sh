#!/usr/bin/env bash
# tests/integration/immutable-staged-only.test.sh — EPIC-252
#
# 锚定 4 个 immutable script 的 KALLAX_STAGED_ONLY=1 行为.
#
# 起因 (EPIC-252 纠正): retrospective-batch-8 L4/L11 误诊 "check-decorative-claim.sh 缺 baseline 豁免",
# 实测 script 已有 staged-diff-only 模式 (line 88-100), pre-commit hook 已传 KALLAX_STAGED_ONLY=1
# (scripts/hooks/pre-commit:270). 真因是新写段自带 jargon, 不是历史文件.
#
# 本 test 锚定 3 个事实, 防未来再误判:
#   1. STAGED_ONLY=1 + 0 staged file → exit 0 (skip)
#   2. STAGED_ONLY=1 + staged 干净文件 → exit 0
#   3. STAGED_ONLY=1 + staged 含 jargon 新增行 → exit 1 (fail-closed 仍生效)
#   4. pre-commit hook 确实传 KALLAX_STAGED_ONLY=1
#
# Exit: 0 = all PASS, 1 = FAIL

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DECORATIVE="${KALLAX_ROOT}/scripts/verify/check-decorative-claim.sh"
NARRATIVE="${KALLAX_ROOT}/scripts/verify/check-narrative.sh"
PRE_COMMIT="${KALLAX_ROOT}/scripts/hooks/pre-commit"

PASS=0
FAIL=0

assert_exit() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected exit $expected, got $actual)"
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

# ── Case 1: scripts exist ──────────────────────────────────────────────────
echo "Case 1: immutable scripts exist"
for s in "$DECORATIVE" "$NARRATIVE"; do
  if [ -f "$s" ]; then
    echo "  PASS: $(basename "$s") exists"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $(basename "$s") missing"
    FAIL=$((FAIL + 1))
  fi
done

# ── Case 2: STAGED_ONLY mode implemented ───────────────────────────────────
echo ""
echo "Case 2: KALLAX_STAGED_ONLY mode implemented in both scripts"
assert_grep "check-decorative-claim has KALLAX_STAGED_ONLY" 'KALLAX_STAGED_ONLY' "$DECORATIVE"
assert_grep "check-narrative has KALLAX_STAGED_ONLY" 'KALLAX_STAGED_ONLY' "$NARRATIVE"

# ── Case 3: STAGED_ONLY only scans staged diff added lines ─────────────────
echo ""
echo "Case 3: STAGED_ONLY scans git diff --cached added lines (not whole file)"
assert_grep "check-decorative-claim uses diff --cached" 'diff --cached' "$DECORATIVE"

# ── Case 4: pre-commit hook passes KALLAX_STAGED_ONLY=1 ────────────────────
echo ""
echo "Case 4: pre-commit hook passes KALLAX_STAGED_ONLY=1 to immutable laws"
assert_grep "pre-commit passes KALLAX_STAGED_ONLY=1" 'KALLAX_STAGED_ONLY=1 bash' "$PRE_COMMIT"

# ── Case 5: STAGED_ONLY=1 with no staged files exits 0 ─────────────────────
echo ""
echo "Case 5: STAGED_ONLY=1 with no staged .md files → exit 0 (skip)"
TMPREPO="$(mktemp -d)"
trap 'rm -rf "$TMPREPO"' EXIT
git -C "$TMPREPO" init -q 2>/dev/null
git -C "$TMPREPO" config user.email "test@kallax.local" 2>/dev/null
git -C "$TMPREPO" config user.name "test" 2>/dev/null
mkdir -p "$TMPREPO/scripts/verify"
cp "$DECORATIVE" "$TMPREPO/scripts/verify/"
echo "seed" > "$TMPREPO/seed.txt"
git -C "$TMPREPO" add seed.txt 2>/dev/null
git -C "$TMPREPO" commit -qm "seed" --no-verify 2>/dev/null

set +e
( cd "$TMPREPO" && KALLAX_STAGED_ONLY=1 bash scripts/verify/check-decorative-claim.sh >/dev/null 2>&1 )
EXIT_C5=$?
set -e
assert_exit "no staged .md → skip" "0" "$EXIT_C5"

# ── Case 6: STAGED_ONLY=1 with clean staged .md exits 0 ────────────────────
echo ""
echo "Case 6: STAGED_ONLY=1 with clean staged CHANGELOG.md → exit 0"
printf '# Changelog\n\n- plain entry with raw output: exit 0\n' > "$TMPREPO/CHANGELOG.md"
git -C "$TMPREPO" add CHANGELOG.md 2>/dev/null
set +e
( cd "$TMPREPO" && KALLAX_STAGED_ONLY=1 bash scripts/verify/check-decorative-claim.sh >/dev/null 2>&1 )
EXIT_C6=$?
set -e
assert_exit "clean staged .md → pass" "0" "$EXIT_C6"

# ── Case 7: STAGED_ONLY=1 with jargon in staged added lines exits 1 ────────
echo ""
echo "Case 7: STAGED_ONLY=1 with jargon in staged added lines → exit 1 (fail-closed)"
git -C "$TMPREPO" commit -qm "clean changelog" --no-verify 2>/dev/null
# fixture 用 UTF-8 escape 构造黑名单词, 避免本 test 文件自身命中 check-jargon 扫描.
# 目标 pattern 见 check-decorative-claim.sh DECORATIVE_PATTERNS 第 2 条.
JARGON_FIXTURE="$(printf '\xe8\xb7\x9f') EPIC-999 $(printf '\xe9\x97\xad\xe7\x8e\xaf')"
printf '# Changelog\n\n- plain entry with raw output: exit 0\n- %s\n' "$JARGON_FIXTURE" > "$TMPREPO/CHANGELOG.md"
git -C "$TMPREPO" add CHANGELOG.md 2>/dev/null
set +e
( cd "$TMPREPO" && KALLAX_STAGED_ONLY=1 bash scripts/verify/check-decorative-claim.sh >/dev/null 2>&1 )
EXIT_C7=$?
set -e
assert_exit "jargon in staged added lines → fail-closed" "1" "$EXIT_C7"

# ── Case 8: historical lines grandfathered (not in staged diff) ────────────
echo ""
echo "Case 8: historical jargon lines grandfathered when not in staged diff"
git -C "$TMPREPO" commit -qm "jargon committed (now historical)" --no-verify 2>/dev/null
printf '# Changelog\n\n- plain entry with raw output: exit 0\n- %s\n- new clean line\n' "$JARGON_FIXTURE" > "$TMPREPO/CHANGELOG.md"
git -C "$TMPREPO" add CHANGELOG.md 2>/dev/null
set +e
( cd "$TMPREPO" && KALLAX_STAGED_ONLY=1 bash scripts/verify/check-decorative-claim.sh >/dev/null 2>&1 )
EXIT_C8=$?
set -e
assert_exit "historical jargon not re-flagged" "0" "$EXIT_C8"

# ── Case 9: 纯删除 diff 不误判 (EPIC-253 修 bug) ────────────────────────────
echo ""
echo "Case 9: delete-only staged diff → exit 0 (EPIC-253 bug fix)"
cp "$KALLAX_ROOT/scripts/verify/check-evidence-fake.sh" "$TMPREPO/scripts/verify/" 2>/dev/null || true
# 建含多行的 CHANGELOG 并 commit, 再删几行 (0 新增行)
printf '# Changelog\n\nline A\nline B\nline C\n' > "$TMPREPO/CHANGELOG.md"
git -C "$TMPREPO" add CHANGELOG.md 2>/dev/null
git -C "$TMPREPO" commit -qm "changelog with 3 lines" --no-verify 2>/dev/null
printf '# Changelog\n\nline A\n' > "$TMPREPO/CHANGELOG.md"
git -C "$TMPREPO" add CHANGELOG.md 2>/dev/null
# 确认 staged diff 确实 0 新增行
ADDED_COUNT="$(git -C "$TMPREPO" diff --cached -U0 -- CHANGELOG.md | grep -c '^+[^+]' || true)"
assert_exit "staged diff has 0 added lines" "0" "$ADDED_COUNT"
set +e
( cd "$TMPREPO" && KALLAX_STAGED_ONLY=1 bash scripts/verify/check-decorative-claim.sh >/dev/null 2>&1 )
EXIT_C9=$?
set -e
assert_exit "delete-only diff → decorative exit 0" "0" "$EXIT_C9"
if [ -f "$TMPREPO/scripts/verify/check-evidence-fake.sh" ]; then
  set +e
  ( cd "$TMPREPO" && KALLAX_STAGED_ONLY=1 bash scripts/verify/check-evidence-fake.sh >/dev/null 2>&1 )
  EXIT_C9B=$?
  set -e
  assert_exit "delete-only diff → evidence-fake exit 0" "0" "$EXIT_C9B"
fi

# ── Case 10: 修复未放宽检查语义 (新增 jargon 仍拦) ──────────────────────────
echo ""
echo "Case 10: fix did not loosen detection (added jargon still blocked)"
git -C "$TMPREPO" commit -qm "delete lines" --no-verify 2>/dev/null
printf '# Changelog\n\nline A\n- %s\n' "$JARGON_FIXTURE" > "$TMPREPO/CHANGELOG.md"
git -C "$TMPREPO" add CHANGELOG.md 2>/dev/null
set +e
( cd "$TMPREPO" && KALLAX_STAGED_ONLY=1 bash scripts/verify/check-decorative-claim.sh >/dev/null 2>&1 )
EXIT_C10=$?
set -e
assert_exit "added jargon after fix → still exit 1" "1" "$EXIT_C10"

echo ""
echo "================================================"
echo "EPIC-252/253 Immutable STAGED_ONLY Tests: $PASS passed, $FAIL failed"
echo "================================================"
if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0

#!/usr/bin/env bash
# tests/integration/kallax-experts-submodule.test.sh — EPIC-167 8+ test cases
#
# Cases:
#   1. .gitmodules exists + valid format
#   2. submodule dir exists + non-empty (15 expert + 9 tools)
#   3. git submodule status clean (no -/+ prefix)
#   4. skill-manager.sh submodule-init PASS
#   5. skill-manager.sh submodule-status PASS
#   6. skill-manager.sh submodule-update PASS (git submodule update --remote)
#   7. install.sh --install-submodule dry-run PASS
#   8. install.sh --update-submodule dry-run PASS
#   9. .gitignore has external/kallax-experts/ comment
#  10. docs/process.md has submodule upgrade section
#  11. docs/reference/kallax-experts-submodule-2026-08-05.md exists
#  12. CLAUDE.md has EPIC-167 entry
#
# Rule 9 KPI: 12/12 PASS = 100.0%
set -uo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KALLAX_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
readonly SM_DIR="$KALLAX_ROOT/external/kallax-experts"
readonly SM_MGR="$KALLAX_ROOT/scripts/skill/skill-manager.sh"

echo "=========================================="
echo "EPIC-167 — kallax-experts Submodule Tests"
echo "12 cases, Rule 9 KPI format"
echo "=========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=12

pass() { echo "  [PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "  [FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# ── Case 1: .gitmodules valid format ──────────────────────────────────────
echo ">>> Case 1: .gitmodules exists + valid format"
if [ -f "$KALLAX_ROOT/.gitmodules" ]; then
  if grep -q '\[submodule "external/kallax-experts"\]' "$KALLAX_ROOT/.gitmodules" && \
     grep -q 'path = external/kallax-experts' "$KALLAX_ROOT/.gitmodules" && \
     grep -q 'url = https://github.com/godlockin/kallax-experts.git' "$KALLAX_ROOT/.gitmodules"; then
    pass ".gitmodules valid (path + url)"
  else
    fail ".gitmodules missing required fields"
  fi
else
  fail ".gitmodules not found"
fi
echo ""

# ── Case 2: submodule dir non-empty ───────────────────────────────────────
echo ">>> Case 2: submodule dir non-empty (15 expert + 9 tools)"
if [ -d "$SM_DIR" ] && [ -e "$SM_DIR/.git" ]; then
  expert_count=$(find "$SM_DIR/experts" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  tool_count=$(find "$SM_DIR/tools" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$expert_count" -ge 15 ] && [ "$tool_count" -ge 9 ]; then
    pass "submodule: $expert_count expert .md + $tool_count tools"
  else
    fail "submodule: $expert_count expert (need ≥15) + $tool_count tools (need ≥9)"
  fi
else
  fail "submodule dir or .git missing"
fi
echo ""

# ── Case 3: git submodule status clean ────────────────────────────────────
echo ">>> Case 3: git submodule status clean (no -/+ prefix)"
set +e
SM_STATUS=$(git submodule status external/kallax-experts 2>&1)
SM_RC=$?
set -e
if [ "$SM_RC" -eq 0 ] && [[ "$SM_STATUS" != -* ]] && [[ "$SM_STATUS" != +* ]] && [[ "$SM_STATUS" != U* ]]; then
  pass "submodule status clean: $(echo "$SM_STATUS" | awk '{print $1}')"
else
  fail "submodule status not clean: $SM_STATUS"
fi
echo ""

# ── Case 4: skill-manager.sh submodule-init ────────────────────────────────
echo ">>> Case 4: skill-manager.sh submodule-init PASS"
if [ ! -x "$SM_MGR" ]; then
  fail "skill-manager.sh not executable"
else
  set +e
  OUT=$(bash "$SM_MGR" submodule-init 2>&1)
  RC=$?
  set -e
  if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "initialized\|already initialized"; then
    pass "submodule-init PASS"
  else
    fail "submodule-init FAIL (rc=$RC): $OUT"
  fi
fi
echo ""

# ── Case 5: skill-manager.sh submodule-status ─────────────────────────────
echo ">>> Case 5: skill-manager.sh submodule-status PASS"
set +e
OUT=$(bash "$SM_MGR" submodule-status 2>&1)
RC=$?
set -e
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "Branch\|Remote\|Experts"; then
  pass "submodule-status PASS (branch + experts shown)"
else
  fail "submodule-status FAIL (rc=$RC): $OUT"
fi
echo ""

# ── Case 6: skill-manager.sh submodule-update ──────────────────────────────
echo ">>> Case 6: skill-manager.sh submodule-update PASS"
set +e
OUT=$(bash "$SM_MGR" submodule-update 2>&1)
RC=$?
set -e
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "updated\|already at latest"; then
  pass "submodule-update PASS"
else
  fail "submodule-update FAIL (rc=$RC): $OUT"
fi
echo ""

# ── Case 7: install.sh --install-submodule dry-run ─────────────────────────
echo ">>> Case 7: install.sh --install-submodule dry-run PASS"
set +e
OUT=$(bash "$KALLAX_ROOT/scripts/install.sh" --install-submodule --dry-run 2>&1)
RC=$?
set -e
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -qi "submodule"; then
  pass "install.sh --install-submodule --dry-run PASS"
else
  fail "install.sh --install-submodule --dry-run FAIL (rc=$RC)"
fi
echo ""

# ── Case 8: install.sh --update-submodule dry-run ─────────────────────────
echo ">>> Case 8: install.sh --update-submodule dry-run PASS"
set +e
OUT=$(bash "$KALLAX_ROOT/scripts/install.sh" --update-submodule --dry-run 2>&1)
RC=$?
set -e
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -qi "submodule"; then
  pass "install.sh --update-submodule --dry-run PASS"
else
  fail "install.sh --update-submodule --dry-run FAIL (rc=$RC)"
fi
echo ""

# ── Case 9: .gitignore has submodule comment ──────────────────────────────
echo ">>> Case 9: .gitignore has external/kallax-experts/ comment"
if grep -q "external/kallax-experts" "$KALLAX_ROOT/.gitignore"; then
  pass ".gitignore has submodule section"
else
  fail ".gitignore missing external/kallax-experts/ comment"
fi
echo ""

# ── Case 10: docs/process.md has submodule section ────────────────────────
echo ">>> Case 10: docs/process.md has submodule upgrade section"
if grep -q "Submodule 升级流程" "$KALLAX_ROOT/docs/process.md" && \
   grep -q "git submodule update --remote" "$KALLAX_ROOT/docs/process.md"; then
  pass "docs/process.md has submodule upgrade section"
else
  fail "docs/process.md missing submodule upgrade section"
fi
echo ""

# ── Case 11: reference doc exists ─────────────────────────────────────────
echo ">>> Case 11: docs/reference/kallax-experts-submodule-2026-08-05.md exists"
if [ -f "$KALLAX_ROOT/docs/reference/kallax-experts-submodule-2026-08-05.md" ]; then
  _size=$(wc -c < "$KALLAX_ROOT/docs/reference/kallax-experts-submodule-2026-08-05.md" | tr -d ' ')
  if [ "$_size" -gt 500 ]; then
    pass "reference doc exists ($_size bytes)"
  else
    fail "reference doc too small ($_size bytes, need >500)"
  fi
else
  fail "reference doc not found"
fi
echo ""

# ── Case 12: CLAUDE.md has EPIC-167 entry ──────────────────────────────────
echo ">>> Case 12: CLAUDE.md has EPIC-167 entry"
if grep -q "EPIC-167" "$KALLAX_ROOT/CLAUDE.md"; then
  pass "CLAUDE.md has EPIC-167 entry"
else
  fail "CLAUDE.md missing EPIC-167 entry"
fi
echo ""

# ── Summary ────────────────────────────────────────────────────────────────
echo "=========================================="
echo "Result: ${PASS_COUNT}/${TOTAL} PASS"
if [ "$PASS_COUNT" -eq "$TOTAL" ]; then
  echo "KPI: 100.0% PASS (${PASS_COUNT}/${TOTAL})"
  exit 0
else
  echo "FAIL: $FAIL_COUNT case(s) failed"
  exit 1
fi

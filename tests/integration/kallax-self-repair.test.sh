#!/usr/bin/env bash
# tests/integration/kallax-self-repair.test.sh — EPIC-164 Self-Repair Skill Tests
#
# AC8: ≥6 case PASS (5 步 repair / dream-up / evidence discipline /
#      vision writeback / scope 标记 / install.sh 集成)
#
# Usage:
#   bash tests/integration/kallax-self-repair.test.sh
#   bash tests/integration/kallax-self-repair.test.sh --verbose
#   bash tests/integration/kallax-self-repair.test.sh --case=5

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_DIR="$KALLAX_ROOT/.claude/skills/kallax-self-repair"

# Counters
TOTAL=0
PASS=0
FAIL=0
VERBOSE=false
CASE_FILTER=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=true; shift ;;
    --case=*) CASE_FILTER="${1#--case=}"; shift ;;
    *) shift ;;
  esac
done

# Helper: test case
run_case() {
  local num="$1"; local name="$2"; local fn="$3"
  TOTAL=$((TOTAL + 1))
  if [[ -n "$CASE_FILTER" && "$CASE_FILTER" != "$num" ]]; then
    return 0
  fi
  if $VERBOSE; then
    echo "[$num] $name"
  fi
  if $fn; then
    PASS=$((PASS + 1))
    echo "  ✓ PASS"
    return 0
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ FAIL"
    return 1
  fi
}

# ─── Case 1: SKILL.md exists and has required frontmatter ────────────────
case_1() {
  local f="$SKILL_DIR/SKILL.md"
  [[ -f "$f" ]] || { echo "SKILL.md not found"; return 1; }
  grep -q "^name: kallax-self-repair" "$f" || { echo "name: missing"; return 1; }
  grep -q "^description:" "$f" || { echo "description: missing"; return 1; }
  grep -q "^triggerKeywords:" "$f" || { echo "triggerKeywords: missing"; return 1; }
  grep -q "^enabled_policy:" "$f" || { echo "enabled_policy: missing"; return 1; }
  grep -q "^skill_scope:" "$f" || { echo "skill_scope: missing"; return 1; }
  return 0
}

# ─── Case 2: 5-step repair loop sections exist ───────────────────────────
case_2() {
  local f="$SKILL_DIR/SKILL.md"
  grep -q "Step 1.*Pause Delivery" "$f" || { echo "Step 1 missing"; return 1; }
  grep -q "Step 2.*Build Evidence Packet" "$f" || { echo "Step 2 missing"; return 1; }
  grep -q "Step 3.*Classify Failure" "$f" || { echo "Step 3 missing"; return 1; }
  grep -q "Step 4.*Assign Responsible Layer" "$f" || { echo "Step 4 missing"; return 1; }
  grep -q "Step 5.*Repair at Lowest Durable Layer" "$f" || { echo "Step 5 missing"; return 1; }
  return 0
}

# ─── Case 3: Dream-Up mechanism exists ───────────────────────────────────
case_3() {
  local f="$SKILL_DIR/SKILL.md"
  grep -q "Dream-Up" "$f" || { echo "Dream-Up section missing"; return 1; }
  grep -q "≥ 3" "$f" || { echo "frequency threshold missing"; return 1; }
  # Dream-Up 禁止事项
  grep -q "降 gate" "$f" || { echo "dream-up 禁止事项 missing"; return 1; }
  grep -q "workaround" "$f" || { echo "workaround 禁止 missing"; return 1; }
  grep -q "commit private logs" "$f" || { echo "private logs 禁止 missing"; return 1; }
  return 0
}

# ─── Case 4: Evidence discipline section exists ───────────────────────────
case_4() {
  local f="$SKILL_DIR/SKILL.md"
  grep -q "Evidence Discipline" "$f" || { echo "Evidence Discipline section missing"; return 1; }
  grep -q "不读 raw private logs" "$f" || { echo "raw logs prohibition missing"; return 1; }
  grep -q "不 solve contradictory by guessing" "$f" || { echo "contradictory prohibition missing"; return 1; }
  grep -q "不 hide primary blocker" "$f" || { echo "primary blocker requirement missing"; return 1; }
  return 0
}

# ─── Case 5: Vision/Replan writeback section exists ──────────────────────
case_5() {
  local f="$SKILL_DIR/SKILL.md"
  grep -q "Vision/Replan Writeback" "$f" || { echo "Writeback section missing"; return 1; }
  grep -q "self_repair" "$f" || { echo "self_repair in state.json missing"; return 1; }
  grep -q "completed_at" "$f" || { echo "completed_at field missing"; return 1; }
  grep -q "dream_up_targets" "$f" || { echo "dream_up_targets missing"; return 1; }
  grep -q "next_action" "$f" || { echo "next_action missing"; return 1; }
  return 0
}

# ─── Case 6: .kallax-skill-scope exists and is 8+ bytes ─────────────────
case_6() {
  local f="$SKILL_DIR/.kallax-skill-scope"
  [[ -f "$f" ]] || { echo ".kallax-skill-scope not found"; return 1; }
  local size
  size=$(wc -c < "$f" | tr -d ' ')
  [[ "$size" -ge 8 ]] || { echo "scope file too small: $size bytes"; return 1; }
  grep -q "self-repair" "$f" || { echo "scope content unexpected"; return 1; }
  return 0
}

# ─── Case 7: agents/ subdir with ≥1 agent ───────────────────────────────
case_7() {
  [[ -d "$SKILL_DIR/agents" ]] || { echo "agents/ not found"; return 1; }
  local count
  count=$(find "$SKILL_DIR/agents" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  [[ "$count" -ge 1 ]] || { echo "no agent .md files found"; return 1; }
  return 0
}

# ─── Case 8: Reference routes section exists ──────────────────────────────
case_8() {
  local f="$SKILL_DIR/SKILL.md"
  grep -q "Reference Routes" "$f" || { echo "Reference Routes missing"; return 1; }
  grep -q "confluence/decisions/" "$f" || { echo "confluence/decisions link missing"; return 1; }
  grep -q "docs/reference/" "$f" || { echo "docs/reference link missing"; return 1; }
  return 0
}

# ─── Case 9: Failure classification matrix exists ─────────────────────────
case_9() {
  local f="$SKILL_DIR/SKILL.md"
  grep -q "agent mistake" "$f" || { echo "agent mistake type missing"; return 1; }
  grep -q "state projection bug" "$f" || { echo "state projection bug missing"; return 1; }
  grep -q "benchmark harness mismatch" "$f" || { echo "benchmark mismatch missing"; return 1; }
  grep -q "docs process hygiene" "$f" || { echo "docs process hygiene missing"; return 1; }
  return 0
}

# ─── Case 10: install.sh has --install-skill flag ────────────────────────
case_10() {
  local f="$KALLAX_ROOT/scripts/install.sh"
  grep -q "install-skill\|INSTALL_SKILL" "$f" || { echo "install-skill flag missing"; return 1; }
  return 0
}

# ─── Main ─────────────────────────────────────────────────────────────────

echo "========================================"
echo "kallax-self-repair.test.sh — EPIC-164"
echo "========================================"
echo ""

run_case 1 "SKILL.md frontmatter (AC1)" case_1
run_case 2 "5-step repair loop (AC2)" case_2
run_case 3 "Dream-Up mechanism (AC3)" case_3
run_case 4 "Evidence discipline (AC5)" case_4
run_case 5 "Vision writeback (AC6)" case_5
run_case 6 ".kallax-skill-scope 8+ bytes (AC4)" case_6
run_case 7 "agents/ subdir ≥1 agent (AC4)" case_7
run_case 8 "Reference routes (AC7)" case_8
run_case 9 "Failure classification matrix (AC2)" case_9
run_case 10 "install.sh skill flag (AC9)" case_10

echo ""
echo "========================================"
echo "Results: $PASS/$TOTAL PASS"
if [[ $FAIL -gt 0 ]]; then
  echo "         $FAIL FAIL"
  echo "========================================"
  exit 1
fi
echo "         All PASS"
echo "========================================"
exit 0

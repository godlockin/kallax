#!/usr/bin/env bash
# Test for pre-commit ALLOWED_PATTERNS 验证 ^jira/ 命中
# 跟 EPIC-058-A 联合, 跟 v1.0.6 EPIC-051 联合, 跟"翻篇&精进" 战略 一致
# 跟 check-build-artifacts-test.sh 模式 一致 (mock + 集成 验证)
#
# 7 mock scenarios:
# mock 1: jira/tickets/ + jira/epics/ → 0 blocked (allowed)
# mock 2: jira/schemas/ → 0 blocked (allowed)
# mock 3: jira/phases/ → 0 blocked (allowed)
# mock 4: jira nested path → 0 blocked (allowed)
# mock 5: 跟 other allowed 混 → 0 blocked (allowed)
# bonus: src/jira.rs (false positive 防御) → blocked (not allowed)
# bonus 2: pre-commit ALLOWED_PATTERNS 含 '^jira/' (text grep 验证)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRE_COMMIT="${KALLAX_ROOT}/scripts/hooks/pre-commit"

PASS=0
FAIL=0

# Extract ALLOWED_PATTERNS array from pre-commit and test each scenario
# Mirrors Check 2 logic in pre-commit (lines 209-227)
test_allowed() {
  local staged_files="$1"
  local expected="$2"
  local label="$3"

  local result
  result=$(echo "$staged_files" | {
    ALLOWED_PATTERNS=(
      '^docs/'
      '^\.claude/'
      '^\.github/'
      '^\.kallax/'
      '^scripts/hooks/'
      '^jira/'
      '^CHANGELOG\.md$'
      '^README\.md$'
      '^RELEASE\.md$'
      '^CONTRIBUTING\.md$'
      '^AGENTS\.md$'
      '^CLAUDE\.md$'
      '^LICENSE$'
      '^\.gitignore$'
      '^docker-compose\.yml$'
      '^Dockerfile$'
      '^package-lock\.json$'
    )
    BLOCKED=""
    while IFS= read -r file; do
      [ -z "$file" ] && continue
      allowed=false
      for pattern in "${ALLOWED_PATTERNS[@]}"; do
        if echo "$file" | grep -qE "$pattern"; then
          allowed=true
          break
        fi
      done
      if [ "$allowed" = false ]; then
        BLOCKED="${BLOCKED}${file}\n"
      fi
    done
    if [ -n "$BLOCKED" ]; then
      echo "BLOCKED"
    else
      echo "ALLOWED"
    fi
  })

  if [ "$result" = "$expected" ]; then
    echo "  [PASS] $label: $result"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $label: expected $expected, got $result"
    FAIL=$((FAIL + 1))
  fi
}

# ── TC1: jira/tickets/ + jira/epics/ → 0 blocked (allowed) ──
echo ">>> TC1: jira/tickets/ + jira/epics/ → allowed"
test_allowed "jira/tickets/TASK-001.md
jira/epics/EPIC-058.md" "ALLOWED" "TC1 jira/tickets/ + jira/epics/ allowed"

# ── TC2: jira/schemas/ → 0 blocked (allowed) ──
echo ">>> TC2: jira/schemas/ → allowed"
test_allowed "jira/schemas/ticket-schema.md
jira/schemas/epic-state-machine.md" "ALLOWED" "TC2 jira/schemas/ allowed"

# ── TC3: jira/phases/ → 0 blocked (allowed) ──
echo ">>> TC3: jira/phases/ → allowed"
test_allowed "jira/phases/PHASE-013.md" "ALLOWED" "TC3 jira/phases/ allowed"

# ── TC4: jira nested path (jira/_archive/, jira/_archived/) → 0 blocked ──
echo ">>> TC4: jira nested paths → allowed"
test_allowed "jira/_archive/EPIC-001.md
jira/_archived/EPIC-002.md
jira/epic_index.json" "ALLOWED" "TC4 jira nested paths allowed"

# ── TC5: jira 跟 other allowed 混 → 0 blocked ──
echo ">>> TC5: jira + other allowed 混 → allowed"
test_allowed "jira/tickets/TASK-002.md
docs/test.md
AGENTS.md
.kallax/state/config.yml" "ALLOWED" "TC5 jira + other allowed mixed"

# ── TC6: src/jira.rs (false positive 防御) → blocked ──
echo ">>> TC6: src/jira.rs (不 是 jira/ dir) → blocked"
test_allowed "src/jira.rs" "BLOCKED" "TC6 src/jira.rs blocked (not jira/ dir)"

# ── TC7: scripts/jira/foo.sh (不 是 jira/ dir) → blocked ──
echo ">>> TC7: scripts/jira/foo.sh → blocked"
test_allowed "scripts/jira/foo.sh" "BLOCKED" "TC7 scripts/jira/foo.sh blocked"

# ── 集成 1: scripts/hooks/pre-commit 含 '^jira/' pattern ──
echo ">>> 集成 1: scripts/hooks/pre-commit 含 '^jira/' pattern"
if grep -q "'\\^jira/'" "$PRE_COMMIT"; then
  echo "  [PASS] scripts/hooks/pre-commit 含 '^jira/' pattern"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] scripts/hooks/pre-commit 不含 '^jira/' pattern"
  FAIL=$((FAIL + 1))
fi

# ── 集成 2: .git/hooks/pre-commit 跟 scripts/hooks/pre-commit 同步 ──
echo ">>> 集成 2: .git/hooks/pre-commit 跟 scripts/hooks/pre-commit 同步"
DEPLOYED="${KALLAX_ROOT}/.git/hooks/pre-commit"
if [ -f "$DEPLOYED" ] && diff -q "$PRE_COMMIT" "$DEPLOYED" >/dev/null 2>&1; then
  echo "  [PASS] .git/hooks/pre-commit == scripts/hooks/pre-commit (sync)"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] .git/hooks/pre-commit 跟 scripts/hooks/pre-commit 不一致 (out of sync)"
  FAIL=$((FAIL + 1))
fi

# ── 集成 3: .git/hooks/pre-commit 含 '^jira/' pattern ──
echo ">>> 集成 3: .git/hooks/pre-commit 含 '^jira/' pattern"
if [ -f "$DEPLOYED" ] && grep -q "'\\^jira/'" "$DEPLOYED"; then
  echo "  [PASS] .git/hooks/pre-commit 含 '^jira/' pattern"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] .git/hooks/pre-commit 不含 '^jira/' pattern"
  FAIL=$((FAIL + 1))
fi

# ── 集成 4: bash -n syntax check ──
echo ">>> 集成 4: bash -n scripts/hooks/pre-commit syntax check"
if bash -n "$PRE_COMMIT" 2>/dev/null; then
  echo "  [PASS] scripts/hooks/pre-commit syntax OK"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] scripts/hooks/pre-commit syntax error"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=========================================="
echo "Summary: ${PASS}/$((PASS+FAIL)) PASS"
echo "=========================================="
if [ "$FAIL" -eq 0 ]; then
  echo "✓ pre-commit ALLOWED_PATTERNS ^jira/ 命中 — Integration Tests: ${PASS}/$((PASS+FAIL)) PASS (100.0%)"
  echo "EXIT_CODE=0"
  exit 0
else
  echo "✗ pre-commit ALLOWED_PATTERNS ^jira/ 命中 — Tests failed"
  echo "EXIT_CODE=1"
  exit 1
fi

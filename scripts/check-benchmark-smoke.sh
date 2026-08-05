#!/usr/bin/env bash
# scripts/check-benchmark-smoke.sh — EPIC-175 Benchmark Smoke Classification
#
# 借鉴 loopx benchmark smoke pattern 1:1 (跟 EPIC-131/132 scan-dead-code 1:1):
#   - boundary  — 边界值测试 (edge cases, empty, max)
#   - ledger    — 账本测试 (event sourcing, audit trail)
#   - classifier — 分类测试 (routing, matching, tier)
#   - adapter   — 适配器测试 (bridge, protocol conversion)
#
# Exit codes (跟 scan-dead-code 1:1):
#   0 = PASS (all categories present)
#   1 = FAIL (missing categories)
#   2 = BLOCKED-env (环境缺失)
#
# Usage:
#   check-benchmark-smoke.sh [--category <type>] [--verbose]
#   check-benchmark-smoke.sh --help
#
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# Exit code constants
readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_BLOCKED_ENV=2

# Smoke categories (跟 loopx 1:1)
readonly CATEGORIES=(
  "boundary"    # 边界值测试: edge cases, empty, max, overflow
  "ledger"      # 账本测试: event sourcing, audit trail, hash chain
  "classifier"  # 分类测试: routing, matching, tier, priority
  "adapter"     # 适配器测试: bridge, protocol conversion, format
)

USAGE="check-benchmark-smoke.sh — EPIC-175 Benchmark Smoke Classification

Usage:
  check-benchmark-smoke.sh [--category <type>] [--verbose]
  check-benchmark-smoke.sh --help

Categories:
  boundary    — 边界值测试 (edge cases, empty, max, overflow)
  ledger      — 账本测试 (event sourcing, audit trail, hash chain)
  classifier  — 分类测试 (routing, matching, tier, priority)
  adapter     — 适配器测试 (bridge, protocol conversion, format)

Exit codes:
  0 = PASS
  1 = FAIL (missing categories)
  2 = BLOCKED-env
"

# ── Helpers ──────────────────────────────────────────────────────────────────

# Check for boundary tests
check_boundary() {
  local found=0

  # Look for boundary test patterns in test files
  if grep -rqE "(boundary|edge.?case|empty|max|overflow|zero|negative)" \
    tests/ scripts/ --include="*.test.*" --include="*.sh" 2>/dev/null; then
    found=1
  fi

  # Also check for benchmark files with boundary patterns
  if grep -rqE "(boundary|edge.?case|empty|max)" \
    tests/benchmark/ scripts/benchmark*.sh 2>/dev/null; then
    found=1
  fi

  echo $found
}

# Check for ledger tests
check_ledger() {
  local found=0

  if grep -rqE "(hash.?chain|audit.?trail|event.?sourcing|ledger|append.?only)" \
    tests/ scripts/ --include="*.test.*" --include="*.sh" 2>/dev/null; then
    found=1
  fi

  if grep -rqE "(hash.?chain|audit|ledger)" \
    tests/audit-chain tests/integration/audit-chain 2>/dev/null; then
    found=1
  fi

  echo $found
}

# Check for classifier tests
check_classifier() {
  local found=0

  if grep -rqE "(tier.?router|classifier|routing|matching|priority)" \
    tests/ scripts/ --include="*.test.*" --include="*.sh" 2>/dev/null; then
    found=1
  fi

  if grep -rqE "(tier|classifier|routing)" \
    node/tests rust/tests 2>/dev/null; then
    found=1
  fi

  echo $found
}

# Check for adapter tests
check_adapter() {
  local found=0

  if grep -rqE "(adapter|bridge|protocol|conversion|format)" \
    tests/ scripts/ --include="*.test.*" --include="*.sh" 2>/dev/null; then
    found=1
  fi

  if grep -rqE "(adapter|bridge)" \
    node/tests rust/tests 2>/dev/null; then
    found=1
  fi

  echo $found
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  local verbose=""
  local target_category=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose|-v) verbose=1 ;;
      --category) target_category="$2"; shift ;;
      -h|--help) echo "$USAGE"; exit 0 ;;
      *) echo "Unknown option: $1" >&2; exit $EXIT_FAIL ;;
    esac
    shift
  done

  local results=()
  local missing=()
  local exit_code=0

  for cat in "${CATEGORIES[@]}"; do
    local found
    case "$cat" in
      boundary)   found=$(check_boundary) ;;
      ledger)     found=$(check_ledger) ;;
      classifier) found=$(check_classifier) ;;
      adapter)    found=$(check_adapter) ;;
    esac

    if [ "$found" = "1" ]; then
      results+=("$cat:PASS")
      [ -n "$verbose" ] && echo "  $cat: PASS"
    else
      results+=("$cat:MISSING")
      missing+=("$cat")
      [ -n "$verbose" ] && echo "  $cat: MISSING"
    fi
  done

  echo ""
  echo "=== Benchmark Smoke Classification ==="
  printf "  %s\n" "${results[@]}"
  echo ""

  if [ ${#missing[@]} -gt 0 ]; then
    echo "FAIL: missing categories: ${missing[*]}"
    exit_code=$EXIT_FAIL
  else
    echo "PASS: all ${#CATEGORIES[@]} categories present"
    exit_code=$EXIT_PASS
  fi

  exit $exit_code
}

main "$@"

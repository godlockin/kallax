#!/usr/bin/env bash
# scripts/audit/kpi-audit.sh — KPI estimator detection (Rule 9a, EPIC-037-A)
#
# Detects KPI falsification patterns in input text. All estimator words FAIL.
#
# Estimator words (Rule 9a list):
#   ~60-70%, ~70%, ~80% etc.   (tilde before number+%)
#   约 80% / 约70%             (Chinese 约)
#   大约 / 大概                  (Chinese 大约/大概)
#   around 80 / around 90       (English "around")
#   approximately 80            (English "approximately")
#   roughly 50 / roughly 60     (English "roughly")
#   PARTIAL                     (status code, not numeric)
#   估计                         (Chinese 估计)
#   should ~70%                 (English "should")
#
# Source: Rule 9a [P0] KPI estimator = FAIL. EPIC-024/028 教训, 主公 2026-06-08 同意升红线.
#
# Usage:
#   bash scripts/audit/kpi-audit.sh scan <file>
#   bash scripts/audit/kpi-audit.sh scan-stdin
#   echo "M1 ~70%" | bash scripts/audit/kpi-audit.sh scan-stdin
#
# Exit codes:
#   0 = PASS (no estimator detected)
#   1 = FAIL (at least one estimator detected)
#   2 = usage error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CMD="${1:-}"
TARGET="${2:-}"

if [[ -z "$CMD" ]]; then
  echo "Usage: $0 {scan <file>|scan-stdin}" >&2
  exit 2
fi

# Read input
read_input() {
  if [[ "$CMD" == "scan-stdin" ]]; then
    INPUT=$(cat)
  elif [[ "$CMD" == "scan" ]]; then
    if [[ -z "$TARGET" || ! -f "$TARGET" ]]; then
      echo "FAIL: target file missing: $TARGET" >&2
      exit 2
    fi
    INPUT=$(cat "$TARGET")
  else
    echo "FAIL: unknown command $CMD" >&2
    exit 2
  fi
}

# Patterns: name | regex (ERE). Order matters — check word boundaries for EN, no-boundary for ZH.
declare -a PATTERNS=(
  "tilde percent|~[0-9]+(\\.[0-9]+)?\\s*%"
  "chinese 约 percent|约[0-9]+(\\.[0-9]+)?\\s*%"
  "chinese 大约|大约"
  "chinese 大概|大概"
  "english around|\\baround\\b[ \\t]+[0-9]+"
  "english approximately|\\bapproximately\\b[ \\t]+[0-9]+"
  "english roughly|\\broughly\\b[ \\t]+[0-9]+"
  "PARTIAL literal|\\bPARTIAL\\b"
  "chinese 估计|估计"
  "english should percent|\\bshould\\b[ \\t]+[~]?[0-9]+(\\.[0-9]+)?\\s*%"
)

scan() {
  read_input
  local total_matches=0
  local matched_names=()

  for entry in "${PATTERNS[@]}"; do
    local name="${entry%%|*}"
    local pat="${entry#*|}"
    if echo "$INPUT" | grep -qE "$pat"; then
      echo "MATCH: $name"
      echo "$INPUT" | grep -oE "$pat" | head -2 | while read -r m; do
        echo "  - $m"
      done
      matched_names+=("$name")
      total_matches=$((total_matches+1))
    fi
  done

  echo ""
  if [[ $total_matches -eq 0 ]]; then
    echo "PASS: KPI audit — 0 estimator patterns detected"
    exit 0
  else
    echo "FAIL: KPI audit — $total_matches estimator pattern(s) detected:"
    for n in "${matched_names[@]}"; do
      echo "  - $n"
    done
    echo ""
    echo "REQUIREMENT: Use exact X/Y numbers with one decimal (e.g. 'M1: 26/30 = 86.7%')."
    echo "Estimates ~= KPI falsification = ticket REJECT (Rule 9a)."
    exit 1
  fi
}

scan
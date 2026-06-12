#!/usr/bin/env bash
# scripts/audit/continuous-audit.sh — 9-pass redaction check (EPIC-037-A)
#
# Scans text input for 9 categories of leaked secrets:
#   1) Authorization header values
#   2) Token header values
#   3) X-Auth-Token header values
#   4) password= fields
#   5) secret= fields
#   6) Basic Auth in URLs (user:pass@host)
#   7) 24-char fallback (any 24-char [A-Za-z0-9_-] run that resembles a token)
#   8) Known prefixes: ghp_ / sk- / AKIA
#   9) JWT (eyJ... . eyJ... . <sig>) + env-var like SECRET_KEY=... / TOKEN=...
#
# Source: Rule 13 redaction hardening (3rd review round) — EPIC-029 design.
#
# Usage:
#   bash scripts/audit/continuous-audit.sh scan <file>
#   bash scripts/audit/continuous-audit.sh scan-stdin
#   echo "Authorization: Bearer ghp_xyz" | bash scripts/audit/continuous-audit.sh scan-stdin
#
# Exit codes:
#   0 = no leak detected
#   1 = at least one pattern matched (leak)
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

# Read input into INPUT variable
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

# Patterns: name | regex (extended regex)
declare -a PATTERNS=(
  "Authorization header|^[Aa]uthorization[[:space:]]*:[[:space:]]*[A-Za-z0-9._~+/=-]{8,}"
  "Token header|^[Tt]oken[[:space:]]*:[[:space:]]*[A-Za-z0-9._~+/=-]{8,}"
  "X-Auth-Token header|^[Xx]-[Aa]uth-[Tt]oken[[:space:]]*:[[:space:]]*[A-Za-z0-9._~+/=-]{8,}"
  "password=|password[[:space:]]*=[[:space:]]*[^[:space:]]{4,}"
  "secret=|secret[[:space:]]*=[[:space:]]*[^[:space:]]{4,}"
  "Basic Auth URL|://[^[:space:]/]+:[^[:space:]]+@"
  "ghp_ prefix|ghp_[A-Za-z0-9]{20,}"
  "sk- prefix|sk-[A-Za-z0-9]{16,}"
  "AKIA prefix|AKIA[0-9A-Z]{16}"
  "JWT|eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}"
  "env-var SECRET/TOKEN|(SECRET|TOKEN|API_KEY|PRIVATE_KEY)[[:space:]]*=[[:space:]]*[A-Za-z0-9._~+/=-]{16,}"
)

# Pattern #8 (24-char fallback) is run separately because we want any 24-char
# token-like run that DOES NOT match a benign context (commit hash).
detect_24char_fallback() {
  # Match any 24-char alphanumeric/[-_] run NOT followed by git-hash context
  # Look for patterns like standalone tokens (preceded by whitespace/punct, followed by EOL/punct)
  local txt="$1"
  # Capture candidate tokens
  local cand
  cand=$(echo "$txt" | grep -oE '\b[A-Za-z0-9_-]{24,}\b' | sort -u || true)
  if [[ -z "$cand" ]]; then
    return 0
  fi
  local bad=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Skip if line is exactly 40 hex chars (likely git SHA-1, not secret)
    if [[ ${#line} -eq 40 && "$line" =~ ^[0-9a-f]+$ ]]; then
      continue
    fi
    # Skip if line is exactly 64 hex chars (likely git SHA-256)
    if [[ ${#line} -eq 64 && "$line" =~ ^[0-9a-f]+$ ]]; then
      continue
    fi
    # Skip pure UUID with dashes at 8-4-4-4-12
    if [[ "$line" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
      continue
    fi
    bad+=("$line")
  done <<< "$cand"
  if [[ ${#bad[@]} -gt 0 ]]; then
    echo "MATCH: 24-char fallback — tokens (count=${#bad[@]})"
    local i=0
    for t in "${bad[@]}"; do
      i=$((i+1))
      [[ $i -le 5 ]] && echo "  - ${t:0:6}...(${ #t} chars)"
    done
    return 1
  fi
  return 0
}

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

  # Pattern #7: 24-char fallback (special handling)
  if detect_24char_fallback "$INPUT"; then
    : # no match
  else
    matched_names+=("24-char fallback")
    total_matches=$((total_matches+1))
  fi

  echo ""
  if [[ $total_matches -eq 0 ]]; then
    echo "PASS: 9-pass redaction — 0 leaks detected"
    exit 0
  else
    echo "FAIL: 9-pass redaction — $total_matches pass(es) detected leaks:"
    for n in "${matched_names[@]}"; do
      echo "  - $n"
    done
    exit 1
  fi
}

scan
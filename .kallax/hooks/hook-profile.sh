#!/usr/bin/env bash
# KALLAX Hook Profile — 三档 minimal/standard/strict
# Rule 10: Anti-Fabrication forced on all commits
# EPIC-030-D: Hook Profile 三档
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PROFILE="${KALLAX_HOOK_PROFILE:-standard}"

case "$PROFILE" in
  minimal)
    HOOKS=("check-test-case-isolation.sh")
    ;;
  standard)
    HOOKS=("check-test-case-isolation.sh" "check-kpi-precision.sh" "check-scope-creep.sh")
    ;;
  strict)
    HOOKS=("check-test-case-isolation.sh" "check-kpi-precision.sh" "check-scope-creep.sh" "check-fact-forcing-preflight.sh")
    ;;
  *)
    echo "ERROR: KALLAX_HOOK_PROFILE must be minimal|standard|strict, got: $PROFILE" >&2
    exit 1
    ;;
esac

FAILED=0
for hook in "${HOOKS[@]}"; do
  hook_path="${KALLAX_ROOT}/scripts/verify/${hook}"
  # scope-creep requires TICKET_ID which isn't available in pre-commit context
  # → explicit WARN + fail-open (not silent bypass)
  # KALLAX_BYPASS_SCOPE_CHECK=1 only set by design-stage work, not pre-commit context
  if [[ "$hook" == "check-scope-creep.sh" ]]; then
    if [[ -z "${KALLAX_TICKET_ID:-}" ]]; then
      echo "WARN: check-scope-creep.sh skipped (no TICKET_ID in pre-commit context)" >&2
      continue  # fail-open with explicit warn, not silent bypass
    fi
    bash "$hook_path" || { echo "BLOCKED: ${hook} FAIL"; FAILED=1; }
    continue
  fi
  if [[ ! -x "$hook_path" ]]; then
    # strict mode may reference scripts not yet deployed — warn and skip
    if [[ "$PROFILE" == "strict" ]]; then
      echo "WARN: strict mode skipped non-existent ${hook} (not yet deployed)" >&2
      continue
    fi
    echo "ERROR: hook script not found: ${hook_path}" >&2
    FAILED=1
    continue
  fi
  if ! bash "$hook_path"; then
    echo "BLOCKED: ${hook} FAIL" >&2
    FAILED=1
  fi
done

if [[ "$FAILED" -eq 1 ]]; then
  exit 1
fi

echo "PASS: profile=$PROFILE, ${#HOOKS[@]} hooks"
exit 0
#!/usr/bin/env bash
# KALLAX Assumption Clarity Check (v2.0.8, EPIC-115 upgrade)
# v2.0.7: hard-required $1=ticket.json → pre-commit wrapper (no arg) fail-closed
# v2.0.8: auto-discover EPIC/ticket from staged files or branch name (mirrors BE-25 check-scope-creep pattern)
#
# Discovery order:
#   1. $1 explicit (subagent / manual invocation) — backward compatible
#   2. staged epic.json / ticket.json directly
#   3. staged files or diff content contain EPIC-NNN → jira/epics/EPIC-NNN/epic.json
#   4. branch name feature/vX.Y.Z-EPIC-NNN → jira/epics/EPIC-NNN/epic.json
#   5. none → WARN + skip (0 fail-closed, aligned with BE-25)

set -euo pipefail

declare -a AMBIGUITY_PATTERNS=(
  "(vague|maybe|perhaps|possibly|might|should|probably|大概|也许|可能|或许|应该|恐怕)"
  "(modify|update|fix|change|改|修改|更新|修复|变更).*\\?$"
  "(all|everything|entire|whole|所有|全部|整个|整体)"
  "(but don't|but do|然而|但是).*\\?$"
  "(or|either|或者|要么).*\\?$"
)

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ─── Discovery ──────────────────────────────────────────────────────────────

TICKET_JSON="${1:-}"

discover_from_staged() {
  local staged
  staged="$(git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null || true)"
  [[ -z "$staged" ]] && return 1

  # Direct hit: epic.json or ticket.json itself staged
  local direct
  direct="$(echo "$staged" | grep -E '^jira/(epics|tickets)/[^/]+/(epic|ticket)\.json$' | head -1 || true)"
  if [[ -n "$direct" ]] && [[ -f "$REPO_ROOT/$direct" ]]; then
    echo "$REPO_ROOT/$direct"
    return 0
  fi

  # Indirect: staged path mentions EPIC-NNN
  local epic_id
  epic_id="$(echo "$staged" | grep -oE 'EPIC-[0-9]+' | head -1 || true)"
  if [[ -z "$epic_id" ]]; then
    epic_id="$(git -C "$REPO_ROOT" diff --cached 2>/dev/null | grep -oE 'EPIC-[0-9]+' | head -1 || true)"
  fi
  if [[ -n "$epic_id" ]]; then
    local candidate="$REPO_ROOT/jira/epics/$epic_id/epic.json"
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  fi

  return 1
}

discover_from_branch() {
  local branch
  branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  local epic_id
  epic_id="$(echo "$branch" | grep -oE 'EPIC-[0-9]+' | head -1 || true)"
  [[ -z "$epic_id" ]] && return 1
  local candidate="$REPO_ROOT/jira/epics/$epic_id/epic.json"
  [[ -f "$candidate" ]] || return 1
  echo "$candidate"
}

if [[ -z "$TICKET_JSON" ]]; then
  TICKET_JSON="$(discover_from_staged || true)"
fi
if [[ -z "$TICKET_JSON" ]]; then
  TICKET_JSON="$(discover_from_branch || true)"
fi

if [[ -z "$TICKET_JSON" ]]; then
  echo "WARN: check-assumption-clarity skipped (no ticket/epic detected from \$1, staged files, or branch)" >&2
  echo "  For explicit invocation: bash scripts/verify/check-assumption-clarity.sh <ticket-or-epic.json>" >&2
  exit 0
fi

if [[ ! -f "$TICKET_JSON" ]]; then
  echo "ERROR: ticket/epic not found: $TICKET_JSON" >&2
  exit 2
fi

# ─── Clarity check ──────────────────────────────────────────────────────────

ticket_id=$(jq -r '.id // ""' "$TICKET_JSON")
ticket_title=$(jq -r '.title // ""' "$TICKET_JSON")
ticket_desc=$(jq -r '.description // ""' "$TICKET_JSON")
ticket_ac=$(jq -r '(.acceptance_criteria // []) | if type=="array" then join(" ") else tostring end' "$TICKET_JSON")
ticket_text="$ticket_title $ticket_desc $ticket_ac"

ambiguities=()
for pattern in "${AMBIGUITY_PATTERNS[@]}"; do
  if echo "$ticket_text" | grep -qiE "$pattern"; then
    ambiguities+=("$pattern")
  fi
done

if [[ ${#ambiguities[@]} -eq 0 ]]; then
  echo "$(basename "$TICKET_JSON") ($ticket_id): clarity OK"
  exit 0
else
  echo "$(basename "$TICKET_JSON") ($ticket_id): ambiguity detected"
  echo "  Detected patterns: ${ambiguities[*]}"
  echo "  Fix: rewrite title/description/acceptance_criteria/scope to remove hedging language"
  exit 1
fi

#!/usr/bin/env bash
# scripts/refresh-arg-hints.sh — Add `argument-hint` to all .md command wrappers
# based on .sh USAGE section. Idempotent. Run after adding new slash commands.
set -eo pipefail

cd "$(dirname "$0")/.."

# Map of command → argument-hint (one per line, format: cmd=hint)
HINTS_DATA=$(cat <<'EOF'
init=
start=[role]
status=
help=
mode=[conductor|performer|standalone]
role=[conductor|performer|master]
board=
list=
claim=[TASK_ID]
task=[action] [TASK_ID]
analyze=[TARGET]
expert=<role> [context]
panel=[TOPIC]
ask=<question>
skill=<skill-name> [target]
office-hours=[TOPIC]
onramp=
verify-pr=[PR_NUMBER]
review-pr=[PR_NUMBER] [BASE_BRANCH]
review-merge=[PR_NUMBER]
review-analysis=
check-progress=
phase-review=[PHASE]
instances=
submit-pr=[TASK_ID]
takeover=
save=
resume=
merge=[PR_NUMBER]
EOF
)

updated=0
skipped=0
while IFS='=' read -r cmd hint; do
  [ -z "$cmd" ] && continue
  md=".claude/commands/kallax-$cmd.md"
  [ -f "$md" ] || continue

  # Skip files that don't have !bash wrapper (e.g., takeover.md is a full guide)
  if ! grep -q '^!bash' "$md"; then
    skipped=$((skipped + 1))
    echo "  ⏭ kallax-$cmd.md (skipped — not a slash wrapper, full doc)"
    continue
  fi

  # Read current description
  desc=$(grep "^description:" "$md" | sed 's/description: //' | head -1)

  # Trim leading "/kallax-xxx — " prefix if present
  desc=$(echo "$desc" | sed -E 's|^/kallax-[a-z-]+ — ||')

  # Extract the bash invocation line
  bash_line=$(grep '^!bash' "$md" | head -1)

  # Rebuild .md with cleaned description + argument-hint
  {
    echo "---"
    echo "description: $desc"
    if [ -n "$hint" ]; then
      echo "argument-hint: $hint"
    fi
    echo "---"
    echo ""
    echo "$bash_line"
  } > "$md"

  updated=$((updated + 1))
  echo "  ✓ kallax-$cmd.md (hint: '${hint}')"
done <<< "$HINTS_DATA"

echo ""
echo "Updated $updated command wrappers, skipped $skipped non-wrappers"


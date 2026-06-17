#!/usr/bin/env bash
# /kallax-skill — Execute a specific skill.
# Locates the skill markdown under .claude/skills/* and prints the
# execution context. The skill content is then loaded and ready to
# apply to the target. Use this to invoke a specific capability
# (e.g. tdd, security-review). Run `/kallax-skill --help`.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help <<'EOF'
/kallax-skill — Execute a specific skill

USAGE:
  /kallax-skill <skill-name> [target]

ARGS:
  skill-name        Skill identifier (required). Examples: tdd,
                    security-review, kallax-init.
  target            Optional file or path the skill should target.

DESCRIPTION:
  Locates the skill markdown under .claude/skills/* and prints the
  execution context. The skill content is then loaded and ready to
  apply to the target.

EXAMPLES:
  /kallax-skill tdd
  /kallax-skill security-review src/api/auth.ts

RELATED:
  /kallax-expert, /kallax-list
EOF
  exit 0
fi

SKILL="${1:-}"
TARGET="${2:-}"

log_title "Execute Skill"

if [ -z "$SKILL" ]; then
  echo "  Available skills:"
  echo ""
  echo "  Algorithm:       algorithm-design"
  echo "  Analysis:        code-analysis, requirements-analysis"
  echo "  Data:            data-modeling"
  echo "  DevOps:          ci-cd, kubernetes"
  echo "  Documentation:   technical-writing, api-docs"
  echo "  Implementation:  tdd, refactoring"
  echo "  LLM:             prompt-engineering, agent-design"
  echo "  Ops:             monitoring, incident-response"
  echo "  Security:        security-review, penetration-testing"
  echo "  UX:              user-research, usability-testing"
  echo ""
  echo "  Usage: /kallax-skill <skill-name> [target]"
  echo ""
  exit 0
fi

log_info "Executing skill: ${SKILL}"

SKILL_FILE="${KALLAX_ROOT}/.claude/skills/kallax/skills/*/${SKILL}.md"
if ls $SKILL_FILE 2>/dev/null | head -1 >/dev/null 2>&1; then
  log_info "Found skill definition"
else
  log_warn "Skill '${SKILL}' not found in local skills"
  log_info "Checking extended skills..."
fi

echo ""
echo "  Skill:      ${SKILL}"
echo "  Target:     ${TARGET:-current context}"
echo ""
echo "  The skill will be loaded and executed."
echo "  Follow the skill's checklist for best results."
echo ""

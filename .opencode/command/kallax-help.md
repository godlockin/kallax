---
description: KALLAX help command
---
# /kallax-help — Show all available KALLAX commands and resources

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

log_title "KALLAX Help"

echo ""
echo "  KALLAX — Knowledge-Augmented Leveraged Learning Agent eXecutor v1.0.0"
echo "  Multi-Agent Collaboration Framework (Conductor/Performer Model)"
echo ""

print_separator

echo ""
echo "  ${BOLD}Quick Commands${NC}"
echo ""
echo "  /kallax-start              Start KALLAX (role selection)"
echo "  /kallax-status             Show system and task status"
echo "  /kallax-help               Show this help"
echo ""

echo "  ${BOLD}Performer Commands${NC}"
echo ""
echo "  /kallax-claim [task]       Claim an available task"
echo "  /kallax-submit-pr [task]   Complete task & submit PR (Saga 5-step)"
echo "  /kallax-save               Save session state"
echo "  /kallax-resume             Resume from saved session"
echo ""

echo "  ${BOLD}Conductor Commands${NC}"
echo ""
echo "  /kallax-review-pr [PR]     Review PR (4-Level Gate Review)"
echo "  /kallax-review-merge [PR]  Review then merge"
echo "  /kallax-verify-pr [PR]     Verify PR before merge"
echo "  /kallax-merge [PR]         Merge approved PR"
echo "  /kallax-board              Show ticket board"
echo "  /kallax-instances          List active instances"
echo "  /kallax-check-progress     Check team progress"
echo ""

echo "  ${BOLD}Analysis & Design${NC}"
echo ""
echo "  /kallax-office-hours       Requirements analysis (6 questions)"
echo "  /kallax-analyze            Analyze project structure"
echo "  /kallax-ask [question]     Ask expert panel a question"
echo "  /kallax-panel [topic]      Launch full expert panel review"
echo "  /kallax-expert [role]      Summon a specific expert"
echo "  /kallax-skill [name]       Execute a specific skill"
echo "  /kallax-list               List all experts and skills"
echo ""

echo "  ${BOLD}Configuration${NC}"
echo ""
echo "  /kallax-init               Initialize KALLAX in new project"
echo "  /kallax-role [role]        View or change agent role"
echo "  /kallax-mode [mode]        Switch between modes"
echo ""

echo "  ${BOLD}CLI Commands${NC}"
echo ""
echo "  kallax task claim           Claim task with worktree isolation"
echo "  kallax task complete        Complete task (Saga 5-step)"
echo "  kallax task status          View task status"
echo "  kallax task progress        Update progress"
echo "  kallax task resume          Resume failed task"
echo "  kallax conductor heartbeat  Run conductor health check"
echo "  kallax conductor poll       Poll for task assignments"
echo "  kallax performer register   Register as performer"
echo "  kallax performer poll       Poll for available tasks"
echo "  kallax isolation:check      Check file scope overlap"
echo "  kallax verify:output        Verify task output (4-Level)"
echo "  kallax system doctor        Run system diagnostics"
echo "  kallax team:status          Show team overview"
echo ""

echo "  ${BOLD}Resources${NC}"
echo ""
echo "  Docs:     .kallax/IDENTITY.md  |  template/docs/"
echo "  Config:   .kallax/config.yml"
echo "  State:    .kallax/state/"
echo "  Inbox:    .kallax/inbox/"
echo ""

print_separator
echo ""

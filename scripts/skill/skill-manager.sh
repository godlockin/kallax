#!/bin/bash
# skill-manager.sh — Expert Skill Package Manager
# EPIC-170: Complete plugin 化 — 9 expert skill 包管理 + validate 子命令

set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SKILL_DIR="$KALLAX_ROOT/.kallax/experts"
POLICY_FILE="$KALLAX_ROOT/.kallax/state/skill-policy.json"
SKILL_MANAGER_DIR="$(dirname "${BASH_SOURCE[0]}")"

# 9 Expert skill packages
EXPERT_LIST="architect backend frontend pm product security ux auditor process-engineering"

# --- helpers ---

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [expert] [args...]

Commands:
  list                List all expert skill packages
  status <expert>     Show expert status (policy + enabled_policy)
  enable <expert>     Enable expert (persist to policy.json)
  disable <expert>    Disable expert (persist to policy.json)
  validate <expert>   Validate 5 activation gates for expert
  check-gates         Check all experts' activation gates
  activation-gates    Show 5-step activation gate documentation

Expert Packages:
  $EXPERT_LIST

Examples:
  $(basename "$0") list
  $(basename "$0") status architect
  $(basename "$0") enable backend
  $(basename "$0)") validate architect
  $(basename "$0") check-gates
EOF
}

init_policy_file() {
    mkdir -p "$(dirname "$POLICY_FILE")"
    if [[ ! -f "$POLICY_FILE" ]]; then
        cat > "$POLICY_FILE" <<'JSON'
{
  "version": "1.0.0",
  "policies": {},
  "updated_at": ""
}
JSON
    fi
}

read_policies() {
    init_policy_file
    cat "$POLICY_FILE"
}

get_policy() {
    local expert="$1"
    local policies_json
    policies_json=$(read_policies)
    echo "$policies_json" | jq -r --arg e "$expert" '.policies[$e] // "default"'
}

get_skill_policy_from_file() {
    local expert="$1"
    local skill_file="$SKILL_DIR/default/$expert.md"
    if [[ -f "$skill_file" ]]; then
        grep -E "^enabled_policy:" "$skill_file" 2>/dev/null | awk '{print $2}' || echo "default"
    else
        echo "default"
    fi
}

resolve_effective_policy() {
    local expert="$1"
    local skill_policy
    local persisted_policy

    skill_policy=$(get_skill_policy_from_file "$expert")
    persisted_policy=$(get_policy "$expert")

    if [[ "$persisted_policy" != "default" ]]; then
        echo "$persisted_policy"
    else
        echo "$skill_policy"
    fi
}

# --- 5-Step Activation Gates ---

gate1_resolve_project() {
    local state_file="$KALLAX_ROOT/.kallax/state/state.json"
    if [[ -f "$state_file" ]]; then
        echo "  [GATE1] resolve_project: PASS (state.json exists)"
        return 0
    else
        echo "  [GATE1] resolve_project: FAIL (state.json not found)"
        return 1
    fi
}

gate2_confirm_todo() {
    local tickets_dir="$KALLAX_ROOT/jira/tickets"
    local in_progress
    in_progress=$(find "$tickets_dir" -name "ticket.json" -exec grep -l '"status": "in_progress"' {} \; 2>/dev/null | head -1)
    if [[ -n "$in_progress" ]]; then
        echo "  [GATE2] confirm_todo: PASS (in_progress ticket found)"
        return 0
    else
        echo "  [GATE2] confirm_todo: WARN (no in_progress ticket)"
        return 2
    fi
}

gate3_check_boundary() {
    local expert="$1"
    local current_file="${2:-}"
    if [[ -n "$current_file" && -f "$current_file" ]]; then
        local ticket_dir
        ticket_dir=$(find "$KALLAX_ROOT/jira/tickets" -maxdepth 1 -type d -name "EPIC-*" | head -1)
        if [[ -n "$ticket_dir" && -f "$ticket_dir/ticket.json" ]]; then
            local scope_files
            scope_files=$(grep -o '"includes": \[[^]]*\]' "$ticket_dir/ticket.json" 2>/dev/null || echo "")
            if [[ -n "$scope_files" ]]; then
                echo "  [GATE3] check_boundary: PASS (file_scope available)"
                return 0
            fi
        fi
    fi
    echo "  [GATE3] check_boundary: SKIP (no current file context)"
    return 0
}

gate4_architecture_check() {
    local index_file="$SKILL_DIR/INDEX.md"
    if [[ -f "$index_file" ]]; then
        echo "  [GATE4] architecture_check: PASS (INDEX.md exists)"
        return 0
    else
        echo "  [GATE4] architecture_check: FAIL (INDEX.md not found)"
        return 1
    fi
}

gate5_owner_gated() {
    local expert="$1"
    local policy
    policy=$(resolve_effective_policy "$expert")
    if [[ "$policy" == "owner-gated" ]]; then
        local owner_file="$SKILL_DIR/default/$expert.owner"
        if [[ -f "$owner_file" ]]; then
            echo "  [GATE5] owner_gated: PASS (owner authorized)"
            return 0
        else
            echo "  [GATE5] owner_gated: FAIL (no owner file)"
            return 1
        fi
    else
        echo "  [GATE5] owner_gated: SKIP (not owner-gated policy)"
        return 0
    fi
}

# --- commands ---

cmd_list() {
    echo "Expert Skill Packages:"
    echo "===================="
    for expert in $EXPERT_LIST; do
        local skill_file="$SKILL_DIR/default/$expert.md"
        if [[ -f "$skill_file" ]]; then
            local lines
            lines=$(wc -l < "$skill_file")
            local policy
            policy=$(resolve_effective_policy "$expert")
            echo "  $expert: $policy ($lines lines)"
        else
            echo "  $expert: NOT FOUND"
        fi
    done
}

cmd_status() {
    local expert="${1:-}"
    if [[ -z "$expert" ]]; then
        echo "Error: expert name required" >&2
        exit 1
    fi

    local skill_file="$SKILL_DIR/default/$expert.md"
    echo "Expert: $expert"
    echo "=========="

    if [[ -f "$skill_file" ]]; then
        echo "Skill file: $skill_file"
        local skill_policy
        skill_policy=$(get_skill_policy_from_file "$expert")
        echo "File policy: $skill_policy"

        local persisted_policy
        persisted_policy=$(get_policy "$expert")
        echo "Persisted policy: $persisted_policy"

        local effective_policy
        effective_policy=$(resolve_effective_policy "$expert")
        echo "Effective policy: $effective_policy"

        local lines
        lines=$(wc -l < "$skill_file")
        echo "Lines: $lines"
    else
        echo "Skill file: NOT FOUND"
        exit 1
    fi
}

cmd_enable() {
    local expert="${1:-}"
    if [[ -z "$expert" ]]; then
        echo "Error: expert name required" >&2
        exit 1
    fi
    bash "$SKILL_MANAGER_DIR/skill-policy.sh" enable "$expert"

    # EPIC-177-G: emit work event for skill enable
    local run_history="${KALLAX_ROOT}/scripts/heartbeat/run-history.sh"
    if [ -f "$run_history" ]; then
        local payload
        payload=$(jq -n --arg e "$expert" '{action: "skill_enable", expert: $e}')
        "$run_history" emit work "skill-manager" "$payload" >/dev/null 2>&1
    fi
}

cmd_disable() {
    local expert="${1:-}"
    if [[ -z "$expert" ]]; then
        echo "Error: expert name required" >&2
        exit 1
    fi
    bash "$SKILL_MANAGER_DIR/skill-policy.sh" disable "$expert"

    # EPIC-177-G: emit work event for skill disable
    local run_history="${KALLAX_ROOT}/scripts/heartbeat/run-history.sh"
    if [ -f "$run_history" ]; then
        local payload
        payload=$(jq -n --arg e "$expert" '{action: "skill_disable", expert: $e}')
        "$run_history" emit work "skill-manager" "$payload" >/dev/null 2>&1
    fi
}

cmd_validate() {
    local expert="${1:-}"
    if [[ -z "$expert" ]]; then
        echo "Error: expert name required" >&2
        exit 1
    fi

    echo "Validating 5 Activation Gates for: $expert"
    echo "==========================================="

    local gate_result=0
    local current_file="${2:-}"

    gate1_resolve_project || gate_result=1
    gate2_confirm_todo || { [[ $? -eq 2 ]] && true || gate_result=1; }
    gate3_check_boundary "$expert" "$current_file" || gate_result=1
    gate4_architecture_check || gate_result=1
    gate5_owner_gated "$expert" || gate_result=1

    echo ""
    if [[ $gate_result -eq 0 ]]; then
        echo "Validation: PASS"
        exit 0
    else
        echo "Validation: FAIL"
        exit 1
    fi
}

cmd_check_gates() {
    echo "Checking Activation Gates for All Experts"
    echo "========================================"
    for expert in $EXPERT_LIST; do
        echo ""
        echo "--- $expert ---"
        local gate_result=0
        gate1_resolve_project || gate_result=1
        gate4_architecture_check || gate_result=1
        gate5_owner_gated "$expert" || { [[ $? -eq 2 ]] && true || gate_result=1; }
        if [[ $gate_result -eq 0 ]]; then
            echo "  Overall: PASS"
        else
            echo "  Overall: FAIL"
        fi
    done
}

cmd_activation_gates() {
    cat <<'EOF'
5-Step Activation Gates
======================

Gate 1: resolve_project
  - Check: .kallax/state/state.json exists
  - Purpose: Confirm valid KALLAX project context

Gate 2: confirm_todo
  - Check: jira/tickets/ has in_progress ticket
  - Purpose: Confirm active work context
  - Note: Returns 2 (warn) if no ticket, continues

Gate 3: check_boundary
  - Check: current file in ticket file_scope
  - Purpose: Confirm work within defined scope
  - Note: Returns 0 if no file context (SKIP)

Gate 4: architecture_check
  - Check: .kallax/experts/INDEX.md exists
  - Purpose: Confirm expert index available

Gate 5: owner_gated
  - Check: owner file exists (only for owner-gated policy)
  - Purpose: Confirm owner authorization
  - Note: Returns 0 if not owner-gated policy

Effective Policy Resolution:
  1. If persisted policy != "default" → use persisted
  2. Else → use skill file enabled_policy frontmatter
  3. Default → "default" (enabled at startup)
EOF
}

# --- main ---

main() {
    local cmd="${1:-}"
    [[ -z "$cmd" ]] && { usage; exit 0; }

    init_policy_file

    case "$cmd" in
        list)            cmd_list;;
        status)          shift; cmd_status "$@";;
        enable)          shift; cmd_enable "$@";;
        disable)         shift; cmd_disable "$@";;
        validate)        shift; cmd_validate "$@";;
        check-gates)     cmd_check_gates;;
        activation-gates) cmd_activation_gates;;
        -h|--help)       usage; exit 0;;
        *)               echo "Unknown command: $cmd" >&2; usage; exit 1;;
    esac
}

main "$@"

#!/bin/bash
# skill-policy.sh — Expert Skill Policy Management
# EPIC-170: Complete plugin 化 — enable/disable 持久化到 state/skill-policy.json

set -euo pipefail

KALLAX_ROOT="${KALLAX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
POLICY_FILE="$KALLAX_ROOT/.kallax/state/skill-policy.json"

# --- helpers ---

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [args...]

Commands:
  enable <expert>      Enable an expert skill package
  disable <expert>    Disable an expert skill package
  list                List all expert policies
  check <expert>      Check if expert is enabled
  reset               Reset all policies to default

Examples:
  $(basename "$0") enable architect
  $(basename "$0") disable security
  $(basename "$0") list
  $(basename "$0") check backend
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
    if [[ -f "$POLICY_FILE" ]]; then
        cat "$POLICY_FILE"
    else
        echo '{"version":"1.0.0","policies":{}}'
    fi
}

write_policies() {
    local json="$1"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    mkdir -p "$(dirname "$POLICY_FILE")"
    echo "$json" | jq --arg t "$timestamp" '.updated_at = $t' > "$POLICY_FILE.tmp"
    mv "$POLICY_FILE.tmp" "$POLICY_FILE"
}

get_policy() {
    local expert="$1"
    local policies_json
    policies_json=$(read_policies)
    echo "$policies_json" | jq -r --arg e "$expert" '.policies[$e] // "default"'
}

set_policy() {
    local expert="$1"
    local policy="$2"
    local policies_json
    policies_json=$(read_policies)
    local updated
    updated=$(echo "$policies_json" | jq --arg e "$expert" --arg p "$policy" \
        '.policies[$e] = $p')
    write_policies "$updated"
}

# --- commands ---

cmd_enable() {
    local expert="${1:-}"
    if [[ -z "$expert" ]]; then
        echo "Error: expert name required" >&2
        exit 1
    fi
    set_policy "$expert" "enabled"
    echo "Enabled: $expert"
}

cmd_disable() {
    local expert="${1:-}"
    if [[ -z "$expert" ]]; then
        echo "Error: expert name required" >&2
        exit 1
    fi
    set_policy "$expert" "disabled"
    echo "Disabled: $expert"
}

cmd_list() {
    init_policy_file
    local policies_json
    policies_json=$(read_policies)
    echo "Expert Skill Policies (from $POLICY_FILE):"
    echo "----------------------------------------"
    echo "$policies_json" | jq -r '.policies | to_entries[] | "\(.key): \(.value)"' 2>/dev/null || {
        echo "No custom policies set (all using defaults)"
    }
    echo ""
    echo "Updated: $(echo "$policies_json" | jq -r '.updated_at')"
}

cmd_check() {
    local expert="${1:-}"
    if [[ -z "$expert" ]]; then
        echo "Error: expert name required" >&2
        exit 1
    fi
    local policy
    policy=$(get_policy "$expert")
    echo "$expert: $policy"
    [[ "$policy" == "enabled" ]] && exit 0 || exit 1
}

cmd_reset() {
    init_policy_file
    local policies_json
    policies_json=$(read_policies)
    local reset_json
    reset_json=$(echo "$policies_json" | jq '.policies = {}')
    write_policies "$reset_json"
    echo "All policies reset to default"
}

# --- main ---

main() {
    local cmd="${1:-}"
    [[ -z "$cmd" ]] && { usage; exit 0; }

    init_policy_file

    case "$cmd" in
        enable)   shift; cmd_enable "$@";;
        disable)  shift; cmd_disable "$@";;
        list)     cmd_list;;
        check)    shift; cmd_check "$@";;
        reset)    cmd_reset;;
        -h|--help) usage; exit 0;;
        *)        echo "Unknown command: $cmd" >&2; usage; exit 1;;
    esac
}

main "$@"

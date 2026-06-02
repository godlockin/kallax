#!/bin/bash
# KALLAX Ticket Board Script
# Display and manage tickets in terminal
# Usage: ./scripts/ticket-board.sh [list|show|create|update|archive] [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
JIRA_DIR="$PROJECT_ROOT/jira"
TICKETS_DIR="$JIRA_DIR/tickets"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Status colors
status_color() {
    case "$1" in
        backlog) echo -e "${GRAY}" ;;
        todo) echo -e "${BLUE}" ;;
        in_progress) echo -e "${YELLOW}" ;;
        review) echo -e "${MAGENTA}" ;;
        done) echo -e "${GREEN}" ;;
        blocked) echo -e "${RED}" ;;
        *) echo -e "${NC}" ;;
    esac
}

# Priority icons
priority_icon() {
    case "$1" in
        critical) echo "🔴" ;;
        high) echo "🟠" ;;
        medium) echo "🟡" ;;
        low) echo "🟢" ;;
        *) echo "⚪" ;;
    esac
}

# Parse YAML field
parse_yaml_field() {
    local file="$1"
    local field="$2"
    grep "^${field}:" "$file" 2>/dev/null | sed "s/^${field}:[[:space:]]*//" | tr -d '"'
}

# List all tickets
list_tickets() {
    local filter_status="${1:-}"
    local filter_assignee="${2:-}"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           KALLAX TICKET BOARD                                 ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""

    if [[ ! -d "$TICKETS_DIR" ]]; then
        echo "No tickets directory found. Creating..."
        mkdir -p "$TICKETS_DIR"
        echo "Run: $0 create --title 'My first ticket'"
        return
    fi

    # Count by status
    local backlog=0 todo=0 in_progress=0 review=0 done=0 blocked=0

    for ticket in "$TICKETS_DIR"/*.md "$TICKETS_DIR"/*.yml; do
        [[ -f "$ticket" ]] || continue
        local status
        status=$(parse_yaml_field "$ticket" "status")
        case "$status" in
            backlog) ((backlog++)) ;;
            todo) ((todo++)) ;;
            in_progress) ((in_progress++)) ;;
            review) ((review++)) ;;
            done) ((done++)) ;;
            blocked) ((blocked++)) ;;
        esac
    done

    # Summary bar
    printf "│ 📋 Backlog: %d │ 📝 Todo: %d │ 🔄 In Progress: %d │ 👀 Review: %d │ ✅ Done: %d │ 🚫 Blocked: %d │\n" \
        "$backlog" "$todo" "$in_progress" "$review" "$done" "$blocked"
    echo ""
    echo "────────────────────────────────────────────────────────────────────────────────"

    # List tickets grouped by status
    for status in blocked in_progress review todo backlog done; do
        local color
        color=$(status_color "$status")
        local status_display
        status_display=$(echo "$status" | tr '_' ' ' | tr '[:lower:]' '[:upper:]')

        local count=0
        local tickets_found=""

        for ticket in "$TICKETS_DIR"/*.md "$TICKETS_DIR"/*.yml; do
            [[ -f "$ticket" ]] || continue

            local t_status
            t_status=$(parse_yaml_field "$ticket" "status")
            [[ "$t_status" != "$status" ]] && continue

            if [[ -n "$filter_status" && "$t_status" != "$filter_status" ]]; then
                continue
            fi

            local t_id t_title t_priority t_assignee
            t_id=$(basename "$ticket" | sed 's/\.\(md\|yml\)$//')
            t_title=$(parse_yaml_field "$ticket" "title")
            t_priority=$(parse_yaml_field "$ticket" "priority")
            t_assignee=$(parse_yaml_field "$ticket" "assignee")

            if [[ -n "$filter_assignee" && "$t_assignee" != "$filter_assignee" ]]; then
                continue
            fi

            local icon
            icon=$(priority_icon "$t_priority")
            tickets_found+="  $icon ${color}${t_id}${NC} - ${t_title:-Untitled}"
            [[ -n "$t_assignee" ]] && tickets_found+=" ${GRAY}(@${t_assignee})${NC}"
            tickets_found+=$'\n'
            ((count++))
        done

        if [[ $count -gt 0 ]]; then
            echo ""
            echo -e "${color}▸ $status_display ($count)${NC}"
            echo "$tickets_found"
        fi
    done

    echo ""
}

# Show single ticket
show_ticket() {
    local ticket_id="$1"

    local ticket_file=""
    for ext in md yml; do
        if [[ -f "$TICKETS_DIR/$ticket_id.$ext" ]]; then
            ticket_file="$TICKETS_DIR/$ticket_id.$ext"
            break
        fi
    done

    if [[ -z "$ticket_file" ]]; then
        echo "Ticket not found: $ticket_id"
        exit 1
    fi

    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"

    local title status priority assignee created
    title=$(parse_yaml_field "$ticket_file" "title")
    status=$(parse_yaml_field "$ticket_file" "status")
    priority=$(parse_yaml_field "$ticket_file" "priority")
    assignee=$(parse_yaml_field "$ticket_file" "assignee")
    created=$(parse_yaml_field "$ticket_file" "created")

    local color
    color=$(status_color "$status")
    local icon
    icon=$(priority_icon "$priority")

    echo -e "  $icon ${WHITE}$ticket_id${NC}: $title"
    echo "────────────────────────────────────────────────────────────────────────────────"
    echo -e "  Status:   ${color}$status${NC}"
    echo -e "  Priority: $priority"
    echo -e "  Assignee: ${assignee:-unassigned}"
    echo -e "  Created:  ${created:-unknown}"
    echo ""

    # Show description (content after YAML frontmatter)
    if [[ -f "$ticket_file" ]]; then
        echo "  Description:"
        echo "  ────────────"
        sed -n '/^---$/,/^---$/d; p' "$ticket_file" | head -20 | sed 's/^/  /'
    fi

    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
}

# Create new ticket
create_ticket() {
    local title=""
    local priority="medium"
    local assignee=""
    local status="backlog"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --title|-t) title="$2"; shift 2 ;;
            --priority|-p) priority="$2"; shift 2 ;;
            --assignee|-a) assignee="$2"; shift 2 ;;
            --status|-s) status="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$title" ]]; then
        echo "Error: --title required"
        exit 1
    fi

    mkdir -p "$TICKETS_DIR"

    # Generate ticket ID
    local date_prefix
    date_prefix=$(date +%Y%m%d)
    local seq=1
    while [[ -f "$TICKETS_DIR/KALLAX-${date_prefix}-$(printf '%03d' $seq).md" ]]; do
        ((seq++))
    done
    local ticket_id="KALLAX-${date_prefix}-$(printf '%03d' $seq)"

    local ticket_file="$TICKETS_DIR/$ticket_id.md"

    cat > "$ticket_file" << EOF
---
id: $ticket_id
title: "$title"
status: $status
priority: $priority
assignee: $assignee
created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
labels: []
epic: ""
---

## Description

TODO: Add description

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Technical Notes

## Related

EOF

    echo "Created: $ticket_id"
    echo "File: $ticket_file"
}

# Update ticket
update_ticket() {
    local ticket_id="$1"
    shift

    local ticket_file=""
    for ext in md yml; do
        if [[ -f "$TICKETS_DIR/$ticket_id.$ext" ]]; then
            ticket_file="$TICKETS_DIR/$ticket_id.$ext"
            break
        fi
    done

    if [[ -z "$ticket_file" ]]; then
        echo "Ticket not found: $ticket_id"
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --status|-s)
                sed -i.bak "s/^status:.*/status: $2/" "$ticket_file"
                rm -f "$ticket_file.bak"
                echo "Updated status: $2"
                shift 2
                ;;
            --priority|-p)
                sed -i.bak "s/^priority:.*/priority: $2/" "$ticket_file"
                rm -f "$ticket_file.bak"
                echo "Updated priority: $2"
                shift 2
                ;;
            --assignee|-a)
                sed -i.bak "s/^assignee:.*/assignee: $2/" "$ticket_file"
                rm -f "$ticket_file.bak"
                echo "Updated assignee: $2"
                shift 2
                ;;
            *) shift ;;
        esac
    done

    # Update timestamp
    sed -i.bak "s/^updated:.*/updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)/" "$ticket_file"
    rm -f "$ticket_file.bak"
}

# Archive completed tickets
archive_tickets() {
    local archive_dir="$TICKETS_DIR/archive"
    mkdir -p "$archive_dir"

    local count=0
    for ticket in "$TICKETS_DIR"/*.md "$TICKETS_DIR"/*.yml; do
        [[ -f "$ticket" ]] || continue
        [[ "$ticket" == *"/archive/"* ]] && continue

        local status
        status=$(parse_yaml_field "$ticket" "status")

        if [[ "$status" == "done" ]]; then
            mv "$ticket" "$archive_dir/"
            ((count++))
        fi
    done

    echo "Archived $count completed tickets"
}

# Show help
show_help() {
    echo "KALLAX Ticket Board"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  list [--status STATUS] [--assignee USER]  List tickets"
    echo "  show TICKET_ID                            Show ticket details"
    echo "  create --title TITLE [options]            Create new ticket"
    echo "  update TICKET_ID [options]                Update ticket"
    echo "  archive                                   Archive done tickets"
    echo ""
    echo "Create/Update Options:"
    echo "  --title, -t      Ticket title"
    echo "  --status, -s     Status (backlog|todo|in_progress|review|done|blocked)"
    echo "  --priority, -p   Priority (critical|high|medium|low)"
    echo "  --assignee, -a   Assignee username"
    echo ""
}

# Main
case "${1:-list}" in
    list) shift; list_tickets "$@" ;;
    show) show_ticket "${2:-}" ;;
    create) shift; create_ticket "$@" ;;
    update) shift; update_ticket "$@" ;;
    archive) archive_tickets ;;
    -h|--help|help) show_help ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac

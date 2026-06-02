#!/bin/bash
# KALLAX Sprint Report Generator
# Generate sprint summary reports
# Usage: ./scripts/generate-sprint-report.sh [--sprint NAME] [--output FILE] [--format md|json|html]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
JIRA_DIR="$PROJECT_ROOT/jira"
TICKETS_DIR="$JIRA_DIR/tickets"
OUTPUT_DIR="$PROJECT_ROOT/output/reports"

# Options
SPRINT_NAME=""
OUTPUT_FILE=""
FORMAT="md"
START_DATE=""
END_DATE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sprint|-s) SPRINT_NAME="$2"; shift 2 ;;
        --output|-o) OUTPUT_FILE="$2"; shift 2 ;;
        --format|-f) FORMAT="$2"; shift 2 ;;
        --start) START_DATE="$2"; shift 2 ;;
        --end) END_DATE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --sprint, -s   Sprint name (default: current week)"
            echo "  --output, -o   Output file (default: stdout)"
            echo "  --format, -f   Output format: md|json|html (default: md)"
            echo "  --start        Start date (YYYY-MM-DD)"
            echo "  --end          End date (YYYY-MM-DD)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Set defaults
if [[ -z "$SPRINT_NAME" ]]; then
    SPRINT_NAME="Week $(date +%V) - $(date +%Y)"
fi

if [[ -z "$START_DATE" ]]; then
    # Start of current week (Monday)
    START_DATE=$(date -v-$(($(date +%u)-1))d +%Y-%m-%d 2>/dev/null || date -d "last monday" +%Y-%m-%d)
fi

if [[ -z "$END_DATE" ]]; then
    END_DATE=$(date +%Y-%m-%d)
fi

mkdir -p "$OUTPUT_DIR"

# Parse YAML field
parse_yaml_field() {
    local file="$1"
    local field="$2"
    grep "^${field}:" "$file" 2>/dev/null | sed "s/^${field}:[[:space:]]*//" | tr -d '"'
}

# Collect metrics
declare -A status_counts
declare -A priority_counts
declare -A assignee_work
completed_tickets=()
in_progress_tickets=()
blocked_tickets=()

status_counts=(["backlog"]=0 ["todo"]=0 ["in_progress"]=0 ["review"]=0 ["done"]=0 ["blocked"]=0)
priority_counts=(["critical"]=0 ["high"]=0 ["medium"]=0 ["low"]=0)

if [[ -d "$TICKETS_DIR" ]]; then
    for ticket in "$TICKETS_DIR"/*.md "$TICKETS_DIR"/*.yml; do
        [[ -f "$ticket" ]] || continue

        local t_id t_title t_status t_priority t_assignee t_updated
        t_id=$(basename "$ticket" | sed 's/\.\(md\|yml\)$//')
        t_title=$(parse_yaml_field "$ticket" "title")
        t_status=$(parse_yaml_field "$ticket" "status")
        t_priority=$(parse_yaml_field "$ticket" "priority")
        t_assignee=$(parse_yaml_field "$ticket" "assignee")
        t_updated=$(parse_yaml_field "$ticket" "updated")

        # Count by status
        if [[ -n "${status_counts[$t_status]+x}" ]]; then
            ((status_counts[$t_status]++))
        fi

        # Count by priority
        if [[ -n "${priority_counts[$t_priority]+x}" ]]; then
            ((priority_counts[$t_priority]++))
        fi

        # Track assignee work
        if [[ -n "$t_assignee" ]]; then
            assignee_work["$t_assignee"]=$((${assignee_work["$t_assignee"]:-0} + 1))
        fi

        # Categorize tickets
        case "$t_status" in
            done) completed_tickets+=("$t_id: $t_title") ;;
            in_progress) in_progress_tickets+=("$t_id: $t_title") ;;
            blocked) blocked_tickets+=("$t_id: $t_title") ;;
        esac
    done
fi

# Git statistics
git_stats() {
    cd "$PROJECT_ROOT"

    if ! git rev-parse --git-dir &>/dev/null; then
        echo "Not a git repository"
        return
    fi

    local commits
    commits=$(git log --oneline --since="$START_DATE" --until="$END_DATE" 2>/dev/null | wc -l | tr -d ' ')

    local authors
    authors=$(git log --format='%an' --since="$START_DATE" --until="$END_DATE" 2>/dev/null | sort -u | wc -l | tr -d ' ')

    local files_changed
    files_changed=$(git diff --stat "$(git log --since="$START_DATE" --format=%H | tail -1 2>/dev/null || echo HEAD~10)" HEAD 2>/dev/null | tail -1 | grep -oE '[0-9]+ files?' | grep -oE '[0-9]+' || echo "0")

    echo "commits:$commits"
    echo "authors:$authors"
    echo "files_changed:$files_changed"
}

# Generate Markdown report
generate_markdown() {
    cat << EOF
# Sprint Report: $SPRINT_NAME

**Period:** $START_DATE to $END_DATE
**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

---

## Summary

| Metric | Count |
|--------|-------|
| Total Tickets | $((${status_counts[backlog]} + ${status_counts[todo]} + ${status_counts[in_progress]} + ${status_counts[review]} + ${status_counts[done]} + ${status_counts[blocked]})) |
| Completed | ${status_counts[done]} |
| In Progress | ${status_counts[in_progress]} |
| Blocked | ${status_counts[blocked]} |

## Status Distribution

| Status | Count |
|--------|-------|
| Backlog | ${status_counts[backlog]} |
| Todo | ${status_counts[todo]} |
| In Progress | ${status_counts[in_progress]} |
| Review | ${status_counts[review]} |
| Done | ${status_counts[done]} |
| Blocked | ${status_counts[blocked]} |

## Priority Distribution

| Priority | Count |
|----------|-------|
| Critical | ${priority_counts[critical]} |
| High | ${priority_counts[high]} |
| Medium | ${priority_counts[medium]} |
| Low | ${priority_counts[low]} |

## Completed This Sprint

EOF

    if [[ ${#completed_tickets[@]} -gt 0 ]]; then
        for ticket in "${completed_tickets[@]}"; do
            echo "- $ticket"
        done
    else
        echo "_No tickets completed_"
    fi

    cat << EOF

## Currently In Progress

EOF

    if [[ ${#in_progress_tickets[@]} -gt 0 ]]; then
        for ticket in "${in_progress_tickets[@]}"; do
            echo "- $ticket"
        done
    else
        echo "_No tickets in progress_"
    fi

    cat << EOF

## Blocked

EOF

    if [[ ${#blocked_tickets[@]} -gt 0 ]]; then
        for ticket in "${blocked_tickets[@]}"; do
            echo "- ⚠️ $ticket"
        done
    else
        echo "_No blocked tickets_"
    fi

    cat << EOF

## Team Activity

| Assignee | Tickets |
|----------|---------|
EOF

    for assignee in "${!assignee_work[@]}"; do
        echo "| $assignee | ${assignee_work[$assignee]} |"
    done

    cat << EOF

## Git Activity

EOF

    while IFS=: read -r key value; do
        case "$key" in
            commits) echo "- **Commits:** $value" ;;
            authors) echo "- **Active Contributors:** $value" ;;
            files_changed) echo "- **Files Changed:** $value" ;;
        esac
    done < <(git_stats)

    cat << EOF

---

## Notes

_Add sprint retrospective notes here_

### What went well

-

### What could be improved

-

### Action items

-

---

_Generated by KALLAX Sprint Report Generator_
EOF
}

# Generate JSON report
generate_json() {
    cat << EOF
{
  "sprint": "$SPRINT_NAME",
  "period": {
    "start": "$START_DATE",
    "end": "$END_DATE"
  },
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "summary": {
    "total": $((${status_counts[backlog]} + ${status_counts[todo]} + ${status_counts[in_progress]} + ${status_counts[review]} + ${status_counts[done]} + ${status_counts[blocked]})),
    "completed": ${status_counts[done]},
    "in_progress": ${status_counts[in_progress]},
    "blocked": ${status_counts[blocked]}
  },
  "status_distribution": {
    "backlog": ${status_counts[backlog]},
    "todo": ${status_counts[todo]},
    "in_progress": ${status_counts[in_progress]},
    "review": ${status_counts[review]},
    "done": ${status_counts[done]},
    "blocked": ${status_counts[blocked]}
  },
  "priority_distribution": {
    "critical": ${priority_counts[critical]},
    "high": ${priority_counts[high]},
    "medium": ${priority_counts[medium]},
    "low": ${priority_counts[low]}
  }
}
EOF
}

# Generate HTML report
generate_html() {
    cat << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sprint Report: $SPRINT_NAME</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f5f5f5; }
        .status-done { color: #28a745; }
        .status-blocked { color: #dc3545; }
        .status-progress { color: #ffc107; }
        .metric-card { display: inline-block; padding: 15px; margin: 5px; background: #f8f9fa; border-radius: 8px; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; color: #007bff; }
        .metric-label { color: #666; }
    </style>
</head>
<body>
    <h1>Sprint Report: $SPRINT_NAME</h1>
    <p><strong>Period:</strong> $START_DATE to $END_DATE</p>

    <div class="metrics">
        <div class="metric-card">
            <div class="metric-value">${status_counts[done]}</div>
            <div class="metric-label">Completed</div>
        </div>
        <div class="metric-card">
            <div class="metric-value">${status_counts[in_progress]}</div>
            <div class="metric-label">In Progress</div>
        </div>
        <div class="metric-card">
            <div class="metric-value">${status_counts[blocked]}</div>
            <div class="metric-label">Blocked</div>
        </div>
    </div>

    <h2>Status Distribution</h2>
    <table>
        <tr><th>Status</th><th>Count</th></tr>
        <tr><td>Backlog</td><td>${status_counts[backlog]}</td></tr>
        <tr><td>Todo</td><td>${status_counts[todo]}</td></tr>
        <tr><td class="status-progress">In Progress</td><td>${status_counts[in_progress]}</td></tr>
        <tr><td>Review</td><td>${status_counts[review]}</td></tr>
        <tr><td class="status-done">Done</td><td>${status_counts[done]}</td></tr>
        <tr><td class="status-blocked">Blocked</td><td>${status_counts[blocked]}</td></tr>
    </table>

    <footer style="margin-top: 40px; color: #999; font-size: 0.9em;">
        Generated by KALLAX Sprint Report Generator
    </footer>
</body>
</html>
EOF
}

# Generate report
case "$FORMAT" in
    md|markdown) report=$(generate_markdown) ;;
    json) report=$(generate_json) ;;
    html) report=$(generate_html) ;;
    *)
        echo "Unknown format: $FORMAT"
        exit 1
        ;;
esac

# Output
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$report" > "$OUTPUT_FILE"
    echo "Report saved to: $OUTPUT_FILE"
else
    echo "$report"
fi

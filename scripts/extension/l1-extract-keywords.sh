#!/usr/bin/env bash
#
# l1-extract-keywords.sh — Extract trigger keywords from EPIC-016/021 tickets
# Usage: l1-extract-keywords.sh --epic EPIC-016 [--output <path>]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

EPIC=""
OUTPUT_FILE=""

# Expert trigger keywords from INDEX.md (symptom-based)
BACKEND_KWS="接口响应慢 列表加载 卡顿 查询 数据库 后端 服务端 API 接口慢 响应慢"
FRONTEND_KWS="页面卡顿 组件错位 前端 UI 界面卡 加载慢 渲染 样式布局"
ARCHITECT_KWS="架构选型 模块边界 抽象层 设计 结构 重构 架构争议"
PRODUCT_KWS="优先级 功能该不该做 砍哪个 产品 决策"
UX_KWS="界面操作 文案 按钮找不到 UX 用户体验 交互流失"

usage() {
    cat <<EOF
Usage: $(basename "$0") --epic EPIC-XXX [--output <path>]

Options:
  --epic EPIC-XXX EPIC to process (e.g., EPIC-016, EPIC-021)
  --output <path>    Output JSON file path (default: .kallax/data/expansion/l1-baseline-data.json)
  -h, --help         Show this help
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --epic)
            EPIC="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

[[ -z "$EPIC" ]] && { echo "ERROR: --epic required" >&2; usage; }

if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="$PROJECT_DIR/.kallax/data/expansion/l1-baseline-data.json"
fi

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

extract_keywords_from_text() {
    local text="$1"
    local expert_kws="$2"
    local result=""

    # Convert to lowercase for case-insensitive matching
    local text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    for kw in $expert_kws; do
        local kw_lower=$(echo "$kw" | tr '[:upper:]' '[:lower:]')
        if echo "$text_lower" | grep -q "$kw_lower"; then
            result="$result $kw"
        fi
    done

    echo "$result" | awk '{for(i=1;i<=NF;i++) if(!seen[$i]++) printf "%s ", $i; print ""}' | sed 's/ $//'
}

resolve_expert() {
    local text="$1"
    local text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    # Backend indicators
    if echo "$text_lower" | grep -qE "(接口|响应慢|查询|数据库|后端|api|服务端)"; then
        echo "backend"
        return
    fi

    # Frontend indicators
    if echo "$text_lower" | grep -qE "(页面|组件|前端|ui|渲染|样式|布局)"; then
        echo "frontend"
        return
    fi

    # Architect indicators
    if echo "$text_lower" | grep -qE "(架构|模块|抽象|设计|结构|重构)"; then
        echo "architect"
        return
    fi

    # Product indicators
    if echo "$text_lower" | grep -qE "(产品|优先级|决策|功能)"; then
        echo "product"
        return
    fi

    # UX indicators
    if echo "$text_lower" | grep -qE "(界面|用户体验|交互|操作|文案|按钮)"; then
        echo "ux"
        return
    fi

    echo "unknown"
}

# Collect all tickets from EPIC-016 and EPIC-021 using arrays
declare -a ALL_TICKETS=()

for epic in EPIC-016 EPIC-021; do
    # Use nullglob to avoid literal match when no files exist
    shopt -s nullglob
    for ticket_file in "$PROJECT_DIR/jira/tickets/${epic}-"*/ticket.json; do
        if [[ -f "$ticket_file" ]]; then
            ALL_TICKETS+=("$ticket_file")
        fi
    done
    shopt -u nullglob
done

echo "INFO: Found ${#ALL_TICKETS[@]} tickets"

# Process tickets and build JSON
json_entries=()
total=${#ALL_TICKETS[@]}

for i in "${!ALL_TICKETS[@]}"; do
    ticket_file="${ALL_TICKETS[$i]}"
    ticket_id=$(basename "$(dirname "$ticket_file")")

    # Read title and description from ticket.json
    title=$(python3 -c "import json; d=json.load(open('$ticket_file')); print(d.get('title',''))" 2>/dev/null || echo "")
    description=$(python3 -c "import json; d=json.load(open('$ticket_file')); print(d.get('description',''))" 2>/dev/null || echo "")
    review_field=$(python3 -c "import json; d=json.load(open('$ticket_file')); print(d.get('review',{}).get('reviewer',''))" 2>/dev/null || echo "")

    # If no description, construct from title
    if [[ -z "$description" ]]; then
        description="$title"
    fi

    # Extract keywords for each expert
    combined_text="$title $description"

    backend_kws=$(extract_keywords_from_text "$combined_text" "$BACKEND_KWS")
    frontend_kws=$(extract_keywords_from_text "$combined_text" "$FRONTEND_KWS")
    architect_kws=$(extract_keywords_from_text "$combined_text" "$ARCHITECT_KWS")
    product_kws=$(extract_keywords_from_text "$combined_text" "$PRODUCT_KWS")
    ux_kws=$(extract_keywords_from_text "$combined_text" "$UX_KWS")

    # Resolve actual expert based on symptom keywords
    resolved=$(resolve_expert "$combined_text")

    # Read actual_expert from review field if present (ticket reviewer indicates actual expert)
    actual_expert=""
    if [[ -n "$review_field" ]]; then
        case "$review_field" in
            *backend*|*Backend*|*后端*) actual_expert="backend" ;;
            *frontend*|*Frontend*|*前端*) actual_expert="frontend" ;;
            *architect*|*Architect*|*架构*) actual_expert="architect" ;;
            *product*|*Product*|*产品*) actual_expert="product" ;;
            *ux*|*UX*|*用户体验*) actual_expert="ux" ;;
            *) actual_expert="$resolved" ;;
        esac
    else
        actual_expert="$resolved"
    fi

    # Create JSON entry using Python for proper escaping
    json_entry=$(python3 <<PYEOF
import json
entry = {
    "ticket_id": "$ticket_id",
    "expert": "$resolved",
    "title": $(python3 -c "import json; print(json.dumps('$title'))" 2>/dev/null || echo '""'),
    "description_keywords": {
        "backend": $(python3 -c "import json; print(json.dumps('$backend_kws'.strip()))" 2>/dev/null || echo '[]'),
        "frontend": $(python3 -c "import json; print(json.dumps('$frontend_kws'.strip()))" 2>/dev/null || echo '[]'),
        "architect": $(python3 -c "import json; print(json.dumps('$architect_kws'.strip()))" 2>/dev/null || echo '[]'),
        "product": $(python3 -c "import json; print(json.dumps('$product_kws'.strip()))" 2>/dev/null || echo '[]'),
        "ux": $(python3 -c "import json; print(json.dumps('$ux_kws'.strip()))" 2>/dev/null || echo '[]')
    },
    "actual_expert": "$actual_expert"
}
print(json.dumps(entry, ensure_ascii=False))
PYEOF
)

    json_entries+=("$json_entry")
    echo " [$((i+1))/$total] $ticket_id -> $resolved (actual: $actual_expert)"
done

# Write JSON array to output file
{
    echo "["
    for i in "${!json_entries[@]}"; do
        entry="${json_entries[$i]}"
        if [[ $i -eq $(( ${#json_entries[@]} - 1 )) ]]; then
            echo " $entry"
        else
            echo "  $entry,"
        fi
    done
    echo "]"
} > "$OUTPUT_FILE"

echo ""
echo "INFO: Wrote $total records to $OUTPUT_FILE"
echo "INFO: Baseline data collection complete"
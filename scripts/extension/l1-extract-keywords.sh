#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXPERT_DIR="$REPO_ROOT/.kallax/experts/default"
JIRA_DIR="$REPO_ROOT/jira/tickets"
OUT_DIR="$REPO_ROOT/.kallax/data/expansion"
OUT_FILE="$OUT_DIR/l1-baseline-data.json"

EPIC_LIST=(EPIC-016 EPIC-021)
EXPERT_LIST=(architect backend frontend ux product)
BACKEND_PATTERN='API|接口慢|数据库|SQL|缓存|后端|压测|daemon|heartbeat|cleanup|benchmark|瘦身|卡死|optimization|降级|stale|lib/daemon|expert-invocation|expert_invocations|state.json|install-hooks|queue|heartbeat-test|check-stale|conductor-session|performer-session'
FRONTEND_PATTERN='页面|组件|渲染|React|Vue|前端|FCP|LCP|白屏|web|UI'
UX_PATTERN='交互|体验|可用性|表单|按钮|UX|易用|操作步骤|用户路径'
PRODUCT_PATTERN='优先级|需求|价值|MVP|产品|roadmap|INDEX|决策树|emoji|症状'
ARCHITECT_PATTERN='架构|ADR|选型|重构|服务|skill|STRICT|ANATOMY|expert|experts/default|Fact-Forcing|output_format|anatomy|Lean|settings.local.json|kallax-init|SKILL.md|SKILL-DETAIL|REVIEW-'
ACTUAL_FRONTEND_PATTERN='页面|组件|渲染|React|Vue|前端|LCP|FCP|白屏|包体积'
ACTUAL_UX_PATTERN='交互|体验|可用性|表单|按钮|UX|易用'
ACTUAL_PRODUCT_PATTERN='优先级|需求|价值|MVP|roadmap'
ACTUAL_ARCHITECT_PATTERN='架构|边界|选型|微服务|API契约|模块耦合|技术债|扩展性|分布式|集成|治理|重构|Fact-Forcing|anatomy|expert persona|skill|分层|分众|tier'

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }

classify() {
    local haystack="$1"
    if [[ "$haystack" =~ $BACKEND_PATTERN ]]; then
        echo "backend"
    elif [[ "$haystack" =~ $FRONTEND_PATTERN ]]; then
        echo "frontend"
    elif [[ "$haystack" =~ $UX_PATTERN ]]; then
        echo "ux"
    elif [[ "$haystack" =~ $PRODUCT_PATTERN ]]; then
        echo "product"
    else
        echo "architect"
    fi
}

parse_trigger() {
    awk '
        /^trigger:[[:space:]]*/ { sub(/^trigger:[[:space:]]*/, ""); printf "%s", $0; flag=1; next }
        flag && /^[a-zA-Z_]+:[[:space:]]/ { exit }
        flag && NF { printf ",%s", $0 }
    ' "$EXPERT_DIR/$1.md"
}

infer_actual_expert() {
    local review_json="$1"
    if [[ -z "$review_json" || "$review_json" == "{}" ]]; then
        echo "null"
        return
    fi
    local b_group a_group
    b_group=$(printf '%s' "$review_json" | jq -r '.b_group_findings // ""')
    a_group=$(printf '%s' "$review_json" | jq -r '.a_group_findings // ""')
    local combined="$b_group $a_group"
    if [[ "$combined" =~ $ACTUAL_FRONTEND_PATTERN ]]; then
        echo "frontend"
    elif [[ "$combined" =~ $ACTUAL_UX_PATTERN ]]; then
        echo "ux"
    elif [[ "$combined" =~ $ACTUAL_PRODUCT_PATTERN ]]; then
        echo "product"
    elif [[ "$combined" =~ $ACTUAL_ARCHITECT_PATTERN ]]; then
        echo "architect"
    elif [[ -n "$b_group" || -n "$a_group" ]]; then
        echo "backend"
    else
        echo "null"
    fi
}

build_record() {
    local ticket_json="$1"
    local id title desc files expert keywords actual_expert review_json
    id=$(jq -r '.id' "$ticket_json")
    title=$(jq -r '.title' "$ticket_json")
    desc=$(jq -r '[(.acceptance_criteria // [] | .[]), (.notes // "" | select(. != ""))] | join(" | ")' "$ticket_json")
    files=$(jq -r '.file_scope.includes // [] | join(" ")' "$ticket_json")
    expert=$(classify "$title $files")
    keywords=$(parse_trigger "$expert")
    review_json=$(jq -c '.review // {}' "$ticket_json")
    actual_expert=$(infer_actual_expert "$review_json")
    jq -n \
        --arg id "$id" \
        --arg expert "$expert" \
        --arg title "$title" \
        --arg desc "$desc" \
        --arg actual "$actual_expert" \
        --arg kws "$keywords" \
        '{
            ticket_id: $id,
            expert: $expert,
            keywords: ($kws | split(",") | map(select(. != ""))),
            title: $title,
            description: $desc,
            actual_expert: (if $actual == "null" then null else $actual end)
        }'
}

main() {
    mkdir -p "$OUT_DIR"
    local records=()
    local total=0
    for ep in "${EPIC_LIST[@]}"; do
        for tdir in "$JIRA_DIR"/${ep}-*/; do
            [[ -d "$tdir" ]] || continue
            local ticket_json="$tdir/ticket.json"
            [[ -f "$ticket_json" ]] || continue
            local rec
            rec=$(build_record "$ticket_json")
            records+=("$rec")
            total=$((total + 1))
        done
    done
    local records_json
    records_json=$(printf '%s\n' "${records[@]}" | jq -s '.')
    jq -n --argjson recs "$records_json" '$recs' > "$OUT_FILE"
    log "Extracted $total records to $OUT_FILE"
    jq -e 'length > 0' "$OUT_FILE" >/dev/null
}

main "$@"

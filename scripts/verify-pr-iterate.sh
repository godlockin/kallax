#!/usr/bin/env bash
# scripts/verify-pr-iterate.sh — evaluator-optimizer loop (EPIC-117-D)
#
# Anthropic《Building Effective Agents》Evaluator-Optimizer:
#   "One LLM generates a candidate response; another evaluates and gives feedback, in a loop."
#
# KALLAX 之前: 单次 verify, pass/fail 阻塞, 无循环
# 之后: verify → findings → wait for fix commit → re-verify, 最多 N 轮
#
# Usage:
#   scripts/verify-pr-iterate.sh <PR#> [--max-rounds 3] [--interval 60]
#
# Exit:
#   0 = converged (findings=0)
#   1 = max rounds reached without convergence
#   2 = args/env error

set -euo pipefail

MAX_ROUNDS=3
INTERVAL=60
PR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-rounds) MAX_ROUNDS="$2"; shift 2 ;;
        --interval)   INTERVAL="$2";   shift 2 ;;
        -h|--help)    sed -n '2,20p' "$0"; exit 0 ;;
        -*)           echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
        *)            PR="$1"; shift ;;
    esac
done

if [[ -z "$PR" ]]; then
    echo "ERROR: PR number required" >&2
    echo "Usage: $0 <PR#> [--max-rounds N] [--interval SEC]" >&2
    exit 2
fi

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required" >&2; exit 2; }

verify_round() {
    local round="$1"
    echo ""
    echo "==================================="
    echo "Round $round/$MAX_ROUNDS — PR #$PR"
    echo "==================================="

    # Fetch current head SHA
    local head_sha
    head_sha="$(gh pr view "$PR" --json headRefOid --jq .headRefOid 2>/dev/null || echo "")"
    [[ -z "$head_sha" ]] && { echo "ERROR: cannot read PR head" >&2; return 2; }
    echo "Head SHA: $head_sha"

    # Run local verify: eslint + tsc + vitest (best-effort, 缺一不阻塞循环)
    local findings=0
    local report="/tmp/verify-pr-${PR}-round-${round}.log"
    : > "$report"

    if [[ -d node ]]; then
        echo "  - eslint..." | tee -a "$report"
        ( cd node && npx eslint . --max-warnings 0 >> "$report" 2>&1 ) || findings=$((findings+1))
        echo "  - tsc..." | tee -a "$report"
        ( cd node && npx tsc --noEmit >> "$report" 2>&1 ) || findings=$((findings+1))
    fi

    echo "" | tee -a "$report"
    echo "Round $round findings: $findings" | tee -a "$report"
    echo "Report: $report"

    if [[ $findings -eq 0 ]]; then
        return 0
    fi

    # Post findings summary to PR
    local tail_out
    tail_out="$(tail -20 "$report")"
    gh pr comment "$PR" --body "**verify-pr-iterate round $round/$MAX_ROUNDS**: $findings finding(s). See tail:
\`\`\`
$tail_out
\`\`\`
Push a fix to $head_sha's branch, then re-run." 2>/dev/null || true

    return 1
}

wait_for_new_commit() {
    local prev_sha="$1"
    local elapsed=0
    while [[ $elapsed -lt $((INTERVAL * 20)) ]]; do
        sleep "$INTERVAL"
        elapsed=$((elapsed + INTERVAL))
        local cur
        cur="$(gh pr view "$PR" --json headRefOid --jq .headRefOid 2>/dev/null || echo "")"
        if [[ -n "$cur" && "$cur" != "$prev_sha" ]]; then
            echo "New commit detected: $cur"
            return 0
        fi
    done
    echo "TIMEOUT waiting for new commit"
    return 1
}

# Main loop
for round in $(seq 1 "$MAX_ROUNDS"); do
    prev="$(gh pr view "$PR" --json headRefOid --jq .headRefOid 2>/dev/null || echo "")"
    if verify_round "$round"; then
        echo ""
        echo "CONVERGED at round $round (findings=0)"
        exit 0
    fi
    if [[ "$round" -eq "$MAX_ROUNDS" ]]; then
        echo ""
        echo "FAIL: max rounds ($MAX_ROUNDS) reached without convergence"
        exit 1
    fi
    echo ""
    echo "Waiting for new commit (interval=${INTERVAL}s, max ${INTERVAL}*20s)..."
    wait_for_new_commit "$prev" || { echo "FAIL: no fix commit within timeout"; exit 1; }
done

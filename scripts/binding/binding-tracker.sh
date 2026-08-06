#!/usr/bin/env bash
# scripts/binding/binding-tracker.sh — EPIC-157 ticket.json expert binding tracker
#
# 用法:
#   binding-tracker.sh suggest <ticket-id> --expert <name>     # Master 拆卡时建议
#   binding-tracker.sh actual <ticket-id> --expert <name> [--reason <text>]  # Performer binding
#   binding-tracker.sh validate <ticket-id>                    # 校验 4 字段 + 一致性
#   binding-tracker.sh validate-all [--dir <jira/tickets>]     # 批量校验 (历史 ticket 跳过)
#   binding-tracker.sh report [--epic <EPIC-XXX>]               # 出一致率报告 (mis_dispatch_rate)
#
# Exit codes: 0=PASS, 1=FAIL, 2=用户错误
# 依赖: jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TICKETS_DIR="${KALLAX_BINDING_TICKETS_DIR:-${KALLAX_TICKETS_DIR:-${KALLAX_ROOT}/jira/tickets}}"

# shellcheck source=lib/expert-pool.sh
source "${SCRIPT_DIR}/lib/expert-pool.sh"
# shellcheck source=lib/ticket-utils.sh
source "${SCRIPT_DIR}/lib/ticket-utils.sh"

cmd_suggest() {
  local ticket_id="${1:-}"
  shift || true
  local expert=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --expert) expert="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ -z "$ticket_id" ] || [ -z "$expert" ]; then
    echo "Usage: binding-tracker.sh suggest <ticket-id> --expert <name>" >&2
    return 2
  fi
  if ! is_allowed_expert "$expert"; then
    echo "FAIL: expert '$expert' not in ExpertPool (allowed: ${ALLOWED_EXPERTS[*]} or custom:<name>)" >&2
    return 1
  fi
  local file
  if ! file="$(find_ticket_file "$ticket_id")"; then
    echo "FAIL: ticket '$ticket_id' not found in $TICKETS_DIR" >&2
    return 2
  fi
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp; tmp="$(mktemp)"
  jq --arg expert "$expert" --arg ts "$ts" \
     '.expert_binding //= {} | .expert_binding.suggested_expert = $expert | .expert_binding.expert_binding_at = (.expert_binding.expert_binding_at // $ts)' \
     "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "OK suggested_expert='$expert' written to $file"
  return 0
}

cmd_actual() {
  local ticket_id="${1:-}"
  shift || true
  local expert="" reason=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --expert) expert="${2:-}"; shift 2 ;;
      --reason) reason="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ -z "$ticket_id" ] || [ -z "$expert" ]; then
    echo "Usage: binding-tracker.sh actual <ticket-id> --expert <name> [--reason <text>]" >&2
    return 2
  fi
  if ! is_allowed_expert "$expert"; then
    echo "FAIL: expert '$expert' not in ExpertPool" >&2
    return 1
  fi
  local file
  if ! file="$(find_ticket_file "$ticket_id")"; then
    echo "FAIL: ticket '$ticket_id' not found" >&2
    return 2
  fi
  local suggested=""
  suggested="$(jq -r '.expert_binding.suggested_expert // empty' "$file" 2>/dev/null || echo "")"
  if [ -n "$suggested" ] && [ "$suggested" != "$expert" ] && [ -z "$reason" ]; then
    echo "FAIL: actual_expert='$expert' differs from suggested_expert='$suggested'. --reason required." >&2
    return 1
  fi
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp; tmp="$(mktemp)"
  jq --arg expert "$expert" --arg ts "$ts" --arg reason "$reason" \
     '.expert_binding //= {} | .expert_binding.actual_expert = $expert | .expert_binding.expert_binding_at = $ts | (if $reason != "" then .expert_binding.binding_change_reason = $reason else . end)' \
     "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "OK actual_expert='$expert' written to $file"
  if [ -n "$reason" ]; then echo "  reason: $reason"; fi

  # EPIC-177-G: emit accounting event for actual binding
  local run_history="${SCRIPT_DIR}/../heartbeat/run-history.sh"
  if [ -f "$run_history" ]; then
    local payload
    payload=$(jq -cn --arg suggested "$suggested" --arg actual "$expert" \
      '{suggested_expert: $suggested, actual_expert: $actual, action: "actual_binding"}')
    "$run_history" emit accounting "$ticket_id" "$payload" >/dev/null 2>&1
  fi

  return 0
}

cmd_validate() {
  local ticket_id="${1:-}"
  if [ -z "$ticket_id" ]; then
    echo "Usage: binding-tracker.sh validate <ticket-id>" >&2
    return 2
  fi
  local file
  if ! file="$(find_ticket_file "$ticket_id")"; then
    echo "FAIL: ticket '$ticket_id' not found" >&2
    return 2
  fi
  local has_binding; has_binding="$(jq 'has("expert_binding")' "$file")"
  if [ "$has_binding" = "false" ]; then
    echo "OK legacy-no-binding: $ticket_id (skipped)"; return 0
  fi
  local errors=()
  local suggested actual reason binding_at
  suggested="$(jq -r '.expert_binding.suggested_expert // empty' "$file")"
  actual="$(jq -r '.expert_binding.actual_expert // empty' "$file")"
  reason="$(jq -r '.expert_binding.binding_change_reason // empty' "$file")"
  binding_at="$(jq -r '.expert_binding.expert_binding_at // empty' "$file")"
  [ -z "$actual" ] && errors+=("actual_expert missing (Performer 必填)")
  { [ -n "$actual" ] && [ -z "$binding_at" ]; } && errors+=("expert_binding_at missing")
  { [ -n "$suggested" ] && [ -n "$actual" ] && [ "$suggested" != "$actual" ] && [ -z "$reason" ]; } && \
    errors+=("binding_change_reason missing (actual '$actual' differs from suggested '$suggested')")
  [ -n "$suggested" ] && ! is_allowed_expert "$suggested" && errors+=("suggested_expert '$suggested' not in ExpertPool")
  [ -n "$actual" ] && ! is_allowed_expert "$actual" && errors+=("actual_expert '$actual' not in ExpertPool")
  # EPIC-177-G: emit accounting event for validation status (valid OR invalid)
  local run_history="${SCRIPT_DIR}/../heartbeat/run-history.sh"
  if [ -f "$run_history" ]; then
    local is_valid=1
    [ ${#errors[@]} -gt 0 ] && is_valid=0
    local payload
    payload=$(jq -cn --argjson is_valid "$is_valid" \
      '{validation_status: (if $is_valid == 1 then "valid" else "invalid" end), error_count: (if $is_valid == 1 then 0 else 1 end)}')
    "$run_history" emit accounting "$ticket_id" "$payload" >/dev/null 2>&1
  fi

  if [ ${#errors[@]} -eq 0 ]; then
    return 0
  fi
  return 1
}

cmd_validate_all() {
  local target_dir="$TICKETS_DIR"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) target_dir="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -d "$target_dir" ] || { echo "FAIL: dir '$target_dir' not found" >&2; return 2; }
  local total=0 passed=0 failed=0 skipped=0
  local failed_files=()
  while IFS= read -r -d '' file; do
    total=$((total + 1))
    local ticket_id; ticket_id="$(jq -r '.ticket_id // .id // empty' "$file" 2>/dev/null || true)"
    if [ -z "$ticket_id" ]; then skipped=$((skipped + 1)); continue; fi
    if cmd_validate "$ticket_id" > /tmp/binding-validate.$$ 2>&1; then
      passed=$((passed + 1))
    else
      grep -q "legacy-no-binding" /tmp/binding-validate.$$ \
        && skipped=$((skipped + 1)) \
        || { failed=$((failed + 1)); failed_files+=("$ticket_id"); }
    fi
    rm -f /tmp/binding-validate.$$
  done < <(find "$target_dir" -mindepth 2 -maxdepth 2 -name "ticket.json" -print0 2>/dev/null)
  echo "================================================"
  echo "Binding Validation Summary"
  echo "================================================"
  echo "Total tickets: $total"
  echo "Passed:        $passed"
  echo "Failed:        $failed"
  echo "Skipped:       $skipped (legacy-no-binding)"
  echo "================================================"
  [ $failed -gt 0 ] && { echo "FAILED tickets:"; for f in "${failed_files[@]}"; do echo "  - $f"; done; }

  # EPIC-177-G: emit decision event for validation-all complete (always)
  local run_history="${SCRIPT_DIR}/../heartbeat/run-history.sh"
  if [ -f "$run_history" ]; then
    local payload
    payload=$(jq -cn \
      --argjson total "$total" \
      --argjson passed "$passed" \
      --argjson failed "$failed" \
      --argjson skipped "$skipped" \
      '{validation_all_complete: true, total: $total, passed: $passed, failed: $failed, skipped: $skipped}')
    "$run_history" emit decision "binding-tracker" "$payload" >/dev/null 2>&1
  fi

  [ $failed -gt 0 ] && return 1
  return 0
}

cmd_report() {
  local epic="" target_dir="$TICKETS_DIR"
  while [ $# -gt 0 ]; do
    case "$1" in
      --epic) epic="${2:-}"; shift 2 ;;
      --dir) target_dir="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done
  local total=0 with_binding=0 consistent=0 divergent=0 divergent_no_reason=0 mis_dispatch=0 parse_errors=0
  while IFS= read -r -d '' file; do
    local ticket_id; ticket_id="$(jq -r '.ticket_id // .id // empty' "$file" 2>/dev/null || true)"
    if [ -z "$ticket_id" ]; then parse_errors=$((parse_errors + 1)); continue; fi
    [ -n "$epic" ] && [[ "$ticket_id" != ${epic}* ]] && continue
    local has_binding; has_binding="$(jq 'has("expert_binding")' "$file" 2>/dev/null || echo "false")"
    [ "$has_binding" = "false" ] && continue
    total=$((total + 1)); with_binding=$((with_binding + 1))
    local suggested actual reason
    suggested="$(jq -r '.expert_binding.suggested_expert // empty' "$file" 2>/dev/null || echo "")"
    actual="$(jq -r '.expert_binding.actual_expert // empty' "$file" 2>/dev/null || echo "")"
    reason="$(jq -r '.expert_binding.binding_change_reason // empty' "$file" 2>/dev/null || echo "")"
    if [ -n "$suggested" ] && [ -n "$actual" ]; then
      if [ "$suggested" = "$actual" ]; then
        consistent=$((consistent + 1))
      else
        divergent=$((divergent + 1))
        [ -z "$reason" ] && divergent_no_reason=$((divergent_no_reason + 1))
        local s_prefix="${suggested%%-*}"; local a_prefix="${actual%%-*}"
        if [ "$s_prefix" != "$a_prefix" ] && [ "$s_prefix" != "custom" ] && [ "$a_prefix" != "custom" ]; then
          mis_dispatch=$((mis_dispatch + 1))
        fi
      fi
    fi
  done < <(find "$target_dir" -mindepth 2 -maxdepth 2 -name "ticket.json" -print0 2>/dev/null)
  echo "================================================"
  echo "Expert Binding Report"
  [ -n "$epic" ] && echo "Scope: $epic" || echo "Scope: all tickets"
  echo "================================================"
  echo "Tickets with binding:        $with_binding"
  echo "Consistent (suggested=actual): $consistent"
  echo "Divergent:                     $divergent"
  echo "  - without change_reason:     $divergent_no_reason"
  echo "  - cross-specialization:      $mis_dispatch"
  [ $parse_errors -gt 0 ] && echo "Parse errors (skipped):       $parse_errors (pre-existing JSON drift, NOT EPIC-157)"
  if [ $with_binding -gt 0 ]; then
    local rate_pct
    rate_pct=$(awk -v m="$mis_dispatch" -v t="$with_binding" 'BEGIN { if (t>0) printf "%.1f", (m/t)*100; else print "0.0" }')
    echo "mis_dispatch_rate: $rate_pct% (target <10%)"
  fi
  echo "================================================"
  return 0
}

cmd="${1:-}"
shift || true
case "$cmd" in
  suggest)        cmd_suggest "$@" ;;
  actual)         cmd_actual "$@" ;;
  validate)       cmd_validate "$@" ;;
  validate-all)   cmd_validate_all "$@" ;;
  report)         cmd_report "$@" ;;
  -h|--help|help|"")
    cat <<EOF
binding-tracker.sh — EPIC-157 ticket.json expert binding tracker

Usage:
  binding-tracker.sh suggest <ticket-id> --expert <name>
  binding-tracker.sh actual <ticket-id> --expert <name> [--reason <text>]
  binding-tracker.sh validate <ticket-id>
  binding-tracker.sh validate-all [--dir <path>]
  binding-tracker.sh report [--epic <EPIC-XXX>]
EOF
    exit 2 ;;
  *) echo "Unknown sub-command: $cmd" >&2; exit 2 ;;
esac
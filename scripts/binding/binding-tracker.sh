#!/usr/bin/env bash
# scripts/binding/binding-tracker.sh — EPIC-157 ticket.json expert binding tracker
#
# 用法 (sub-command 模式):
#   binding-tracker.sh suggest <ticket-id> --expert <name>     # Master 拆卡时建议
#   binding-tracker.sh actual <ticket-id> --expert <name> [--reason <text>]  # Performer binding
#   binding-tracker.sh validate <ticket-id>                    # 校验 4 字段 + 一致性
#   binding-tracker.sh validate-all [--dir <jira/tickets>]     # 批量校验 (历史 ticket 跳过)
#   binding-tracker.sh report [--epic <EPIC-XXX>]               # 出一致率报告 (mis_dispatch_rate)
#
# 设计:
# - 4 字段独立于 sqlite 内部 Ticket, 直接读写 jira/tickets/<EPIC>/ticket.json
# - 向后兼容: 历史 ticket (无 expert_binding 字段) 跳过校验
# - Performer 改 actual_expert 时, 若跟 suggested_expert 不同 → 必填 --reason
# - Master 拍板 recommended 改动
#
# Exit codes:
#   0 = PASS / 写入成功
#   1 = FAIL (校验失败 / 字段缺失 / 偏离无 reason)
#   2 = 用户错误 (参数缺 / ticket 不存在)
#
# 依赖: jq (读写 JSON)
# 可选: yq (YAML, 当前未用)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Allow override via env (for tests / CI / other consumers)
TICKETS_DIR="${KALLAX_BINDING_TICKETS_DIR:-${KALLAX_TICKETS_DIR:-${KALLAX_ROOT}/jira/tickets}}"

# Expert pool (跟 node/src/core/schema-validator.ts ExpertPool 字段保持 1:1)
# 4 default + 5 extended + 15 local
ALLOWED_EXPERTS=(
  backend frontend ux product
  security-tool-bypass process-engineering-self-verify
  auditor-independent-witness compliance-rule-merge
  decision-gate-complex-only
  architect sre devops security performance
  database aiml mlops data-analyst tester
  reviewer docs-writer tech-lead conductor master
)

is_allowed_expert() {
  local name="$1"
  for e in "${ALLOWED_EXPERTS[@]}"; do
    if [ "$e" = "$name" ]; then
      return 0
    fi
  done
  # 接受 custom:<name> 自定义命名空间
  case "$name" in
    custom:*) return 0 ;;
  esac
  return 1
}

find_ticket_file() {
  local ticket_id="$1"
  # ticket_id 形如 EPIC-157 或 EPIC-157-A
  local prefix="${ticket_id%%-*}"  # EPIC
  # 找 ticket.json 在 jira/tickets/<EPIC-XXX>/ 或 jira/tickets/<EPIC-XXX-A>/
  local found=""
  for d in "$TICKETS_DIR/${ticket_id}" "$TICKETS_DIR/${prefix}"; do
    if [ -d "$d" ] && [ -f "$d/ticket.json" ]; then
      found="$d/ticket.json"
      break
    fi
    # 也支持 sub-ticket: jira/tickets/EPIC-XXX-A/ticket.json
    if [ -d "$TICKETS_DIR/${ticket_id}-A" ] && [ -f "$TICKETS_DIR/${ticket_id}-A/ticket.json" ]; then
      found="$TICKETS_DIR/${ticket_id}-A/ticket.json"
      break
    fi
  done
  if [ -z "$found" ]; then
    return 1
  fi
  echo "$found"
}

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
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # 原子写入: tmp + jq update + mv
  local tmp
  tmp="$(mktemp)"
  jq --arg expert "$expert" \
     --arg ts "$ts" \
     '.expert_binding //= {} | .expert_binding.suggested_expert = $expert | .expert_binding.expert_binding_at = (.expert_binding.expert_binding_at // $ts)' \
     "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "OK suggested_expert='$expert' written to $file"
  return 0
}

cmd_actual() {
  local ticket_id="${1:-}"
  shift || true
  local expert=""
  local reason=""
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
  # 读 suggested_expert, 偏离时强制 reason
  local suggested=""
  suggested="$(jq -r '.expert_binding.suggested_expert // empty' "$file" 2>/dev/null || echo "")"
  if [ -n "$suggested" ] && [ "$suggested" != "$expert" ] && [ -z "$reason" ]; then
    echo "FAIL: actual_expert='$expert' differs from suggested_expert='$suggested'. --reason required." >&2
    return 1
  fi
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp
  tmp="$(mktemp)"
  jq --arg expert "$expert" \
     --arg ts "$ts" \
     --arg reason "$reason" \
     '.expert_binding //= {} | .expert_binding.actual_expert = $expert | .expert_binding.expert_binding_at = $ts | (if $reason != "" then .expert_binding.binding_change_reason = $reason else . end)' \
     "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "OK actual_expert='$expert' written to $file"
  if [ -n "$reason" ]; then
    echo "  reason: $reason"
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
  # 历史 ticket (无 expert_binding) → 跳过, exit 0
  local has_binding
  has_binding="$(jq 'has("expert_binding")' "$file")"
  if [ "$has_binding" = "false" ]; then
    echo "OK legacy-no-binding: $ticket_id (skipped)"
    return 0
  fi
  local errors=()
  local suggested actual
  suggested="$(jq -r '.expert_binding.suggested_expert // empty' "$file")"
  actual="$(jq -r '.expert_binding.actual_expert // empty' "$file")"
  local reason
  reason="$(jq -r '.expert_binding.binding_change_reason // empty' "$file")"
  # 校验 actual_expert 必填
  if [ -z "$actual" ]; then
    errors+=("actual_expert missing (Performer 必填)")
  fi
  # 校验 expert_binding_at 必填 (actual 填了时)
  local binding_at
  binding_at="$(jq -r '.expert_binding.expert_binding_at // empty' "$file")"
  if [ -n "$actual" ] && [ -z "$binding_at" ]; then
    errors+=("expert_binding_at missing (claim 时必填)")
  fi
  # 校验偏离时 reason 必填
  if [ -n "$suggested" ] && [ -n "$actual" ] && [ "$suggested" != "$actual" ] && [ -z "$reason" ]; then
    errors+=("binding_change_reason missing (actual '$actual' differs from suggested '$suggested')")
  fi
  # 校验 expert pool 合法性
  if [ -n "$suggested" ] && ! is_allowed_expert "$suggested"; then
    errors+=("suggested_expert '$suggested' not in ExpertPool")
  fi
  if [ -n "$actual" ] && ! is_allowed_expert "$actual"; then
    errors+=("actual_expert '$actual' not in ExpertPool")
  fi
  if [ ${#errors[@]} -eq 0 ]; then
    echo "OK binding valid: $ticket_id (suggested=$suggested actual=$actual)"
    return 0
  fi
  echo "FAIL binding invalid: $ticket_id"
  for e in "${errors[@]}"; do
    echo "  - $e"
  done
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
  if [ ! -d "$target_dir" ]; then
    echo "FAIL: dir '$target_dir' not found" >&2
    return 2
  fi
  local total=0
  local passed=0
  local failed=0
  local skipped=0
  local failed_files=()
  while IFS= read -r -d '' file; do
    total=$((total + 1))
    local ticket_id
    ticket_id="$(jq -r '.ticket_id // .id // empty' "$file")"
    if [ -z "$ticket_id" ]; then
      skipped=$((skipped + 1))
      continue
    fi
    if cmd_validate "$ticket_id" > /tmp/binding-validate.$$ 2>&1; then
      passed=$((passed + 1))
    else
      local exit_code=$?
      if grep -q "legacy-no-binding" /tmp/binding-validate.$$; then
        skipped=$((skipped + 1))
      else
        failed=$((failed + 1))
        failed_files+=("$ticket_id")
      fi
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
  if [ $failed -gt 0 ]; then
    echo "FAILED tickets:"
    for f in "${failed_files[@]}"; do
      echo "  - $f"
    done
    return 1
  fi
  return 0
}

cmd_report() {
  local epic=""
  local target_dir="$TICKETS_DIR"
  while [ $# -gt 0 ]; do
    case "$1" in
      --epic) epic="${2:-}"; shift 2 ;;
      --dir) target_dir="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done
  local total=0
  local with_binding=0
  local consistent=0
  local divergent=0
  local divergent_no_reason=0
  local mis_dispatch=0  # 偏离 specialization
  local parse_errors=0
  local epic_filter=""
  if [ -n "$epic" ]; then
    epic_filter="$epic"
  fi
  while IFS= read -r -d '' file; do
    local ticket_id
    ticket_id="$(jq -r '.ticket_id // .id // empty' "$file" 2>/dev/null || true)"
    if [ -z "$ticket_id" ]; then
      parse_errors=$((parse_errors + 1))
      continue
    fi
    if [ -n "$epic_filter" ] && [[ "$ticket_id" != ${epic_filter}* ]]; then
      continue
    fi
    local has_binding
    has_binding="$(jq 'has("expert_binding")' "$file" 2>/dev/null || echo "false")"
    if [ "$has_binding" = "false" ]; then
      continue
    fi
    total=$((total + 1))
    with_binding=$((with_binding + 1))
    local suggested actual reason
    suggested="$(jq -r '.expert_binding.suggested_expert // empty' "$file" 2>/dev/null || echo "")"
    actual="$(jq -r '.expert_binding.actual_expert // empty' "$file" 2>/dev/null || echo "")"
    reason="$(jq -r '.expert_binding.binding_change_reason // empty' "$file" 2>/dev/null || echo "")"
    if [ -n "$suggested" ] && [ -n "$actual" ]; then
      if [ "$suggested" = "$actual" ]; then
        consistent=$((consistent + 1))
      else
        divergent=$((divergent + 1))
        if [ -z "$reason" ]; then
          divergent_no_reason=$((divergent_no_reason + 1))
        fi
        # mis_dispatch 简化定义: 实际 binding 不在 Master 建议的 specialization group
        # 这里用 prefix 粗判: backend vs frontend 等跨组算 mis_dispatch
        # 完整定义留给 metrics 脚本
        local s_prefix="${suggested%%-*}"
        local a_prefix="${actual%%-*}"
        if [ "$s_prefix" != "$a_prefix" ] && [ "$s_prefix" != "custom" ] && [ "$a_prefix" != "custom" ]; then
          mis_dispatch=$((mis_dispatch + 1))
        fi
      fi
    fi
  done < <(find "$target_dir" -mindepth 2 -maxdepth 2 -name "ticket.json" -print0 2>/dev/null)
  echo "================================================"
  echo "Expert Binding Report"
  if [ -n "$epic_filter" ]; then
    echo "Scope: $epic_filter"
  else
    echo "Scope: all tickets"
  fi
  echo "================================================"
  echo "Tickets with binding:        $with_binding"
  echo "Consistent (suggested=actual): $consistent"
  echo "Divergent:                     $divergent"
  echo "  - without change_reason:     $divergent_no_reason"
  echo "  - cross-specialization:      $mis_dispatch"
  if [ $parse_errors -gt 0 ]; then
    echo "Parse errors (skipped):       $parse_errors (pre-existing JSON drift, NOT EPIC-157)"
  fi
  if [ $with_binding -gt 0 ]; then
    local rate_pct
    rate_pct=$(awk -v m="$mis_dispatch" -v t="$with_binding" 'BEGIN { if (t>0) printf "%.1f", (m/t)*100; else print "0.0" }')
    echo "mis_dispatch_rate: $rate_pct% (target <10%)"
  fi
  echo "================================================"
  return 0
}

# ─── main dispatch ──────────────────────────────────────────────────────────

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

Examples:
  binding-tracker.sh suggest EPIC-157 --expert backend
  binding-tracker.sh actual EPIC-157 --expert backend
  binding-tracker.sh actual EPIC-157 --expert frontend --reason "scope covers both backend+frontend"
  binding-tracker.sh validate-all
  binding-tracker.sh report --epic EPIC-157
EOF
    exit 2
    ;;
  *)
    echo "Unknown sub-command: $cmd" >&2
    exit 2
    ;;
esac
#!/usr/bin/env bash
# scripts/audit/alert.sh — Alert mechanism for failed continuous audit (EPIC-037-B)
# 跟 EPIC-037-A 9-pass + EPIC-037-B cron 联合
# 失败时自动写 .kallax/audit/alert-YYYY-MM-DD.jsonl (jq -n 防 JSON injection, 跟 EPIC-029 决策门 一致)
#
# Usage: alert.sh {write|read|count} [args...]
#   write <source> <severity> <message> [details_json]
#     source: continuous-audit | kpi-audit | cron | alert-sh
#     severity: info | warn | error | critical
#   read [YYYY-MM-DD]
#   count [YYYY-MM-DD] [severity]
#
# Output: .kallax/audit/alert-YYYY-MM-DD.jsonl
# Format: {timestamp, source, severity, message, details}
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ALERT_DIR="${ALERT_DIR:-${KALLAX_ROOT}/.kallax/audit}"

# 白名单常量 (4 source × 4 severity, 跟 EPIC-037 范围 一致, 0 隐藏)
VALID_SOURCES=("continuous-audit" "kpi-audit" "cron" "alert-sh")
VALID_SEVERITIES=("info" "warn" "error" "critical")

# write_alert <source> <severity> <message> [details_json]
write_alert() {
  local source="$1"
  local severity="$2"
  local message="$3"
  local details="${4:-null}"

  local valid_source=0
  local s
  for s in "${VALID_SOURCES[@]}"; do
    if [[ "$s" == "$source" ]]; then
      valid_source=1
      break
    fi
  done
  if [[ "$valid_source" -eq 0 ]]; then
    echo "ERROR: source must be one of: ${VALID_SOURCES[*]}, got '$source'" >&2
    return 1
  fi

  local valid_severity=0
  local v
  for v in "${VALID_SEVERITIES[@]}"; do
    if [[ "$v" == "$severity" ]]; then
      valid_severity=1
      break
    fi
  done
  if [[ "$valid_severity" -eq 0 ]]; then
    echo "ERROR: severity must be one of: ${VALID_SEVERITIES[*]}, got '$severity'" >&2
    return 1
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

  mkdir -p "${ALERT_DIR}"
  local alert_file
  alert_file="${ALERT_DIR}/alert-$(date -u +%Y-%m-%d).jsonl"

  local entry
  if [[ "$details" == "null" ]] || [[ -z "$details" ]]; then
    entry=$(jq -n \
      --arg ts "$timestamp" \
      --arg src "$source" \
      --arg sev "$severity" \
      --arg msg "$message" \
      '{timestamp:$ts, source:$src, severity:$sev, message:$msg, details:null}')
  else
    entry=$(jq -n \
      --arg ts "$timestamp" \
      --arg src "$source" \
      --arg sev "$severity" \
      --arg msg "$message" \
      --argjson det "$details" \
      '{timestamp:$ts, source:$src, severity:$sev, message:$msg, details:$det}')
  fi
  # 武器 1 (Iter 4): 通过 audit-chain.sh append 加 prev_hash + chain_hash
  local audit_chain="$SCRIPT_DIR/audit-chain.sh"
  if [[ -x "$audit_chain" ]]; then
      bash "$audit_chain" append "$alert_file" "$entry" || {
          echo "WARN: audit-chain append failed, falling back to raw write" >&2
          printf '%s\n' "$entry" >> "$alert_file"
          chmod 600 "$alert_file" 2>/dev/null || true
      }
  else
      printf '%s\n' "$entry" >> "$alert_file"
      chmod 600 "$alert_file" 2>/dev/null || true
  fi
}

# read_alert [YYYY-MM-DD]
read_alert() {
  local date_arg="${1:-$(date -u +%Y-%m-%d)}"
  local alert_file="${ALERT_DIR}/alert-${date_arg}.jsonl"
  if [[ -f "$alert_file" ]]; then
    cat "$alert_file"
  fi
}

# count_alert [YYYY-MM-DD] [severity]
count_alert() {
  local date_arg="${1:-$(date -u +%Y-%m-%d)}"
  local severity="${2:-}"
  local alert_file="${ALERT_DIR}/alert-${date_arg}.jsonl"
  if [[ -f "$alert_file" ]]; then
    if [[ -z "$severity" ]]; then
      jq -s 'length' "$alert_file" 2>/dev/null || echo "0"
    else
      jq -s --arg sev "$severity" 'map(select(.severity == $sev)) | length' "$alert_file" 2>/dev/null || echo "0"
    fi
  else
    echo "0"
  fi
}

# 入口
case "${1:-}" in
  write)
    shift
    write_alert "$@"
    ;;
  read)
    shift
    read_alert "$@"
    ;;
  count)
    shift
    count_alert "$@"
    ;;
  help|--help|-h)
    echo "Usage: $0 {write <source> <severity> <message> [details_json]|read [YYYY-MM-DD]|count [YYYY-MM-DD] [severity]}"
    echo "  source: ${VALID_SOURCES[*]}"
    echo "  severity: ${VALID_SEVERITIES[*]}"
    echo "  Output: .kallax/audit/alert-YYYY-MM-DD.jsonl"
    ;;
  *)
    echo "Usage: $0 {write|read|count} [args...]" >&2
    echo "  write <source> <severity> <message> [details_json]" >&2
    echo "  read [YYYY-MM-DD]" >&2
    echo "  count [YYYY-MM-DD] [severity]" >&2
    exit 1
    ;;
esac

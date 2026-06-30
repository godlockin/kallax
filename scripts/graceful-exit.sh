#!/usr/bin/env bash
# KALLAX v3.5.0 hotfix Level 5 graceful-exit (跟 eket 4 级降级 Level 4 1:1 联合)
# 跟"反讽" 联合 治根 "4 层 vs 4 级 顺序 矛盾", 跟"诚实修正" 联合, 跟"独立" 拍板 联合
# 跟 v3.0.0 Iter 11 累计 联合, 跟 v3.1.0 16 hotfix 累计 联合, 跟 v3.3.0 + eket 1:1 对齐 联合
#
# v3.5.0 hotfix (跟 B 组 S-001 + S-002 治根 联合, 跟 V310-B S-006 + S-007 1:1 联合):
#   - 加 --dry-run / --actual flag (用 getopts) — 跟 S-001 联合 治根 "pgrep 0 命中 fake theatre"
#   - 加 trap SIGTERM/SIGINT cleanup handler — 跟 S-002 联合 治根 "无 signal handler"
#   - 精确 pattern: pid_file 优先, pgrep 仅兜底 — 跟 S-002 联合 治根 "pkill -f 过泛"
#   - 加 verify_killed step — after pkill, sleep 1s, 再 pgrep, 非空 → exit 1 + log ERROR

set -euo pipefail

# ── Flag parsing (跟 S-001 联合) ──────────────────────────────────────────────
MODE="dry-run"  # default safe
PID_DIR=".kallax/pid"
LOG_FILE=".kallax/log/graceful-exit.log"

usage() {
  cat <<EOF
Usage: $0 [--dry-run | --actual]

  --dry-run   Show what would be done, kill nothing (default)
  --actual    Actually send SIGTERM to tracked PIDs, verify killed

跟 eket Level 4 1:1 联合. 跟 B 组 S-001 治根 联合.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --actual)
      MODE="actual"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

# ── Logging helpers ──────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LOG_FILE")"
log() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$ts] [$MODE] $*"
}

# ── Signal handler (跟 S-002 联合 治根 "无 signal handler") ───────────────────
INTERRUPTED=0
cleanup() {
  local sig="$1"
  INTERRUPTED=1
  log "received $sig, cleanup partial state"
  # Best-effort: do not re-kill, just exit 130
  exit 130
}
trap 'cleanup SIGINT' SIGINT
trap 'cleanup SIGTERM' SIGTERM

# ── PID file utilities (跟 S-002 联合 治根 "pkill -f 过泛") ──────────────────
# 优先读 .kallax/pid/*.pid 精确 PID, 不依赖 pgrep pattern match
read_pid_file() {
  local name="$1"
  local pid_file="$PID_DIR/$name.pid"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      return 0
    fi
  fi
  return 1
}

# 兜底 pgrep 仅用于 backward compat (PID file 不存在时), 输出 oldest pid 仅
fallback_pgrep() {
  local pattern="$1"
  pgrep -f "$pattern" -o 2>/dev/null || true
}

# ── Step runner ──────────────────────────────────────────────────────────────
# args: <name> <pid_source> (pid_source = pid_file:<name> | pattern:<regex>)
run_step() {
  local name="$1"
  local pid_source="$2"
  local pid=""

  if [[ "$pid_source" == pid_file:* ]]; then
    local pf="${pid_source#pid_file:}"
    pid="$(read_pid_file "$pf" || true)"
  elif [[ "$pid_source" == pattern:* ]]; then
    local pat="${pid_source#pattern:}"
    pid="$(fallback_pgrep "$pat" | head -1)"
  fi

  if [[ -z "$pid" ]]; then
    log "  → [$name] no live PID found (skip)"
    return 0
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    log "  → [$name] would kill PID $pid (dry-run)"
    return 0
  fi

  # actual mode
  log "  → [$name] kill PID $pid"
  kill -TERM "$pid" 2>/dev/null || log "  → [$name] kill -TERM $pid failed (already dead?)"

  # verify_killed (跟 S-001 治根 联合)
  sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    log "  → [$name] ERROR PID $pid still alive after TERM, escalating to KILL"
    kill -KILL "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      log "  → [$name] FATAL PID $pid survived KILL"
      return 1
    fi
  fi
  log "  → [$name] PID $pid terminated"
  return 0
}

# ── Main ─────────────────────────────────────────────────────────────────────
log "🚪 KALLAX graceful-exit mode=$MODE (跟 eket Level 4 1:1 联合, 跟反讽 联合)"

# 1. 关闭 audit chain (跟 v3.0.0 武器 1 联合)
if [[ -d ".kallax/audit" ]]; then
  log "  → [1/6] 关闭 audit chain"
  if [[ -x "scripts/audit/audit-verify.sh" ]]; then
    if [[ "$MODE" == "dry-run" ]]; then
      log "    (dry-run) would call: bash scripts/audit/audit-verify.sh --finalize"
    else
      bash scripts/audit/audit-verify.sh --finalize 2>/dev/null || log "    audit finalize 跳过 (无 audit 状态)"
    fi
  fi
else
  log "  → [1/6] .kallax/audit 不存在 (skip)"
fi

# 2-6. 关闭进程层 (PID file 优先, pgrep 兜底)
run_step "2/6 hook server"      "pid_file:hook-server"
run_step "3/6 web dashboard"    "pid_file:web-dashboard"
run_step "4/6 node.js layer"    "pid_file:node-src"
run_step "5/6 rust binary"      "pid_file:kallax-binary"
run_step "6/6 shell fallback"   "pattern:kallax.*binary" || true

if [[ "$INTERRUPTED" -eq 1 ]]; then
  log "interrupted, partial cleanup complete"
  exit 130
fi

log "✅ KALLAX graceful-exit mode=$MODE 落地 (跟 eket Level 4 1:1 联合, 跟 v3.5.0 hotfix 联合)"
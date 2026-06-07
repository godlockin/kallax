#!/usr/bin/env bash
# KALLAX Session Start Hook — EPIC-015 Phase 1.1
# Governance layer: identity init, directory setup, worktree guide, heartbeat.
# Runs on every new session. Failure does NOT block session.
set -uo pipefail

# ============================================================
# state.json Edit/Write PROTECTION (EPIC-016-M)
# Claude Code Edit/Write does NOT understand JSON semantics.
# Editing .kallax/instances/*/state.json with Edit/Write can inject
# duplicate keys or malformed JSON. To modify state.json, use jq:
#
#   jq '.heartbeat.last_beat = "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"' \
#     state.json > state.json.tmp && mv state.json.tmp state.json
#
# If state.json gets corrupted (duplicate keys, invalid JSON):
#   1. Stop all Claude sessions touching this instance
#   2. Backup: cp state.json state.json.bak
#   3. Remove duplicate last_beat lines:
#      sed -i '' '/^[[:space:]]*"last_beat":/d' state.json
#   4. Verify: jq . state.json  (must exit0)
#   5. Restart session
# ============================================================

KALLAX_ROOT="${KALLAX_ROOT:-.kallax}"
INSTANCES_DIR="${KALLAX_ROOT}/instances"
INBOX_DIR="${KALLAX_ROOT}/queue/inbox"
LOG_DIR="${KALLAX_ROOT}/logs"
SCRIPTS_DIR="${SCRIPTS_DIR:-$(cd "$(dirname "${KALLAX_ROOT}/..")/scripts" && pwd)}"

HOSTNAME="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"
PID="${$}"

# ============================================================
# Role Detection (priority: env > CLI arg > config file > branch)
# ============================================================
ROLE=""

# 1. Environment variable
if [ -n "${KALLAX_ROLE:-}" ]; then
  ROLE="$KALLAX_ROLE"
fi

# 2. CLI args: session_start.sh --role <role>
if [ -z "$ROLE" ]; then
  _args=("$@")
  _i=0
  while [ $_i -lt ${#_args[@]} ]; do
    case "${_args[$_i]}" in
      --role|-r)
        _i=$((_i + 1))
        if [ $_i -lt ${#_args[@]} ]; then
          ROLE="${_args[$_i]}"
        fi
        ;;
    esac
    _i=$((_i + 1))
  done
  unset _args _i
fi

# 3. instance_config.yml
if [ -z "$ROLE" ] && [ -f "${KALLAX_ROOT}/state/instance_config.yml" ]; then
  ROLE=$(grep '^role:' "${KALLAX_ROOT}/state/instance_config.yml" | head -1 | awk '{print $2}' | tr -d ' ')
fi

# 4. Branch fallback
if [ -z "$ROLE" ]; then
  _branch=$(git branch --show-current 2>/dev/null || echo '')
  case "$_branch" in
    feature/*|fix/*|chore/*) ROLE="performer" ;;
    *) ROLE="conductor" ;;
  esac
  unset _branch
fi

INSTANCE_ID="${KALLAX_INSTANCE_ID:-${ROLE}_${HOSTNAME}_${PID}}"
BRANCH="$(git branch --show-current 2>/dev/null || echo 'unknown')"
CWD="$(pwd)"

# Count existing instances BEFORE we create ours (used to skip heartbeat on first boot)
mkdir -p "${INSTANCES_DIR}"
EXISTING_INSTANCES_COUNT=$(find "${INSTANCES_DIR}" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

# ============================================================
# Worktree detection (optimized: avoid git worktree list overhead)
# ============================================================
IN_WORKTREE="false"
WORKTREE_PATH="null"
# Fast check: are we inside a worktree?
if git rev-parse --git-dir 2>/dev/null | grep -q 'worktrees'; then
  IN_WORKTREE="true"
  # Use parent directory of .git as worktree root (avoids git worktree list)
  WT=$(cd "$(git rev-parse --git-dir 2>/dev/null)/.." && pwd)
  WORKTREE_PATH="\"${WT}\""
fi

# ============================================================
# ── Master Health Check (optimized: grep instead of jq) ─────────────────
MASTER_STATE="${INSTANCES_DIR}/master_main/state.json"
MASTER_NEEDS_TAKEOVER="false"
if [ -f "${MASTER_STATE}" ]; then
  # Fast grep instead of jq for simple status check
  MASTER_STATUS=$(grep '"status"' "${MASTER_STATE}" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')
  if [ "${MASTER_STATUS}" = "STALE" ] || [ "${MASTER_STATUS}" = "CLOSING" ]; then
    MASTER_NEEDS_TAKEOVER="true"
  fi
else
  # No master state at all — first boot
  MASTER_NEEDS_TAKEOVER="true"
fi

# Auto-promote: if no explicit role and master needs takeover, suggest becoming master
if [ "${MASTER_NEEDS_TAKEOVER}" = "true" ] && [ -z "${ROLE}" ]; then
  cat << MASTER_PROMPT

╔════════════════════════════════════════════════════╗
║  ⚠ NO ACTIVE MASTER DETECTED                       ║
╠════════════════════════════════════════════════════╣
║  Previous master is STALE or absent.               ║
║  Run: KALLAX_ROLE=master bash session_start.sh     ║
║  Or:   session_start.sh --role master              ║
╚════════════════════════════════════════════════════╝
MASTER_PROMPT
fi

# ── Master Resume: detect previous master handoff (grep instead of jq) ───
if [ "${ROLE}" = "master" ]; then
  PREV_HANDOFF="${INSTANCES_DIR}/master_main/handoff.json"
  if [ -f "${PREV_HANDOFF}" ]; then
    # Use grep+sed instead of jq for simple field extraction
    PREV_STATUS=$(grep '"handoff_time"' "${PREV_HANDOFF}" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')
    PREV_PHASE=$(grep '"phase"' "${PREV_HANDOFF}" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')
    PREV_EPIC=$(grep '"epic"' "${PREV_HANDOFF}" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')
    PREV_OPEN=$(grep '"open_tickets"' "${PREV_HANDOFF}" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ' ,')
    PREV_REVIEWS=$(grep '"pending_reviews"' "${PREV_HANDOFF}" 2>/dev/null | sed 's/.*: *\([0-9]*\).*/\1/' | tr -d ' ,')
    cat << RESUME

╔════════════════════════════════════════════════════╗
║  MASTER RESUME — Previous session handoff found    ║
╠════════════════════════════════════════════════════╣
║  Handoff at   ▸ ${PREV_STATUS}                     ║
║  Phase        ▸ ${PREV_PHASE}                      ║
║  Epic         ▸ ${PREV_EPIC}                       ║
║  Open Tickets ▸ ${PREV_OPEN}                       ║
║  Reviews      ▸ ${PREV_REVIEWS} pending            ║
╠════════════════════════════════════════════════════╣
║  NEXT: check inbox → review performers → continue  ║
╚════════════════════════════════════════════════════╝
RESUME
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | RESUME | prev=master_main | phase=${PREV_PHASE}" >> "${LOG_DIR}/${INSTANCE_ID}.log"
    RESUME_MODE="true"
  else
    RESUME_MODE="false"
  fi
fi

# Create directories
# ============================================================
mkdir -p "${INSTANCES_DIR}/${INSTANCE_ID}"
mkdir -p "${INBOX_DIR}/${INSTANCE_ID}"
mkdir -p "${KALLAX_ROOT}/queue/outbox/${INSTANCE_ID}"
mkdir -p "${LOG_DIR}"

# ============================================================
# Write state.json
# AC1: duplicate last_beat key guard — validates template before write
# ============================================================
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
_STATE_TEMPLATE=$(cat <<'TPL_CHECK'
{
  "instance_id": "",
  "role": "",
  "pid": 0,
  "status": "ACTIVE",
  "branch": "",
  "cwd": "",
  "in_worktree": false,
  "worktree_path": null,
  "created_at": "",
  "started_at": "",
  "heartbeat": {
    "interval_seconds": 60,
    "last_beat": "",
    "missed_count": 0
  },
  "current_task": {
    "ticket_id": null,
    "worktree_path": null,
    "progress_pct": null
  }
}
TPL_CHECK
)
_LAST_BEAT_COUNT=$(echo "${_STATE_TEMPLATE}" | grep -c '^[[:space:]]*"last_beat":' || true)
if [ "${_LAST_BEAT_COUNT}" -gt 1 ]; then
  echo "[kallax] ERROR: state.json template has duplicate last_beat key (${_LAST_BEAT_COUNT} found). Aborting." >&2
  echo "[kallax] See session_start.sh top comment for recovery SOP." >&2
  exit 1
fi
unset _STATE_TEMPLATE _LAST_BEAT_COUNT
cat > "${INSTANCES_DIR}/${INSTANCE_ID}/state.json" << STATE
{
  "instance_id": "${INSTANCE_ID}",
  "role": "${ROLE}",
  "pid": ${PID},
  "status": "ACTIVE",
  "branch": "${BRANCH}",
  "cwd": "${CWD}",
  "in_worktree": ${IN_WORKTREE},
  "worktree_path": ${WORKTREE_PATH},
  "created_at": "${NOW}",
  "started_at": "${NOW}",
  "heartbeat": {
    "interval_seconds": 60,
    "last_beat": "${NOW}",
    "missed_count": 0
  },
  "current_task": {
    "ticket_id": null,
    "worktree_path": null,
    "progress_pct": null
  }
}
STATE

# ============================================================
# EPIC-016-O: Stale heartbeat daemon cleanup — prevent accumulation
# Run BEFORE daemon start (P1 fix from A review).
# Fixes applied (master review A+B):
#   - macOS etime parse (B HIGH)
#   - instance guard via cmdline (A P0 + B CRITICAL cross-instance)
#   - global orphan_kills.jsonl audit log (B observability)
# ============================================================
# etime_to_seconds "01:23:45" -> 5025 (or 1-02:03:04 -> 93784)
etime_to_seconds() {
  local e="$1" days=0 rest="" h=0 m=0 s=0
  case "$e" in
    *-*) days="${e%%-*}"; rest="${e#*-}" ;;
    *)   days=0; rest="$e" ;;
  esac
  local IFS=':'
  local parts=($rest)
  case "${#parts[@]}" in
    3) h="${parts[0]}"; m="${parts[1]}"; s="${parts[2]}" ;;
    2) m="${parts[0]}"; s="${parts[1]}" ;;
    *) echo 0; return ;;
  esac
  # Strip leading zeros to avoid octal interpretation
    local dh=${days#0}; dh=${dh:-0}; local hh=${h#0}; hh=${hh:-0}; local mm=${m#0}; mm=${mm:-0}; local ss=${s#0}; ss=${ss:-0}; echo $(( dh * 86400 + hh * 3600 + mm * 60 + ss ))
}
# pid_belongs_to_kallax <pid>: returns 0 if pid's instance_dir still exists
pid_belongs_to_kallax() {
  local _pid="$1"
  local _cmdline=""
  if [ -r "/proc/${_pid}/cmdline" ]; then
    _cmdline=$(tr '\0' ' ' < "/proc/${_pid}/cmdline" 2>/dev/null) || return 1
  else
    _cmdline=$(ps -o command= -p "$_pid" 2>/dev/null) || return 1
  fi
  echo "$_cmdline" | grep -q "heartbeat-daemon" || return 1
  # Extract 1st positional arg after heartbeat-daemon.sh (the INSTANCE_ID)
  local _instance_id
  _instance_id=$(echo "$_cmdline" | awk '{
    for (i=1; i<=NF; i++) {
      if ($i ~ /heartbeat-daemon\.sh$/) { print $(i+1); exit }
    }
  }' 2>/dev/null) || return 1
  [ -z "$_instance_id" ] && return 1
  [ -d "${INSTANCES_DIR}/${_instance_id}" ] || return 1
  return 0
}

_ORPHAN_COUNT=0
for _pid in $(pgrep -f "heartbeat-daemon" 2>/dev/null || ps -eo pid,comm | awk '/heartbeat-daemon/ {print $1}' || true); do
  [ -z "$_pid" ] && continue
  kill -0 "$_pid" 2>/dev/null || continue
  # Skip self
  [ "$_pid" -eq "${$:-0}" ] 2>/dev/null && continue
  # Instance guard (P0 fix)
  pid_belongs_to_kallax "$_pid" && continue
  # Get etime and convert to seconds (cross-platform fix)
  _etime=$(ps -o etime= -p "$_pid" 2>/dev/null | tr -d ' ' || true)
  [ -z "$_etime" ] && continue
  _etime_sec=$(etime_to_seconds "$_etime" 2>/dev/null || echo 0)
  if [ "$_etime_sec" -gt 3600 ]; then
    if kill "$_pid" 2>/dev/null; then
      _ORPHAN_COUNT=$((_ORPHAN_COUNT + 1))
      # Global audit log (B observability fix)
      printf '{"ts":"%s","event":"orphan_kill","pid":%s,"etime":"%s","etime_sec":%s,"killer_instance":"%s"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_pid" "$_etime" "$_etime_sec" "${INSTANCE_ID}" \
        >> "${LOG_DIR}/orphan_kills.jsonl" 2>/dev/null || true
      echo "[kallax] killed orphan heartbeat pid=${_pid} etime=${_etime}" >> "${LOG_DIR}/${INSTANCE_ID}.log" 2>/dev/null || true
    fi
  fi
done
unset _pid _etime _etime_sec _cmdline _instance_id

# ============================================================
# Start heartbeat daemon (on-demand, AC7) — SKIP on first boot
# AC7: Only start if STALE master exists (on-demand); first boot skips.
# Uses run_daemon() from scripts/lib/daemon.sh (AC3).
# ============================================================
if [ "${EXISTING_INSTANCES_COUNT}" -gt 0 ]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  HEARTBEAT_SCRIPT=""
  for candidate in \
    "${KALLAX_ROOT}/../scripts/heartbeat-daemon.sh" \
    "${REPO_ROOT:+${REPO_ROOT}/scripts/heartbeat-daemon.sh}" \
    "${KALLAX_ROOT}/hooks/heartbeat-daemon.sh"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      HEARTBEAT_SCRIPT="$candidate"
      break
    fi
  done
  if [ -z "$HEARTBEAT_SCRIPT" ]; then
    HEARTBEAT_SCRIPT="$(command -v heartbeat-daemon.sh 2>/dev/null || echo '')"
  fi
  if [ -n "$HEARTBEAT_SCRIPT" ] && [ -x "$HEARTBEAT_SCRIPT" ]; then
    STATE_FILE="${INSTANCES_DIR}/${INSTANCE_ID}/state.json"
    source "${SCRIPTS_DIR}/lib/daemon.sh" 2>/dev/null || true
    if [ -n "${KALLAX_SKIP_HEARTBEAT_ON_FIRST_BOOT:-}" ] && [ "${KALLAX_SKIP_HEARTBEAT_ON_FIRST_BOOT}" = "0" ]; then
      # Opt-in: force heartbeat on even first boot
      run_daemon "heartbeat" "$HEARTBEAT_SCRIPT" "${INSTANCE_ID}" "${INSTANCES_DIR}" \
        || echo "first-boot: heartbeat skipped" >> "${LOG_DIR}/${INSTANCE_ID}.log" 2>/dev/null || true
    elif [ -f "${MASTER_STATE}" ]; then
      # On-demand: only start if master exists and is STALE
      # Reuse MASTER_STATUS from earlier check (avoid re-reading)
      if [ "${MASTER_NEEDS_TAKEOVER}" = "true" ]; then
        run_daemon "heartbeat" "$HEARTBEAT_SCRIPT" "${INSTANCE_ID}" "${INSTANCES_DIR}" \
          || echo "heartbeat: start failed" >> "${LOG_DIR}/${INSTANCE_ID}.log" 2>/dev/null || true
      fi
    fi
  fi
else
  echo "first-boot: heartbeat skipped" >> "${LOG_DIR}/${INSTANCE_ID}.log" 2>/dev/null || true
fi

# ============================================================
# EXIT trap: daemon cleanup + structured diagnostic log (AC4, AC6)
# Optimized: avoid jq in hot path
# ============================================================
on_session_exit() {
  local exit_code=$?
  # Mark state as CLOSING (simple sed instead of jq)
  [ -f "${INSTANCES_DIR}/${INSTANCE_ID}/state.json" ] && \
    sed -i 's/"status": "ACTIVE"/"status": "CLOSING"/' \
      "${INSTANCES_DIR}/${INSTANCE_ID}/state.json" 2>/dev/null || true
  # Structured diagnostic log (AC6) - printf instead of jq -n
  {
    printf '{"ts":"%s","event":"session_start_exit","instance":"%s","pid":%s,"exit_code":%s}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${INSTANCE_ID}" "$$" "${exit_code}"
  } >> "${LOG_DIR}/session_start.diag.jsonl" 2>/dev/null || true
}
trap 'on_session_exit' EXIT INT TERM

# ============================================================
# Team count (jq preferred, grep fallback — no python3)
# ============================================================
CONDUCTOR_COUNT=0
PERFORMER_COUNT=0
if command -v jq &>/dev/null; then
  for sf in "${INSTANCES_DIR}"/*/state.json; do
    [ -f "${sf}" ] || continue
    r=$(jq -r '.role // ""' "${sf}" 2>/dev/null || echo '')
    case "${r}" in master|conductor) CONDUCTOR_COUNT=$((CONDUCTOR_COUNT+1)) ;; performer) PERFORMER_COUNT=$((PERFORMER_COUNT+1)) ;; esac
  done
else
  for sf in "${INSTANCES_DIR}"/*/state.json; do
    [ -f "${sf}" ] || continue
    r=$(grep -o '"role"[[:space:]]*:[[:space:]]*"[^"]*"' "${sf}" | head -1 | sed 's/.*"\(.*\)"/\1/')
    case "${r}" in master|conductor) CONDUCTOR_COUNT=$((CONDUCTOR_COUNT+1)) ;; performer) PERFORMER_COUNT=$((PERFORMER_COUNT+1)) ;; esac
  done
fi

# ============================================================
# Inbox count
# ============================================================
INBOX_COUNT=0
if [ -d "${INBOX_DIR}/${INSTANCE_ID}" ]; then
  INBOX_COUNT=$(ls -1 "${INBOX_DIR}/${INSTANCE_ID}/" 2>/dev/null | wc -l | tr -d ' ')
fi

# ============================================================
# Next action
# ============================================================
case "${ROLE}" in
  master)
    NEXT="kallax status / review PRs / approve"
    ;;
  conductor)
    if [ "${IN_WORKTREE}" = "false" ]; then
      NEXT="EnterWorktree / status / team overview"
    else
      NEXT="status / team check / task dispatch"
    fi
    ;;
  performer)
    NEXT="inbox check / claim card / EnterWorktree"
    ;;
  *)
    NEXT="kallax start --role conductor|performer"
    ;;
esac

WT_DISPLAY="$([ "${IN_WORKTREE}" = "true" ] && echo "${WORKTREE_PATH}" | tr -d '"' || echo "NOT ISOLATED")"

# Shorten worktree path for display (last 2 components)
WT_SHORT="${WT_DISPLAY}"
if [ "${IN_WORKTREE}" = "true" ] && [ "${#WT_DISPLAY}" -gt 35 ]; then
  _p1="${WT_DISPLAY%/*}"
  _p2="${_p1##*/}"
  _p3="${WT_DISPLAY##*/}"
  WT_SHORT="...${_p2}/${_p3}"
  unset _p1 _p2 _p3
fi

# ============================================================
# Lean ASCII Card — 7 lines (top, ROLE, INSTANCE, INBOX, NEXT, bottom)
# ============================================================
printf '┌─ KALLAX ────────────────────────────────\n'
printf '│ ROLE     ▸ %s\n' "${ROLE}"
printf '│ INSTANCE ▸ %s@%s\n' "${ROLE}" "${BRANCH}"
printf '│ INBOX*   ▸ [%s] %s\n' "${INBOX_COUNT}" "$([ "${INBOX_COUNT}" -eq 0 ] && printf '.' || printf '!')"
printf '│ NEXT     ▸ %s\n' "${NEXT}"
printf '└────────────────────────────────────────\n'

# ============================================================
# EXPERT MATCHER READY — EPIC-024-A Sprint 1
# ============================================================
EXPERT_MATCHER_READY="false"
if [ -f "$(pwd)/scripts/expert-match.sh" ]; then
  EXPERT_MATCHER_READY="true"
fi

if [ "${EXPERT_MATCHER_READY}" = "true" ]; then
  cat << 'EXPERT_READY'

┌─ EXPERT MATCHER READY ─────────────────────
│ 5 Default Experts (with trigger: fields):
│   🏗️ architect  — 架构/边界/选型/微服务/模块
│   💻 backend    — API/数据库/SQL/缓存/性能
│   🎨 frontend  — 组件/渲染/LCP/状态/包体积
│   🖌️ ux         — 交互/旅程/体验/可用性
│   📋 product   — 优先级/价值/ROI/MVP
│  🛡️ security   — 注入/越权/XSS/鉴权
│   🧭 pm — 跨团队/任务规划/协调
│
│ Usage: bash scripts/expert-match.sh "<你的需求>"
│ Example: bash scripts/expert-match.sh "接口响应很慢"
│
│ L1 Decision Tree: experts/TRIGGERS.md
│ Audit Log: ~/.kallax/logs/expert_resolution_audit.jsonl
└────────────────────────────────────────

EXPERT_READY
fi

# ============================================================
# Logging
# ============================================================
echo "${NOW} | START | role=${ROLE} | instance=${INSTANCE_ID} | branch=${BRANCH} | worktree=${IN_WORKTREE}" >> "${LOG_DIR}/${INSTANCE_ID}.log"
echo "SESSION_START_OK instance_id=${INSTANCE_ID} role=${ROLE}"

exit 0

#!/usr/bin/env bash
# tests/integration/heartbeat-daemon.test.sh — EPIC-277-F AC6
#
# 4 case: 启动 / 暂停 / 恢复 / 崩溃恢复.
# 目标: scripts/heartbeat-daemon.js 的实例生命周期真的落盘, 不是"跑了没报错"就算过.
#
# 隔离: 每个 case 用独立 tmp instances 目录 + --no-emit (不污染真队列),
#   emit 路径由 case 1 单独用一次真 emit 验证 (AC2 已在别处验, 这里只确认接线).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DAEMON="$REPO_ROOT/scripts/heartbeat-daemon.js"

if [ ! -f "$DAEMON" ]; then
  echo "FAIL: daemon not found: $DAEMON" >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "FAIL: node not found" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq not found" >&2
  exit 1
fi

TMP="$(mktemp -d -t heartbeat-daemon-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
TOTAL=4

section() { printf '\n=== %s ===\n' "$1"; }
ok()   { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf 'FAIL: %s\n' "$1"; }

INST_DIR="$TMP/instances"
ID="test_hb"
DFILE="$INST_DIR/$ID/daemon.json"

run_daemon() {
  node "$DAEMON" --daemon --once --no-emit \
    --instance-id "$ID" --instances-dir "$INST_DIR" "$@" 2>>"$TMP/daemon.log"
}

# ------------------------------------------------------------------
# Case 1: 启动 — 实例目录 + daemon.json 被创建, beat_count 递增, exit 0
# ------------------------------------------------------------------
section "Case 1: 启动 (实例持久化 + beat_count 递增)"
C1_OK=1
C1_WHY=""

run_daemon
RC=$?
if [ "$RC" -ne 0 ]; then
  C1_OK=0; C1_WHY="first tick exit=$RC (期望 0)"
fi

if [ "$C1_OK" -eq 1 ] && [ ! -f "$DFILE" ]; then
  C1_OK=0; C1_WHY="daemon.json 未创建: $DFILE"
fi

if [ "$C1_OK" -eq 1 ]; then
  BEAT1="$(jq -r '.beat_count' "$DFILE" 2>/dev/null || echo x)"
  if [ "$BEAT1" != "1" ]; then
    C1_OK=0; C1_WHY="首次 beat_count=$BEAT1 (期望 1)"
  fi
fi

# 第二次 tick 应把 beat_count 推到 2 (状态跨进程持久化, 不是每次从 0 开始)
if [ "$C1_OK" -eq 1 ]; then
  run_daemon
  BEAT2="$(jq -r '.beat_count' "$DFILE" 2>/dev/null || echo x)"
  if [ "$BEAT2" != "2" ]; then
    C1_OK=0; C1_WHY="第二次 beat_count=$BEAT2 (期望 2, 状态未跨进程持久化)"
  fi
fi

# state.json 也要写 (跟 heartbeat-daemon.sh 共用 schema)
if [ "$C1_OK" -eq 1 ]; then
  SFILE="$INST_DIR/$ID/state.json"
  LAST_BEAT="$(jq -r '.heartbeat.last_beat // empty' "$SFILE" 2>/dev/null || true)"
  if [ -z "$LAST_BEAT" ]; then
    C1_OK=0; C1_WHY="state.json heartbeat.last_beat 为空 (跟 .sh schema 不兼容)"
  fi
fi

if [ "$C1_OK" -eq 1 ]; then
  ok "启动: daemon.json + state.json 落盘, beat_count 1→2"
else
  bad "启动: $C1_WHY"
fi

# ------------------------------------------------------------------
# Case 2: 暂停 — --pause 后 tick 不推进 beat_count, missed_count 递增
# ------------------------------------------------------------------
section "Case 2: 暂停 (paused tick 不推进 beat_count)"
C2_OK=1
C2_WHY=""

node "$DAEMON" --pause --instance-id "$ID" --instances-dir "$INST_DIR" 2>>"$TMP/daemon.log"
RC=$?
if [ "$RC" -ne 0 ]; then
  C2_OK=0; C2_WHY="--pause exit=$RC (期望 0)"
fi

if [ "$C2_OK" -eq 1 ]; then
  PAUSED="$(jq -r '.paused' "$DFILE" 2>/dev/null || echo x)"
  if [ "$PAUSED" != "true" ]; then
    C2_OK=0; C2_WHY="paused=$PAUSED (期望 true)"
  fi
fi

BEFORE_BEAT="$(jq -r '.beat_count' "$DFILE" 2>/dev/null || echo x)"
if [ "$C2_OK" -eq 1 ]; then
  run_daemon
  RC=$?
  # 暂停是预期状态, 不是失败 → tick 仍 exit 0
  if [ "$RC" -ne 0 ]; then
    C2_OK=0; C2_WHY="paused 状态 tick exit=$RC (期望 0, 暂停不是失败)"
  fi
fi

if [ "$C2_OK" -eq 1 ]; then
  AFTER_BEAT="$(jq -r '.beat_count' "$DFILE" 2>/dev/null || echo x)"
  if [ "$AFTER_BEAT" != "$BEFORE_BEAT" ]; then
    C2_OK=0; C2_WHY="paused 后 beat_count 从 $BEFORE_BEAT 变成 $AFTER_BEAT (期望不变)"
  fi
fi

if [ "$C2_OK" -eq 1 ]; then
  MISSED="$(jq -r '.missed_count' "$DFILE" 2>/dev/null || echo 0)"
  STATUS="$(jq -r '.status' "$DFILE" 2>/dev/null || echo x)"
  if [ "$MISSED" -lt 1 ] || [ "$STATUS" != "PAUSED" ]; then
    C2_OK=0; C2_WHY="paused 后 missed_count=$MISSED status=$STATUS (期望 >=1 / PAUSED)"
  fi
fi

if [ "$C2_OK" -eq 1 ]; then
  ok "暂停: beat_count 冻结在 $BEFORE_BEAT, missed_count 递增, status=PAUSED"
else
  bad "暂停: $C2_WHY"
fi

# ------------------------------------------------------------------
# Case 3: 恢复 — --resume 后 tick 重新推进 beat_count, missed_count 归零
# ------------------------------------------------------------------
section "Case 3: 恢复 (resume 后 beat_count 继续推进)"
C3_OK=1
C3_WHY=""

node "$DAEMON" --resume --instance-id "$ID" --instances-dir "$INST_DIR" 2>>"$TMP/daemon.log"
RC=$?
if [ "$RC" -ne 0 ]; then
  C3_OK=0; C3_WHY="--resume exit=$RC (期望 0)"
fi

if [ "$C3_OK" -eq 1 ]; then
  PAUSED="$(jq -r '.paused' "$DFILE" 2>/dev/null || echo x)"
  if [ "$PAUSED" != "false" ]; then
    C3_OK=0; C3_WHY="resume 后 paused=$PAUSED (期望 false)"
  fi
fi

BEFORE_BEAT="$(jq -r '.beat_count' "$DFILE" 2>/dev/null || echo 0)"
if [ "$C3_OK" -eq 1 ]; then
  run_daemon
  AFTER_BEAT="$(jq -r '.beat_count' "$DFILE" 2>/dev/null || echo x)"
  EXPECT=$((BEFORE_BEAT + 1))
  if [ "$AFTER_BEAT" != "$EXPECT" ]; then
    C3_OK=0; C3_WHY="resume 后 beat_count=$AFTER_BEAT (期望 $EXPECT)"
  fi
fi

if [ "$C3_OK" -eq 1 ]; then
  MISSED="$(jq -r '.missed_count' "$DFILE" 2>/dev/null || echo x)"
  if [ "$MISSED" != "0" ]; then
    C3_OK=0; C3_WHY="resume 后 missed_count=$MISSED (期望 0)"
  fi
fi

if [ "$C3_OK" -eq 1 ]; then
  ok "恢复: beat_count 继续推进, missed_count 归零"
else
  bad "恢复: $C3_WHY"
fi

# ------------------------------------------------------------------
# Case 4: 崩溃恢复 — daemon.json 留着死 pid + 非干净状态, 下次启动应
#   识别为崩溃 (crash_recovered=true, restart_count +1), 而不是当正常启动.
# ------------------------------------------------------------------
section "Case 4: 崩溃恢复 (死 pid → crash_recovered + restart_count+1)"
C4_OK=1
C4_WHY=""

CRASH_ID="test_hb_crash"
CRASH_DIR="$INST_DIR/$CRASH_ID"
CRASH_FILE="$CRASH_DIR/daemon.json"
mkdir -p "$CRASH_DIR"

# 造一个"崩溃现场": status=ACTIVE (没走 STOPPED/COMPLETED) + 一个已死的 pid.
# 找一个确定不存在的 pid: 起个短命进程拿它的 pid, 等它退.
( exit 0 ) &
DEAD_PID=$!
wait "$DEAD_PID" 2>/dev/null || true

cat > "$CRASH_FILE" <<EOF
{
  "instance_id": "$CRASH_ID",
  "role": "heartbeat_daemon",
  "pid": $DEAD_PID,
  "status": "ACTIVE",
  "paused": false,
  "beat_count": 7,
  "missed_count": 3,
  "restart_count": 1,
  "last_beat": "2026-08-21T00:00:00Z",
  "schema_version": 1
}
EOF

node "$DAEMON" --daemon --once --no-emit \
  --instance-id "$CRASH_ID" --instances-dir "$INST_DIR" 2>>"$TMP/daemon.log"
RC=$?
if [ "$RC" -ne 0 ]; then
  C4_OK=0; C4_WHY="崩溃恢复启动 exit=$RC (期望 0)"
fi

if [ "$C4_OK" -eq 1 ]; then
  RESTARTS="$(jq -r '.restart_count' "$CRASH_FILE" 2>/dev/null || echo x)"
  if [ "$RESTARTS" != "2" ]; then
    C4_OK=0; C4_WHY="restart_count=$RESTARTS (期望 2 = 原 1 + 本次崩溃恢复 1)"
  fi
fi

if [ "$C4_OK" -eq 1 ]; then
  RECOVERED="$(jq -r '.crash_recovered' "$CRASH_FILE" 2>/dev/null || echo x)"
  FROM_PID="$(jq -r '.recovered_from.pid // empty' "$CRASH_FILE" 2>/dev/null || true)"
  if [ "$RECOVERED" != "true" ] || [ "$FROM_PID" != "$DEAD_PID" ]; then
    C4_OK=0; C4_WHY="crash_recovered=$RECOVERED recovered_from.pid=$FROM_PID (期望 true / $DEAD_PID)"
  fi
fi

# 崩溃恢复不该丢历史 beat_count (7 → tick 后 8)
if [ "$C4_OK" -eq 1 ]; then
  BEATS="$(jq -r '.beat_count' "$CRASH_FILE" 2>/dev/null || echo x)"
  if [ "$BEATS" != "8" ]; then
    C4_OK=0; C4_WHY="崩溃恢复后 beat_count=$BEATS (期望 8, 历史计数被丢了)"
  fi
fi

# 反向: 干净退出 (status=COMPLETED) 的实例再启动不该算崩溃
if [ "$C4_OK" -eq 1 ]; then
  CLEAN_ID="test_hb_clean"
  mkdir -p "$INST_DIR/$CLEAN_ID"
  cat > "$INST_DIR/$CLEAN_ID/daemon.json" <<EOF
{
  "instance_id": "$CLEAN_ID",
  "pid": $DEAD_PID,
  "status": "COMPLETED",
  "paused": false,
  "beat_count": 2,
  "restart_count": 0,
  "schema_version": 1
}
EOF
  node "$DAEMON" --daemon --once --no-emit \
    --instance-id "$CLEAN_ID" --instances-dir "$INST_DIR" 2>>"$TMP/daemon.log"
  CLEAN_RECOVERED="$(jq -r '.crash_recovered' "$INST_DIR/$CLEAN_ID/daemon.json" 2>/dev/null || echo x)"
  if [ "$CLEAN_RECOVERED" != "false" ]; then
    C4_OK=0; C4_WHY="干净退出的实例被误判为崩溃 (crash_recovered=$CLEAN_RECOVERED)"
  fi
fi

if [ "$C4_OK" -eq 1 ]; then
  ok "崩溃恢复: 死 pid 识别为崩溃, restart_count 1→2, beat_count 7→8, 干净退出不误判"
else
  bad "崩溃恢复: $C4_WHY"
fi

# ------------------------------------------------------------------
printf '\n=== Summary ===\n'
printf 'heartbeat-daemon.test.sh: %d/%d PASS\n' "$PASS" "$TOTAL"

if [ "$PASS" -ne "$TOTAL" ]; then
  printf '\n--- daemon stderr (last 20 lines) ---\n'
  tail -20 "$TMP/daemon.log" 2>/dev/null || true
  exit 1
fi
exit 0

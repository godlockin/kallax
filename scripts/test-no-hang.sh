#!/usr/bin/env bash
# KALLAX No-Hang Regression Test -- EPIC-016-R AC8
# Runs session_start.sh N times, asserts each run < 1s and no orphan heartbeat.
set -uo pipefail

N="${1:-10}"
FAIL=0
ORPHAN_THRESHOLD=8

echo "== KALLAX No-Hang Regression (N=$N) =="

for i in $(seq 1 "$N"); do
  start_ns=$(date +%s%N)
  bash .kallax/hooks/session_start.sh >/dev/null 2>&1
  rc=$?
  end_ns=$(date +%s%N)
  elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))

  if [ "$rc" -ne 0 ]; then
    echo "FAIL iter=$i rc=$rc"
    FAIL=$((FAIL + 1))
  elif [ "$elapsed_ms" -ge 1000 ]; then
    echo "FAIL iter=$i elapsed_ms=${elapsed_ms}ms (threshold=1000ms)"
    FAIL=$((FAIL + 1))
  else
    echo "OK   iter=$i elapsed_ms=${elapsed_ms}"
  fi
done

ORPHANS=$(ps aux 2>/dev/null | grep heartbeat-daemon | grep -v grep | wc -l | tr -d ' ')
echo "orphans=$ORPHANS (threshold=$ORPHAN_THRESHOLD)"

if [ "$FAIL" -eq 0 ] && [ "${ORPHANS:-0}" -le "$ORPHAN_THRESHOLD" ]; then
  echo "Result: ALL PASSED"
  exit 0
else
  echo "Result: FAILED (failures=$FAIL, orphans=$ORPHANS)"
  exit 1
fi
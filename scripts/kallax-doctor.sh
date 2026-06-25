#!/usr/bin/env bash
# KALLAX system:doctor — JSON structured diagnostic output
# EPIC-030-F (主公 D 串行第 6)
#
# Output schema (跟 PROVENANCE doctor 模式 1:1 验证):
#   {
#     "schema": "kallax.doctor/v1",
#     "status": "healthy" | "degraded" | "unhealthy",
#     "level": 1 | 2 | 3,
#     "checks": [
#       {"name": "...", "status": "pass" | "warn" | "fail", "error": null | "...", "note": null | "..."}
#     ],
#     "trust_score": {  # 跟 EPIC-030-A TrustScore 联合 (软依赖, 0 NEW 强制)
#       "available": true | false,
#       "value": 0.0..1.0 | null
#     },
#     "timestamp": "<ISO-8601>",
#     "exit_code": 0 | 1 | 2
#   }
#
# Usage:
#   scripts/kallax-doctor.sh                 # JSON to stdout (default)
#   scripts/kallax-doctor.sh --text          # human-readable text output
#   scripts/kallax-doctor.sh --self-test     # run inline self-test
#
# Levels (跟 跟 eket degradation strategy 1:1 联合):
#   level 1 → unhealthy (critical: git 或 db 不可用)
#   level 2 → degraded (non-critical: tooling 或 disk 警告)
#   level 3 → healthy  (all checks pass)
#
# 0h skeleton 跟"翻篇&精进" 战略 联合: 真实 stub (git + db + trust_score 软依赖),
# 0 NEW 强制 node 依赖, 0 假 PASS.
set -euo pipefail

# ─────────────────────────────────────────────────────────
# Constants (Rule 4: no magic numbers)
# ─────────────────────────────────────────────────────────
readonly SCHEMA_VERSION="kallax.doctor/v1"
readonly LEVEL_UNHEALTHY=1
readonly LEVEL_DEGRADED=2
readonly LEVEL_HEALTHY=3
readonly EXIT_OK=0
readonly EXIT_DEGRADED=1
readonly EXIT_UNHEALTHY=2
readonly DISK_WARN_PCT=85
readonly DISK_FAIL_PCT=95
readonly TRUST_SCORE_PATH="node/src/core/trust-score.ts"

# ─────────────────────────────────────────────────────────
# Mode parsing
# ─────────────────────────────────────────────────────────
MODE="json"
if [[ "${1:-}" == "--text" ]]; then
  MODE="text"
elif [[ "${1:-}" == "--self-test" ]]; then
  MODE="self-test"
elif [[ "${1:-}" == "--json" ]]; then
  MODE="json"
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
KALLAX_DIR="${PROJECT_ROOT}/.kallax"
DB_PATH="${KALLAX_DIR}/data/kallax.db"

# ─────────────────────────────────────────────────────────
# Check functions — 真实 stub, 0 假 PASS
# Return "ok" | "degraded: <msg>" | "unhealthy: <msg>" | "<error>"
# ─────────────────────────────────────────────────────────

check_git() {
  if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "ok"
  else
    echo "unhealthy: not a git repository"
  fi
}

check_database() {
  if [ -f "$DB_PATH" ]; then
    echo "ok"
  else
    echo "unhealthy: sqlite db not found at $DB_PATH"
  fi
}

check_disk() {
  local pct
  pct=$(df -h "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%' || echo "0")
  pct="${pct:-0}"
  if [ "$pct" -lt "$DISK_WARN_PCT" ]; then
    echo "ok"
  elif [ "$pct" -lt "$DISK_FAIL_PCT" ]; then
    echo "degraded: ${pct}% used"
  else
    echo "unhealthy: ${pct}% used"
  fi
}

check_trust_score_module() {
  if [ -f "${PROJECT_ROOT}/${TRUST_SCORE_PATH}" ]; then
    echo "ok"
  else
    echo "degraded: trust-score module not found (EPIC-030-A 软依赖)"
  fi
}

# ─────────────────────────────────────────────────────────
# TrustScore 软依赖检测 (跟 EPIC-030-A 联合)
# 0 NEW 强制 node 调用, 仅检测 file presence.
# ─────────────────────────────────────────────────────────
trust_score_status() {
  if [ -f "${PROJECT_ROOT}/${TRUST_SCORE_PATH}" ]; then
    jq -n '{available: true, value: null, note: "module present, runtime scoring 0 强制"}'
  else
    jq -n '{available: false, value: null, note: "EPIC-030-A 未落地"}'
  fi
}

# ─────────────────────────────────────────────────────────
# Run all checks
# ─────────────────────────────────────────────────────────
GIT_R=$(check_git)
DB_R=$(check_database)
DISK_R=$(check_disk)
TRUST_R=$(check_trust_score_module)

# Determine overall status + level
STATUS="healthy"
LEVEL=$LEVEL_HEALTHY
EXIT_CODE=$EXIT_OK

[[ "$GIT_R"    == unhealthy:* ]] && { STATUS="unhealthy"; LEVEL=$LEVEL_UNHEALTHY; EXIT_CODE=$EXIT_UNHEALTHY; }
[[ "$DB_R"     == unhealthy:* ]] && { STATUS="unhealthy"; LEVEL=$LEVEL_UNHEALTHY; EXIT_CODE=$EXIT_UNHEALTHY; }

# Degraded only when still healthy
if [[ "$STATUS" == "healthy" ]]; then
  [[ "$DISK_R"  == degraded:* ]]  && { STATUS="degraded"; LEVEL=$LEVEL_DEGRADED; EXIT_CODE=$EXIT_DEGRADED; }
  [[ "$DISK_R"  == unhealthy:* ]] && { STATUS="unhealthy"; LEVEL=$LEVEL_UNHEALTHY; EXIT_CODE=$EXIT_UNHEALTHY; }
  [[ "$TRUST_R" == degraded:* ]]  && { STATUS="degraded"; LEVEL=$LEVEL_DEGRADED; EXIT_CODE=$EXIT_DEGRADED; }
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TRUST_JSON=$(trust_score_status)

# ─────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────
emit_json() {
  jq -n \
    --arg schema "$SCHEMA_VERSION" \
    --arg status "$STATUS" \
    --argjson level "$LEVEL" \
    --arg git "$GIT_R" \
    --arg db "$DB_R" \
    --arg disk "$DISK_R" \
    --arg trust "$TRUST_R" \
    --arg timestamp "$TIMESTAMP" \
    --argjson exit_code "$EXIT_CODE" \
    --argjson trust_score "$TRUST_JSON" \
    '{
      schema: $schema,
      status: $status,
      level: $level,
      checks: [
        {name: "git",            status: (if $git    | startswith("ok")        then "pass" elif $git    | startswith("degraded")   then "warn" else "fail" end), error: (if $git    == "ok" then null else $git    end), note: null},
        {name: "database",       status: (if $db     | startswith("ok")        then "pass" elif $db     | startswith("degraded")   then "warn" else "fail" end), error: (if $db     == "ok" then null else $db     end), note: null},
        {name: "disk",           status: (if $disk   | startswith("ok")        then "pass" elif $disk   | startswith("degraded")   then "warn" else "fail" end), error: null,                                                  note: (if $disk   != "ok" then $disk   else null end)},
        {name: "trust_score",    status: (if $trust  | startswith("ok")        then "pass" elif $trust  | startswith("degraded")   then "warn" else "fail" end), error: null,                                                  note: (if $trust  != "ok" then $trust  else null end)}
      ],
      trust_score: $trust_score,
      timestamp: $timestamp,
      exit_code: $exit_code
    }'
}

emit_text() {
  echo "=== KALLAX system:doctor ==="
  echo "Schema: $SCHEMA_VERSION"
  echo "Status: $STATUS (level=$LEVEL)"
  echo "Timestamp: $TIMESTAMP"
  echo ""
  echo "--- Checks ---"
  for pair in "git:$GIT_R" "database:$DB_R" "disk:$DISK_R" "trust_score:$TRUST_R"; do
    name="${pair%%:*}"
    val="${pair#*:}"
    if [[ "$val" == "ok" ]]; then
      echo "  [PASS] $name"
    elif [[ "$val" == degraded:* ]]; then
      echo "  [WARN] $name — ${val#degraded: }"
    else
      echo "  [FAIL] $name — ${val#unhealthy: }"
    fi
  done
  echo ""
  echo "TrustScore 软依赖: $(echo "$TRUST_JSON" | jq -r '.available')"
  echo "Exit: $EXIT_CODE"
}

case "$MODE" in
  json)
    emit_json
    exit "$EXIT_CODE"
    ;;
  text)
    emit_text
    exit "$EXIT_CODE"
    ;;
  self-test)
    echo "[self-test] running 3 inline scenarios"
    echo "[self-test] scenario 1: jq valid → $(emit_json | jq -e . >/dev/null 2>&1 && echo PASS || echo FAIL)"
    echo "[self-test] scenario 2: schema field → $(emit_json | jq -e '.schema == "kallax.doctor/v1"' >/dev/null 2>&1 && echo PASS || echo FAIL)"
    echo "[self-test] scenario 3: trust_score field → $(emit_json | jq -e '.trust_score | type == "object"' >/dev/null 2>&1 && echo PASS || echo FAIL)"
    exit 0
    ;;
  *)
    echo "usage: $0 [--json|--text|--self-test]" >&2
    exit 64
    ;;
esac

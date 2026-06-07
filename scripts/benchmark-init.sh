#!/usr/bin/env bash
# KALLAX Init Benchmark — 测量 session_start.sh 的 wall-time + 资源开销
# Usage:
#   benchmark-init.sh [--label NAME] [--iter N] [--out PATH]
#   benchmark-init.sh --diff FILE1 FILE2
#
# 输出:
#   .kallax/benchmarks/<label>-<unix_ts>.json  (单次)
#   .kallax/benchmarks/history.jsonl          (append 历史)
#   终端: 一行 summary
#
# 测量维度:
#   - wall_time_ms: session_start.sh 冷/热启动耗时
#   - script_bytes: 脚本大小(对 I/O 量有提示)
#   - files_created: 本次新创建的 .kallax/ 文件数
#   - files_touched: 本次读+写的 .kallax/ 文件数
#   - out_bytes: 脚本 stdout 大小
#   - tokens_est: 基于 out_bytes × 0.25 token/byte 的粗估
set -uo pipefail

# Hard dependency: python3 (for JSON manipulation; no jq-only alternative is shorter)
command -v python3 &>/dev/null || { echo "ERR: python3 required for JSON" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
KALLAX_ROOT="${PROJECT_ROOT}/.kallax"
HOOK="${KALLAX_ROOT}/hooks/session_start.sh"
BENCH_DIR="${KALLAX_ROOT}/benchmarks"
HISTORY="${BENCH_DIR}/history.jsonl"

LABEL=""
ITER=3
OUT=""
DIFF_A=""
DIFF_B=""
HASH_MODE=""

for arg in "$@"; do
  case "$arg" in
    --label) shift; LABEL="${1:-}"; shift || true ;;
    --iter)  shift; ITER="${1:-3}"; shift || true ;;
    --out)   shift; OUT="${1:-}"; shift || true ;;
    --diff)  shift; DIFF_A="${1:-}"; DIFF_B="${2:-}"; shift 2 || true ;;
    --hash-session-start) HASH_MODE="true"; shift ;;
    --help|-h) sed -n '2,18p' "$0"; exit 0 ;;
  esac
done

mkdir -p "$BENCH_DIR"
LABEL="${LABEL:-$(date +%Y%m%d-%H%M%S)}"

# ── diff 模式 ──
if [ -n "$DIFF_A" ] && [ -n "$DIFF_B" ]; then
  if [ ! -f "$DIFF_A" ] || [ ! -f "$DIFF_B" ]; then
    echo "ERR: --diff 需要两个 JSON 文件" >&2; exit 1
  fi
  python3 - "$DIFF_A" "$DIFF_B" <<'PY'
import json, sys
a = json.load(open(sys.argv[1]))
b = json.load(open(sys.argv[2]))
def pct(x, y): return f"{(x-y)/x*100:+.1f}%" if x else "n/a"
print(f"{'metric':<20} {'baseline':>14} {'optimized':>14} {'delta':>10}")
print("─" * 62)
for k in ["wall_time_ms", "out_bytes", "tokens_est", "files_created", "files_touched"]:
    va, vb = a.get(k, 0), b.get(k, 0)
    print(f"{k:<20} {va:>14} {vb:>14} {pct(va, vb):>10}")
PY
  exit $?
fi

# ── hash-session-start 模式 ──
if [ "$HASH_MODE" = "true" ]; then
  if [ ! -x "$HOOK" ]; then
    echo "ERR: $HOOK 不可执行" >&2; exit 1
  fi
  mkdir -p "$BENCH_DIR"

  # 捕获 session_start.sh stdout (排除 stderr)
  STDOUT_TMP=$(mktemp)
  KALLAX_ROLE=master bash "$HOOK" --role master > "$STDOUT_TMP" 2>&1

  # 计算 sha256 hash
  STDOUT_SHA256=$(shasum -a 256 "$STDOUT_TMP" | awk '{print $1}')
  STDOUT_CONTENT=$(cat "$STDOUT_TMP")
  rm -f "$STDOUT_TMP"

  # 写入 expected hash 文件
  echo "expected_stdout_sha256: ${STDOUT_SHA256}" > "${BENCH_DIR}/expected_card_hash.txt"

  # 输出 stdout + hash
  echo "=== SESSION_START.STDOUT ==="
  echo "$STDOUT_CONTENT"
  echo "=== SESSION_START.SHA256 ==="
  echo "${STDOUT_SHA256}"
  echo "=== EXPECTED_HASH_FILE ==="
  echo "${BENCH_DIR}/expected_card_hash.txt"
  echo "expected_stdout_sha256: ${STDOUT_SHA256}"
  exit 0
fi

# ── 单次测量 ──
if [ ! -x "$HOOK" ]; then
  echo "ERR: $HOOK 不可执行" >&2; exit 1
fi

# Cold start: 删除 .kallax/{instances,queue,logs},保留 hooks
PRESERVE_INSTANCES_BEFORE=$(ls -1 "$KALLAX_ROOT/instances/" 2>/dev/null | wc -l | tr -d ' ')
rm -rf "$KALLAX_ROOT/instances" "$KALLAX_ROOT/queue" "$KALLAX_ROOT/logs" 2>/dev/null

START_NS=$(date +%s%N)
KALLAX_ROLE=master bash "$HOOK" --role master > /tmp/bench-stdout.$$ 2>&1
END_NS=$(date +%s%N)
WALL_TIME_MS=$(( (END_NS - START_NS) / 1000000 ))

OUT_BYTES=$(wc -c < /tmp/bench-stdout.$$ | tr -d ' ')
OUT_LINES=$(wc -l < /tmp/bench-stdout.$$ | tr -d ' ')
TOKENS_EST=$(( OUT_BYTES / 4 ))

FILES_CREATED=$(find "$KALLAX_ROOT/instances" "$KALLAX_ROOT/queue" "$KALLAX_ROOT/logs" -type f 2>/dev/null | wc -l | tr -d ' ')
SCRIPT_BYTES=$(wc -c < "$HOOK" | tr -d ' ')

# 写结果
RESULT=$(cat <<JSON
{
  "label": "${LABEL}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "unix_ts": $(date +%s),
  "host": "$(hostname)",
  "hook": "${HOOK}",
  "wall_time_ms": ${WALL_TIME_MS},
  "out_bytes": ${OUT_BYTES},
  "out_lines": ${OUT_LINES},
  "tokens_est": ${TOKENS_EST},
  "files_created": ${FILES_CREATED},
  "files_touched": ${FILES_CREATED},
  "script_bytes": ${SCRIPT_BYTES},
  "iter": ${ITER},
  "preserved_instances_before": ${PRESERVE_INSTANCES_BEFORE}
}
JSON
)

rm -f /tmp/bench-stdout.$$

# 跑 ITER 次 warm start 拿平均(每次前清掉上一次 session 状态,避免 state 增长污染)
WARM_TOTAL=0
WARM_MAX=0
for _ in $(seq 1 "$ITER"); do
  # 清理本 session 创建的 instances/<new id>/,只保留之前累积的(模拟真实 warm 场景)
  find "$KALLAX_ROOT/instances" -maxdepth 1 -mindepth 1 -newer "$HOOK" -type d -exec rm -rf {} + 2>/dev/null || true
  START_NS=$(date +%s%N)
  KALLAX_ROLE=master bash "$HOOK" --role master > /dev/null 2>&1
  END_NS=$(date +%s%N)
  ELAPSED=$(( (END_NS - START_NS) / 1000000 ))
  WARM_TOTAL=$(( WARM_TOTAL + ELAPSED ))
  [ $ELAPSED -gt $WARM_MAX ] && WARM_MAX=$ELAPSED
done
WARM_AVG=$(( WARM_TOTAL / ITER ))

# 更新 result 含 warm 字段
RESULT=$(echo "$RESULT" | python3 -c "
import json, sys
r = json.load(sys.stdin)
r['wall_time_warm_ms_avg'] = ${WARM_AVG}
r['wall_time_warm_ms_max'] = ${WARM_MAX}
r['wall_time_warm_iter'] = ${ITER}
print(json.dumps(r, indent=2))
")

# 输出
echo "$RESULT" | tee "${OUT:-${BENCH_DIR}/${LABEL}-$(date +%s).json}"
echo "$RESULT" | python3 -c "
import json, sys
r = json.load(sys.stdin)
print(f'─── {r[\"label\"]} ───', file=sys.stderr)
print(f'cold wall  : {r[\"wall_time_ms\"]} ms', file=sys.stderr)
print(f'warm avg   : {r[\"wall_time_warm_ms_avg\"]} ms ({r[\"wall_time_warm_iter\"]} iter)', file=sys.stderr)
print(f'out        : {r[\"out_bytes\"]} bytes / {r[\"out_lines\"]} lines / ~{r[\"tokens_est\"]} tokens', file=sys.stderr)
print(f'files      : {r[\"files_created\"]} created', file=sys.stderr)
" >&2

# 追加 history(单行)
echo "$RESULT" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin)))" >> "$HISTORY"

exit 0

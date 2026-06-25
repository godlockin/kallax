#!/usr/bin/env bash
# KALLAX Init Benchmark — EPIC-016-A
# 测量 init 流程的 wall-time + 资源开销
#
# Usage:
#   benchmark-init.sh [--label NAME] [--out PATH]
#   benchmark-init.sh --diff LABEL1 LABEL2
#
# 测量维度 (per AC2):
#   - wall_time       : session_start.sh 执行总耗时(秒)
#   - files_read      : init 流程中读文件操作次数 (source/cat/head/tail/jq)
#   - bash_calls      : init 流程中 bash 命令调用次数 (含嵌套子 shell)
#   - tokens_est      : 从 .kallax/logs 本次新增字节数 / 4 推算
#
# 输出 (per AC3 + AC4):
#   - .kallax/benchmarks/<label>-<unix_ts>.json
#   - .kallax/benchmarks/history.jsonl (append)
#   - 终端: 一行 summary
set -uo pipefail

# ── Constants (no magic numbers, Performer Rule 4) ──
readonly NANOSECONDS_PER_SECOND=1000000000
readonly BYTES_PER_TOKEN=4
readonly DIFF_TABLE_WIDTH=56
readonly TRACE_FILE_READ_REGEX='^\+ (source|\.|cat |head |tail |jq |grep |sed |awk )'
readonly TRACE_CALL_REGEX='^\++ '

# ── Paths ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly KALLAX_ROOT="${PROJECT_ROOT}/.kallax"
readonly HOOK="${KALLAX_ROOT}/hooks/session_start.sh"
readonly BENCH_DIR="${KALLAX_ROOT}/benchmarks"
readonly HISTORY="${BENCH_DIR}/history.jsonl"
readonly LOG_DIR="${KALLAX_ROOT}/logs"

# ── Dependency check (fail fast, Performer Rule 4) ──
command -v python3 &>/dev/null || { echo "ERR: python3 required for JSON I/O" >&2; exit 1; }
[ -x "$HOOK" ] || { echo "ERR: $HOOK not executable" >&2; exit 1; }

# ── Args ──
LABEL=""
OUT_PATH=""
DIFF_A=""
DIFF_B=""

usage() {
  sed -n '2,12p' "$0"
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --label) LABEL="${2:-}"; shift 2 ;;
      --out)   OUT_PATH="${2:-}"; shift 2 ;;
      --diff)  DIFF_A="${2:-}"; DIFF_B="${3:-}"; shift 3 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERR: unknown arg: $1" >&2; exit 1 ;;
    esac
  done
}

# ── Metric helpers (no copy-paste, Performer Rule 8) ──
count_trace_lines() {
  local trace_file="$1" regex="$2"
  local n
  n=$(grep -cE "$regex" "$trace_file" 2>/dev/null) || n=0
  printf '%d' "${n:-0}"
}

log_bytes_added() {
  local before_bytes="$1" after_bytes="$2"
  echo $(( after_bytes - before_bytes ))
}

sum_log_bytes() {
  if [ -d "$LOG_DIR" ]; then
    find "$LOG_DIR" -type f -name '*.log' -exec wc -c {} + 2>/dev/null \
      | awk 'END { s += $1 } END { print s+0 }'
  else
    echo 0
  fi
}

# ── Measurement (per AC2) ──
measure_init() {
  local trace_tmp stdout_tmp start_ns end_ns before_bytes after_bytes
  trace_tmp=$(mktemp)
  stdout_tmp=$(mktemp)

  before_bytes=$(sum_log_bytes)

  start_ns=$(date +%s%N)
  KALLAX_ROLE=master bash -x "$HOOK" --role master \
    >"$stdout_tmp" 2>"$trace_tmp" || true
  end_ns=$(date +%s%N)

  after_bytes=$(sum_log_bytes)

  WALL_TIME_S=$(awk "BEGIN { printf \"%.3f\", (${end_ns} - ${start_ns}) / ${NANOSECONDS_PER_SECOND} }")
  BASH_CALLS=$(count_trace_lines "$trace_tmp" "$TRACE_CALL_REGEX")
  FILES_READ=$(count_trace_lines "$trace_tmp" "$TRACE_FILE_READ_REGEX")
  local added
  added=$(log_bytes_added "$before_bytes" "$after_bytes")
  TOKENS_EST=$(( added / BYTES_PER_TOKEN ))

  rm -f "$trace_tmp" "$stdout_tmp"
}

# ── Result writer (per AC3 + AC4) ──
write_result() {
  local out_file="$1"
  local timestamp unix_ts notes
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  unix_ts=$(date +%s)
  notes="init flow via bash -x ${HOOK##*/} --role master; tokens_est = log_bytes_added/4"

  python3 - "$out_file" "$HISTORY" "$LABEL" "$timestamp" "$WALL_TIME_S" \
    "$FILES_READ" "$BASH_CALLS" "$TOKENS_EST" "$notes" <<'PY'
import json, os, sys

out_path, hist_path, label, ts, wall, fr, bc, tok, notes = sys.argv[1:]
record = {
    "timestamp": ts,
    "label": label,
    "wall_time": float(wall),
    "files_read": int(fr),
    "bash_calls": int(bc),
    "tokens_est": int(tok),
    "notes": notes,
}
os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, "w") as f:
    json.dump(record, f, indent=2)
    f.write("\n")
with open(hist_path, "a") as f:
    f.write(json.dumps(record) + "\n")
print(json.dumps(record, indent=2))
PY
}

# ── Diff mode (per AC5) ──
# Strict label lookup: filename must be exactly `<label>-<digits>.json`
# to avoid prefix collisions (label=foo must not match foo-bar-123.json).
find_latest_by_label() {
  local label="$1" pattern base
  pattern="^${label}-[0-9]+\.json$"
  for f in "${BENCH_DIR}/${label}-"*.json; do
    [ -f "$f" ] || continue
    base="${f##*/}"
    [[ "$base" =~ $pattern ]] && printf '%s\n' "$f"
  done | sort -r | head -1
}

run_diff() {
  local a_path b_path
  a_path=$(find_latest_by_label "$DIFF_A")
  b_path=$(find_latest_by_label "$DIFF_B")
  if [ -z "$a_path" ] || [ -z "$b_path" ]; then
    echo "ERR: --diff label not found (a='$DIFF_A'→'$a_path', b='$DIFF_B'→'$b_path')" >&2
    exit 1
  fi
  python3 - "$a_path" "$b_path" "$DIFF_A" "$DIFF_B" "$DIFF_TABLE_WIDTH" <<'PY'
import json, sys
a_path, b_path, la, lb, width = sys.argv[1:6]
a, b = json.load(open(a_path)), json.load(open(b_path))
w = int(width)

def pct(x, y):
    return f"{(x-y)/x*100:+.1f}%" if x else "n/a"

print(f"{'metric':<14} {la:>14} {lb:>14} {'delta':>10}")
print("─" * w)
for k in ["wall_time", "files_read", "bash_calls", "tokens_est"]:
    va, vb = a.get(k, 0), b.get(k, 0)
    print(f"{k:<14} {str(va):>14} {str(vb):>14} {pct(va, vb):>10}")
PY
}

# ── Terminal summary ──
print_summary() {
  {
    echo "─── ${LABEL} ───"
    echo "wall  : ${WALL_TIME_S}s"
    echo "files : ${FILES_READ} read"
    echo "calls : ${BASH_CALLS} bash"
    echo "tokens: ${TOKENS_EST} est"
    echo "saved : ${RESULT_FILE}"
  } >&2
}

# ── Main ──
main() {
  parse_args "$@"
  mkdir -p "$BENCH_DIR"
  LABEL="${LABEL:-run-$(date +%Y%m%d-%H%M%S)}"

  if [ -n "$DIFF_A" ] && [ -n "$DIFF_B" ]; then
    run_diff
    exit $?
  fi

  measure_init
  RESULT_FILE="${OUT_PATH:-${BENCH_DIR}/${LABEL}-$(date +%s).json}"
  write_result "$RESULT_FILE"
  print_summary
  exit 0
}

main "$@"

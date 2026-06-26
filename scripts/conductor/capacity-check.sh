#!/bin/bash
# conductor/capacity-check.sh — 1+4 容量验证 (EPIC-038-B)
# 1 Conductor + 4 Performer sub-roles (analyst/incremental/major/auditor, 动态 N)
# 跟 EPIC-038-A handoff_depth 字段 + Rule 15 联合
# 跟 EPIC-030-A best-matching-slaver.sh 同源 (.kallax/state/instances.json)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 默认 4 Performer sub-roles (跟 Rule 15 联合)
readonly DEFAULT_PERFORMER_SUBROLES=("analyst" "incremental" "major" "auditor")

# State file: production = .kallax/state/instances.json, test = tests/fixtures/agent/instances.json
INSTANCES_FILE="${KALLAX_ROOT}/.kallax/state/instances.json"
if [[ "${KALLAX_TEST_FIXTURES:-0}" == "1" ]]; then
  INSTANCES_FILE="${KALLAX_ROOT}/tests/fixtures/agent/instances.json"
fi

CONDUCTOR_MIN=1
PERFORMER_MIN=4
SUBROLES=("${DEFAULT_PERFORMER_SUBROLES[@]}")

# 帮助
print_help() {
  cat <<'USAGE'
Usage: capacity-check.sh [OPTIONS]

1+4 容量验证 (1 Conductor + 4 Performer sub-roles, 动态 N)

Options:
  --instances=<path>   自定义 instances.json 路径
                       (默认: KALLAX_TEST_FIXTURES=1 → tests/fixtures/agent/instances.json)
                       (      默认: production → .kallax/state/instances.json)
  --conductor-min <N>  最小 Conductor 数 (默认 1)
  --performer-min <N>  最小 Performer 数 (默认 4)
  --subroles <list>    自定义 sub-roles 列表 (逗号分隔, 默认 analyst,incremental,major,auditor)
  --help, -h           显示此帮助

Output:
  CAPACITY: status=<ok|warn|fail> conductor=<N> performer=<N> total=<N+M> subroles=<list>

Exit codes:
  0 = capacity ok
  1 = capacity fail
USAGE
}

# 解析参数 (顺序不敏感, 一次扫描)
i=0
ARGS=("$@")
while [[ $i -lt $# ]]; do
  arg="${ARGS[$i]}"
  case "$arg" in
    --help|-h)
      print_help
      exit 0
      ;;
    --instances=*)
      INSTANCES_FILE="${arg#*=}"
      if [[ -z "$INSTANCES_FILE" ]]; then
        echo "ERROR: --instances= requires non-empty path" >&2
        exit 1
      fi
      i=$((i + 1))
      ;;
    --conductor-min)
      i=$((i + 1))
      CONDUCTOR_MIN="${ARGS[$i]:-1}"
      i=$((i + 1))
      ;;
    --performer-min)
      i=$((i + 1))
      PERFORMER_MIN="${ARGS[$i]:-4}"
      i=$((i + 1))
      ;;
    --subroles)
      i=$((i + 1))
      sub_csv="${ARGS[$i]:-}"
      if [[ -n "$sub_csv" ]]; then
        SUBROLES=()
        IFS=',' read -r -a SUBROLES <<< "$sub_csv"
      fi
      i=$((i + 1))
      ;;
    *)
      echo "ERROR: unknown arg: $arg" >&2
      exit 1
      ;;
  esac
done

# 文件存在性检查
if [[ ! -f "$INSTANCES_FILE" ]]; then
  echo "ERROR: instances file not found: $INSTANCES_FILE (set KALLAX_TEST_FIXTURES=1 for test/CI)" >&2
  exit 1
fi

# 统计 conductor / performer 数量
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required for capacity-check.sh" >&2
  exit 1
fi

CONDUCTOR_COUNT=$(jq -r '[.instances[] | select(.role == "conductor")] | length' "$INSTANCES_FILE" 2>/dev/null || echo "0")
PERFORMER_COUNT=$(jq -r '[.instances[] | select(.role == "performer")] | length' "$INSTANCES_FILE" 2>/dev/null || echo "0")

# 检查 sub-roles (跟 Rule 15 联合): 4 类 Performer (analyst/incremental/major/auditor)
FOUND_SUBROLES=()
for sub in "${SUBROLES[@]}"; do
  # Performer sub-role 命名约定: performer-<sub> 或 id contains <sub>
  match=$(jq -r --arg sub "$sub" \
    '[.instances[] | select((.role == "performer") and ((.id | contains("performer-" + $sub)) or (.sub_role == $sub)))] | length' \
    "$INSTANCES_FILE" 2>/dev/null || echo "0")
  if [[ "$match" -gt 0 ]]; then
    FOUND_SUBROLES+=("$sub")
  fi
done

SUBROLE_COUNT=${#FOUND_SUBROLES[@]}
if [[ ${#FOUND_SUBROLES[@]} -gt 0 ]]; then
  SUBROLE_LIST=$(IFS=','; echo "${FOUND_SUBROLES[*]}")
else
  SUBROLE_LIST=""
fi
TOTAL=$((CONDUCTOR_COUNT + PERFORMER_COUNT))

# 状态判断 (fail > warn > ok, 优先级: fail 不会被 warn 覆盖)
STATUS="ok"
if [[ "$CONDUCTOR_COUNT" -lt "$CONDUCTOR_MIN" ]]; then
  STATUS="fail"
fi
if [[ "$PERFORMER_COUNT" -lt "$PERFORMER_MIN" ]]; then
  STATUS="fail"
fi
# sub-roles 缺失: 已经在 fail 状态不降级; 缺 0 强制 fail; 部分缺失 → warn
if [[ "$SUBROLE_COUNT" -lt "${#SUBROLES[@]}" ]]; then
  if [[ "$SUBROLE_COUNT" -eq 0 ]]; then
    STATUS="fail"
  elif [[ "$STATUS" != "fail" ]]; then
    STATUS="warn"
  fi
fi

# 输出 (跟 dispatch.sh 格式对齐, 1 line structured log)
echo "CAPACITY: status=$STATUS conductor=$CONDUCTOR_COUNT performer=$PERFORMER_COUNT total=$TOTAL subroles=$SUBROLE_LIST subrole_count=$SUBROLE_COUNT expected_subroles=${#SUBROLES[@]} conductor_min=$CONDUCTOR_MIN performer_min=$PERFORMER_MIN"

if [[ "$STATUS" == "ok" ]]; then
  exit 0
fi
exit 1

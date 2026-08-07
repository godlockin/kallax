#!/usr/bin/env bash
# tests/integration/epic-204-docs-only-metrics-test.sh
# EPIC-204 docs-only metrics 适配 — sprint-metrics.sh --docs-only flag 验证
#
# TCs:
#   T1: --docs-only exit 3 (DOCS_ONLY_SKIP)
#   T2: --docs-only JSON 输出含 status=DOCS_ONLY_SKIP
#   T3: --docs-only Markdown 输出含 DOCS_ONLY_SKIP 标记
#   T4: 不带 --docs-only 仍然 NO_DATA (exit 2) (不破坏现有行为)
#   T5: --docs-only --output 文件写 .json + .md
#   T6: --help 显示 --docs-only + exit code 3
#
# 注: 测试本身禁用 set -e 因为 sprint-metrics.sh exit 3/2 是 expected

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPRINT_METRICS="${REPO_ROOT}/scripts/metrics/sprint-metrics.sh"

PASS=0
FAIL=0

assert() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $name"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $name (expected=$expected actual=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

# 捕获 exit code (不依赖 set -e)
run_capture() {
  local actual_exit
  "$@" >/dev/null 2>&1
  actual_exit=$?
  printf '%d' "$actual_exit"
}

echo "=== EPIC-204 docs-only metrics 适配 ==="

# T1: --docs-only exit 3
EXIT_CODE="$(run_capture bash "$SPRINT_METRICS" --epic EPIC-197 --docs-only --format json)"
assert "T1: --docs-only exit 3" "3" "$EXIT_CODE"

# T2: JSON output has status DOCS_ONLY_SKIP
JSON_OUT="$(bash "$SPRINT_METRICS" --epic EPIC-197 --docs-only --format json 2>/dev/null)"
HAS_STATUS="$(printf '%s' "$JSON_OUT" | jq -r '.status')"
assert "T2: JSON status=DOCS_ONLY_SKIP" "DOCS_ONLY_SKIP" "$HAS_STATUS"

# T3: Markdown output has DOCS_ONLY_SKIP marker
MD_OUT="$(bash "$SPRINT_METRICS" --epic EPIC-197 --docs-only --format markdown 2>/dev/null)"
HAS_MARKER="$(printf '%s' "$MD_OUT" | grep -c 'DOCS_ONLY_SKIP')"
[ "$HAS_MARKER" -ge 1 ] && HAS_MARKER=1
assert "T3: Markdown 含 DOCS_ONLY_SKIP 标记" "1" "$HAS_MARKER"

# T4: 不带 --docs-only 仍然 NO_DATA (exit 2)
EXIT_CODE="$(run_capture bash "$SPRINT_METRICS" --epic EPIC-197 --format json)"
assert "T4: 无 --docs-only 仍然 exit 2 (NO_DATA)" "2" "$EXIT_CODE"

# T5: --output 文件
TMP_DIR="$(mktemp -d -t epic-204.XXXXXX)"
TMP_BASE="${TMP_DIR}/metrics-test"
bash "$SPRINT_METRICS" --epic EPIC-197 --docs-only --format both --output "$TMP_BASE" >/dev/null 2>&1
JSON_FILE_EXISTS=0
MD_FILE_EXISTS=0
[ -f "${TMP_BASE}.json" ] && JSON_FILE_EXISTS=1
[ -f "${TMP_BASE}.md" ] && MD_FILE_EXISTS=1
assert "T5a: --output 写 .json 文件" "1" "$JSON_FILE_EXISTS"
assert "T5b: --output 写 .md 文件" "1" "$MD_FILE_EXISTS"
rm -rf "$TMP_DIR"

# T6: --help 显示 --docs-only + exit code 3
HELP_OUT="$(bash "$SPRINT_METRICS" --help 2>&1)"
HAS_DOCS_FLAG="$(printf '%s' "$HELP_OUT" | grep -c -- '--docs-only')"
HAS_EXIT_3="$(printf '%s' "$HELP_OUT" | grep -c '3  DOCS_ONLY_SKIP')"
[ "$HAS_DOCS_FLAG" -ge 1 ] && HAS_DOCS_FLAG=1
assert "T6a: --help 含 --docs-only" "1" "$HAS_DOCS_FLAG"
assert "T6b: --help 含 exit 3 说明" "1" "$HAS_EXIT_3"

echo ""
echo "=== Result: ${PASS} pass / ${FAIL} fail ==="
if [ "$FAIL" -gt 0 ]; then
  echo "FAILED"
  exit 1
fi
echo "PASS"
exit 0
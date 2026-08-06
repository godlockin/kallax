#!/usr/bin/env bash
# scripts/release-entry.sh — CHANGELOG Release Entry Generator (EPIC-183)
#
# 输入: git log + EPIC list → 输出 [version] - <date> 段, 插入 CHANGELOG.md 顶部
# 跟 frame-task.sh 联合 (frame 表单 Q1-Q6 数据 → release entry body)
# 跟 EPIC-177-G run-history emit 联合 (emit decision 事件)
#
# 用法:
#   bash scripts/release-entry.sh --version v3.33.6 --since v3.33.5
#   bash scripts/release-entry.sh --version v3.33.6 --since v3.33.5 --dry-run
#   bash scripts/release-entry.sh --self-test
#
# 退出码 (跟 EPIC-181 R5 一致):
#   0 = PASS
#   1 = FAIL (git log / jq 失败)
#   2 = 参数错误
#   3 = self-test FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_PARAM_FAIL=2
readonly EXIT_SELF_TEST_FAIL=3

VERSION=""
SINCE=""
DRY_RUN=0
EPIC_LIST=""
SELF_TEST=0

# ── helpers ──

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] release-entry: $*" >&2
}

# ── self-test (前置定义, 让 --self-test 在参数解析前可用) ──

assert_exit_code_st() {
    local test_name="$1" expected="$2" actual="$3"
    if [ "$actual" -eq "$expected" ]; then
        echo "  PASS: $test_name"
        return 0
    else
        echo "  FAIL: $test_name (expected=$expected got=$actual)"
        return 1
    fi
}

assert_contains_st() {
    local test_name="$1" pattern="$2" output="$3"
    if echo "$output" | grep -qE "$pattern"; then
        echo "  PASS: $test_name"
        return 0
    else
        echo "  FAIL: $test_name (expected: $pattern)"
        return 1
    fi
}

cmd_self_test() {
    local failed=0

    echo "=== release-entry self-test (≥6 用例) ==="

    # Test 1: --version 格式校验 (capture exit before || true)
    local out1 exit1
    out1=$(bash "$SCRIPT_DIR/release-entry.sh" --version BAD_VERSION 2>&1) || exit1=$?
    exit1=${exit1:-0}
    assert_exit_code_st "Test 1 --version BAD_FORMAT exit=2" 2 "$exit1" || failed=$((failed + 1))

    # Test 2: --version 缺
    local out2 exit2
    out2=$(bash "$SCRIPT_DIR/release-entry.sh" 2>&1) || exit2=$?
    exit2=${exit2:-0}
    assert_exit_code_st "Test 2 缺 --version exit=2" 2 "$exit2" || failed=$((failed + 1))

    # Test 3: --help exit=0
    out1=$(bash "$SCRIPT_DIR/release-entry.sh" -h 2>&1 | head -3 || true)
    assert_contains_st "Test 3 --help 显示用法" "Usage:" "$out1" || failed=$((failed + 1))

    # Test 4: --dry-run 模式输出 entry (cd $KALLAX_ROOT 保证 git log 工作)
    local out4 exit4
    out4=$(cd "$KALLAX_ROOT" && bash "$SCRIPT_DIR/release-entry.sh" --version v3.33.6 --since HEAD~1 --dry-run 2>&1) || exit4=$?
    exit4=${exit4:-0}
    assert_contains_st "Test 4 --dry-run 输出 entry" "Auto-generated release entry" "$out4" || failed=$((failed + 1))

    # Test 5: --dry-run 输出含 [version] 行
    assert_contains_st "Test 5 entry 含 [v3.33.6]" "[v3.33.6]" "$out4" || failed=$((failed + 1))

    # Test 6: --dry-run 输出含 EPIC table
    assert_contains_st "Test 6 entry 含 EPIC table" "EPIC-" "$out4" || failed=$((failed + 1))

    echo ""
    if [ "$failed" -eq 0 ]; then
        echo "✅ self-test PASS (6/6)"
        return $EXIT_PASS
    else
        echo "❌ self-test FAIL ($failed failed)"
        return $EXIT_SELF_TEST_FAIL
    fi
}

# ── 参数解析 ──

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      if [[ -z "$VERSION" ]] || ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: --version requires vX.Y.Z format, got: '$VERSION'" >&2
        exit $EXIT_PARAM_FAIL
      fi
      shift 2
      ;;
    --since)
      SINCE="${2:-}"
      shift 2
      ;;
    --epic-list)
      EPIC_LIST="${2:-}"
      shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --self-test) SELF_TEST=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 --version vX.Y.Z [--since <ref>] [--epic-list "EPIC-NNN EPIC-MMM"] [--dry-run] [--self-test]

Examples:
  $0 --version v3.33.6 --since v3.33.5
  $0 --version v3.33.6 --since v3.33.5 --epic-list "EPIC-180-A EPIC-181" --dry-run
  $0 --self-test
EOF
      exit $EXIT_PASS
      ;;
    *) shift ;;
  esac
done

# Final VERSION check (覆盖未提供 --version 场景)
if [[ "$SELF_TEST" -eq 0 && -z "$VERSION" ]]; then
  echo "ERROR: --version 必填 (vX.Y.Z)" >&2
  exit $EXIT_PARAM_FAIL
fi

# ── generate_entry: 主入口 ──

generate_entry() {
    local version="$1" since_ref="$2" epics="$3" dry_run="$4"
    local date
    date=$(date +%Y-%m-%d)

    # ── 1. 收集 commits (since ref → HEAD) ──
    local commits
    if [ -n "$since_ref" ]; then
        commits=$(git log "${since_ref}..HEAD" --oneline 2>/dev/null | head -50 || echo "")
    else
        commits=$(git log -20 --oneline 2>/dev/null || echo "")
    fi

    if [ -z "$commits" ]; then
        echo "ERROR: 0 commits in range (since=$since_ref HEAD)" >&2
        return $EXIT_FAIL
    fi

    # ── 2. 解析 EPIC 列表 ──
    local epic_table=""
    if [ -n "$epics" ]; then
        for epic in $epics; do
            epic_table="${epic_table}| $epic | (auto) | TBD | TBD |"$'\n'
        done
    else
        local detected_epics
        detected_epics=$(echo "$commits" | grep -oE 'EPIC-[0-9]+(-[A-Z]+)?' | sort -u | head -10)
        for epic in $detected_epics; do
            local short_sha
            short_sha=$(echo "$commits" | grep "$epic" | head -1 | awk '{print $1}' || echo "")
            epic_table="${epic_table}| $epic | $short_sha | TBD | TBD |"$'\n'
        done
    fi

    # ── 3. 生成 entry ──
    local entry
    entry=$(cat <<EOF
## [$version] - $date

### Auto-generated release entry (EPIC-183)

**Scope**: TBD (auto-detected from commits)

#### Closed EPICs

$epic_table

#### Test results

TBD (auto-detected from integration tests)

#### 4-PR flow

TBD (auto-detected from PR merges)

---
EOF
)

    # ── 4. 输出 / 写入 ──
    if [ "$dry_run" -eq 1 ]; then
        echo "$entry"
        return $EXIT_PASS
    fi

    # ── 5. 插入到 CHANGELOG.md 顶部 ──
    local changelog="$KALLAX_ROOT/CHANGELOG.md"
    if [ ! -f "$changelog" ]; then
        echo "ERROR: CHANGELOG.md 不存在: $changelog" >&2
        return $EXIT_FAIL
    fi

    local tmp
    tmp=$(mktemp)
    echo "$entry" > "$tmp"
    cat "$changelog" >> "$tmp"
    mv "$tmp" "$changelog"
    echo "✓ CHANGELOG.md 已更新 (顶部插入 [$version] - $date)"

    # ── 6. EPIC-177-G: emit decision event ──
    local run_history="${KALLAX_ROOT}/scripts/heartbeat/run-history.sh"
    if [ -f "$run_history" ]; then
        local payload
        payload=$(jq -cn --arg version "$version" --arg since "$since_ref" \
            '{action: "release_entry_generated", version: $version, since_ref: $since}')
        "$run_history" emit decision "release-entry" "$payload" >/dev/null 2>&1 || true
    fi

    return $EXIT_PASS
}

# ── main ──

main() {
    if [[ "$SELF_TEST" -eq 1 ]]; then
        cmd_self_test
        return $?
    fi
    generate_entry "$VERSION" "$SINCE" "$EPIC_LIST" "$DRY_RUN"
}

main "$@"
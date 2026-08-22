#!/usr/bin/env bash
# KALLAX verify-agent-note-format.sh — EPIC-280 (DSH Path A admission, 主公 2026-08-21 拍板)
#
# 验 staged .md 满足 Agent Note schema:
#   1. 文件路径闭集: agent-notes/{proposed,implemented,rejected}/{class}/<file>.md
#                    OR 根目录白名单 (CLAUDE.md / README.md / AGENTS.md / CHANGELOG.md)
#   2. header 三行必填:
#        # Agent Note: <title>
#        Status: <status>
#        <空白行>
#   3. ## Problem 段必填
#   4. class 6 闭集: feature / bug-fix / architecture / process / testing / simplification
#   5. Status 4 闭集: proposed / accepted / implemented / rejected
#
# 借鉴: DSH Path A 报告 §4 + agent-note-adr-proposal paper
#      (跟 EPIC-225 check-jargon 同模式接入 pre-commit, 复用 EPIC-279 check-doc-budgets 路径)
#
# Exit: 0 = PASS, 1 = REJECT (fail-closed)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# 闭集
CLASS_RE='^(feature|bug-fix|architecture|process|testing|simplification)$'
STATUS_RE='^(proposed|accepted|implemented|rejected)$'

# 路径: agent-notes/{proposed|implemented|rejected}/{class}/<file>.md
AGENT_NOTE_RE='^agent-notes/(proposed|implemented|rejected)/[^/]+/[^/]+\.md$'

# 根目录白名单
ROOT_WHITELIST_RE='^(CLAUDE\.md|README\.md|AGENTS\.md|CHANGELOG\.md)$'

is_meta_file() {
  local rel="${1:-}"
  case "$rel" in
    *verify-agent-note-format.sh) return 0 ;;
  esac
  return 1
}

# 0 = pass, N = violations count
check_one_file() {
  local rel="$1"
  local full="$REPO_ROOT/$rel"
  local out="${TMP_OUT:-/tmp/verify-agent-note-vio.$$}"
  : > "$out"

  is_meta_file "$rel" && { echo 0 > "$out.count"; return 0; }
  [ -f "$full" ] || { echo 0 > "$out.count"; return 0; }

  # 路径 in-scope 判定
  local in_scope=0
  if echo "$rel" | grep -qE "$AGENT_NOTE_RE"; then
    in_scope=1
  elif echo "$rel" | grep -qE "$ROOT_WHITELIST_RE"; then
    # 根白名单: 只当 header 是 Agent Note 时才校验
    if head -1 "$full" 2>/dev/null | grep -qE '^#\s+Agent Note:'; then
      in_scope=1
    fi
  fi

  [ "$in_scope" -eq 1 ] || { echo 0 > "$out.count"; return 0; }

  # class 校验 (从路径)
  if echo "$rel" | grep -qE "$AGENT_NOTE_RE"; then
    local class
    class="$(echo "$rel" | sed -E "s|.*/(proposed|implemented|rejected)/([^/]+)/.*|\2|" 2>/dev/null || echo "")"
    if [ -z "$class" ] || ! echo "$class" | grep -qE "$CLASS_RE"; then
      echo "  $rel: class 段不在 6 闭集 (got: '$class', want: feature|bug-fix|architecture|process|testing|simplification)" >> "$out"
    fi
  fi

  # line1: "# Agent Note: <title>"
  local line1 line2 line3
  line1="$(head -1 "$full" 2>/dev/null || echo "")"
  if ! echo "$line1" | grep -qE '^#\s+Agent Note:'; then
    echo "  $rel: line1 必为 '# Agent Note: <title>' (got: '$line1')" >> "$out"
  fi

  # line2: "Status: <status>"
  line2="$(sed -n '2p' "$full" 2>/dev/null || echo "")"
  if ! echo "$line2" | grep -qE '^Status:\s+'; then
    echo "  $rel: line2 必为 'Status: <status>' (got: '$line2')" >> "$out"
  elif ! echo "$line2" | grep -qE "Status:\s+${STATUS_RE}\s*$"; then
    echo "  $rel: Status 值不在闭集 (got: '$line2', want: proposed|accepted|implemented|rejected)" >> "$out"
  fi

  # line3: 必空白
  line3="$(sed -n '3p' "$full" 2>/dev/null || true)"
  if [ -n "$line3" ]; then
    echo "  $rel: line3 必为空白 (got: '$line3')" >> "$out"
  fi

  # ## Problem 段必填
  if ! grep -qE '^##\s+Problem\b' "$full" 2>/dev/null; then
    echo "  $rel: 缺 '## Problem' 段" >> "$out"
  fi

  local n
  n=$(wc -l < "$out" | tr -d ' ' || echo 0)
  echo "$n" > "$out.count"
  [ "$n" -eq 0 ]
}

# ── 主流程 ────────────────────────────────────────────────────────────
cmd="${1:-}"

TMP_OUT="$(mktemp -t van-vio.XXXXXX)"
trap 'rm -rf "$TMP_OUT" "${TMP_OUT}.count"' EXIT

case "$cmd" in
  --staged|"")
    TMP_LIST="$(mktemp -t van-list.XXXXXX)"
    trap 'rm -rf "$TMP_OUT" "${TMP_OUT}.count" "$TMP_LIST"' EXIT
    git diff --cached --name-only --diff-filter=ACM -- '*.md' 2>/dev/null \
      > "$TMP_LIST" || true

    if [ ! -s "$TMP_LIST" ]; then
      echo "OK: 0 staged .md files, no agent-note validation needed"
      exit 0
    fi

    while IFS= read -r rel; do
      [ -z "$rel" ] && continue
      # 收集 violations 到 TMP_OUT (允许 0 / >0)
      set +e
      check_one_file "$rel"
      rc=$?
      set -e
      # rc=0 时也可能 violations > 0 (因 wc -l 决定); 看 .count
      cnt="$(cat "${TMP_OUT}.count" 2>/dev/null || echo 0)"
      [ "${cnt:-0}" -gt 0 ] || true
    done < "$TMP_LIST"

    if [ -s "$TMP_OUT" ]; then
      n=$(wc -l < "$TMP_OUT" | tr -d ' ')
      echo "REJECT: $n agent-note format violation(s) (EPIC-280 fail-closed):"
      cat "$TMP_OUT"
      echo ""
      echo "Fix: 参考 agent-note-adr-proposal paper, 补 class / Status / Problem"
      exit 1
    fi
    echo "OK: agent-note format PASS"
    exit 0
    ;;
  --self-test)
    SELF_TMP="$(mktemp -d -t van-selftest.XXXXXX)"
    trap 'rm -rf "$TMP_OUT" "${TMP_OUT}.count" "$SELF_TMP"' EXIT

    # 创建测试文件 (放 wt 内临时目录, 跑完清理)
    GOOD="$SELF_TMP/good.md"
    cat > "$GOOD" <<'EOF'
# Agent Note: 测试标题

Status: proposed

## Problem
测试用 problem 段.
EOF

    mkdir -p "$REPO_ROOT/agent-notes/proposed/foo"
    cat > "$REPO_ROOT/agent-notes/proposed/foo/bad-class.md" <<'EOF'
# Agent Note: bad class

Status: proposed

## Problem
x
EOF

    mkdir -p "$REPO_ROOT/agent-notes/proposed/testing"
    cat > "$REPO_ROOT/agent-notes/proposed/testing/missing-problem.md" <<'EOF'
# Agent Note: 缺 Problem

Status: implemented
EOF

    # 模拟 staged 文件列表
    TMP_LIST="$(mktemp -t van-list.XXXXXX)"
    trap 'rm -rf "$TMP_OUT" "${TMP_OUT}.count" "$SELF_TMP" "$TMP_LIST" && rm -rf "$REPO_ROOT/agent-notes"' EXIT
    echo "agent-notes/proposed/foo/bad-class.md" > "$TMP_LIST"
    echo "agent-notes/proposed/testing/missing-problem.md" >> "$TMP_LIST"
    # GOOD 不在 agent-notes 路径下, 加一个 testing/class 合规的:
    cat > "$REPO_ROOT/agent-notes/proposed/testing/good.md" <<'EOF'
# Agent Note: good testing

Status: proposed

## Problem
all good
EOF
    echo "agent-notes/proposed/testing/good.md" >> "$TMP_LIST"

    total=0
    while IFS= read -r rel; do
      [ -z "$rel" ] && continue
      set +e
      check_one_file "$rel"
      set -e
      cnt="$(cat "${TMP_OUT}.count" 2>/dev/null || echo 0)"
      total=$((total + cnt))
    done < "$TMP_LIST"

    if [ "$total" -ge 3 ]; then
      echo "OK: self-test 检出 $total 个 violations (bad-class + missing-problem 应 ≥ 3, good 应 0)"
      exit 0
    fi
    echo "FAIL: self-test 只检出 $total 个 violations, 期望 ≥ 3 (bad-class + missing-problem 应 ≥ 3)"
    cat "$TMP_OUT"
    exit 1
    ;;
  *)
    echo "Usage: $0 [--staged|--self-test]" >&2
    exit 1
    ;;
esac
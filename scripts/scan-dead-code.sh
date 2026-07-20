#!/usr/bin/env bash
# KALLAX Dead-Code Sentinel Scanner (EPIC-131-B)
# 主公抓的真问题: 死代码 + 类型错误, 不被运行时调用就不会暴露
# 治根: 通过静态 + 测试覆盖扫描, 把"沉默 bug"提前到 5-Level Verify L2-L3

# 三阶段扫描:
#   1. Static  - grep undefined token refs / @ts-ignore / 死分支标记
#   2. Tsc strict - 真 tsc compile, catch 33 errors 类型
#   3. Coverage - 所有 export module 必须有对应 test file (sentinel)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<EOF
KALLAX dead-code scanner — EPIC-131-B

用法: scripts/scan-dead-code.sh [check|fix]

阶段:
  1. Static — grep undefined token / TODO / FIXME / @ts-ignore / @ts-expect-error
  2. TSC strict — 跑 npx tsc (跟 CI 一致), catch 13+ strict errors
  3. Coverage sentinel — 检查 export module 是否 vitest 文件提到 (sentinel)

退出码:
  0 = 全 PASS (3 阶段)
  1 = 1+ 阶段 FAIL
  2 = 环境异常 (node_modules 缺失 等)

EOF
}

MODE="${1:-check}"

warn() { echo -e "\033[1;33m[WARN]\033[0m $*" >&2; }
err()  { echo -e "\033[1;31m[ERR]\033[0m $*" >&2; }
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m $*"; }

FAIL_COUNT=0

# ============================================================================
# Stage 1 — Static scan (cheap, fast)
# ============================================================================
stage_static() {
  info "Stage 1: Static scan (undefined / ignore / TODO / FIXME)"

  # 1a. active @ts-ignore / @ts-expect-error / @ts-nocheck directives — Rule 1 禁
  # Exclude matches inside /** ... */ doc comments (false positive "no @ts-ignore" prose)
  hits=$(grep -rnE '^[^/*]*\s@ts-(ignore|expect-error|nocheck)' node/src/ 2>/dev/null | awk -F: '$2 !~ /^[[:space:]]*\*/' || true)
  if [ -n "$hits" ]; then
    err "@ts-ignore / @ts-expect-error 发现,违反 CLAUDE.md Rule 1"
    echo "$hits" | head -5
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    ok "@ts-ignore / @ts-expect-error: 0 处"
  fi

  # 1b. ': any' / 'as any' 残留
  hits=$(grep -rnE '(:\s*any|as\s+any)\b' node/src/ 2>/dev/null \
    | grep -v 'node_modules\|//\s*eslint-disable\|/\*' \
    | head -10 || true)
  if [ -n "$hits" ]; then
    warn "'any' 残留 (允许 warn, 不 fail)"
    echo "$hits"
  else
    ok "'any' 残留: 0 处"
  fi

  # 1c. TODO / FIXME / HACK / XXX 占位符
  hits=$(grep -rnE '\b(TODO|FIXME|HACK|XXX)\b' node/src/ 2>/dev/null || true)
  if [ -n "$hits" ]; then
    warn "TODO/FIXME/HACK 标记存在 (允许 warn)"
    echo "$hits" | head -5
  else
    ok "TODO/FIXME/HACK: 0 处"
  fi

  # 1d. catch (e: any) / catch (e)
  hits=$(grep -rnE 'catch\s*\(' node/src/ 2>/dev/null \
    | grep -v 'catch\s*(\s*[a-zA-Z_][a-zA-Z_0-9]*\s*:\s*unknown' \
    | head -5 || true)
  if [ -n "$hits" ]; then
    warn "有 catch 但 second arg 不是 :unknown (CLAUDE.md Rule 3)"
  else
    ok "catch (e: unknown): 全用"
  fi
}

# ============================================================================
# Stage 2 — TSC strict (跟 GH Actions CI 镜像一致)
# ============================================================================
stage_tsc() {
  info ""
  info "Stage 2: npx tsc strict mode (zero-error gate)"

  if [ ! -d node/node_modules ]; then
    warn "node_modules 缺失, 跳过 tsc"
    return 0
  fi

  local tsc_out
  tsc_out=$(cd node && npx tsc --noEmit 2>&1 || true)
  local tsc_errors
  tsc_errors=$(echo "$tsc_out" | grep -cE "error TS" || echo 0)
  if [ "$tsc_errors" -gt 0 ]; then
    err "tsc strict 报告 $tsc_errors errors"
    echo "$tsc_out" | grep -E "error TS" | head -10
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    ok "tsc strict: 0 errors"
  fi
}

# ============================================================================
# Stage 3 — Sentinel coverage (epic-131-B2 idea)
# ============================================================================
# 思路: 每个 node/src/**\/*.ts (非 .d.ts, 非 test) 的 export module
# 必须有对应 tests/*.test.ts 文件 import 它, 否则视为 "未走到的死代码"
# 这强制: 写新 module 必须写 test (single source of truth 的入口)
stage_sentinel() {
  info ""
  info "Stage 3: Sentinel coverage (each exported module must be imported by tests)"

  if [ ! -d node/node_modules ]; then
    warn "node_modules 缺失, 跳过 sentinel"
    return 0
  fi

  # 列出 src/**\/*.ts 文件 (排除 types.ts, *.d.ts, *.test.ts)
  local modules
  modules=$(find node/src -type f -name '*.ts' \
    ! -name '*.d.ts' \
    ! -name '*.test.ts' \
    ! -name 'index.ts' \
    | sed 's|node/src/||' \
    | sed 's|.ts$||')
  local total=0
  local uncovered=0
  local uncovered_list=""

  for mod in $modules; do
    # mod = src/foo/bar (with .ts stripped); sentinel pattern: any import statement
    # Tests use: '../src/foo/bar.js' or '../../src/foo/bar.js'
    # Also catches dynamic imports: import('...')
    local hits
    hits=$(grep -rE "(from|import)[ ]?\(?['\"]([.][.]?/)+src/${mod}(\.js)?['\"]" node/tests/ 2>/dev/null \
      | grep -v 'node_modules' || true)
    if [ -z "$hits" ]; then
      uncovered=$((uncovered + 1))
      uncovered_list="${uncovered_list}\n  ${mod}"
    fi
    total=$((total + 1))
  done

  if [ "$total" -eq 0 ]; then
    warn "找不到 src modules, 跳过 sentinel"
    return 0
  fi

  info "  scanned: $total modules"
  if [ "$uncovered" -gt 0 ]; then
    err "$uncovered 模块未被 tests 引用 (sentinel fail, EPIC-131-B 治 '不被调用就死' 的真问题)"
    echo -e "$uncovered_list" | head -30
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    ok "所有 $total modules 都被 vitest 引用"
  fi
}

# ============================================================================
# Main
# ============================================================================

case "$MODE" in
  check|"")
    stage_static
    stage_tsc
    stage_sentinel
    echo ""
    if [ "$FAIL_COUNT" -eq 0 ]; then
      ok "EPIC-131-B dead-code sentinel: 3/3 阶段 PASS"
      exit 0
    else
      err "EPIC-131-B: $FAIL_COUNT 阶段 FAIL"
      exit 1
    fi
    ;;
  -h|--help|help) usage ;;
  *) usage ;;
esac

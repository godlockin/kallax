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
  0 = 全 PASS (3 阶段都实际跑了)
  1 = 1+ 阶段 FAIL (真发现违规)
  2 = 环境异常 (BLOCKED-env: node_modules 缺失 等, 阶段被跳过)

修复 BLOCKED-env: cd node && npm install
  (P0-7 治理: 禁止 BLOCKED 时谎报 '3/3 PASS' + exit 0)
EOF
}

MODE="${1:-check}"

warn() { echo -e "\033[1;33m[WARN]\033[0m $*" >&2; }
err()  { echo -e "\033[1;31m[ERR]\033[0m $*" >&2; }
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m $*"; }

FAIL_COUNT=0
BLOCKED_COUNT=0  # P0-7: 阶段被跳过 (env-blocker, 不算 PASS, exit 2)
STAGE_RAN=0       # 实际跑的阶段数 (真跑过的, 用来精确报告 N/M PASS)
STAGE_TOTAL=3     # 总阶段数

# ============================================================================
# Stage 1 — Static scan (cheap, fast)
# ============================================================================
stage_static() {
  info "Stage 1: Static scan (undefined / ignore / TODO / FIXME)"
  STAGE_RAN=$((STAGE_RAN + 1))

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

  # 1b. ': any' / 'as any' ACTIVE type usage (exclude JSDoc comments)
  hits=$(grep -rnE '(:\s*any\b|as\s+any\b)' node/src/ 2>/dev/null \
    | grep -vE '^\S+:\s*[0-9]+:\s*\*' \
    | head -5 || true)
  if [ -n "$hits" ]; then
    warn "'any' 残留 in code (allow warn)"
    echo "$hits"
  else
    ok "'any' 残留 in code: 0 active (JSDoc comments allowed)"
  fi

  # 1c. ACTIVE TODO / FIXME / HACK (exclude: regex patterns, string literals, enum values)
  # Only flag // <comment> markers indicating unfinished work
  hits=$(grep -rnE '//\s*(TODO|FIXME|HACK|XXX)\b' node/src/ 2>/dev/null \
    | grep -v "TODO: 'todo'\|TODO:\\s*'todo'\|FIXME:\\s*'fixme'" \
    | head -5 || true)
  if [ -n "$hits" ]; then
    warn "real TODO/FIXME/HACK markers in comments (allow review)"
    echo "$hits"
  else
    ok "real TODO/FIXME/HACK in code comments: 0"
  fi

  # 1d. catch (e: any) / catch (e) — only try { } catch (e) form, not Promise.catch
  hits=$(grep -rnE 'catch\s*\(\s*[a-zA-Z_][a-zA-Z_0-9]*\s*(?::\s*[a-zA-Z]+)?\s*\)' node/src/ 2>/dev/null \
    | grep -v 'catch\s*(\s*[a-zA-Z_][a-zA-Z_0-9]*\s*:\s*unknown' \
    | grep -v '\.catch(' \
    | head -5 || true)
  if [ -n "$hits" ]; then
    warn "有 try { } catch 但 second arg 不是 :unknown (CLAUDE.md Rule 3)"
    echo "$hits"
  else
    ok "try { } catch (e: unknown): 全用"
  fi
}

# ============================================================================
# Stage 2 — TSC strict (跟 GH Actions CI 镜像一致)
# ============================================================================
stage_tsc() {
  info ""
  info "Stage 2: npx tsc strict mode (zero-error gate)"

  if [ ! -d node/node_modules ]; then
    err "[BLOCKED-env] Stage 2 SKIPPED: node/node_modules 缺失"
    echo "[BLOCKED-env] 修复: cd node && npm install  (better-sqlite3 native build 在 Node 26.5.0 可能 FAIL, 跟 EPIC-154 ticket.json:75 一致)"
    BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
    return 0
  fi
  STAGE_RAN=$((STAGE_RAN + 1))

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
    err "[BLOCKED-env] Stage 3 SKIPPED: node/node_modules 缺失"
    echo "[BLOCKED-env] 修复: cd node && npm install"
    BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
    return 0
  fi
  STAGE_RAN=$((STAGE_RAN + 1))

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
# Stage 4 — Shell dead-function 报告 (EPIC-249)
# ============================================================================
# 起因: EPIC-247 在 scripts/lib/workspace.sh 找到无限递归 bug, 存活很久没被发现,
#   因为 Stage 1-3 只扫 node/src/** 的 TS, 不扫 scripts/**/*.sh.
#
# 为什么只报告不 fail:
#   实测 scripts/lib/*.sh 有 31/60 函数 0 外部引用. 但这里面混了几类:
#     - 真 dead code (如 workspace_* 全家, EPIC-247 已确认 0 调用方)
#     - 仅内部互调的 helper (grep 不出来但不是死的)
#     - 给 source 用的 public API (调用方在别的仓库 / 未来才用)
#   区分需要人判断, 强制 fail 会有大量误报 → 只报告, 让人看.
stage_shell_report() {
  info ""
  info "Stage 4: Shell dead-function 报告 (EPIC-249, 不 fail)"

  local total=0
  local dead=0
  local report=""

  local f
  for f in scripts/lib/*.sh; do
    [ -f "$f" ] || continue
    local funcs fn n
    funcs=$(grep -oE '^[a-z_][a-z0-9_]*\(\)' "$f" 2>/dev/null | tr -d '()' || true)
    [ -n "$funcs" ] || continue
    local file_dead=0
    local file_total=0
    local file_list=""
    for fn in $funcs; do
      file_total=$((file_total + 1))
      total=$((total + 1))
      # 找 fn 的所有出现 (file:line:content), 排除定义行本身 (^fn())
      # 注 1: 用 \b 边界; 字符类 [^a-zA-Z0-9_(] 会漏掉行尾/定义行
      # 注 2: 不能写 `... | wc -l | tr -d ' ' || echo 0` —
      #       grep 无匹配时返回 1, `||` 触发 echo 0, 而 wc 已经输出了 "0",
      #       结果 n="0\n0" 多行, [ "$n" -eq 0 ] 判断失败 → 误报"有引用".
      #       用 `|| true` 只吞退出码, 不追加输出.
      n=$(grep -rnE "\\b${fn}\\b" --include='*.sh' --include='*.ts' . 2>/dev/null \
          | grep -v 'node_modules' \
          | grep -vE "^[^:]+:[0-9]+:${fn}\\(\\)" \
          | wc -l | tr -d ' ' || true)
      n=${n:-0}
      if [ "$n" -eq 0 ] 2>/dev/null; then
        file_dead=$((file_dead + 1))
        dead=$((dead + 1))
        file_list="${file_list} ${fn}"
      fi
    done
    if [ "$file_dead" -gt 0 ] 2>/dev/null; then
      report="${report}
  $(basename "$f"): ${file_dead}/${file_total} 无外部引用 →${file_list}"
    fi
  done

  info "  scanned: $total shell functions in scripts/lib/"
  if [ "$dead" -gt 0 ]; then
    warn "$dead/$total shell 函数无外部引用 (报告, 不 fail — 需人判断是否真 dead)"
    echo -e "$report"
    echo ""
    echo "  判断方法: 逐个 grep 确认是否仅内部互调 / 是否 public API"
    echo "  真 dead 的处理: 删除 或 加 test 覆盖 (跟 Stage 3 TS sentinel 同原则)"
  else
    ok "所有 $total shell 函数都有外部引用"
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
    stage_shell_report
    echo ""
    # P0-7 治理: 区分 FAIL (exit 1) vs BLOCKED-env (exit 2) vs PASS (exit 0)
    # 不再谎报 '3/3 PASS' 当实际只跑了 1/3 阶段
    if [ "$BLOCKED_COUNT" -gt 0 ]; then
      err "EPIC-131-B dead-code sentinel: BLOCKED-env ($BLOCKED_COUNT 阶段跳过, $STAGE_RAN/$STAGE_TOTAL 实际跑)"
      err "FAIL_COUNT=$FAIL_COUNT (真违规), BLOCKED_COUNT=$BLOCKED_COUNT (env-blocker)"
      err "修复 env-blocker: cd node && npm install"
      exit 2
    elif [ "$FAIL_COUNT" -gt 0 ]; then
      err "EPIC-131-B dead-code sentinel: $FAIL_COUNT 阶段 FAIL ($STAGE_RAN/$STAGE_TOTAL 阶段实跑)"
      exit 1
    else
      ok "EPIC-131-B dead-code sentinel: $STAGE_RAN/$STAGE_TOTAL 阶段 PASS"
      exit 0
    fi
    ;;
  -h|--help|help) usage ;;
  *) usage ;;
esac

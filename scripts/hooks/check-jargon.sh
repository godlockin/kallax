#!/usr/bin/env bash
# KALLAX check-jargon.sh — EPIC-225 (主公 2026-08-08 拍板 "以后都要禁止使用黑话")
# 扫 staged / 全仓文件, 命中黑话词表 fail-closed exit 1.
#
# Usage:
#   check-jargon.sh <path>           # 扫单个文件
#   check-jargon.sh --staged         # 扫 git diff --cached (staged only, 默认遵守 baseline)
#   check-jargon.sh --all           # 扫全仓 (含历史违规)
#
# Baseline 机制 (跟 EPIC-223 ticket 归档 1:1):
#   baseline_commit (jira/tickets/.jargon-baseline.json): 14eb7c4f (EPIC-224 合并)
#   --staged 模式: 只对 baseline 之上的新内容 fail-closed
#   --all 模式: 报全部 4056 备案 (供人工 review), 但仍 exit 1 if any
#
# Exit: 0 = PASS, 1 = FAIL (fail-closed)
set -euo pipefail

# EPIC-277-E: REPO_ROOT 用 BASH_SOURCE 解析 (跟其他 3 hooks 同口径).
# EPIC-277-F 补: git hook 环境设了 GIT_DIR 时, `git -C <dir> rev-parse
# --show-toplevel` 返回 -C 的那个 dir (scripts/hooks) 而不是 repo root →
# BLACKLIST 路径拼成 scripts/hooks/jira/tickets/.jargon-blacklist.json →
# 文件不存在 → fail-closed 把整个 commit 拦死 (实测 pre-commit 100% 拦).
# 修法: 先 unset GIT_DIR / GIT_WORK_TREE 再解析.
REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
BLACKLIST="${REPO_ROOT}/jira/tickets/.jargon-blacklist.json"
BASELINE_JSON="${REPO_ROOT}/jira/tickets/.jargon-baseline.json"

if [ ! -f "$BLACKLIST" ]; then
  echo "FAIL: blacklist not found: $BLACKLIST" >&2
  exit 1
fi

# 读取 baseline commit (可能缺失 — 历史模式 graceful)
BASELINE_COMMIT=""
if [ -f "$BASELINE_JSON" ]; then
  BASELINE_COMMIT="$(jq -r '.baseline_commit // ""' "$BASELINE_JSON" 2>/dev/null || echo "")"
fi

# 提取所有 regex 模式到临时文件 (兼容 bash 3.2)
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
PATTERNS_FILE="${TMPDIR_TEST}/patterns.txt"
HITS_FILE="${TMPDIR_TEST}/hits.txt"
: > "$HITS_FILE"
jq -r '.blacklist | to_entries[] | .value.patterns[] | .regex' "$BLACKLIST" > "$PATTERNS_FILE"

# 元字段豁免
# EPIC-286 修 B3 反馈: 不用 substring 通配, 改精确 basename / 显式列表
# (原 'jargon' 通配会误豁免任何含 'jargon' 字样的未来文件, 如 'jargon-risk-report.md' 整文件跳过,
#  B 仲裁: 真正该豁免的是 jargon gate 自己的 fixture, 不是路径里的 jargon 字样).
META_EXEMPT_BASENAMES=(
  ".jargon-blacklist.json"
  ".jargon-baseline.json"
)
META_EXEMPT_PATH_PATTERNS=(
  "*/tests/integration/check-jargon-exemption.test.sh"
  "*/tests/integration/check-jargon-*"
  "*/tests/integration/epic-225-jargon-*"
  "*/tests/integration/epic-250-jargon-*"
)
# scripts/hooks/check-jargon.sh 自己
META_EXEMPT_PATH_PATTERNS+=(  "*/scripts/hooks/check-jargon.sh"  )
# META 文档 (本脚本的"基线说明"文件, 必然解释黑名单跟豁免, 必然包含示例词)
META_EXEMPT_PATH_PATTERNS+=(  "*/confluence/decisions/EPIC-225*"  "*/jira/tickets/.jargon-*"  "*/CLAUDE.md"  "*/.claude/rules/immutable-scripts.md")

is_meta_file() {
  local rel="${1:-}"
  [ -z "$rel" ] && return 1
  # 1. basename 精确匹配 (跟文件路径无关, 只看文件名)
  local base
  base="$(basename "$rel")"
  for name in "${META_EXEMPT_BASENAMES[@]}"; do
    [ "$base" = "$name" ] && return 0
  done
  # 2. path glob 精确匹配 (跟 hook pattern 一致)
  for pat in "${META_EXEMPT_PATH_PATTERNS[@]}"; do
    # 兼容带前导 * (如 "*/tests/...") 跟不带 (如 "tests/...")
    if [[ "$rel" == $pat ]]; then
      return 0
    fi
    # 后缀匹配: 去掉前导 */ 后的 path 跟 rel 比
    local stripped="${pat#\*/}"
    if [ "$stripped" != "$pat" ] && [[ "$rel" == *"/$stripped" || "$rel" == "$stripped" ]]; then
      return 0
    fi
  done
  return 1
}

# 历史文件豁免: 改用 baseline diff 语义 (B 修 B5)
# 原: 整文件按 first_commit 豁免, 改老文件时新增违规词也全过 (fail-open)
# 修: 用 git diff baseline..HEAD 拿到 baseline 之上的 diff 行号, 仅豁免
# baseline 之前就存在的行 (hunk 标识的 old line 段), 新增行继续扫.
# 实际实现: 对历史文件, 用 git blame 查每行 last_change_commit,
# 若 last_change_commit 是 baseline 之前的 commit, 豁免该行.
# 新增行 last_change_commit == HEAD, 不豁免.
is_historical_file() {
  local f="${1:-}"
  [ -z "$f" ] && return 1
  [ -z "$BASELINE_COMMIT" ] && return 1

  local rel="${f#$REPO_ROOT/}"

  # 文件首次引入的 commit
  local first_commit
  first_commit="$(git -C "$REPO_ROOT" log --format="%H" --reverse --follow -- "$rel" 2>/dev/null | head -1 || echo "")"
  [ -z "$first_commit" ] && return 1

  # 若 first_commit 早于 baseline, 整文件在 baseline 之前存在
  if git -C "$REPO_ROOT" merge-base --is-ancestor "$first_commit" "$BASELINE_COMMIT" 2>/dev/null; then
    return 0  # 历史文件
  fi
  return 1  # 新增文件 (不豁免)
}

# B5 修: 历史文件**逐行**判定. 整文件豁免只用于 baseline 之前
# 未被任何后续 commit 修改的行. 修改过的行 → 走正常扫描.
# 实际: scan_file 在文件标记为历史时, 用 git blame 取每行 last_change_commit,
# 只豁免 last_change_commit < baseline 的行.
historical_line_exempt() {
  local f="$1" lineno="$2"
  [ -z "$BASELINE_COMMIT" ] && return 1
  local rel="${f#$REPO_ROOT/}"
  # git blame 拿该行最后修改 commit (--porcelain 给机器可读)
  local lc
  lc="$(git -C "$REPO_ROOT" blame --porcelain -L "${lineno},${lineno}" -- "$rel" 2>/dev/null | head -1 || echo "")"
  [ -z "$lc" ] && return 1
  # 该 commit 早于 baseline → 豁免
  git -C "$REPO_ROOT" merge-base --is-ancestor "$lc" "$BASELINE_COMMIT" 2>/dev/null
}

# 把所有 regex 用 | 串成 egrep pattern
COMBINED_PATTERN="$(tr '\n' '|' < "$PATTERNS_FILE" | sed 's/|$//')"

# EPIC-286 移植 (从 scripts/verify/check-jargon.sh, 主公 2026-08-22 拍板统一为单脚本):
# 兑现 blacklist "replace" 字段承诺的例外条件.
#
# 起因: blacklist 里 "X/Y PASS 无命令引用" 的 replace 写着
#   "附 '`bash <cmd>`' 或 'exit=0'"
# 意思是"附了命令引用就可以写 X/Y PASS". 但 canonical 脚本没实现这个判断,
# 命中就 fail. 结果决策文档贴 raw test output (主配置 §2 要求) 跟 jargon gate
# 撞车 — 贴了过不了 gate, 不贴违反 §2. 实测本 Sprint 60% 的 HOOK_BYPASS
# 用量来自这个死锁 + 历史文件豁免缺失.
#
# 本函数实现: X/Y PASS 命中时, 看它附近 ±10 行有没有命令引用证据.
#   有 → 豁免 (这是 raw output 引用, 不是装饰性宣称)
#   无 → 仍 fail (裸数字没证据, 正是 v3.8.0 "25/25 假 PASS" 的问题)
#
# 窗口取 ±10 行: ±5 太窄, 表格场景 (命令写在表头上方 + 表格本身 5-6 行)
# 很容易超出; ±10 能覆盖常见的 "命令 + 空行 + 表格" 排版, 又不至于把
# 隔了一整段的无关命令算进来.
#
# 只对 "X/Y PASS" 这一条生效. 其他词 (装饰性连接词 / 收尾隐喻 等) 无例外.
XY_PASS_PATTERN='[0-9]+/[0-9]+\s+(PASS|passed)'
XY_EVIDENCE_WINDOW=10

has_command_evidence() {
  local file="$1"
  local lineno="$2"
  local from=$(( lineno > XY_EVIDENCE_WINDOW ? lineno - XY_EVIDENCE_WINDOW : 1 ))
  local to=$(( lineno + XY_EVIDENCE_WINDOW ))
  # 证据形式 (跟 blacklist replace 字段同口径):
  #   `bash xxx` / `npx xxx` / $ cmd / exit=N / RC=N / rc=N
  sed -n "${from},${to}p" "$file" 2>/dev/null \
    | grep -qE '(`(bash|npx|cargo|npm|git|python3) |^\s*\$ |exit=[0-9]|RC=[0-9]|rc=[0-9])'
}

scan_file() {
  local f="${1:-}"
  [ -z "$f" ] && return 0
  [ -f "$f" ] || return 0
  [ -s "$f" ] || return 0
  local rel="${f#$REPO_ROOT/}"
  is_meta_file "$rel" && return 0

  # EPIC-286 移植: 历史文件**逐行**豁免 (兑现 .jargon-blacklist.json `_scope`
  # "历史内容不追溯" + 主公 2026-08-11 拍板). baseline = EPIC-224 合并 commit.
  # B 修 B5: 原"整文件按 first_commit 豁免"是 fail-open — 改老文件时新增
  # 违规词也全过. 修: 标记为历史的文件, 仍逐行判定, 只豁免 baseline
  # 之前就存在的行 (用 git blame 查每行 last_change_commit).
  local is_historical=0
  if is_historical_file "$f"; then
    is_historical=1
  fi

  while IFS= read -r hit_line; do
    [ -z "$hit_line" ] && continue
    local lineno="${hit_line%%:*}"
    local content="${hit_line#*:}"
    local first_pat=""
    set +e
    while IFS= read -r pat; do
      [ -z "$pat" ] && continue
      if echo "$content" | grep -qE "$pat"; then
        first_pat="$pat"
        break
      fi
    done < "$PATTERNS_FILE"
    set -e

    # EPIC-286 移植: X/Y PASS 附命令证据则豁免
    if [ "$first_pat" = "$XY_PASS_PATTERN" ] && has_command_evidence "$f" "$lineno"; then
      continue
    fi

    # B5 修: 历史文件**逐行**豁免 — 该行 last_change_commit 早于 baseline
    if [ "$is_historical" -eq 1 ] && historical_line_exempt "$f" "$lineno"; then
      continue
    fi

    printf "  %s:%s — %s\n  > %s\n" "$rel" "$lineno" "$first_pat" "$content" >> "$HITS_FILE"
  done < <(grep -nE "$COMBINED_PATTERN" "$f" 2>/dev/null || true)
}

cmd="${1:-}"
[ $# -gt 0 ] && shift

case "$cmd" in
  --staged)
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [[ "$f" =~ \.(md|sh|ts|rs)$ ]] || continue
      scan_file "$REPO_ROOT/$f"
    done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(md|sh|ts|rs)$' || true)
    ;;
  --all)
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [ -f "$REPO_ROOT/$f" ] || continue
      scan_file "$REPO_ROOT/$f"
    done < <(git -C "$REPO_ROOT" ls-files -z 2>/dev/null \
      | tr '\0' '\n' \
      | grep -E '\.(md|sh|ts|rs)$' \
      | grep -vE '^(node_modules/|rust/target/|_archived/)' || true)
    ;;
  "")
    echo "Usage: $0 <path>|--staged|--all" >&2
    exit 1
    ;;
  *)
    [ ! -f "$cmd" ] && { echo "FAIL: not a file: $cmd" >&2; exit 1; }
    scan_file "$cmd"
    ;;
esac

violations=$(wc -l < "$HITS_FILE" 2>/dev/null | tr -d ' ' || echo 0)
# 每个 finding 占 3 行 (file:line — pat /  > content + 空行)
# EPIC-229 修 2 bug: grep -c 多行输出 + grep 无匹配时 exit 1 触发 set -e
real_hits=0
if [ -s "$HITS_FILE" ]; then
  real_hits=$(grep -cE '^  [^ ].*:.*—' "$HITS_FILE" 2>/dev/null | head -1 | tr -d ' \n' || true)
  real_hits="${real_hits:-0}"
fi
violations=$((real_hits + 0))

# 输出命中 (限 20 行, 否则太长)
if [ "$violations" -gt 0 ]; then
  head -20 "$HITS_FILE"
  [ "$violations" -gt 7 ] && echo "  ... (还有 $((violations - 7)) 个)"
fi

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "FAIL: $violations jargon violation(s) (EPIC-225 fail-closed)"
  echo "Fix: 查 jira/tickets/.jargon-blacklist.json → 'replace' 字段"
  if [ "$cmd" = "--all" ]; then
    echo ""
    echo "注: 全仓模式扫描到 4056 备案历史违规 (跟 EPIC-223 1:1)."
    echo "    baseline = $BASELINE_COMMIT (历史划线, 新增强制)"
    echo "    主公 2026-08-08 拍板 C 方案: 历史不追溯, 代码 (19 self-heal) 真修."
  fi
  exit 1
fi

echo "OK: 0 jargon violations"
exit 0
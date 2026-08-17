#!/usr/bin/env bash
# next-epic-id.sh — 查下一个可用的 EPIC 编号
#
# 起因 (EPIC-259): EPIC-245 的计划文档在落后 21 commits 的本地 base 上数 ticket
# 目录, 算出"最大编号 244", 于是把一张卡编成 EPIC-248 — 而远端 EPIC-248 早已是
# 另一张卡并且 done. 编号双重占用, 靠人肉数目录必然复发.
#
# 编号来源 4 处 (少查任何一处都可能撞号):
#   1. 远端 ticket 目录 (jira/tickets/EPIC-NNN)
#   2. 远端 confluence/decisions/ 文件名 — EPIC-178~222 这 45 个编号只有决策文档
#      没有 ticket.json (见 jira/tickets/.archive-baseline.json), 漏掉这处会让
#      9 个已用编号报 FREE
#   3. 本地 ticket 目录 (worktree 里刚建还没提交的卡)
#   4. branch 名 (有人在做但还没建卡)
#
# 默认**不** fetch — 读的是本地 remote-tracking ref, 可能陈旧.
# 想让它先 fetch: 加 --fetch, 或设 KALLAX_NUMBERING_FETCH=1.
# 不 fetch 时会打印 ref 的提交时间, 自己判断新旧.
#
# 用法:
#   bash scripts/next-epic-id.sh              # 下一个可用编号
#   bash scripts/next-epic-id.sh --fetch      # 先 git fetch 再查 (推荐建卡前跑)
#   bash scripts/next-epic-id.sh --check 259  # 检查 259 是否空闲
#   bash scripts/next-epic-id.sh --list-tail  # 列最后 10 个已占编号
#
# 退出码: 0 = 成功/空闲 | 1 = 编号已占用 | 2 = 用法错误 | 3 = 无法确定编号

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# --show-toplevel 而非 BASH_SOURCE 推导 — worktree 里 BASH_SOURCE 会解析到主仓 (EPIC-227)
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/..")"

REMOTE_REF="${KALLAX_NUMBERING_REF:-origin/miao}"
DO_FETCH="${KALLAX_NUMBERING_FETCH:-0}"

# EPIC 编号 regex. 严格 3 位 — 放宽成 {3,} 会把文件名里的日期吃进来
# (实测: retrospective-batch-8-EPIC-2026-08-12.md 被解析成 EPIC-2026).
# 编号跑到 1000 时这里要改, 同时改 to_decimal 和输出的 %03d.
# 大小写都匹配 — 有历史文件名用小写 epic-188-retrospective-*.md
EPIC_NUM_RE='[Ee][Pp][Ii][Cc]-[0-9]{3}([^0-9]|$)'

# 编号位数上限断言: 当前约定 3 位. 若某天出现 4 位编号, 这个脚本会静默截断
# → 系统性撞号. 用 --audit 可查是否已出现超 3 位的编号.
EPIC_OVERFLOW_RE='[Ee][Pp][Ii][Cc]-[0-9]{4,}'

usage() {
  cat <<'EOF'
Usage: next-epic-id.sh [--fetch] [--check <N> | --list-tail | --help]

  (无参数)        输出下一个可用 EPIC 编号
  --check <N>    检查编号 N 是否空闲 (exit 0 空闲 / 1 已占用)
  --list-tail    列最后 10 个已占编号
  --fetch        先 git fetch 再查 (建卡前推荐)

编号来源: 远端 ticket 目录 + 远端 confluence/decisions/ + 本地 ticket 目录 + branch 名

环境变量:
  KALLAX_NUMBERING_REF    查询 ref (默认 origin/miao)
  KALLAX_NUMBERING_FETCH  设 1 等同 --fetch

退出码: 0 成功/空闲 | 1 已占用 | 2 用法错误 | 3 无法确定编号
EOF
}

# 把任意编号输入归一成十进制整数.
# 关键: 10# 前缀强制十进制 — 否则 015 会被当八进制解析成 13.
to_decimal() {
  local raw="$1"
  # 去掉前导零后如果空了 (输入是 0 / 00 / 000), 归成 0
  local stripped="${raw#"${raw%%[!0]*}"}"
  if [ -z "$stripped" ]; then
    echo 0
    return 0
  fi
  echo "$((10#$stripped))"
}

# 各来源分别取. 注意: 不能把这些放进一个函数再用 $(fn) 调用 —
# 命令替换开子 shell, 函数里的变量赋值传不出来 (写本脚本时踩过).
src_remote_tickets() {
  git -C "$REPO_ROOT" ls-tree -d --name-only "$REMOTE_REF" -- jira/tickets/ 2>/dev/null \
    | grep -oE "$EPIC_NUM_RE" || true
}

# decisions 是文件不是目录, 用 -r 递归. EPIC-178~222 这 45 个编号只有决策文档
# 没有 ticket.json (见 .archive-baseline.json), 漏这处会让已用编号报 FREE.
#
# 只扫文件名, 不扫正文 — 扫正文会把"提到别的卡"当成占用 (决策文档大量交叉引用).
# 代价: 只在正文出现的编号扫不到 (如 EPIC-246 只在 EPIC-247 文档正文里被提及).
# 这是有意的取舍, 不是遗漏.
src_remote_decisions() {
  git -C "$REPO_ROOT" ls-tree -r --name-only "$REMOTE_REF" -- confluence/decisions/ 2>/dev/null \
    | grep -oE "$EPIC_NUM_RE" || true
}

src_local_tickets() {
  if [ -d "$REPO_ROOT/jira/tickets" ]; then
    ls -1 "$REPO_ROOT/jira/tickets" 2>/dev/null | grep -oE "$EPIC_NUM_RE" || true
  fi
}

src_branches() {
  git -C "$REPO_ROOT" for-each-ref --format='%(refname:short)' 2>/dev/null \
    | grep -oE "$EPIC_NUM_RE" || true
}

count_lines() {
  # grep -c 无匹配时已输出 0 且 rc=1 — 用 || true 吞退出码, 不能用 || echo 0
  # (否则变量成 "0\n0", EPIC-254 清了全仓 32 处这个坑)
  printf '%s' "$1" | grep -c . || true
}

# 归一成十进制整数再排序 — 避免 "015" 和 "15" 被当成两个不同编号
# 只取 3 位数字, 跟 EPIC_NUM_RE 同口径
# 防幽灵占位: 用 grep -oE 抓 EPIC- + 3 位数字 + 边界 (非数字或行尾), 然后 sed
# 切数字部分. 不能用 ([0-9]+|$) 包含 4 位, 因为 EPIC-1234 整行也不匹配 —
# 1234 后面没有非数字. 同样 EPIC-2026-08-12 也不匹配 (2026 后面是 -).
# sed 再去掉可能的边界字符 (grep -oE 把 ([^0-9]) 也带进输出).
normalize_all() {
  printf '%s\n%s\n%s\n%s\n' "$1" "$2" "$3" "$4" \
    | grep -oiE 'EPIC-[0-9]{3}([^0-9]|$)' \
    | sed -E 's/^EPIC-([0-9]{3})([^0-9]|$)/\1/i' \
    | while read -r n; do
        [ -n "$n" ] && to_decimal "$n"
      done \
    | sort -un
}

# 检查有没有出现超过 3 位的编号 — 那意味着本脚本的 3 位假设已经失效
check_overflow() {
  local hits
  hits="$( { git -C "$REPO_ROOT" ls-tree -d --name-only "$REMOTE_REF" -- jira/tickets/ 2>/dev/null || true
             ls -1 "$REPO_ROOT/jira/tickets" 2>/dev/null || true
           } | grep -oE "$EPIC_OVERFLOW_RE" | sort -u || true )"
  if [ -n "$hits" ]; then
    echo "WARN: 发现超过 3 位的 EPIC 编号 — 本脚本的 3 位假设已失效, 会静默截断:" >&2
    printf '%s\n' "$hits" | sed 's/^/  /' >&2
    echo "  修法: 改 EPIC_NUM_RE / normalize_all / 所有 %03d 格式串" >&2
    return 1
  fi
  return 0
}

resolve_ref() {
  if [ "$DO_FETCH" = "1" ]; then
    echo "fetching origin ..." >&2
    if ! git -C "$REPO_ROOT" fetch origin >/dev/null 2>&1; then
      echo "WARN: git fetch origin 失败 — 继续用本地缓存 ref (可能陈旧)" >&2
    fi
  fi

  if ! git -C "$REPO_ROOT" rev-parse --verify "$REMOTE_REF" >/dev/null 2>&1; then
    echo "ERROR: ref not found: $REMOTE_REF" >&2
    echo "  先跑 git fetch origin (或加 --fetch), 或用 KALLAX_NUMBERING_REF 指定别的 ref" >&2
    return 3
  fi
  return 0
}

# 不 fetch 时提示 ref 有多旧 — 让"本地落后"这件事可见, 而不是静默给错答案
warn_ref_age() {
  if [ "$DO_FETCH" = "1" ]; then
    return 0
  fi
  local ref_date
  ref_date="$(git -C "$REPO_ROOT" log -1 --format='%ci' "$REMOTE_REF" 2>/dev/null || true)"
  if [ -n "$ref_date" ]; then
    echo "note: 读本地缓存 ref $REMOTE_REF (最新 commit: $ref_date), 未 fetch. 建卡前建议加 --fetch" >&2
  fi
}

MODE="next"
CHECK_N=""

# 先剥 --fetch (可跟其他参数组合)
ARGS=()
for a in "$@"; do
  case "$a" in
    --fetch) DO_FETCH=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --check)
    MODE="check"
    CHECK_N="${2:-}"
    if ! printf '%s' "$CHECK_N" | grep -qE '^[0-9]+$'; then
      echo "ERROR: --check 需要一个非负整数, 收到: '${CHECK_N}'" >&2
      usage >&2
      exit 2
    fi
    # 位数上限: KALLAX 编号约定 3 位. 4 位及以上属用法错 (超过 3 位前提
    # 下 release 才能放开, 见 EPIC-259 backlog).
    if [ "${#CHECK_N}" -gt 3 ]; then
      echo "ERROR: --check 需要 3 位编号 (1-999), 收到 ${#CHECK_N} 位: '$CHECK_N'" >&2
      exit 2
    fi
    if [ "${3:-}" != "" ]; then
      echo "ERROR: --check 只接受 1 个参数, 多余的: '${3}'" >&2
      exit 2
    fi
    ;;
  --list-tail)
    MODE="list"
    if [ "${2:-}" != "" ]; then
      echo "ERROR: --list-tail 不接受参数, 多余的: '${2}'" >&2
      exit 2
    fi
    ;;
  "") MODE="next" ;;
  *) echo "ERROR: 未知参数: $1" >&2; usage >&2; exit 2 ;;
esac

if ! resolve_ref; then
  exit 3
fi
warn_ref_age

RAW_REMOTE_TICKETS="$(src_remote_tickets)"
RAW_REMOTE_DECISIONS="$(src_remote_decisions)"
RAW_LOCAL_TICKETS="$(src_local_tickets)"
RAW_BRANCHES="$(src_branches)"

SRC_COUNT_REMOTE_TICKETS="$(count_lines "$RAW_REMOTE_TICKETS")"
SRC_COUNT_REMOTE_DECISIONS="$(count_lines "$RAW_REMOTE_DECISIONS")"
SRC_COUNT_LOCAL_TICKETS="$(count_lines "$RAW_LOCAL_TICKETS")"
SRC_COUNT_BRANCHES="$(count_lines "$RAW_BRANCHES")"

# 3 位假设失效时告警 (不阻塞, 但让人看到)
check_overflow || true

USED="$(normalize_all "$RAW_REMOTE_TICKETS" "$RAW_REMOTE_DECISIONS" "$RAW_LOCAL_TICKETS" "$RAW_BRANCHES")"

# 远端来源单独为 0 就报错 — 不等三处全空.
# 理由: 远端是权威源. 它为 0 说明 ref 错了或 repo 结构变了, 此时靠本地目录 +
# branch 名给出的编号可能撞号. 宁可 exit 3 让人去查, 不给可能错的建议.
REMOTE_TOTAL=$(( SRC_COUNT_REMOTE_TICKETS + SRC_COUNT_REMOTE_DECISIONS ))
if [ "$REMOTE_TOTAL" -eq 0 ]; then
  echo "ERROR: 远端 ref '$REMOTE_REF' 上 0 个编号来源" >&2
  echo "  jira/tickets/: $SRC_COUNT_REMOTE_TICKETS 项, confluence/decisions/: $SRC_COUNT_REMOTE_DECISIONS 项" >&2
  echo "  预期两处合计至少几十个. 不输出编号建议, 避免撞号." >&2
  echo "  排查: git -C <repo> ls-tree -d --name-only $REMOTE_REF -- jira/tickets/" >&2
  exit 3
fi

if [ -z "$USED" ]; then
  echo "ERROR: 0 个已占编号 — 查询逻辑可能坏了 (ref=$REMOTE_REF)" >&2
  exit 3
fi

case "$MODE" in
  list)
    echo "已占编号 (最后 10 个; 来源: 远端 ticket $SRC_COUNT_REMOTE_TICKETS + 远端 decisions $SRC_COUNT_REMOTE_DECISIONS + 本地 ticket $SRC_COUNT_LOCAL_TICKETS + branch $SRC_COUNT_BRANCHES):"
    printf '%s\n' "$USED" | tail -10 | while read -r n; do
      printf '  EPIC-%03d\n' "$n"
    done
    ;;
  check)
    CHECK_DEC="$(to_decimal "$CHECK_N")"
    # USED 已是十进制整数, CHECK_DEC 也是 — 同口径比对
    if printf '%s\n' "$USED" | grep -qx "$CHECK_DEC"; then
      printf 'OCCUPIED: EPIC-%03d 已占用\n' "$CHECK_DEC"
      # 指出占在哪. 用 0* 兼容 3 位零填充与更多位数
      PADDED="$(printf '%03d' "$CHECK_DEC")"
      git -C "$REPO_ROOT" ls-tree -d --name-only "$REMOTE_REF" -- jira/tickets/ 2>/dev/null \
        | grep -iE "EPIC-0*${PADDED}(-|/|$)" | sed 's/^/  远端 ticket: /' || true
      git -C "$REPO_ROOT" ls-tree -r --name-only "$REMOTE_REF" -- confluence/decisions/ 2>/dev/null \
        | grep -iE "EPIC-0*${PADDED}(-|_|\.|$)" | sed 's/^/  远端 decision: /' || true
      ls -1 "$REPO_ROOT/jira/tickets" 2>/dev/null \
        | grep -iE "^EPIC-0*${PADDED}(-|$)" | sed 's/^/  本地 ticket: /' || true
      git -C "$REPO_ROOT" for-each-ref --format='%(refname:short)' 2>/dev/null \
        | grep -iE "EPIC-0*${PADDED}(-|/|$)" | sed 's/^/  branch: /' || true
      exit 1
    fi
    printf 'FREE: EPIC-%03d 空闲\n' "$CHECK_DEC"
    ;;
  next)
    MAX="$(printf '%s\n' "$USED" | tail -1)"
    printf 'EPIC-%03d\n' "$(( MAX + 1 ))"
    ;;
esac

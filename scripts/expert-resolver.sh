#!/usr/bin/env bash
# scripts/expert-resolver.sh — 索引式专家池 resolver
#
# 列出 default + 外挂合并池, 同名增强不覆盖. 不物理合并到 .claude/agents/.
#
# 用法:
#   bash scripts/expert-resolver.sh list                    # 列出合并池
#   bash scripts/expert-resolver.sh list --source=default    # 只 default
#   bash scripts/expert-resolver.sh list --source=plugin    # 只外挂
#   bash scripts/expert-resolver.sh find <query>            # 按 query 找
#   bash scripts/expert-resolver.sh path <role_id>          # 查定义文件路径

set -uo pipefail

# 配置 (env 覆盖, fail-soft: 不存在不报错)
KALLAX_ROOT="${KALLAX_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DEFAULT_AGENTS_DIR="${KALLAX_AGENTS_DIR:-$KALLAX_ROOT/.claude/agents}"
PLUGIN_ROOT="${KALLAX_EXPERTS_DIR:-$HOME/.claude/skills/kallax-experts}"
# 远程 kallax-experts 仓库把定义放在 experts/ 子目录 (嵌套 <division>/[<domain>/]*.md).
# 若该子目录存在就用它, 否则回退到 root (兼容直接把 md 摊在根的布局).
if [ -d "$PLUGIN_ROOT/experts" ]; then
  PLUGIN_EXPERTS_DIR="$PLUGIN_ROOT/experts"
else
  PLUGIN_EXPERTS_DIR="$PLUGIN_ROOT"
fi

MODE="${1:-list}"
shift || true

# 解析剩余参数
# 位置参数按 MODE 归属: find 用 QUERY, path 用 ROLE_ID (原来无条件先填 QUERY,
# 导致 `path <role_id>` 的参数进了 QUERY, ROLE_ID 空 → 报 "需要 role_id 参数")
SOURCE_FILTER=""
QUERY=""
ROLE_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --source=*) SOURCE_FILTER="${1#--source=}" ;;
    *)
      case "$MODE" in
        path) [ -z "$ROLE_ID" ] && ROLE_ID="$1" ;;
        *)    [ -z "$QUERY" ] && QUERY="$1" ;;
      esac
      ;;
  esac
  shift
done

# 解析单个 frontmatter 文件
parse_md() {
  local f="$1"
  local source="$2"
  awk -v src="$source" '
    /^---[[:space:]]*$/ { in_fm = !in_fm; next }
    in_fm && /^name:[[:space:]]*/ { gsub(/^name:[[:space:]]*/, ""); print "name|" $0; next }
    in_fm && /^role_id:[[:space:]]*/ { gsub(/^role_id:[[:space:]]*/, ""); print "role_id|" $0; next }
    in_fm && /^source:[[:space:]]*/ { gsub(/^source:[[:space:]]*/, ""); print "source|" $0; next }
    in_fm && /^domains:[[:space:]]*/ { gsub(/^domains:[[:space:]]*/, ""); print "domains|" $0; next }
    in_fm && /^divisions:[[:space:]]*/ { gsub(/^divisions:[[:space:]]*/, ""); print "divisions|" $0; next }
    in_fm && /^vibe:[[:space:]]*/ { gsub(/^vibe:[[:space:]]*/, ""); print "vibe|" $0; next }
    in_fm && /^priority:[[:space:]]*/ { gsub(/^priority:[[:space:]]*/, ""); print "priority|" $0; next }
    in_fm && /^tools:[[:space:]]*/ { gsub(/^tools:[[:space:]]*/, ""); print "tools|" $0; next }
    # triggers 是嵌套块: "triggers:" 后跟缩进的 "zh: [...]" / "en: [...]"
    # 远程 kallax-experts 的关键词主要在这里 (use_when_* 是场景描述, triggers 是关键词)
    in_fm && /^triggers:[[:space:]]*$/ { in_triggers = 1; next }
    in_triggers && /^[[:space:]]+(zh|en):[[:space:]]*\[/ {
      line = $0
      sub(/^[[:space:]]+(zh|en):[[:space:]]*/, "", line)
      gsub(/^\[|\][[:space:]]*$/, "", line)
      print "triggers|" line
      next
    }
    in_triggers && /^[a-z]/ { in_triggers = 0 }
    in_fm && /^use_when_zh:[[:space:]]*/ { in_use_when_zh = 1; next }
    in_fm && /^use_when_en:[[:space:]]*/ { in_use_when_en = 1; next }
    in_fm && /^[a-z]/ && !/^use_when/ { in_use_when_zh = 0; in_use_when_en = 0 }
    in_use_when_zh && /^[[:space:]]*- / { gsub(/^[[:space:]]*- /, ""); print "use_when_zh|" $0; next }
    in_use_when_en && /^[[:space:]]*- / { gsub(/^[[:space:]]*- /, ""); print "use_when_en|" $0; next }
    in_fm && /^---[[:space:]]*$/ { in_fm = 0 }
  ' "$f"
}

# 解析目录, 输出 role_id 唯一最新
# default 池是扁平 (.claude/agents/*.md), 外挂池是嵌套 (experts/<division>/[<domain>/]*.md)
# 用 find 统一处理两种层级
scan_dir() {
  local dir="$1"
  local source="$2"
  [ -d "$dir" ] || return 0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    local parsed
    parsed="$(parse_md "$f" "$source")"
    local name role_id vibe tools priority
    name="$(echo "$parsed" | grep '^name|' | head -1 | cut -d'|' -f2-)"
    role_id="$(echo "$parsed" | grep '^role_id|' | head -1 | cut -d'|' -f2-)"
    vibe="$(echo "$parsed" | grep '^vibe|' | head -1 | cut -d'|' -f2-)"
    tools="$(echo "$parsed" | grep '^tools|' | head -1 | cut -d'|' -f2-)"
    priority="$(echo "$parsed" | grep '^priority|' | head -1 | cut -d'|' -f2-)"
    [ -z "$role_id" ] && continue
    local use_when_zh use_when_en triggers
    use_when_zh="$(echo "$parsed" | grep '^use_when_zh|' | head -10 | cut -d'|' -f2- | paste -sd ';' -)"
    use_when_en="$(echo "$parsed" | grep '^use_when_en|' | head -10 | cut -d'|' -f2- | paste -sd ';' -)"
    triggers="$(echo "$parsed" | grep '^triggers|' | head -4 | cut -d'|' -f2- | paste -sd ',' -)"
    echo "${role_id}|${name}|${source}|${f}|${vibe}|${tools}|${priority}|${use_when_zh}|${use_when_en}|${triggers}"
  done < <(find "$dir" -type f -name '*.md' 2>/dev/null | sort)
}

# 列模式
cmd_list() {
  local tmp
  tmp="$(mktemp)"
  for src in default plugin; do
    case "$src" in
      default) scan_dir "$DEFAULT_AGENTS_DIR" "$src" >> "$tmp" ;;
      plugin)  scan_dir "$PLUGIN_EXPERTS_DIR" "$src" >> "$tmp" ;;
    esac
  done
  awk -F'|' '
    { key = $1 }
    !seen[key]++ { print $0 }
  ' "$tmp" | sort -t'|' -k1,1
  rm -f "$tmp"
}

# 过滤 source
apply_source_filter() {
  local mode="$1"
  case "$mode" in
    default) grep -E '\|default\|' ;;
    plugin) grep -E '\|plugin\|' ;;
    *) cat ;;
  esac
}

# 找模式 (按 query 匹配)
cmd_find() {
  local query="$1"
  local tmp
  tmp="$(mktemp)"
  cmd_list > "$tmp"
  # 匹配 name/role_id/vibe/use_when/triggers 任何字段含 query (大小写不敏感)
  awk -F'|' -v q="$(echo "$query" | tr '[:upper:]' '[:lower:]')" '
    {
      hay = tolower($1 " " $2 " " $5 " " $8 " " $9 " " $10)
      if (index(hay, q) > 0) print
    }
  ' "$tmp" | sort -t'|' -k1,1
  rm -f "$tmp"
}

# 路径模式
cmd_path() {
  local rid="$1"
  for src in default plugin; do
    case "$src" in
      default) scan_dir "$DEFAULT_AGENTS_DIR" "$src" | grep -E "^${rid}\\|" | cut -d'|' -f4 ;;
      plugin)  scan_dir "$PLUGIN_EXPERTS_DIR" "$src" | grep -E "^${rid}\\|" | cut -d'|' -f4 ;;
    esac
  done
}

# 输出格式
format_row() {
  local data="$1"
  IFS='|' read -r role_id name source path vibe <<< "$data"
  printf "  %-22s [%s]  %s\n  %s  %s\n" "$role_id" "$source" "$name" "  path: $path" ""
}

# 入口
case "$MODE" in
  list)
    echo "=== 合并池 (default + 外挂, 同名增强不覆盖) ==="
    if [ -n "$SOURCE_FILTER" ]; then
      cmd_list | apply_source_filter "$SOURCE_FILTER" | while IFS= read -r row; do
        [ -n "$row" ] && format_row "$row"
      done
      echo ""
      echo "总: $(cmd_list | apply_source_filter "$SOURCE_FILTER" | wc -l | tr -d ' ')"
    else
      cmd_list | while IFS= read -r row; do
        [ -n "$row" ] && format_row "$row"
      done
      echo ""
      echo "总: $(cmd_list | wc -l | tr -d ' ')"
    fi
    ;;
  find)
    [ -z "$QUERY" ] && { echo "ERROR: 需要 query 参数" >&2; exit 1; }
    echo "=== 找 query: $QUERY ==="
    cmd_find "$QUERY" | while IFS= read -r row; do
      [ -n "$row" ] && format_row "$row"
    done
    ;;
  path)
    [ -z "$ROLE_ID" ] && { echo "ERROR: 需要 role_id 参数" >&2; exit 1; }
    echo "=== 查 $ROLE_ID 的定义文件 ==="
    cmd_path "$ROLE_ID"
    ;;
  *)
    echo "Usage: $0 {list|find|path} [args...]" >&2
    exit 1
    ;;
esac

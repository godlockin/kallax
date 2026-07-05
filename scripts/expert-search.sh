#!/usr/bin/env bash
# expert-search.sh - 关键词搜索专家
#
# 用法:
#   bash scripts/expert-search.sh <keyword>          # 搜索 builtin + extended
#   bash scripts/expert-search.sh -l <keyword>       # 列出 builtin only
#   bash scripts/expert-search.sh -e <keyword>       # 列 extended(需 git clone 外部库)
#   bash scripts/expert-search.sh --all              # 列出所有 builtin
#
# 设计:Token 优化
# - 索引:150 tokens(替代 2100 tokens MD 索引)
# - 搜索:O(1) 哈希查表
# - 输出:专家 ID + 文件 + 简短说明,详细 Read 按需

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INDEX_FILE="$KALLAX_ROOT/experts/index/experts-index.yml"
EXTENDED_DIR="$HOME/.claude/experts-extended"

MODE="all"  # all/builtin/extended

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--builtin) MODE="builtin"; shift;;
    -e|--extended) MODE="extended"; shift;;
    --all) shift; KEYWORD="";;
    -h|--help)
      cat <<'EOF'
expert-search.sh - 关键词搜索专家

用法:
  bash expert-search.sh <keyword>          搜索 builtin + extended
  bash expert-search.sh -l <keyword>       只列 builtin
  bash expert-search.sh -e <keyword>       只列 extended
  bash expert-search.sh --all              列出所有 builtin

示例:
  bash expert-search.sh 架构
  bash expert-search.sh API
  bash expert-search.sh 性能

输出:
  [专家 ID]  (来源)  简短说明
  文件: 路径
EOF
      exit 0 ;;
    *) KEYWORD="$1"; shift;;
  esac
done

# 颜色
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; NC='\033[0m'
else
  GREEN=''; CYAN=''; YELLOW=''; NC=''
fi

# 列出 builtin 所有
list_builtin() {
  echo "📋 kallax 内置专家 (5 个 default):"
  echo ""
  if command -v yq >/dev/null 2>&1; then
    yq '.builtin[] | "  " + .emoji + " " + .id + " (" + .name + ") - " + .file' "$INDEX_FILE" 2>/dev/null
  else
    grep -A10 'builtin:' "$INDEX_FILE" | grep 'id:' | awk -F'"' '{print "  " $2 " (" $4 ")"}'
  fi
}

# 搜索 builtin
search_builtin() {
  local keyword="$1"
  echo "🔍 builtin 搜索: '$keyword'"
  echo ""

  # 用 yq 找 triggers
  if command -v yq >/dev/null 2>&1; then
    local experts
    experts=$(yq ".triggers.\"$keyword\" // []" "$INDEX_FILE" 2>/dev/null)
    if [[ "$experts" != "[]" && -n "$experts" ]]; then
      echo "  命中: $experts"
      for e in $experts; do
        local file
        file=$(yq ".builtin[] | select(.id == \"$e\") | .file" "$INDEX_FILE" 2>/dev/null)
        local emoji
        emoji=$(yq ".builtin[] | select(.id == \"$e\") | .emoji" "$INDEX_FILE" 2>/dev/null)
        echo -e "  ${GREEN}${emoji} $e${NC}"
        echo "    📄 kallax/.claude/commands/kallax/experts/$file"
      done
    else
      echo "  builtin 中无 '$keyword' 匹配"
      echo "  💡 提示:关键词可能存在于 extended 库(eket/agency-agents)"
    fi
  else
    echo "  ⚠️  yq 未装,用 grep 兜底"
    local hits
    hits=$(grep -A1 "  ${keyword}:" "$INDEX_FILE" | grep -oE '\[.*\]' | head -1)
    if [[ -n "$hits" ]]; then
      echo "  命中: $hits"
      # 尝试从 builtin 找名字
      for e in $(echo "$hits" | tr -d '[]' | tr ',' ' '); do
        local name
        name=$(grep -A2 "id: $e$" "$INDEX_FILE" | grep "name:" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
        echo "    $e ($name)"
      done
    else
      echo "  无匹配"
    fi
  fi
}

# 搜索 extended(在 ~/.claude/experts-extended/)
search_extended() {
  local keyword="$1"

  if [[ ! -d "$EXTENDED_DIR" ]]; then
    echo "⚠️  Extended 库未安装"
    echo "   跑: bash $KALLAX_ROOT/scripts/expert-install.sh"
    return
  fi

  echo "🔍 extended 搜索: '$keyword'"
  echo ""

  for lib in eket agency-agents; do
    local lib_dir="$EXTENDED_DIR/$lib"
    if [[ -d "$lib_dir" ]]; then
      echo "📚 $lib:"
      # 在 markdown 文件名 + 内容里搜
      grep -rli "$keyword" "$lib_dir" 2>/dev/null | head -5 | while read -r f; do
        local name
        name=$(basename "$f" .md)
        echo "  📄 $lib/$name"
      done
    fi
  done
}

# 入口
if [[ "${1:-}" == "--all" ]] || [[ -z "${KEYWORD:-}" ]]; then
  list_builtin
  echo ""
  echo "💡 关键词搜索: bash expert-search.sh <keyword>"
  exit 0
fi

case "$MODE" in
  builtin) search_builtin "$KEYWORD" ;;
  extended) search_extended "$KEYWORD" ;;
  all)
    search_builtin "$KEYWORD"
    echo ""
    search_extended "$KEYWORD"
    ;;
esac
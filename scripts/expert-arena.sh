#!/usr/bin/env bash
# expert-arena.sh - 专家竞技场
#
# 用法:
#   bash scripts/expert-arena.sh <keyword>     # 多专家"投标",前 3 名
#
# 机制(从 eket 学到):
# - 输入关键词,触发多个候选专家
# - 每个候选按"匹配度"评分(简单 keyword overlap)
# - 显示 Top 3,用户选
# - 然后用 Read 加载详细 prompt
#
# Token 优化:
# - 索引 + 搜索 = ~150 tokens
# - 不全量加载所有专家 prompt

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INDEX_FILE="$KALLAX_ROOT/experts/index/experts-index.yml"
EXTENDED_DIR="$HOME/.claude/experts-extended"

if [[ $# -lt 1 ]]; then
  echo "用法: bash expert-arena.sh <keyword>"
  echo "示例: bash expert-arena.sh API"
  exit 2
fi
KEYWORD="$1"

# 颜色
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

echo ""
echo -e "${BOLD}🏟️  Expert Arena / 专家竞技场${NC}"
echo "关键词: ${CYAN}$KEYWORD${NC}"
echo ""

# 收集所有候选(用临时文件 + 行数组,避免关联数组在 bash 3.2 问题)
CANDIDATES_FILE=$(mktemp -t avle_arena.XXXXXX)
trap "rm -f '$CANDIDATES_FILE'" EXIT
: > "$CANDIDATES_FILE"

# 1. builtin
if [[ -f "$INDEX_FILE" ]]; then
  while IFS= read -r line; do
    # 匹配 "  关键词: [expert1, expert2]"
    if [[ "$line" =~ ^[[:space:]]+([^:]+):[[:space:]]*\[(.+)\][[:space:]]*$ ]]; then
      kw="${BASH_REMATCH[1]}"
      experts="${BASH_REMATCH[2]}"
      if [[ "$kw" == *"$KEYWORD"* ]] || [[ "$KEYWORD" == *"$kw"* ]]; then
        if [[ "$kw" == "$KEYWORD" ]]; then
          score=100
        elif [[ "$kw" == *"$KEYWORD"* ]]; then
          score=80
        else
          score=60
        fi
        for e in $(echo "$experts" | tr -d '[]' | tr ',' ' '); do
          e=$(echo "$e" | tr -d ' ')
          # builtin 路径(整行匹配,所有字段都在同一行)
          # name 字段在 YAML 中可能带或不带引号(中文常无引号)
          inline=$(grep -E "^\s*-\s*\{id: $e," "$INDEX_FILE" 2>/dev/null | head -1)
          file=$(echo "$inline" | grep -oE "file:[[:space:]]*\"[^\"]+\"" | sed -E "s/.*\"([^\"]+)\".*/\1/")
          emoji=$(echo "$inline" | grep -oE "emoji:[[:space:]]*\"[^\"]+\"" | sed -E "s/.*\"([^\"]+)\".*/\1/")
          # name 优先引号,fallback 无引号
          name=$(echo "$inline" | grep -oE "name:[[:space:]]*\"[^\"]+\"" | sed -E "s/.*\"([^\"]+)\".*/\1/")
          if [[ -z "$name" ]]; then
            name=$(echo "$inline" | grep -oE "name:[[:space:]]*[^,\}]+" | sed -E "s/name:[[:space:]]*//" | tr -d ' ')
          fi
          [[ -z "$file" ]] && file="kallax/.claude/commands/kallax/experts/${e}.md"
          echo "${score}|${e}|${file}|${emoji}|${name}" >> "$CANDIDATES_FILE"
        done
      fi
    fi
  done < "$INDEX_FILE"
fi

# 2. extended(在文件名 + 内容中搜)
if [[ -d "$EXTENDED_DIR" ]]; then
  grep -ril "$KEYWORD" "$EXTENDED_DIR" 2>/dev/null | head -10 | while read -r f; do
    name=$(basename "$f" .md)
    echo "50|${name}|${f}|📦|extended" >> "$CANDIDATES_FILE"
  done
fi

# 排序 + 去重(取最高分)
CANDIDATES=$(sort -t'|' -k1 -nr "$CANDIDATES_FILE" | awk -F'|' '
  !seen[$2]++ { print }
' | head -3)

# 排序 + 显示 Top 3
if [[ -z "$CANDIDATES" || "$CANDIDATES" == "" ]]; then
  echo -e "${YELLOW}⚠️  无候选专家匹配 '"'"'$KEYWORD'"'"'${NC}"
  echo "提示: 试试其他关键词 / 检查索引文件"
  exit 0
fi

echo -e "${BOLD}🎯 Top 3 候选(按匹配度):${NC}"
echo ""
rank=1
echo "$CANDIDATES" | while IFS='|' read -r score id file emoji name; do
  echo -e "${BOLD}#${rank} ${emoji} ${name} (${id})${NC}"
  echo -e "    匹配度: ${score}"
  echo -e "    📄 ${file}"
  echo ""
  rank=$((rank+1))
done

# 提示
echo -e "${BOLD}下一步:${NC}"
echo "  bash scripts/expert-search.sh ${KEYWORD}  # 完整搜索结果"
echo "  Read <file>                              # 加载详细 prompt"
echo ""
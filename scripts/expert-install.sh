#!/usr/bin/env bash
# expert-install.sh - 安装外部专家库(eket-experts-extended + agency-agents)
#
# 用法:
#   bash scripts/expert-install.sh              # 装全部
#   bash scripts/expert-install.sh eket        # 装 eket
#   bash scripts/expert-install.sh agency      # 装 agency
#   bash scripts/expert-install.sh --list      # 列出可装的库
#   bash scripts/expert-install.sh --update    # 更新已装的库
#
# 安装位置: ~/.claude/experts-extended/

set -eo pipefail

EXTENDED_DIR="$HOME/.claude/experts-extended"
KALLAX_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 库元数据(用临时文件,避免 bash 3.2 declare -A 限制)
LIBS_DIR=$(mktemp -d -t avle_libs.XXXXXX)
trap "rm -rf '$LIBS_DIR'" EXIT

# 格式: <url>|<count>|<domains>|<features>
echo "https://github.com/godlockin/eket-experts-extended.git|70个专家|11个domain|YAML倒排索引+CLI搜索" > "$LIBS_DIR/eket"
echo "https://github.com/msitarzewski/agency-agents.git|280个agent|17个division|frontmatter metadata" > "$LIBS_DIR/agency-agents"
# kallax-experts(融合 eket + agency 的统一索引)
echo "https://github.com/godlockin/kallax-experts.git|350+专家|28个domain|统一索引+frontmatter+跨库引用" > "$LIBS_DIR/kallax-experts"

# 帮助
show_help() {
  cat <<'EOF'
expert-install.sh - 安装外部专家库

用法:
  bash scripts/expert-install.sh                装全部
  bash scripts/expert-install.sh eket          装 eket
  bash scripts/expert-install.sh agency        装 agency
  bash scripts/expert-install.sh --list        列出可装库
  bash scripts/expert-install.sh --update      更新已装库

安装位置:~/.claude/experts-extended/<lib>/

EOF
}

# 安装单个库
install_lib() {
  local lib="$1"
  if [[ ! -f "$LIBS_DIR/$lib" ]]; then
    echo "❌ 未知库: $lib"
    echo "可装:"
    for f in "$LIBS_DIR"/*; do
      [[ -f "$f" ]] && echo "  $(basename "$f")"
    done
    return 1
  fi
  local meta
  meta=$(cat "$LIBS_DIR/$lib")
  local url=$(echo "$meta" | cut -d'|' -f1)
  local count=$(echo "$meta" | cut -d'|' -f2)
  local domains=$(echo "$meta" | cut -d'|' -f3)
  local features=$(echo "$meta" | cut -d'|' -f4)

  echo "📥 安装 $lib ..."
  echo "   URL: $url"
  echo "   内容: $count, $domains, $features"
  echo ""

  mkdir -p "$EXTENDED_DIR"

  if [[ -d "$EXTENDED_DIR/$lib" ]]; then
    echo "   ⚠️  $EXTENDED_DIR/$lib 已存在,跳过"
    echo "   用 --update 更新"
    return 0
  fi

  if command -v git >/dev/null 2>&1; then
    if git clone --depth 1 "$url" "$EXTENDED_DIR/$lib" 2>/dev/null; then
      echo "   ✅ 装好: $EXTENDED_DIR/$lib"
    else
      echo "   ❌ git clone 失败,可能无网络"
    fi
  else
    echo "   ❌ 缺 git,无法装"
  fi
}

# 更新
update_libs() {
  if [[ ! -d "$EXTENDED_DIR" ]]; then
    echo "❌ 未装任何库"
    return 1
  fi
  for lib in "$EXTENDED_DIR"/*/; do
    [[ -d "$lib/.git" ]] || continue
    local name
    name=$(basename "$lib")
    echo "🔄 更新 $name ..."
    (cd "$lib" && git pull --depth 1 2>/dev/null) || echo "   ❌ 更新失败"
  done
}

# 列出
list_libs() {
  echo "📚 可装外部库:"
  for f in "$LIBS_DIR"/*; do
    [[ -f "$f" ]] || continue
    local lib
    lib=$(basename "$f")
    local meta
    meta=$(cat "$f")
    echo "  $lib — $(echo "$meta" | cut -d'|' -f2), $(echo "$meta" | cut -d'|' -f3)"
  done
  echo ""
  echo "已装(在 $EXTENDED_DIR/):"
  if [[ -d "$EXTENDED_DIR" ]]; then
    for lib in "$EXTENDED_DIR"/*/; do
      [[ -d "$lib" ]] || continue
      local n
      n=$(basename "$lib")
      local count
      count=$(find "$lib" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
      echo "  $n — $count 个 agent/persona"
    done
  else
    echo "  (无)"
  fi
}

# 入口
case "${1:-}" in
  --help|-h) show_help; exit 0 ;;
  --list) list_libs ;;
  --update) update_libs ;;
  eket|agency|kallax-experts) install_lib "$1" ;;
  "") install_lib eket; install_lib agency ;;
  *) echo "❌ 未知: $1" >&2; show_help; exit 2 ;;
esac

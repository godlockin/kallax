#!/usr/bin/env bash
# setup.sh - 一行引导安装 kallax CLI Rule
#
# 用法:
#   # 从本地仓库(开发用)
#   bash scripts/setup.sh
#
#   # 从 GitHub Release 下载稳定版(生产用)
#   curl -fsSL https://raw.githubusercontent.com/<org>/kallax/main/scripts/setup.sh \
#     | bash -s -- --release v1.0.0
#
#   # 指定仓库(默认 <org>/kallax)
#   curl ... | bash -s -- --release v1.0.0 --repo <org>/kallax
#
# 选项(环境变量 / 参数):
#   --release TAG      从 GitHub Release 下载指定 tag(默认:本地仓库)
#   --repo ORG/REPO     GitHub org/repo(默认:your-org/kallax)
#   --home DIR          安装目录(默认 ~/.claude/)
#   --non-interactive   非交互模式
#   --force             强制覆盖
#   --no-verify         安装后不跑 verify
#
# 退出码:
#   0  成功
#   1  一般错误
#   2  参数错误
#   4  系统不支持

set -uo pipefail

# ============ 默认值 ============
KALLAX_REPO="${KALLAX_REPO:-your-org/kallax}"
INIT_SUBCMD=""
HOME_DIR="${KALLAX_HOME_DIR:-$HOME/.claude}"
NON_INTERACTIVE="${KALLAX_NON_INTERACTIVE:-0}"
FORCE="${KALLAX_FORCE:-0}"
NO_VERIFY="${KALLAX_NO_VERIFY:-0}"
RELEASE_TAG=""
LOCAL_ROOT=""

# ============ 解析参数 ============
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)    RELEASE_TAG="$2"; shift 2;;
    --repo)       KALLAX_REPO="$2"; shift 2;;
    --home)       HOME_DIR="$2"; shift 2;;
    --non-interactive) NON_INTERACTIVE=1; shift;;
    --force)      FORCE=1; shift;;
    --no-verify)  NO_VERIFY=1; shift;;
    --local)      LOCAL_ROOT="$2"; shift 2;;  # 内部用
    init)         INIT_SUBCMD="$2"; shift 2;;  # 项目级初始化
    -h|--help)
      cat <<'EOF'
kallax CLI Rule 一行安装

用法:
  bash setup.sh [options]

子命令:
  install      默认(用户级安装)
  init <path>  项目级初始化(转 init-project.sh)

选项:
  --release TAG       从 GitHub Release 下载 TAG 版(默认:本地仓库)
  --repo ORG/REPO      GitHub 仓库(默认 your-org/kallax)
  --home DIR           安装目录(默认 ~/.claude/)
  --non-interactive    非交互模式
  --force              强制覆盖
  --no-verify          安装后不跑 verify

示例:
  # 本地仓库(开发)
  bash scripts/setup.sh

  # 在线一行安装
  curl -fsSL https://raw.githubusercontent.com/your-org/kallax/main/scripts/setup.sh \
    | bash -s -- --release v1.0.0

  # 自定义仓库 + 目录
  curl -fsSL ... | bash -s -- --release v1.0.0 --repo myorg/kallax --home /opt/claude
EOF
      exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

# ============ 头部 UI ============
echo "═══════════════════════════════════════════"
echo "  🛡️  kallax CLI Rule 一行安装"
echo "═══════════════════════════════════════════"
echo ""
echo "  仓库:    $KALLAX_REPO"
echo "  安装到:  $HOME_DIR"
# 来源字符串(在 SCRIPT_PATH 检测后再定)
SOURCE_DISPLAY="未知(需 --release 或本地)"
[[ -n "$RELEASE_TAG" ]] && SOURCE_DISPLAY="Release $RELEASE_TAG"
[[ -n "$LOCAL_ROOT" ]] && SOURCE_DISPLAY="本地: $LOCAL_ROOT"
echo "  来源:    $SOURCE_DISPLAY"
echo ""

# ============ 平台检查 ============
case "$(uname -s)" in
  Darwin|Linux) ;;
  *) echo "❌ 仅支持 macOS / Linux" >&2; exit 4 ;;
esac

# ============ 决定来源:本地 vs Release ============
if [[ -n "$LOCAL_ROOT" ]]; then
  # 显式指定本地
  KALLAX_ROOT="$LOCAL_ROOT"
  SOURCE_KIND="local"
elif [[ -n "$RELEASE_TAG" ]]; then
  KALLAX_ROOT=$(mktemp -d -t kallax-cli-rule.XXXXXX)
  SOURCE_KIND="release"
else
  # 自动检测:如果 SCRIPT_PATH 在仓库内,本地;否则友好提示
  SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
  if [[ -n "$SCRIPT_PATH" ]] && [[ "$SCRIPT_PATH" != "bash" ]] && [[ "$SCRIPT_PATH" != "/dev/stdin" ]] && [[ -f "$SCRIPT_PATH" ]]; then
    KALLAX_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
    SOURCE_KIND="local"
  else
    # 通过 curl | bash 运行,无本地路径
    echo "⚠️  一行安装请指定 --release TAG:"
    echo ""
    echo "   curl -fsSL https://raw.githubusercontent.com/your-org/kallax/main/scripts/setup.sh \\"
    echo "     | bash -s -- --release v1.0.0"
    echo ""
    echo "或先克隆仓库:"
    echo "   git clone https://github.com/your-org/kallax.git"
    echo "   cd kallax && bash scripts/setup.sh"
    exit 1
  fi
fi

# ============ 模式 1:从 GitHub Release 下载 ============
if [[ "$SOURCE_KIND" == "release" ]]; then
  echo "📥 从 GitHub Release 下载..."
  echo ""

  ARCHIVE_NAME="kallax-cli-rule-${RELEASE_TAG}.tar.gz"
  DOWNLOAD_URL="https://github.com/${KALLAX_REPO}/releases/download/${RELEASE_TAG}/${ARCHIVE_NAME}"

  # 检查必需工具
  for cmd in curl tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "❌ 缺少工具: $cmd" >&2
      exit 1
    fi
  done

  echo "  URL: $DOWNLOAD_URL"

  cd "$KALLAX_ROOT"
  if ! curl -fsSL "$DOWNLOAD_URL" -o "$ARCHIVE_NAME" 2>/dev/null; then
    echo "❌ 下载失败" >&2
    echo "  提示: 1) 检查 TAG 是否存在 2) GitHub Release 可能未发布" >&2
    echo "        3) 网络问题(尝试 --repo your-org/kallax)" >&2
    exit 1
  fi

  echo "✅ 已下载: $ARCHIVE_NAME"

  # 验证 SHA256(如有 .sha256 文件)
  SHA_FILE="${ARCHIVE_NAME}.sha256"
  if curl -fsSL "${DOWNLOAD_URL}.sha256" -o "$SHA_FILE" 2>/dev/null; then
    if shasum -a 256 -c "$SHA_FILE" >/dev/null 2>&1; then
      echo "✅ SHA256 校验通过"
    else
      echo "❌ SHA256 校验失败(可能是下载不完整)" >&2
      exit 1
    fi
  else
    echo "⚠️  无 SHA256 校验文件,跳过"
  fi

  # 解压
  tar -xzf "$ARCHIVE_NAME"
  echo "✅ 已解压到: $KALLAX_ROOT"
  echo ""
fi

# ============ 验证仓库结构 ============
if [[ ! -f "$KALLAX_ROOT/hooks/exec-task.sh" ]] || \
   [[ ! -f "$KALLAX_ROOT/hooks/bash-rule-enforcer.sh" ]] || \
   [[ ! -f "$KALLAX_ROOT/hooks/verify-rule.sh" ]] || \
   [[ ! -f "$KALLAX_ROOT/scripts/cli-rule" ]]; then
  echo "❌ 仓库文件不完整" >&2
  echo "  需要 hooks/exec-task.sh + bash-rule-enforcer.sh + verify-rule.sh + scripts/cli-rule" >&2
  exit 1
fi

# ============ 清理临时目录(仅 release 模式) ============
if [[ "$SOURCE_KIND" == "release" && -n "$RELEASE_TAG" ]]; then
  # 保留临时目录(里面有解压的文件)直到 cli-rule 跑完
  CLEANUP_DIR="$KALLAX_ROOT"
  trap 'rm -rf "$CLEANUP_DIR"' EXIT
fi

# ============ 跑 cli-rule install(默认) 或 init-project(init 子命令) ============
echo "🚀 开始安装..."
echo ""

# 检测 init 子命令(参数解析时已存到 INIT_SUBCMD)
INIT_PATH="$INIT_SUBCMD"

if [[ -n "$INIT_PATH" ]]; then
  # init 子命令:转 init-project.sh
  echo "ℹ️  转 init-project.sh(项目级初始化)"
  exec "$KALLAX_ROOT/scripts/init-project.sh" "$INIT_PATH" \
    $([[ $NON_INTERACTIVE -eq 1 ]] && echo "--non-interactive") \
    $([[ $FORCE -eq 1 ]] && echo "--force") \
    --template="${TEMPLATE:-minimal}" \
    --hooks --rules --git
fi

exec "$KALLAX_ROOT/scripts/cli-rule" install \
  --home "$HOME_DIR" \
  $([[ $NON_INTERACTIVE -eq 1 ]] && echo "--non-interactive") \
  $([[ $FORCE -eq 1 ]] && echo echo "--force") \
  $([[ $NO_VERIFY -eq 1 ]] && echo echo "--no-verify") \
  --verbose
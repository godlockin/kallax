#!/usr/bin/env bash
# setup.sh - 一行引导安装 kallax CLI Rule
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/.../setup.sh | bash    # 在线
#   bash scripts/setup.sh                                            # 本地仓库
#
# 选项(环境变量):
#   KALLAX_HOME_DIR   自定义安装位置(默认 ~/.claude/)
#   KALLAX_NON_INTERACTIVE=1  非交互模式
#   KALLAX_FORCE=1           强制覆盖
#   KALLAX_NO_VERIFY=1       安装后不跑 verify
#
# 退出码:
#   0  成功
#   1  一般错误
#   4  系统不支持

set -uo pipefail

# 找到这个脚本的真实位置
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
if [[ "$SCRIPT_PATH" == "bash" ]] || [[ "$SCRIPT_PATH" == "/dev/stdin" ]]; then
  # 通过 curl | bash 运行,无法定位自己
  # 用户应该从仓库克隆
  echo "⚠️  一行安装请用:"
  echo "   git clone https://github.com/<your-org>/kallax.git"
  echo "   cd kallax"
  echo "   bash scripts/setup.sh"
  exit 1
fi

KALLAX_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"

# 默认参数(环境变量覆盖)
HOME_DIR="${KALLAX_HOME_DIR:-$HOME/.claude}"
NON_INTERACTIVE="${KALLAX_NON_INTERACTIVE:-0}"
FORCE="${KALLAX_FORCE:-0}"
NO_VERIFY="${KALLAX_NO_VERIFY:-0}"

echo "═══════════════════════════════════════════"
echo "  kallax CLI Rule 一行安装"
echo "═══════════════════════════════════════════"
echo ""
echo "目标目录: $HOME_DIR"
echo "kallax 仓库: $KALLAX_ROOT"
echo ""

# 检查仓库
if [[ ! -d "$KALLAX_ROOT/hooks" ]] || [[ ! -d "$KALLAX_ROOT/docs" ]]; then
  echo "❌ 仓库结构不完整(需 hooks/ 和 docs/)" >&2
  exit 1
fi

# 检查平台
case "$(uname -s)" in
  Darwin|Linux) ;;
  *) echo "❌ 仅支持 macOS / Linux"; exit 4 ;;
esac

# 跑 cli-rule install
exec "$KALLAX_ROOT/scripts/cli-rule" install \
  --home "$HOME_DIR" \
  $([[ $NON_INTERACTIVE -eq 1 ]] && echo "--non-interactive") \
  $([[ $FORCE -eq 1 ]] && echo "--force") \
  $([[ $NO_VERIFY -eq 1 ]] && echo "--no-verify") \
  --verbose
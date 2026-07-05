#!/usr/bin/env bash
# init-project.sh - 新项目初始化脚本
# 在新项目目录里跑,自动创建 CLAUDE.md + 可选 hooks/rules/git
#
# 用法:
#   bash scripts/init-project.sh <project-path> [options]
#
# Examples:
#   bash scripts/init-project.sh my-app                    # 交互式
#   bash scripts/init-project.sh my-app --quick           # 快速
#   bash scripts/init-project.sh my-app --template=full --hooks --git
#   bash scripts/init-project.sh . --template=minimal
#
# 选项:
#   --template NAME    minimal|standard|full (默认 minimal)
#   --hooks            复制 hook scripts 到 .claude/hooks/
#   --rules            创建项目根的 rules/ 子目录
#   --git              初始化 git 仓库
#   --kallax-rules     创建符号链接到 kallax 的 rules/(跨项目共享)
#   --force            覆盖已存在文件
#   --non-interactive  非交互模式
#   --no-kallax-rules  不创建 rules 符号链接(默认行为)
#
# 类似 create-next-app / cargo new 的体验,但专为 Claude Code 配置

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$KALLAX_ROOT/templates"
HOOKS_DIR="$KALLAX_ROOT/hooks"

# 默认值
TEMPLATE="minimal"
INSTALL_HOOKS=0
INSTALL_RULES=0
INIT_GIT=0
SYMLINK_RULES=0
FORCE=0
NON_INTERACTIVE=0
PROJECT_PATH=""

# 颜色
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# 帮助
show_help() {
  cat <<EOF
${BOLD}init-project.sh v1.0.0${NC} - 新项目 Claude Code 初始化

${BOLD}用法:${NC}
  bash init-project.sh <project-path> [options]

${BOLD}参数:${NC}
  <project-path>    项目目录路径(.  表示当前)
                    不存在则创建,存在则检查

${BOLD}选项:${NC}
  --template NAME    minimal(63)|standard(97)|full(138),默认 minimal
  --hooks            复制 hook scripts 到 <project>/.claude/hooks/
  --rules            创建 <project>/rules/ 目录结构
  --git              初始化 git 仓库
  --kallax-rules     符号链接到 kallax rules/(跨项目共享)
  --force            覆盖已存在文件
  --non-interactive  非交互模式,全默认

${BOLD}示例:${NC}
  # 交互式(向导模式)
  bash init-project.sh my-app

  # 快速(全默认)
  bash init-project.sh my-app --quick

  # 完整套装
  bash init-project.sh my-app --template=standard --hooks --rules --git

  # 当前目录
  bash init-project.sh . --template=minimal

EOF
}

# 工具函数
log_info() { echo -e "${BLUE}ℹ${NC}  $*" >&2; }
log_ok()   { echo -e "${GREEN}✓${NC}  $*" >&2; }
log_warn() { echo -e "${YELLOW}⚠${NC}  $*" >&2; }
log_err()  { echo -e "${RED}✗${NC}  $*" >&2; }

ask() {
  local prompt="$1" default="${2:-}"
  local answer
  if [[ $NON_INTERACTIVE -eq 1 ]]; then
    answer="$default"
  else
    if [[ -n "$default" ]]; then
      read -rp "$(printf "${CYAN}?${NC} %s [%s]: " "$prompt" "$default")" answer
      answer="${answer:-$default}"
    else
      read -rp "$(printf "${CYAN}?${NC} %s: " "$prompt")" answer
    fi
  fi
  ANSWER="$answer"
}

ask_yn() {
  local prompt="$1" default="${2:-y}"
  local label
  case "$default" in
    y|Y) label="Y/n" ;;
    n|N) label="y/N" ;;
    *)   label="y/n" ;;
  esac
  local answer
  if [[ $NON_INTERACTIVE -eq 1 ]]; then
    answer="$default"
  else
    read -rp "$(printf "${CYAN}?${NC} %s [%s]: " "$prompt" "$label")" answer
    answer="${answer:-$default}"
  fi
  case "$answer" in
    y|Y|yes|YES) ANSWER_YN=1 ;;
    *)           ANSWER_YN=0 ;;
  esac
}

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    --template) TEMPLATE="$2"; shift 2;;
    --template=*) TEMPLATE="${1#*=}"; shift;;
    --hooks) INSTALL_HOOKS=1; shift;;
    --rules) INSTALL_RULES=1; shift;;
    --git) INIT_GIT=1; shift;;
    --kallax-rules) SYMLINK_RULES=1; shift;;
    --force) FORCE=1; shift;;
    --non-interactive) NON_INTERACTIVE=1; shift;;
    --quick) INSTALL_HOOKS=1; INSTALL_RULES=0; INIT_GIT=0; shift;;
    -*) echo "未知参数: $1" >&2; show_help; exit 2;;
    *) PROJECT_PATH="$1"; shift;;
  esac
done

# 检查项目路径
if [[ -z "$PROJECT_PATH" ]]; then
  echo "❌ 必须提供项目路径" >&2
  show_help
  exit 2
fi

# 解析 ~ / . / 绝对路径
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"
PROJECT_PATH="${PROJECT_PATH%/}"
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd || echo "$PROJECT_PATH")"

# ============ 欢迎 ============
echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║  🛡️  kallax 新项目 Claude Code 初始化        ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  目标项目: ${BOLD}$PROJECT_PATH${NC}"
echo ""

# ============ 检查项目状态 ============
echo -e "${BOLD}Step 1/5 - 检查项目状态${NC}"

if [[ -d "$PROJECT_PATH" ]]; then
  log_ok "项目目录存在"

  if [[ -f "$PROJECT_PATH/CLAUDE.md" ]] && [[ $FORCE -eq 0 ]]; then
    log_warn "CLAUDE.md 已存在(用 --force 覆盖)"
    if [[ $NON_INTERACTIVE -eq 0 ]]; then
      ask_yn "覆盖现有 CLAUDE.md?" "n"
      [[ $ANSWER_YN -eq 0 ]] && log_err "已取消" && exit 3
      FORCE=1
    fi
  fi
else
  log_info "项目目录不存在,创建"
  mkdir -p "$PROJECT_PATH"
  log_ok "已创建: $PROJECT_PATH"
fi

# ============ 交互模式收集参数 ============
if [[ $NON_INTERACTIVE -eq 0 ]] && \
   [[ -z "${TEMPLATE:-}" || "$TEMPLATE" == "minimal" ]] && \
   [[ $INSTALL_HOOKS -eq 0 && $INSTALL_RULES -eq 0 && $INIT_GIT -eq 0 ]]; then

  echo ""
  echo -e "${BOLD}Step 2/5 - 选择配置${NC}"
  echo ""

  # 模板
  echo "📋 CLAUDE.md 模板:"
  echo "  - minimal (63 行,默认推荐)"
  echo "  - standard (97 行,团队项目)"
  echo "  - full (138 行,多角色协作)"
  ask "模板" "minimal"
  TEMPLATE="$ANSWER"

  # Hooks
  ask_yn "复制 hook scripts 到 .claude/hooks/? (bash-rule-enforcer + token-economy)" "y"
  INSTALL_HOOKS=$ANSWER_YN

  # Rules
  ask_yn "创建项目 rules/ 目录?" "n"
  INSTALL_RULES=$ANSWER_YN

  # Git
  if [[ ! -d "$PROJECT_PATH/.git" ]]; then
    ask_yn "初始化 git 仓库?" "y"
    INIT_GIT=$ANSWER_YN
  else
    log_info "git 已存在,跳过"
    INIT_GIT=0
  fi
fi

# ============ 复制 CLAUDE.md ============
echo ""
echo -e "${BOLD}Step 3/5 - 创建 CLAUDE.md${NC}"

TEMPLATE_FILE="$TEMPLATES_DIR/CLAUDE.md.${TEMPLATE}"
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  log_warn "模板不存在: $TEMPLATE_FILE,fallback minimal"
  TEMPLATE_FILE="$TEMPLATES_DIR/CLAUDE.md.minimal"
fi

if [[ -f "$PROJECT_PATH/CLAUDE.md" ]] && [[ $FORCE -eq 0 ]]; then
  log_warn "CLAUDE.md 已存在,跳过(用 --force 覆盖)"
else
  cp "$TEMPLATE_FILE" "$PROJECT_PATH/CLAUDE.md"
  log_ok "已创建 CLAUDE.md(模板: $TEMPLATE,$(wc -l < "$PROJECT_PATH/CLAUDE.md" | tr -d ' ') 行)"
fi

# ============ 复制 hooks ============
if [[ $INSTALL_HOOKS -eq 1 ]]; then
  echo ""
  echo -e "${BOLD}Step 4/5 - 复制 hooks${NC}"

  mkdir -p "$PROJECT_PATH/.claude/hooks"
  log_ok "目录: $PROJECT_PATH/.claude/hooks/"

  for hook_file in "$HOOKS_DIR"/*.sh; do
    if [[ -f "$hook_file" ]]; then
      local_name=$(basename "$hook_file")
      if [[ -f "$PROJECT_PATH/.claude/hooks/$local_name" ]] && [[ $FORCE -eq 0 ]]; then
        log_warn "已存在: $local_name"
      else
        cp "$hook_file" "$PROJECT_PATH/.claude/hooks/$local_name"
        chmod +x "$PROJECT_PATH/.claude/hooks/$local_name"
        log_ok "已复制: $local_name"
      fi
    fi
  done

  # 也复制 exec-task.sh 和 verify-rule.sh 到项目级
  for tool_file in exec-task.sh verify-rule.sh; do
    if [[ -f "$HOOKS_DIR/$tool_file" ]]; then
      if [[ -f "$PROJECT_PATH/.claude/$tool_file" ]] && [[ $FORCE -eq 0 ]]; then
        log_warn "已存在: $tool_file"
      else
        cp "$HOOKS_DIR/$tool_file" "$PROJECT_PATH/.claude/$tool_file"
        chmod +x "$PROJECT_PATH/.claude/$tool_file"
        log_ok "已复制: $tool_file"
      fi
    fi
  done

  # 写 .claude/settings.json 配 PreToolUse
  SETTINGS_FILE="$PROJECT_PATH/.claude/settings.json"
  if [[ ! -f "$SETTINGS_FILE" ]] || [[ $FORCE -eq 1 ]]; then
    cat > "$SETTINGS_FILE" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/bash-rule-enforcer.sh"
          },
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/token-economy-enforcer.sh"
          }
        ]
      }
    ]
  }
}
EOF
    log_ok "已创建 .claude/settings.json(PreToolUse hooks)"
  fi
fi

# ============ 创建 rules/ ============
if [[ $INSTALL_RULES -eq 1 ]]; then
  echo ""
  echo -e "${BOLD}Step 4.5/5 - 创建 rules/${NC}"

  mkdir -p "$PROJECT_PATH/rules"

  # 写 README 说明 rules 用途
  cat > "$PROJECT_PATH/rules/README.md" <<'EOF'
# Project Rules / 项目规则

> **kallax 框架** — 项目级规则,大模型按需 Read

## 用法

每个 `.md` 文件是一条规则,大模型在需要时 Read(不会永远加载)。

## 文件命名建议

- `coding-style.md` — 代码风格
- `git-conventions.md` — Git 规范
- `testing.md` — 测试规则
- `deployment.md` — 部署规则
- `security.md` — 安全规范
- `architecture.md` — 架构原则

## 引用

从 `CLAUDE.md` 引用:

```markdown
## 📚 项目规则
- rules/coding-style.md — 代码风格(开发时必读)
- rules/git-conventions.md — Commit 规范
- rules/testing.md — 测试要求
```
EOF
  log_ok "已创建 rules/README.md"

  # 模板示例
  if [[ ! -f "$PROJECT_PATH/rules/coding-style.md" ]]; then
    cat > "$PROJECT_PATH/rules/coding-style.md" <<'EOF'
# Coding Style / 代码风格

> 项目特定编码规范,大模型按需 Read

## 通用原则

1. **可读性 > 聪明** — 代码是给人看的
2. **一致 > 个人偏好** — 跟随项目已有风格
3. **测试覆盖** — 新功能必须带测试
4. **小 PR** — 一个 PR 一个关注点

## 具体规则(项目填)

(在此填项目特定的编码规则)
EOF
    log_ok "已创建 rules/coding-style.md(模板)"
  fi
fi

# ============ Git init ============
if [[ $INIT_GIT -eq 1 ]]; then
  echo ""
  echo -e "${BOLD}Step 5/5 - 初始化 git${NC}"

  cd "$PROJECT_PATH"
  if [[ ! -d .git ]]; then
    git init -q
    log_ok "git init 完成"
  fi

  # .gitignore(Claude Code 文件不进 git)
  if [[ ! -f .gitignore ]]; then
    cat > .gitignore <<'EOF'
# Claude Code 本地配置(不进 git)
.claude/settings.local.json
.claude/state.json

# 个人数据(进 gitignore)
*.log
*.tmp
EOF
    log_ok "已创建 .gitignore"
  fi

  # 第一次 commit
  if [[ -f CLAUDE.md ]]; then
    git add CLAUDE.md .claude/ 2>/dev/null || true
    git commit -q -m "chore: initialize with kallax CLI Rule (template=$TEMPLATE)" || true
    log_ok "已创建初始 commit"
  fi
fi

# ============ 完成 ============
echo ""
echo -e "${BOLD}${GREEN}✅ 完成!${NC}"
echo ""
echo -e "📋 项目结构:"
echo -e "   ${BOLD}$PROJECT_PATH${NC}/"
[[ -f "$PROJECT_PATH/CLAUDE.md" ]] && echo -e "   ├── CLAUDE.md (模板: $TEMPLATE)"
[[ -d "$PROJECT_PATH/.claude/hooks" ]] && echo -e "   ├── .claude/hooks/ (bash-rule-enforcer + token-economy)"
[[ -f "$PROJECT_PATH/.claude/settings.json" ]] && echo -e "   ├── .claude/settings.json"
[[ -d "$PROJECT_PATH/rules" ]] && echo -e "   └── rules/ (项目级规则)"
[[ -d "$PROJECT_PATH/.git" ]] && echo -e "   └── .git/ (initialized)"
echo ""
echo -e "🚀 下一步:"
echo -e "   cd $PROJECT_PATH"
echo -e "   bash .claude/verify-rule.sh verify    # 验证 hooks 工作"
echo -e "   ${BOLD}# 现在进入项目目录,Claude Code 会自动加载 CLAUDE.md${NC}"
echo ""
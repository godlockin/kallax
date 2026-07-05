#!/usr/bin/env bash
# token-economy-enforcer.sh - Claude Code PreToolUse hook
# 拦截"会污染大模型上下文的命令",提示精简替代
#
# 配合 ~/.claude/CLAUDE.md 第 10 章(软约束)
# 与 bash-rule-enforcer.sh 互补(那个拦日志监控,这个拦大输出)
#
# 设计原则:
# - 智能判断:根据文件大小 / 命令类型决定是否拦截
# - 友好提示:不只说"违规",还告诉"如何改"
# - 误报低:小文件 cat 不拦,只拦 > 100KB
# - exit 2 拒绝(exit 0 警告但放行)
#
# 检测模式:
#  1. cat/cp/diff 大文件(> 100KB)
#  2. find 不带 -max-depth / head
#  3. grep -r 不带 --max-count
#  4. git log --all 不带 --oneline/-n
#  5. ls -R (递归,可能巨大)
#  6. du -sh 不带 --max-depth

set -uo pipefail

# 从 stdin 读 hook payload(JSON)
PAYLOAD=$(cat)
TOOL_NAME=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")

# 只拦截 Bash 工具
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

CMD=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

if [[ -z "$CMD" ]]; then
  exit 0
fi

# 通过 exec-task.sh 跑的合规
if echo "$CMD" | grep -qE '\bexec-task\.sh\b'; then
  exit 0
fi

# 文件大小阈值(KB)
LARGE_FILE_KB=50    # > 50KB 拒绝
WARN_FILE_KB=10     # > 10KB 警告

# 分两类:ERR(拒绝,exit 2)和 WARN(警告,exit 0)
ERRORS=()
WARNS=()

# === 检查 1:cat/cp/diff/head 大文件 ===
check_large_file_cmd() {
  local tool="$1" cmd="$2"
  # 提取参数(去掉开头 tool,跳过 -it/-n 等 flag)
  local args
  args=$(echo "$cmd" | sed -E "s/.*\b${tool}\b//" | awk '{for(i=1;i<=NF;i++) print $i}')

  for f in $args; do
    # 跳过 - 开头的 flag
    [[ "$f" == -* ]] && continue
    [[ "$f" == *"|"* ]] && continue
    [[ -f "$f" ]] || continue
    local size_kb
    size_kb=$(($(stat -f %z "$f" 2>/dev/null || stat -c %s "$f" 2>/dev/null || echo 0) / 1024))
    if [[ $size_kb -gt $LARGE_FILE_KB ]]; then
      ERRORS+=("❌ ${tool} ${f} (${size_kb}KB) > ${LARGE_FILE_KB}KB,建议 tail -n 50 或 jq/yq")
    elif [[ $size_kb -gt $WARN_FILE_KB ]]; then
      WARNS+=("⚠️  ${tool} ${f} (${size_kb}KB) > ${WARN_FILE_KB}KB,建议确认是否需要全文")
    fi
  done
}

if echo "$CMD" | grep -qE '\bcat[[:space:]]+[^|;&]'; then
  check_large_file_cmd "cat" "$CMD"
fi
if echo "$CMD" | grep -qE '\bcp[[:space:]]+[^|;&]'; then
  check_large_file_cmd "cp" "$CMD"
fi
if echo "$CMD" | grep -qE '\bdiff[[:space:]]+[^|;&]'; then
  check_large_file_cmd "diff" "$CMD"
fi

# === 检查 2:find 不带 max-depth 或 head ===
# 例外:有 | head/tail/wc/-max-depth 算合规
if echo "$CMD" | grep -qE '\bfind[[:space:]]'; then
  if ! echo "$CMD" | grep -qE '\|[[:space:]]*(head|tail|wc|-print)'; then
    if ! echo "$CMD" | grep -qE '\-(maxdepth|max-depth)'; then
      # 但 find . 不算违规(限定到当前目录)
      if ! echo "$CMD" | grep -qE '\bfind[[:space:]]+\.[[:space:]]*$'; then
        VIOLATIONS+=("⚠️  find 无 max-depth 或 head/tail/wc,可能输出大量路径(建议加 -maxdepth 4)")
      fi
    fi
  fi
fi

# === 检查 3:grep -r 不带 --max-count ===
if echo "$CMD" | grep -qE '\bgrep[[:space:]]+-[a-zA-Z]*[rR]'; then
  if ! echo "$CMD" | grep -qE '(--max-count|-m[[:space:]]+[0-9]|head[[:space:]]+-[0-9]+)'; then
    VIOLATIONS+=("⚠️  grep -r 无 --max-count,可能输出大量行(建议加 -m 20)")
  fi
fi

# === 检查 4:git log --all 不带 -n ===
if echo "$CMD" | grep -qE '\bgit[[:space:]]+log[[:space:]]+(.*--all|-p)'; then
  if ! echo "$CMD" | grep -qE '(-n[[:space:]]+[0-9]+|--oneline|--stat)'; then
    VIOLATIONS+=("⚠️  git log --all 无 --oneline/-n N,可能输出全部 commit(建议加 --oneline -20)")
  fi
fi

# === 检查 5:git diff 不带 --stat ===
if echo "$CMD" | grep -qE '\bgit[[:space:]]+diff([[:space:]]|$)'; then
  if ! echo "$CMD" | grep -qE '(--stat|--name-only|--name-status)'; then
    VIOLATIONS+=("⚠️  git diff 无 --stat,可能输出大量行(建议先 --stat 看摘要)")
  fi
fi

# === 检查 6:ls -R (递归) ===
if echo "$CMD" | grep -qE '\bls[[:space:]]+(-[a-zA-Z]*[rR]|[[:space:]]+-[a-zA-Z]*[rR])'; then
  VIOLATIONS+=("⚠️  ls -R 递归,可能输出大量文件(建议 ls /path | head)")
fi

# === 输出结果 ===
if [[ ${#ERRORS[@]} -gt 0 ]] || [[ ${#WARNS[@]} -gt 0 ]]; then
  {
    echo "⚡ Token Economy 提醒 (Bash PreToolUse Hook)"
    echo ""
    [[ ${#ERRORS[@]} -gt 0 ]] && { echo "🔴 必须修复:"; printf '%s\n' "${ERRORS[@]}"; echo ""; }
    [[ ${#WARNS[@]} -gt 0 ]] && { echo "🟡 建议确认:"; printf '%s\n' "${WARNS[@]}"; echo ""; }
    echo "💡 精简策略:"
    echo "  - 大文件 → tail -n 50 / head -n 20"
    echo "  - JSON   → jq '.field'"
    echo "  - YAML   → yq '.spec'"
    echo "  - Git    → --oneline -20 / --stat"
    echo "  - 搜索   → rg --max-count 20"
    echo ""
    echo "📖 完整规则:~/.claude/CLAUDE.md 第 10 章 + docs/token-economy.md"
  } >&2

  # ERR 拒绝,WARN 放行(但 stderr 提示)
  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    exit 2
  else
    exit 0
  fi
fi

# 合规
exit 0
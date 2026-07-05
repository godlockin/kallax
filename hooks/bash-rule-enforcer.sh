#!/usr/bin/env bash
# bash-rule-enforcer.sh - Claude Code PreToolUse hook
# 拦截 Bash 工具调用,检测违反 CLI Rule 的命令模式
#
# 配置在 ~/.claude/settings.json 的 hooks.PreToolUse 中
# 匹配 Bash 工具,exit 2 = 拒绝并 stderr 提示原因
#
# 检测的违规模式:
#  1. tail -f / tail -F / less +F(监控日志,违反 Rule 5)
#  2. watch <cmd>(实时监控)
#  3. cat <big.log> 不通过 exec-task.sh wrapper 直接 dump
#  4. head/tail 后跟大数字(>=1000 行)
#
# 任何违规 exit 2 + stderr 提示正确用法
# 合规 exit 0

set -uo pipefail

# 从 stdin 读 hook payload(JSON)
PAYLOAD=$(cat)
TOOL_NAME=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")

# 只拦截 Bash 工具
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# 提取 bash 命令
CMD=$(echo "$PAYLOAD" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

if [[ -z "$CMD" ]]; then
  exit 0
fi

VIOLATIONS=()

# === 检查 1: tail -f / tail -F / less +F / watch ===
if echo "$CMD" | grep -qE '\btail[[:space:]]+(-[a-zA-Z]*[fF]|-[a-zA-Z]*f|-[a-zA-Z]*F)'; then
  VIOLATIONS+=("❌ 检测到日志监控命令 tail -f")
elif echo "$CMD" | grep -qE '\bless[[:space:]]+\+F'; then
  VIOLATIONS+=("❌ 检测到 less +F 监控命令")
elif echo "$CMD" | grep -qE '\bwatch[[:space:]]'; then
  VIOLATIONS+=("❌ 检测到 watch 监控命令")
fi

# === 检查 2: 直接 tail/cat 大文件,不用 exec-task wrapper ===
# 例外:exec-task.sh 调用本身 / head 小数字 / --tail N(单次快照 OK)
if echo "$CMD" | grep -qE '\bexec-task\.sh\b'; then
  # 通过 wrapper 跑,合规
  :
elif echo "$CMD" | grep -qE '\b(tail|cat|head|less|more)[[:space:]]+[^|;&]*/[^|;&]*\.(log|out|txt|err)([[:space:]]|$|;|\|)'; then
  # /path/to/something.{log,out,txt,err}
  VIOLATIONS+=("❌ 直接读 .log/.out/.txt/.err,应通过 exec-task.sh 或 tail -n 10(单次)")
elif echo "$CMD" | grep -qE '\b(tail|cat|head|less|more)[[:space:]]+[^|;&]*[^/]*\.(log|out|txt|err)([[:space:]]|$|;|\|)'; then
  # basename.ext 也可能匹配(somefile.log)
  VIOLATIONS+=("❌ 直接读 .log/.out/.txt/.err,应通过 exec-task.sh 或 tail -n 10(单次)")
elif echo "$CMD" | grep -qE '\b(tail|cat|head|less|more)[[:space:]]+[^|;&]*\b(log|syslog|access\.log|error\.log|debug\.log)([[:space:]]|$|;|\|)'; then
  # /var/log/syslog, app.log, error.log, etc.
  VIOLATIONS+=("❌ 直接读日志文件(常见名),应通过 exec-task.sh 或 tail -n 10")
elif echo "$CMD" | grep -qE '\btail[[:space:]]+-[nN][0-9]+'; then
  VIOLATIONS+=("⚠️  tail -n N 仍会输出 N 行,建议用 exec-task.sh --tail N 自动包装")
fi

# === 检查 3: head/tail 行数 ≥100(可能是 dump 大量输出) ===
HUGE_LINE=$(echo "$CMD" | grep -oE '\b(head|tail)[[:space:]]+-[a-zA-Z]*[0-9]{3,}' | head -1)
if [[ -n "$HUGE_LINE" ]] && ! echo "$CMD" | grep -q 'exec-task.sh'; then
  VIOLATIONS+=("❌ head/tail 行数过大($HUGE_LINE),可能 dump 大量输出")
fi

# === 检查 4: 查找/搜索输出过大(find/grep 无 head/limit) ===
if echo "$CMD" | grep -qE '\bfind[[:space:]]+[^|;&]*$' && \
   ! echo "$CMD" | grep -qE 'head|tail|wc'; then
  # find 无 pipe 限行 = 可能输出千万路径
  VIOLATIONS+=("⚠️  find 无 head/tail 限行,可能输出大量路径(建议 pipe 给 head -n)")
fi

# === 输出结果 ===
if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  {
    echo "🚨 CLI Rule 违规拦截 (Bash PreToolUse Hook)"
    echo ""
    printf '%s\n' "${VIOLATIONS[@]}"
    echo ""
    echo "✅ 正确用法:"
    echo "  bash ~/.claude/exec-task.sh '<name>' '<cmd>'   # 后台 + 自动 tail 10"
    echo ""
    echo "📖 完整规则见 ~/.claude/CLAUDE.md 第 9 章"
  } >&2
  exit 2  # 拒绝命令
fi

# 合规
exit 0
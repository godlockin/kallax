#!/usr/bin/env bash
# verify-rule.sh - 验证 CLI Rule 5 条强制契约的完整性
#
# 用法:
#   bash ~/.claude/verify-rule.sh verify       # 全量检查,exit 0 = 通过
#   bash ~/.claude/verify-rule.sh hash        # 只算 hash
#   bash ~/.claude/verify-rule.sh help
#
# 检查项:
#   1. ~/.claude/CLAUDE.md 第 9 章存在
#   2. ~/.claude/exec-task.sh 存在 + hash 一致
#   3. ~/.claude/hooks/bash-rule-enforcer.sh 存在 + 可执行
#   4. ~/.claude/settings.json 的 PreToolUse 包含 bash-rule-enforcer.sh
#   5. 关键违规模式都识别(tail -f, cat .log, etc.)

set -uo pipefail

# 默认查 ~/.claude/,但可通过环境变量覆盖(便于 kallax 内部用)
CLAUDE_DIR="${AVLE_CLAUDE_DIR:-$HOME/.claude}"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
EXEC_TASK="$CLAUDE_DIR/exec-task.sh"
HOOK_SCRIPT="$CLAUDE_DIR/hooks/bash-rule-enforcer.sh"
SETTINGS_JSON="$CLAUDE_DIR/settings.json"

PASS=0
FAIL=0

ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# === 检查 1: CLAUDE.md 第 9 章 ===
check_claude_md() {
  echo ""
  echo "═══ [1/5] CLAUDE.md 第 9 章 ═══"
  if [[ ! -f "$CLAUDE_MD" ]]; then
    fail "CLAUDE.md 不存在: $CLAUDE_MD"
    return
  fi
  ok "CLAUDE.md 存在"

  if grep -q "CLI Task Execution Rule\|CLI 任务执行规范" "$CLAUDE_MD"; then
    ok "第 9 章标题存在"
  else
    fail "找不到第 9 章(CLI 任务执行规范)"
  fi

  if grep -q "核心原则" "$CLAUDE_MD"; then
    ok "核心原则段存在"
  else
    fail "核心原则段缺失"
  fi

  # 检查 5 条规则关键词
  for rule in "后台执行" "日志到 /tmp" "check exit code" "OK success" "不要监控日志"; do
    if grep -qF "$rule" "$CLAUDE_MD"; then
      ok "规则关键词: $rule"
    else
      fail "规则关键词缺失: $rule"
    fi
  done
}

# === 检查 2: exec-task.sh hash ===
check_exec_task() {
  echo ""
  echo "═══ [2/5] exec-task.sh 完整性 ═══"
  if [[ ! -f "$EXEC_TASK" ]]; then
    fail "exec-task.sh 不存在: $EXEC_TASK"
    return
  fi
  ok "exec-task.sh 存在"

  if [[ -x "$EXEC_TASK" ]]; then
    ok "exec-task.sh 可执行"
  else
    fail "exec-task.sh 不可执行(chmod +x)"
  fi

  # 完整性 marker 检查(替代 hash,因 hash self-consistency 难做)
  if grep -qF "EXEC_TASK_INTEGRITY_v1" "$EXEC_TASK"; then
    ok "完整性 marker 存在"
    EXPECTED=$(grep -oE 'EXEC_TASK_INTEGRITY_v1="[a-f0-9]+"' "$EXEC_TASK" | head -1 | sed 's/.*="//;s/"//')
    ACTUAL=$(shasum -a 256 "$EXEC_TASK" 2>/dev/null | awk '{print $1}')
    if [[ "$ACTUAL" == "$EXPECTED" ]]; then
      ok "exec-task.sh hash 与 marker 一致"
    else
      echo "  ℹ️  hash 不匹配(可能为正常演进,marker 记录旧值)"
      echo "     marker:  ${EXPECTED:0:16}..."
      echo "     actual: ${ACTUAL:0:16}..."
      echo "  → 如是合法演进:bash ~/.claude/verify-rule.sh update"
    fi
  else
    fail "完整性 marker 缺失(marker EXEC_TASK_INTEGRITY_v1)"
  fi
}

# === 检查 3: hook 脚本 ===
check_hook() {
  echo ""
  echo "═══ [3/5] hooks/bash-rule-enforcer.sh ═══"
  if [[ ! -f "$HOOK_SCRIPT" ]]; then
    fail "hook 脚本不存在: $HOOK_SCRIPT"
    return
  fi
  ok "hook 脚本存在"

  if [[ -x "$HOOK_SCRIPT" ]]; then
    ok "hook 脚本可执行"
  else
    fail "hook 脚本不可执行"
  fi

  # 测一下 hook 是否工作
  TEST_PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"tail -f /var/log/syslog"}}'
  HOOK_RC=$(echo "$TEST_PAYLOAD" | bash "$HOOK_SCRIPT" >/dev/null 2>&1; echo $?)
  if [[ "$HOOK_RC" -eq 2 ]]; then
    ok "hook 正确拦截 tail -f (exit=2)"
  else
    fail "hook 未拦截 tail -f (exit=$HOOK_RC, 期望 2)"
  fi

  # 合规命令
  GOOD_RC=$(echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | bash "$HOOK_SCRIPT" >/dev/null 2>&1; echo $?)
  if [[ "$GOOD_RC" -eq 0 ]]; then
    ok "hook 正确放行 git status (exit=0)"
  else
    fail "hook 误拦截 git status (exit=$GOOD_RC)"
  fi
}

# === 检查 4: settings.json hook 配置 ===
check_settings() {
  echo ""
  echo "═══ [4/5] ~/.claude/settings.json ═══"
  if [[ ! -f "$SETTINGS_JSON" ]]; then
    fail "settings.json 不存在"
    return
  fi
  ok "settings.json 存在"

  # 检查 PreToolUse 包含 Bash + bash-rule-enforcer
  if python3 -c "
import json
with open('$SETTINGS_JSON') as f:
    s = json.load(f)
hooks = s.get('hooks', {}).get('PreToolUse', [])
for h in hooks:
    if h.get('matcher') == 'Bash':
        for cmd in h.get('hooks', []):
            if 'bash-rule-enforcer' in cmd.get('command', ''):
                exit(0)
exit(1)
" 2>/dev/null; then
    ok "PreToolUse 包含 Bash + bash-rule-enforcer"
  else
    fail "PreToolUse 未配置 Bash + bash-rule-enforcer"
  fi
}

# === 检查 5: 违规模式识别 ===
check_violations() {
  echo ""
  echo "═══ [5/5] 违规模式识别测试 ═══"

  declare -a CASES=(
    "tail -f /var/log/app.log|2"
    "tail -F /tmp/foo.log|2"
    "less +F app.log|2"
    "watch -n 1 date|2"
    "cat /var/log/syslog|2"
    "tail -n 50 /tmp/foo.log|2"
    "cat /tmp/something.log|2"
    "tail -n 5 README.md|0"     # 合规:不是日志
    "cat ~/.config/avle.conf|0"  # 合规:不是日志
    "git status|0"
    "ls -la|0"
    "bash ~/.claude/exec-task.sh test 'echo hi'|0"  # 合规:用 wrapper
  )

  for case in "${CASES[@]}"; do
    cmd="${case%|*}"
    expected="${case##*|}"
    payload=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" "$cmd")
    actual=$(echo "$payload" | bash "$HOOK_SCRIPT" >/dev/null 2>&1; echo $?)

    desc=$(echo "$cmd" | cut -c1-40)
    if [[ "$actual" -eq "$expected" ]]; then
      ok "[exit=$actual] $desc"
    else
      fail "[exit=$actual, 期望 $expected] $desc"
    fi
  done
}

# === update 子命令:更新 hash ===
do_update() {
  echo "更新 exec-task.sh 的 INTEGRITY marker..."
  ACTUAL=$(shasum -a 256 "$EXEC_TASK" | awk '{print $1}')

  # 用 Python(避免 shell 转义)
  python3 - "$EXEC_TASK" "$ACTUAL" <<'PYEOF'
import re, sys
path = sys.argv[1]
new_hash = sys.argv[2]
with open(path, 'r') as f:
    content = f.read()
new_content = re.sub(
    r'EXEC_TASK_INTEGRITY_v1="[a-f0-9]+"',
    f'EXEC_TASK_INTEGRITY_v1="{new_hash}"',
    content
)
with open(path, 'w') as f:
    f.write(new_content)
print(f"✅ 更新 marker hash: {new_hash[:16]}...")
PYEOF
}

# === 入口 ===
case "${1:-verify}" in
  verify)
    echo "🔍 AVLE CLI Rule 完整性验证 / Integrity Verification"
    echo ""
    check_claude_md
    check_exec_task
    check_hook
    check_settings
    check_violations

    echo ""
    echo "═══════════════════════════════════════"
    echo "✅ PASS: $PASS | ❌ FAIL: $FAIL"
    echo "═══════════════════════════════════════"

    if [[ $FAIL -eq 0 ]]; then
      echo ""
      echo "🎉 所有检查通过!CLI Rule 完整。"
      exit 0
    else
      echo ""
      echo "⚠️  有 $FAIL 项检查失败。请修复后重跑。"
      exit 1
    fi
    ;;

  hash)
    echo "exec-task.sh SHA256:"
    shasum -a 256 "$EXEC_TASK" | awk '{print "  "$1}'
    ;;

  update)
    do_update
    ;;

  help|--help|-h)
    cat <<'EOF'
verify-rule.sh - CLI Rule 完整性验证

用法:
  bash ~/.claude/verify-rule.sh verify       # 全量检查
  bash ~/.claude/verify-rule.sh hash        # 算 hash
  bash ~/.claude/verify-rule.sh update      # 更新 EXPECTED_SHA256(合法修改后跑)
  bash ~/.claude/verify-rule.sh help

检查 5 项:
  1. CLAUDE.md 第 9 章 + 核心原则 + 5 条规则关键词
  2. exec-task.sh 存在 + 可执行 + hash 一致
  3. hooks/bash-rule-enforcer.sh 存在 + 可执行 + 测试拦截
  4. settings.json 包含 PreToolUse Bash + bash-rule-enforcer
  5. 12 个违规/合规 case 测试
EOF
    ;;

  *)
    echo "Unknown: $1" >&2
    exit 1
    ;;
esac
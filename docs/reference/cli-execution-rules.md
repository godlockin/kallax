# CLI 执行规范 (whisper-cpp 教训)

> 主 CLAUDE.md 提到 "5 immutable scripts" 但没展开 5 条 CLI 规则

**主 CLAUDE.md**: root, 中段 (引用本文件)
**本文件加载场景**: Master (主公) 派遣新 sub-performer, 或 sub-performer 在跑 long-running bash 任务时

---

## 来源

whisper-cpp 10 段全失败未发现 (wrapper 无 fail-fast + 未主动 grep "FAILED"). KALLAX v0 时代吃了亏定下规则.

---

## 5 条强制

1. **后台执行** — 所有 CLI 命令后台跑, 不阻塞主会话
   - 用 `run_in_background: true` 参数 (Bash tool)
   - 或 `nohup ... &` + `disown`
   - 或本仓库 `bash ~/.claude/exec-task.sh "<name>" "<cmd>"` 包装脚本

2. **日志到 /tmp** — 所有输出重定向到 `/tmp/claude-tasks/<task>-<ts>.log`:
   ```bash
   mkdir -p /tmp/claude-tasks
   LOG="/tmp/claude-tasks/mytask-$(date +%Y%m%d-%H%M%S).log"
   my_command > "$LOG" 2>&1 &
   ```

3. **检查 exit code** — 不假设 "没看到错误 = 成功":
   ```bash
   if ! cmd; then
     echo "error"
     exit 1
   fi
   ```

4. **返回 OK/FAILED + 自动 tail** — 成功只返回一行, 失败自动 tail 最后 10 行:
   ```
   OK success
   log: /tmp/claude-tasks/foo-20260726-123456.log
   
   # or
   
   FAILED exit=1
   log: /tmp/claude-tasks/foo-20260726-123456.log
   --- last 10 lines ---
   <exit 10 lines>
   --- end ---
   ```

5. **禁止监控日志** — ❌ `tail -f` / `tail -F` / `less +F` / `watch`. 永远只看尾部静态快照.

---

## ⚠️ nohup & 是逃逸路径

- `nohup ... &` 可绕过 PreToolUse hook 的 `tail -f` 拦截检测 (hook 以为是 "后台任务" 而不是 "监控")
- 解法: 统一走 `~/.claude/exec-task.sh` wrapper
- Wrapper 自身必须 `set -e` + `trap ERR`, 否则内部命令失败也静默

---

## Fail-Fast 强制 (EPIC-026-A 教训)

- ❌ 禁止 `cmd || true` 吞错误继续跑
- ✅ 必须 `if ! cmd; then echo "error"; exit 1; fi`
- 关键路径 (heartbeat-daemon / queue emit / atomic mv): 每步必须显式检查

---

## 验证

```bash
bash ~/.claude/verify-rule.sh verify   # 检查 ~/.claude/ 配置完整性
```

---

## 与 Token Economy Rule 的关系

CLI 执行规范是 Claude Code agent 层面的 runtime rule; Token Economy Rule (CLAUDE.md 第 10 章) 是 agent 内容输出层的 rule. 两者 orthogonal.

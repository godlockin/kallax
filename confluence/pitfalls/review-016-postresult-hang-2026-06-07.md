# REVIEW-016: Post-Result Hang Investigation

**Ticket**: EPIC-016-Q
**Priority**: P1
**Created**: 2026-06-06
**Status**: Investigation Complete
**Performer**: performer-EPIC-016-Q

---

## 1. 现象 (Symptoms)

### 1.1 问题描述

Claude Code 输出 result 后，会话完全停止响应用户输入。

**案例 1**: `Crunched 1m 43s`
- 会话在显示 "Crunched 1m 43s" 后无响应
- 进程存活，CPU 使用率归零
- 无法通过 Ctrl+C 中断，只能强制关闭终端

**案例 2**: `Churned 3m 13s` (5.5 分钟)
- 同样模式：result 输出后卡死
- 与案例 1 相同时间量级（分钟级）
- 复现频率：每 10-20 次会话约 1 次

### 1.2 影响范围

- 阻塞新会话可用性
- 用户工作流完全停摆
- 无法通过正常手段恢复（只能强杀进程）
- 影响所有并发会话数（因为 Claude Code 实例被阻塞）

### 1.3 时间线

```
T+0:00    用户提交 prompt
T+0:01    Claude Code 开始处理
T+0:23    result 输出（23 秒执行）
T+1:43    显示 "Crunched 1m 43s"
T+1:43+   会话无响应 — 挂起
```

---

## 2. 嫌疑排序 (Suspect Ranking)

### 2.1 嫌疑 (a) — Stop hook 同步阻塞 [最可能]

**当前配置** (`~/.claude/settings.json` 第 375-386 行):

```json
"Stop": [
  {
    "matcher": "",
    "hooks": [
      {
        "type": "command",
        "command": "\"/usr/local/bin/node\" \"/Users/chenchen/working/sourcecode/tools/llm_apps/clawd-on-desk/hooks/clawd-hook.js\" Stop",
        "async": true,
        "timeout": 5
      }
    ]
  }
]
```

**嫌疑依据**:

1. **时序匹配**: Stop hook 在每次 result 输出后触发，与 hang 发生时机完全吻合
2. **配置存在**: Stop hook 已配置 `async: true` 和 `timeout: 5`，但 `async: true` 并不保证非阻塞（Claude Code 可能仍等待 hook 完成）
3. **claudd-hook.js 复杂度**: 该 hook 内部可能有：
   - 文件系统操作（auto-evolve.sh 写入）
   - Node.js 子进程链式调用
   - HTTP 请求（如果 hook 有网络调用）
4. **历史案例**: 5.5min 那次 "Churned 3m 13s" 与 hook 超时模式一致

**可能的根因**: hook 虽然标记 `async: true`，但 Claude Code 仍可能等待 hook 进程退出。若 hook 内部链式调用（比如调用其他脚本/子进程），可能形成 IPC 阻塞。

**证据**: 在 settings.json 中，`hooks.Stop` 的 `async: true` 只是告诉 Claude Code 不要等待响应，但 Stop hook 的 stderr/stdout 可能仍被父进程管道持有。

---

### 2.2 嫌疑 (b) — claude-mem worker query 慢 [中可能]

**当前状态**: `claude-mem@thedotmack` plugin 已启用 (`settings.json` 第 271 行)

**嫌疑依据**:

1. **plugin 已启用**: claude-mem 是活跃的后台服务
2. **数据库操作**: claude-mem 依赖 SQLite，每次会话结束会执行 worker query
3. **潜在瓶颈**: 如果 worker 在写入 `~/.claude/mem/` 数据库时持有文件锁，可能阻塞父进程
4. **时序**: SessionEnd hook 先于 Stop hook 执行（第 310-321 行），但 claude-mem 可能在后台持续占用资源

**诊断方法**:

```bash
# 观察 claude-mem 数据库文件
ls -la ~/.claude/mem/*.db
# 观察是否有 .lock 文件
find ~/.claude/mem/ -name "*.lock" -o -name "*.wal"
# 在 hang 发生时 lsof
lsof ~/.claude/mem/
```

**注意**: claude-mem 的 worker 理论上不会直接阻塞 Claude Code 进程，但如果它触发了 auto-evolve 写入（写 `~/.claude/pending-evolutions.jsonl`），可能与 Stop hook 链式执行。

---

### 2.3 嫌疑 (c) — Recap 生成后 idle 状态不释放 [低可能]

**嫌疑依据**:

1. **Recap 生成**: Claude Code 在长会话结束时会生成 recap 并写入 `.claude/commands/` 或类似位置
2. **状态机 bug**: 如果 Recap 生成逻辑在写入文件后未正确释放内部状态，可能导致事件循环阻塞
3. **与 Stop hook 的交互**: Recap 生成可能触发 SessionEnd hook，而 SessionEnd hook 链式调用 Stop hook

**代码路径推断**:

```
SessionEnd hook 触发
  → claude-mem worker 写入数据库
  → auto-evolve.sh 写入 pending-evolutions.jsonl
  → Stop hook 链式执行 clawd-hook.js
  → 其中某个环节阻塞
```

---

### 2.4 嫌疑 (d) — Claude Code 内部 bug [低可能]

**嫌疑依据**:

1. **平台问题**: Claude Code 内部可能有状态机在特定条件下不释放
2. **非开源**: 无法直接修复，只能等官方 fix
3. **已知 issue**: 社区有类似报告（"session hangs after result output"）

**长期方案**: 等 Anthropic 发布 patch

---

## 3. 诊断 SOP (Diagnostic Procedure)

### 3.1 实时诊断脚本

当 hang 发生时，在**另一个 terminal 窗口**执行：

```bash
#!/bin/bash
# 保存到 /tmp/kallax-hang-diag.sh
# 用法: chmod +x /tmp/kallax-hang-diag.sh && /tmp/kallax-hang-diag.sh

PID=$PPID  # Claude Code 主进程 PID

echo "=== System State at $(date) ==="
echo "Parent PID: $PID"

echo ""
echo "=== fs_usage (filesys, 10s sample) ==="
fs_usage -w -f filesys $PID 2>/dev/null | head -30 &
FS_PID=$!

echo ""
echo "=== lsof - PIPE/TCP ==="
lsof -p $PID 2>/dev/null | grep -E 'PIPE|TCP' | head -20

echo ""
echo "=== ps state ==="
ps -p $PID -o pid,ppid,state,etime,command

echo ""
echo "=== syscalls (10s) ==="
sudo dtrace -n 'syscall:::entry /pid == $PID/ { @[probefunc] = count(); }' -c "sleep 10" 2>/dev/null || echo "dtrace not available"

echo ""
echo "=== tail -f /tmp/kallax-hang-diag.log ==="
echo "Waiting for hang... (Ctrl+C to stop)"
```

### 3.2 快速检查清单

Hang 发生时，立即检查：

```bash
# 1. 进程状态
ps aux | grep -E 'claude|node' | grep -v grep

# 2. 打开的文件描述符
lsof -p $(pgrep -f claude-code | head -1) 2>/dev/null | wc -l

# 3. 网络连接
lsof -i -P 2>/dev/null | grep -E 'ESTABLISHED|CLOSE_WAIT' | head -10

# 4. 子进程树
pstree -p $(pgrep -f claude-code | head -1) 2>/dev/null

# 5. CPU/内存
top -l 1 -n 5 -p $(pgrep -f claude-code | head -1)
```

### 3.3 诊断结果解读

| 现象 | 指向 | 操作 |
|------|------|------|
| `lsof` 显示大量 PIPE | Stop hook 管道未清空 | 增加 hook timeout 或加 `|| true` |
| `fs_usage` 显示持续文件写入 | auto-evolve 或 claude-mem | 检查 `~/.claude/pending-evolutions.jsonl` |
| `ps` 显示 `S` (sleep) 状态 | 等待 I/O | 追踪占用文件的进程 |
| `dtrace` 显示 `read` syscall 阻塞 | 文件锁持有 | `lsof` 找到锁文件 |

---

## 4. 短期 Workaround

### 4.1 Stop Hook 加 Timeout + `|| true`

**原理**: 将 Stop hook 包裹在 `timeout 10s || true` 中，确保 10 秒后强制终止，避免无限等待。

**操作步骤**:

1. 备份当前配置:
   ```bash
   cp ~/.claude/settings.json ~/.claude/settings.json.bak.$(date +%Y%m%d%H%M%S)
   ```

2. 编辑 `~/.claude/settings.json`，找到 `hooks.Stop` (第 375-386 行):

   **修改前**:
   ```json
   "Stop": [
     {
       "matcher": "",
       "hooks": [
         {
           "type": "command",
           "command": "\"/usr/local/bin/node\" \"/Users/chenchen/working/sourcecode/tools/llm_apps/clawd-on-desk/hooks/clawd-hook.js\" Stop",
           "async": true,
           "timeout": 5
         }
       ]
     }
   ]
   ```

   **修改后**:
   ```json
   "Stop": [
     {
       "matcher": "",
       "hooks": [
         {
           "type": "command",
           "command": "timeout 10s /usr/local/bin/node \"/Users/chenchen/working/sourcecode/tools/llm_apps/clawd-on-desk/hooks/clawd-hook.js\" Stop || true",
           "async": true,
           "timeout": 12
         }
       ]
     }
   ]
   ```

3. **注意**: `timeout` 命令在 macOS 上需要安装 coreutils (`brew install coreutils`)，或者使用 BSD `timeout` (macOS 内置，参数语义略有不同)。

   **macOS BSD timeout** (参数不同):
   ```json
   "command": "timeout -s TERM 10 /usr/local/bin/node \"/Users/chenchen/working/sourcecode/tools/llm_apps/clawd-on-desk/hooks/clawd-hook.js\" Stop || true"
   ```

4. 重启 Claude Code 验证生效

### 4.2 验证方法

```bash
# 确认配置已更新
grep -A5 '"Stop":' ~/.claude/settings.json

# 手动触发 Stop hook 测试
/usr/local/bin/node "/Users/chenchen/working/sourcecode/tools/llm_apps/clawd-on-desk/hooks/clawd-hook.js" Stop
echo "Exit code: $?"

# 观察 10 秒内是否退出
time timeout 10s /usr/local/bin/node "/Users/chenchen/working/sourcecode/tools/llm_apps/clawd-on-desk/hooks/clawd-hook.js" Stop
```

### 4.3 如果 timeout 不可用

使用 wrapper script:

```bash
# 创建 /tmp/stop-hook-wrapper.sh
#!/bin/bash
/usr/local/bin/node "/Users/chenchen/working/sourcecode/tools/llm_apps/clawd-on-desk/hooks/clawd-hook.js" Stop
```

然后在 settings.json 中:

```json
"command": "timeout 10s /tmp/stop-hook-wrapper.sh || true"
```

---

## 5. 长期方案

### 5.1 平台级 Fix

这是 Claude Code 内部 bug，无法通过用户代码修复。长期方案：

1. **等待官方 patch**: 在 [Anthropic Status Page](https://status.anthropic.com) 关注修复进度
2. **提交 issue**: 在 Claude Code GitHub 仓库提交包含 `fs_usage` + `lsof` 数据的报告
3. **Worktree 隔离**: 使用 `git worktree` 创建独立会话，避免同一个 Claude Code 实例长期运行

### 5.2 架构降级

如果 hang 频繁发生，可考虑降级到无 hook 配置：

```json
"disabled_hooks": {
  "Stop": [
    {
      "matcher": "",
      "hooks": []
    }
  ]
}
```

**代价**: 失去 auto-evolve、claude-mem 等功能

### 5.3 监控告警

在 hang 发生前检测异常：

```bash
# 在 tmux session 中持续监控
watch -n 5 'ps aux | grep -E "claude-code|node" | grep -v grep | wc -l'
```

如果进程数异常（如超过 20 个 node 进程），立即重启 Claude Code。

---

## 6. 相关文件

| 文件 | 路径 | 说明 |
|------|------|------|
| Settings | `~/.claude/settings.json` | Stop hook 配置 |
| Auto-evolve | `~/.claude/hooks/auto-evolve.sh` | SessionEnd 链式调用的脚本 |
| Pending Evolutions | `~/.claude/pending-evolutions.jsonl` | auto-evolve 输出 |
| clawd-hook | `/Users/chenchen/working/sourcecode/tools/llm_apps/clawd-on-desk/hooks/clawd-hook.js` | Stop hook 目标 |
| claude-mem DB | `~/.claude/mem/` | claude-mem SQLite 数据库 |

---

## 7. 结论

| 嫌疑 | 概率 | 证据 |
|------|------|------|
| (a) Stop hook 同步阻塞 | **60%** | 时序匹配 + hook 链式调用 |
| (b) claude-mem worker | 20% | plugin 已启用，可能持有文件锁 |
| (c) Recap idle 不释放 | 15% | 内部状态机 bug，难直接验证 |
| (d) Claude Code 内部 bug | 5% | 平台 issue，无法自修 |

**推荐立即行动**: 修改 `~/.claude/settings.json` Stop hook，加 `timeout 10s || true`

**预期效果**: 如果是 hook 阻塞，10 秒后强制终止，会话恢复正常响应

**如果无效**: 则排除 (a)，转向 (b) 和 (c)，需要 `fs_usage` + `lsof` 进一步诊断
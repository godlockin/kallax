# CLI Rule (kallax framework) / CLI 执行规范

> **来源**:从 `anti-violent-layoff-evidence` 项目提取(v1.2.7)。
> **位置**:`~/.claude/` 用户级,kallax 通过 `hooks/` 分发脚本。
> **目的**:防止大模型/协同框架遗忘或绕过 CLI 执行规范。

---

## 🎯 核心原则 / Core Principle

```
准备和构建命令时需要跟大模型交互;
运行时使用后台进程 + 返回值监控,
不要监控日志(tail -f 或前台执行),
通过监控返回值校验任务状态:

  ✅ 成功 → 直接标记 OK,删除日志(节省空间)
  ❌ 失败 → 自动 tail -10 看上下文
            信息不够 → tail -10..20..30 逐步加大窗口
            看完整 → cat <log>

核心:不浪费上下文窗口给无意义的实时日志流。
```

---

## 📜 5 条强制规则 / 5 Mandatory Rules

任何 CLI 任务(无论 bash / git / curl / awk / sed / node / python / cargo / brew / kubectl / docker 等)必须遵守:

### Rule 1 — 后台执行
- 用 `run_in_background: true` 或 `nohup ... &` + `disown`

### Rule 2 — 日志到 /tmp
- `/tmp/claude-tasks/<name>-<ts>.log`

### Rule 3 — check exit code
- `$?` / `$EXIT_CODE`,**永远不要假设成功**

### Rule 4 — 返回 OK success / FAILED + 自动 tail
- 成功:`OK success` + 删除日志
- 失败:`FAILED exit=N` + 自动 tail -10 + hint

### Rule 5 — 不监控日志
- ❌ `tail -f` / `less +F` / `watch`
- ✅ `tail -n 10 <log>`(单次快照)
- ✅ `cat <log>`(单次完整)

---

## 🛠️ 4 层防护 / 4 Layers of Protection

```
┌─────────────────────────────────────────────┐
│  Layer 1: Hook 系统级拦截                    │
│  ~/.claude/hooks/bash-rule-enforcer.sh     │
│  exit 2 = Claude Code 拒绝执行              │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  Layer 2: 自校验 marker                      │
│  exec-task.sh EXEC_TASK_INTEGRITY_v1        │
│  marker 缺失 → 启动警告                      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  Layer 3: verify-rule.sh 一键验证            │
│  5 项检查 + 12 个 case                       │
│  实测 29/29 PASS                            │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  Layer 4: CLAUDE.md 文档                     │
│  ~/.claude/CLAUDE.md 第 9 章                │
│  5 条规则 + 核心原则                        │
└─────────────────────────────────────────────┘
```

---

## 📦 文件清单 / Files

### 用户级配置(`~/.claude/`)
- `CLAUDE.md` — 第 9 章规则文档
- `exec-task.sh` — CLI wrapper(后台 + tail 10)
- `verify-rule.sh` — 验证脚本(5 项检查)
- `hooks/bash-rule-enforcer.sh` — PreToolUse hook
- `settings.json` — PreToolUse 配置

### kallax 分发(`kallax/hooks/`)
- `exec-task.sh` ← 同上
- `bash-rule-enforcer.sh` ← 同上
- `verify-rule.sh` ← 同上

---

## 🚀 接入方式 / Setup

### 用户首次接入

```bash
# 1) 复制脚本到 ~/.claude
cp kallax/hooks/exec-task.sh ~/.claude/
cp kallax/hooks/bash-rule-enforcer.sh ~/.claude/hooks/
cp kallax/hooks/verify-rule.sh ~/.claude/
chmod +x ~/.claude/exec-task.sh ~/.claude/hooks/*.sh ~/.claude/verify-rule.sh

# 2) 添加规则段到 ~/.claude/CLAUDE.md
# (手动复制"5 条强制规则" + "核心原则"两段)

# 3) 配置 hook 到 settings.json
# (手动合并 PreToolUse Bash matcher)

# 4) 验证
bash ~/.claude/verify-rule.sh verify
# 期望:29/29 PASS
```

### 用户接入后使用

```bash
# CLI 任务用 wrapper
bash ~/.claude/exec-task.sh "scan" "bash scripts/storage-evidence-scanner.sh"

# 输出:
# OK success
# log: /tmp/claude-tasks/scan-20260705-001305.log

# 失败时:
# FAILED exit=1
# log: /tmp/claude-tasks/scan-20260705-001305.log
# --- last 10 lines ---
# <末尾 10 行>
# --- end ---
# hint: bash ~/.claude/exec-task.sh --tail 20 ...  (追加 10 行)
```

---

## 📊 实测性能 / Benchmark

### Hook 拦截效果

| Case | 命令 | 期望 | 实测 |
|------|------|------|------|
| 应拦截 | `tail -f /var/log/app.log` | exit 2 | ✅ |
| 应拦截 | `tail -F /tmp/foo.log` | exit 2 | ✅ |
| 应拦截 | `less +F app.log` | exit 2 | ✅ |
| 应拦截 | `watch -n 1 date` | exit 2 | ✅ |
| 应拦截 | `cat /var/log/syslog` | exit 2 | ✅ |
| 应拦截 | `tail -n 50 /tmp/foo.log` | exit 2 | ✅ |
| 应拦截 | `cat /tmp/something.log` | exit 2 | ✅ |
| 合规 | `tail -n 5 README.md` | exit 0 | ✅ |
| 合规 | `cat ~/.config/avle.conf` | exit 0 | ✅ |
| 合规 | `git status` | exit 0 | ✅ |
| 合规 | `ls -la` | exit 0 | ✅ |
| 合规 | `bash exec-task.sh test echo hi` | exit 0 | ✅ |

**12/12 全部正确**

### Rust 加速(bash-rule-enforcer 不影响)

| 工具 | 替代 | 加速 |
|------|------|------|
| fd | find | **15.5x** (~/ 4 层 *.png: 1.24s → 0.08s) |
| rg | grep | 5-20x |
| eza | ls | 视觉 |
| bat | cat | 语法高亮 |
| delta | diff | 更好看 |
| dust | du | 可视化 |
| procs | ps | 视觉 |
| sd | sed | DX |
| xh | curl | DX |

---

## 🎯 集成案例 / Integration Cases

### Case 1: anti-violent-layoff-evidence(v1.2.7)
- 使用场景:扫描 ~/ 找证据文件、git commit 遍历、构建 case-brief.md
- 接入后:从 ~3min(find)→ 8s(fd);tail -f 自动拦截;日志自动管理

### Case 2: 任何大项目
- 任何有"长跑命令"的项目(构建、测试、迁移、扫描)都适用
- 只需要把 `hooks/` 复制到 `~/.claude/`

### Case 3: kallax 内部流程
- KALLAX 5 levels × 4 roles = 25 cells 中的后台任务
- 跑 expert 分析、生成 ADR 等

---

## 🛠️ 故障排查 / Troubleshooting

| 问题 | 解决 |
|------|------|
| `bash: exec-task.sh: command not found` | `chmod +x ~/.claude/exec-task.sh` |
| hook 不工作 | `bash verify-rule.sh verify` 看具体失败项 |
| verify 显示"hash 不匹配" | `bash verify-rule.sh update` |
| 误拦合规命令 | 改 hook `bash-rule-enforcer.sh` 加白名单 |

---

## 📚 完整文档链 / Doc Chain

- `kallax/docs/cli-rule.md` ← 你在这里
- `kallax/hooks/{exec-task,bash-rule-enforcer,verify-rule}.sh` ← 脚本
- `~/.claude/CLAUDE.md` 第 9 章 ← 用户级规则文档
- `~/.claude/settings.json` PreToolUse ← hook 配置
- `anti-violent-layoff-evidence/lessons-learned.md` ← 30 条原始教训

---

## 🪝 设计哲学 / Design Philosophy

**为什么这条 Rule 必须强制?**

1. **大模型上下文窗口宝贵** — 不能浪费在实时日志流上
2. **任务状态可用 exit code 完全表示** — 不需要监控
3. **失败时上下文是有限的** — 10-30 行足够诊断
4. **Hook 系统级拦截** — 大模型无法绕过自己写的规则
5. **Marker + verify 双保险** — 即使 hook 被改,marker 也能发现

**为什么用 4 层而非 1 层?**

1. 单层(只 CLAUDE.md)→ 大模型忽略
2. 单层(只 hook)→ hook 可被删
3. 单层(只 verify)→ 不自动拦截
4. **4 层叠加** → 文件被改,marker 警告;hook 被删,verify 报警;CLAUDE.md 被删,verify 失败;settings.json 被改,hook 不工作

---

## ⚖️ 一句话原则 / One-liner

> **后台跑,看 exit code,成功删日志,失败 tail 10 行。**
> **不要 tail -f。这条规则不可妥协。**

---

**Maintained by**:kallax framework
**Last updated**:2026-07-05
**Source**:anti-violent-layoff-evidence v1.2.7
**License**:MIT
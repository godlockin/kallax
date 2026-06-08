# EPIC-016-R: session_start.sh 永久卡死 — daemon stdio 全面防御

## 需求描述

EPIC-016「Init Performance Optimization」优化过程中，`.kallax/hooks/session_start.sh` 引入回归：每次在 kallax 目录下启动 Claude Code 都**永久卡死**（在 ~ 等其他目录启动正常，因为没有项目级 hook）。

### 根因（专家组确认）

**L2 系统设计缺陷**：项目从未定义「daemon invocation 标准」。在优化「首启动跳过心跳守护」时，把 `heartbeat-daemon.sh ... &` 包进 `if [ "${EXISTING_INSTANCES_COUNT}" -gt 0 ]; then` 块，**丢失了 `>/dev/null 2>&1` 重定向**——这导致后台 daemon 进程继承父 shell 的 stdout/stderr 管道，Node.js 的 `child_process.spawn` 等待所有继承 fd 关闭，永久 hang。

### 5 专家联合评审（2026-06-06 15:18 UTC）

| 专家 | 关键发现 |
|---|---|
| 🏗️ Architect | 根因层级 **L2**；还缺 `< /dev/null` (stdin) 重定向；首启动跳过心跳是监控盲区 |
| 💻 Backend | bash 机制确认；heartbeat-test.sh:99,178 有同模式 bug |
| 🖌️ UX | P0 严重度；Ctrl-C 后 zombie 循环（daemon 不死，state 永远 ACTIVE） |
| 📋 Product | P1 严重度（开发阻塞，非 customer-facing）；直接 commit 进 miao |
| ⚙️ DevOps | line 193 已修；建议 `setsid` + `disown` 完整进程组隔离；加结构化诊断日志 |

### 已修复部分

`.kallax/hooks/session_start.sh:193` 当前 working tree 已含 `>/dev/null 2>&1 &`，**实测 0.685s 退出**。

### 待修复（本次 ticket 范围）

详见 `ticket.json` 的 11 条 AC。

## 接受标准 (AC)

17 条 AC 详见 `ticket.json`（AC1-11: stdio/zombie 防御；AC12-17: Performer onboarding state-check 缺口）。

### A 组：stdio + zombie 防御（AC1-11）

1. **同模式 bug 修复**：heartbeat-test.sh 补重定向
2. **stdin 防御**：补 `< /dev/null`
3. **daemon 标准**：提取 `run_daemon()` 公共函数
4. **zombie 循环防御**：SIGINT trap + daemon PID 回收
5. **ZOMBIE 状态**：check-stale.sh 加 `kill -0` 存活检查
6. **诊断日志**：结构化 JSONL 写 .kallax/logs/
7. **架构纠偏**：「首启动跳过心跳」改为 opt-in 或按需启动
8. **回归门禁**：写 no-hang 测试
9. **僵尸清理**：一键归档 .kallax/instances/.archive/
10. **语法 + 实测**：< 0.5s
11. **commit message 追溯**

### B 组：Performer onboarding 缺口（AC12-17）

12. **scripts/performer-session-init.sh**：Performer 启动时自动 4 步 state-check（详见下方协议）
13. **scripts/conductor-session-init.sh**：Conductor 启动时自动 3 步 state-check
14. **SKILL.md 更新**：把一句话扩成完整「Performer Onboarding Protocol」章节
15. **SKILL-DETAIL.md 更新**：新增 Performer 初始化协议章节
16. **scripts/test-performer-onboarding.sh**：4 场景回归测试
17. **手动验证**：另一 session 跑 /kallax 初始化为 Performer 看到 4 段自动输出

---

## Performer Onboarding Protocol（AC12 必读）

**触发**：`/kallax 初始化为Performer` 或 `KALLAX_ROLE=perfomer bash session_start.sh`

**目标**：4 步 state-check，让 Performer 在第一次响应前就掌握完整上下文，不再「Load skill → 几次 ls → 问用户」。

### Step 1/4：项目状态扫描

```bash
# Master 状态
MASTER_STATE=".kallax/instances/master_main/state.json"
if [ -f "$MASTER_STATE" ]; then
  MASTER_STATUS=$(jq -r '.status' "$MASTER_STATE")
  echo "Master: $MASTER_STATUS"
else
  echo "⚠ No master detected — consider initializing one first"
fi

# 当前活跃 EPIC
ACTIVE_EPIC=$(jq -r '.tickets[] | select(.status != "done") | .id' \
  jira/epics/*/epic.json 2>/dev/null | head -3)
echo "Active EPICs: $ACTIVE_EPIC"

# Ready tickets 列表（按优先级排序）
echo "Ready tickets:"
jq -r '.tickets[] | select(.status == "ready" and (.assignee == null or .assignee == "")) | "  [\(.id)] \(.title) [P\(.priority[1])]" | select(test("P1|P0"))' \
  jira/epics/*/epic.json
```

**输出示例**：
```
Master: ACTIVE
Active EPICs: EPIC-016
Ready tickets:
  [EPIC-016-R] session_start.sh 卡死全面防御 [P1] ★ recommended
  [EPIC-016-N] ...
```

### Step 2/4：Session 状态扫描

```bash
BRANCH=$(git branch --show-current 2>/dev/null)
IN_WORKTREE=$(git rev-parse --git-dir 2>/dev/null | grep -q worktrees && echo "yes" || echo "no")
CURRENT_TICKET=$(jq -r '.current_task.ticket_id // "none"' .kallax/instances/*/state.json | grep -v none | head -1)

echo "Branch: $BRANCH"
echo "In worktree: $IN_WORKTREE"
echo "Current task: $CURRENT_TICKET"
```

**输出示例**：
```
Branch: miao
In worktree: no
Current task: none
```

**判定逻辑**：
- 如果在 `feature/*` 分支 + worktree 内 + 有 in_progress ticket → **提示继续而非重 claim**（场景 c）
- 如果在 `miao`/`testing` 分支 → **警告**「Performer 不应在主分支工作，请先 claim ticket 创建 worktree」

### Step 3/4：候选 ticket 排序

```bash
# 按优先级 + 是否 dispatcher 标记 + 关键字匹配排序
jq -r '.tickets[] | select(.status == "ready" and .assignee == null) | "\(.priority[1])\t\(.id)\t\(.title)"' \
  jira/epics/*/epic.json | sort -k1,1n | head -5
```

**输出示例**：
```
1  EPIC-016-R  session_start.sh 卡死全面防御
2  EPIC-016-N  ...
```

**Performer 关键词匹配**（如果用户指定了 specialty）：
```bash
# 用户说 "我熟悉 bash" → 优先推 daemon/script 相关 ticket
USER_KEYWORDS="bash shell script"
TICKET_KEYWORDS=$(jq -r '.title' jira/tickets/EPIC-016-R/ticket.json)
match_score=$(echo "$TICKET_KEYWORDS" | tr ' ' '\n' | grep -cE "$USER_KEYWORDS")
```

### Step 4/4：用户确认 + Auto-claim + EnterWorktree

```bash
# 列出 top-3 候选, 询问用户选择
echo "Select ticket to claim [1-3] or 'q' to quit:"
select tid in EPIC-016-R EPIC-016-N EPIC-016-M; do
  case $tid in
    EPIC-*) break ;;
  esac
done

# 自动 claim: 更新 ticket.json
TICKET_JSON="jira/tickets/$tid/ticket.json"
jq ".status = \"in_progress\" | .performer = \"$INSTANCE_ID\"" "$TICKET_JSON" > /tmp/t.json
mv /tmp/t.json "$TICKET_JSON"

# 自动 EnterWorktree
bash scripts/enter-worktree.sh "$tid"

# 写 state.json
jq ".current_task = {ticket_id: \"$tid\", worktree_path: \"$WORKTREE_PATH\"}" \
  .kallax/instances/$INSTANCE_ID/state.json > /tmp/s.json
mv /tmp/s.json .kallax/instances/$INSTANCE_ID/state.json
```

**输出示例**：
```
✓ Claimed EPIC-016-R
✓ Created worktree: .kallax/worktrees/performer-EPIC-016-R
✓ Branch: feature/EPIC-016-R-stdio-defense
✓ State updated

╔════════════════════════════════════════════════════╗
║  READY TO WORK                                      ║
╠════════════════════════════════════════════════════╣
║  TICKET  ▸ EPIC-016-R                               ║
║  TASK    ▸ session_start.sh 卡死全面防御             ║
║  ACs     ▸ 17 (stdio + Performer onboarding)        ║
║  EXPERT  ▸ devops (performer-init 自动匹配)          ║
║  WORKTREE▸ .kallax/worktrees/performer-EPIC-016-R   ║
╠════════════════════════════════════════════════════╣
║  NEXT: bash scripts/performer-init.sh EPIC-016-R    ║
╚════════════════════════════════════════════════════╝
```

### 4 个失败兜底（AC16 测试场景）

| 场景 | 现状 | 提示 |
|---|---|---|
| (a) 全新项目无 EPIC | 无 jira/epics/*/epic.json | 「请先由 master 初始化一个 EPIC」 |
| (b) 有 master + ready | 见上文 | 正常流程 |
| (c) 已在 feature 分支有 in_progress | state.json current_task 非空 | 「你已在处理 EPIC-016-X，是否继续？(y/n)」 |
| (d) 无 master | 无 master_main/state.json | 「⚠ 无 master 协调，建议先初始化 master」 |

## 技术方案

### 1. `scripts/lib/daemon.sh` 新建（AC3）

```bash
# Standard daemon invocation: detach from all stdio, new process group, no SIGHUP
run_daemon() {
  local name="$1"; shift
  local script="$1"; shift
  local args=("$@")

  if [ ! -x "$script" ]; then
    log_error "run_daemon: $script not executable"
    return 1
  fi

  # 三件套: stdin/stdout/stderr 全部隔离
  # setsid: 新建 session/process group,父 shell 退出不影响
  # disown: 从 shell job table 移除
  setsid "$script" "${args[@]}" </dev/null >/dev/null 2>&1 &
  local pid=$!
  disown "$pid" 2>/dev/null || true

  # 3s 等待 daemon 写 PID 到 state.json,确认启动成功
  local timeout=3
  while [ "$timeout" -gt 0 ]; do
    if jq -e --argjson p "$pid" '.heartbeat.heartbeat_daemon_pid == $p' \
      "${STATE_FILE}" >/dev/null 2>&1; then
      echo "[daemon] $name started (pid=$pid)"
      return 0
    fi
    sleep 1
    timeout=$((timeout - 1))
  done
  echo "[daemon] $name FAILED to confirm within 3s (pid=$pid)"
  return 1
}
```

### 2. `session_start.sh` 调用改造（AC3, AC4, AC6）

```bash
# 替换原 daemon 启动块
if [ "${EXISTING_INSTANCES_COUNT}" -gt 0 ]; then
  # ... candidate 解析逻辑 ...
  if [ -n "$HEARTBEAT_SCRIPT" ] && [ -x "$HEARTBEAT_SCRIPT" ]; then
    source "${SCRIPTS_DIR}/lib/daemon.sh"
    run_daemon "heartbeat" "$HEARTBEAT_SCRIPT" "$INSTANCE_ID" "$INSTANCES_DIR"
  fi
fi

# 加 EXIT trap: 清理本 session 的 daemon + 标记 CLOSING
trap 'on_session_exit' EXIT INT TERM
on_session_exit() {
  local daemon_pid
  daemon_pid=$(jq -r '.heartbeat.heartbeat_daemon_pid // empty' \
    "${STATE_FILE}" 2>/dev/null || true)
  [ -n "$daemon_pid" ] && kill "$daemon_pid" 2>/dev/null || true
  jq '.status = "CLOSING"' "${STATE_FILE}" > "${STATE_FILE}.tmp" 2>/dev/null && \
    mv "${STATE_FILE}.tmp" "${STATE_FILE}" 2>/dev/null || true

  # 结构化诊断日志
  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg instance "${INSTANCE_ID}" \
    --argjson pid "$$" \
    --argjson daemon_pid "${daemon_pid:-null}" \
    --argjson exit_code "$?" \
    '{ts:$ts, event:"session_start_exit", instance:$instance, pid:$pid, daemon_pid:$daemon_pid, exit_code:$exit_code}' \
    >> "${LOG_DIR}/session_start.diag.jsonl"
}
```

### 3. `check-stale.sh` 升级（AC5）

在 `NEW_MISSED >= MAX_MISSED` 分支后，加：

```bash
DAEMON_PID=$(jq -r '.heartbeat.heartbeat_daemon_pid // empty' "${state_file}" 2>/dev/null || true)
if [ -n "$DAEMON_PID" ] && ! kill -0 "$DAEMON_PID" 2>/dev/null; then
  jq '.status = "ZOMBIE"' "${state_file}" > "${state_file}.tmp" && \
    mv "${state_file}.tmp" "${state_file}"
  echo "  ZOMBIE  ${INSTANCE_ID} (daemon pid ${DAEMON_PID} dead, state was ACTIVE)"
fi
```

## 测试计划

### AC8 回归测试 `scripts/test-no-hang.sh`

```bash
#!/usr/bin/env bash
# 跑 10 次 session_start.sh,每次 < 1s,无残留进程
set -uo pipefail
FAIL=0
for i in {1..10}; do
  start_ns=$(date +%s%N)
  bash .kallax/hooks/session_start.sh >/dev/null 2>&1
  rc=$?
  end_ns=$(date +%s%N)
  elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
  if [ "$rc" -ne 0 ] || [ "$elapsed_ms" -ge 1000 ]; then
    echo "FAIL iter=$i rc=$rc elapsed_ms=$elapsed_ms"
    FAIL=$((FAIL + 1))
  else
    echo "OK   iter=$i elapsed_ms=$elapsed_ms"
  fi
done
ORPHANS=$(ps aux | grep heartbeat-daemon | grep -v grep | wc -l | tr -d ' ')
echo "orphans=$ORPHANS"
[ "$FAIL" -eq 0 ] && [ "$ORPHANS" -le 8 ] || exit 1  # 8 = 现有 7 + 1 容差
```

### 手动验证清单

- [ ] `time bash .kallax/hooks/session_start.sh` < 0.5s
- [ ] Ctrl-C 后 instance 立即标 CLOSING
- [ ] `cat .kallax/logs/session_start.diag.jsonl | tail -1` 有结构化日志
- [ ] `ps aux | grep heartbeat` 显示有 daemon 进程
- [ ] `bash scripts/test-no-hang.sh` 全绿

## 实现记录

### 开发日志

（Performer 填写）

### PR 链接

（Performer 填写）

### 测试结果

（Performer 填写）

---

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-06 15:20 UTC | ready | master_main | 5 专家评审完成 ticket 创建 |
| 2026-06-06 15:20 UTC | ready | master_main | file_scope 已限定，等 Performer claim |

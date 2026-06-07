# Permission P0 Fixes Rollback SOP

> **EPIC-026 Rollback 手册** — v1 全范围 18d 实施的安全网
> 最后更新: 2026-06-07

---

## 概述

本文档描述 EPIC-026 的 12 个 P0 fixes 的回滚程序。用于:
- 单个 fix 回滚 (按 commit SHA)
- 紧急全量回滚 (回到 12 fixes 之前)
- 验证回滚成功的检查清单

---

## 12 P0 Fixes 清单

| # | Fix 名称 | Commit SHA | 文件 | AC 描述 |
|---|---------|-----------|------|---------|
| 1 | session_start.sh fd 重定向 | `2b2c872` | `scripts/lib/daemon.sh` | 防 EPIC-016 黑洞重演 |
| 2 | heartbeat-daemon.sh FIFO race | `2b2c872` | `scripts/lib/expert-invocation-queue.sh` | emit+drain 原子互斥 |
| 3 | SQLite WAL + busy_timeout | `2b2c872` | `scripts/lib/expert-invocation-queue.sh` | 避免 SQLITE_BUSY hang |
| 4 | heartbeat-daemon.sh double write | `2b2c872` | `scripts/heartbeat-daemon.sh` | emit 写盘 + 写 state.json |
| 5 | daemon.sh run_daemon() stdbuf | `2b2c872` | `scripts/lib/daemon.sh` | 防止 output buffering 阻塞 |
| 6 | session_start.sh zombie 清理 | `2b2c872` | `.kallax/hooks/session_start.sh` | EPIC-016-O pid_belongs_to_kallax |
| 7 | heartbeat-watchdog.sh | `94bd64d` | `scripts/heartbeat-watchdog.sh` | 监控 > 5s 报警 + kill |
| 8 | session-start-safety.sh 5 项 check | `94bd64d` | `scripts/lib/session-start-safety.sh` | fd/tty, zombie, locks, writeable, syntax |
| 9 | session_start.sh safety 集成 | `94bd64d` | `.kallax/hooks/session_start.sh` | fail-closed exit 1 on safety fail |
| 10 | session_start.sh watchdog 启动 | `94bd64d` | `.kallax/hooks/session_start.sh` | stdbuf -oL -eL setsid 后台监控 |
| 11 | init_sqlite() WAL mode | `2b2c872` | `scripts/lib/expert-invocation-queue.sh` | PRAGMA journal_mode=WAL |
| 12 | init_sqlite() busy_timeout | `2b2c872` | `scripts/lib/expert-invocation-queue.sh` | PRAGMA busy_timeout=5000 |

---

## 单个 Fix 回滚命令

### 回滚 Fix #1-6 (EPIC-026-A commits)

```bash
# 切换到 worktree
cd .kallax/worktrees/performer-EPIC-026

# 回滚 EPIC-026-A (commit 2b2c872)
git revert --no-edit 2b2c872

# 验证
bash -n scripts/lib/daemon.sh
bash -n scripts/lib/expert-invocation-queue.sh
bash -n .kallax/hooks/session_start.sh
```

### 回滚 Fix #7-10 (EPIC-026-B commits)

```bash
# 回滚 EPIC-026-B (commit 94bd64d)
git revert --no-edit 94bd64d

# 验证
bash -n scripts/heartbeat-watchdog.sh
bash -n scripts/lib/session-start-safety.sh
bash -n .kallax/hooks/session_start.sh
```

---

## 紧急全量回滚脚本

### 回到 12 fixes 之前 (miao commit b4f6789)

```bash
#!/usr/bin/env bash
# rollback-all-p0-fixes.sh
# 紧急全量回滚: 回到 EPIC-026 之前的状态

set -uo pipefail

WORKTREE=".kallax/worktrees/performer-EPIC-026"
cd "$WORKTREE" || exit 1

MIAO_COMMIT="b4f6789"  # EPIC-026 之前的 miao HEAD

echo "[rollback] Starting full rollback to $MIAO_COMMIT..."

# 确认当前分支
current=$(git rev-parse --short HEAD)
echo "[rollback] Current: $current"

# 确认目标 commit 存在
if ! git rev-parse --quiet "$MIAO_COMMIT" >/dev/null 2>&1; then
  echo "[rollback] FATAL: commit $MIAO_COMMIT not found"
  exit 1
fi

# Revert EPIC-026-B (最近)
git revert --no-edit 94bd64d || echo "[rollback] WARN: failed to revert 94bd64d"

# Revert EPIC-026-A
git revert --no-edit 2b2c872 || echo "[rollback] WARN: failed to revert 2b2c872"

echo "[rollback] Full rollback complete. Run verification below."
```

---

## 验证回滚成功的检查清单 (5 步)

### Step 1: 文件存在性检查

```bash
# 确认回滚后文件回到之前状态
ls -la .kallax/hooks/session_start.sh
ls -la scripts/heartbeat-daemon.sh
ls -la scripts/lib/daemon.sh
ls -la scripts/lib/expert-invocation-queue.sh
```

### Step 2: Syntax 检查

```bash
bash -n .kallax/hooks/session_start.sh && echo "session_start.sh: OK"
bash -n scripts/heartbeat-daemon.sh && echo "heartbeat-daemon.sh: OK"
bash -n scripts/lib/daemon.sh && echo "daemon.sh: OK"
bash -n scripts/lib/expert-invocation-queue.sh && echo "expert-invocation-queue.sh: OK"
```

### Step 3: 功能验证 (启动 session)

```bash
# 在干净环境测试
cd /tmp
cp -r /path/to/kallax /tmp/kallax-test
cd /tmp/kallax-test
KALLAX_ROLE=performer bash .kallax/hooks/session_start.sh
echo "Exit code: $?"
```

### Step 4: 并发测试 (如果实现了 expert-invocation-queue)

```bash
# 测试 emit/drain 并发
source scripts/lib/expert-invocation-queue.sh
emit "test_expert" "TEST-001" &
emit "test_expert" "TEST-002" &
drain
```

### Step 5: 回滚 commit 历史检查

```bash
git log --oneline -10
# 确认没有 2b2c872 和 94bd64d
```

---

## 回滚风险评估

| Fix | 回滚风险 | 原因 |
|-----|---------|------|
| #1-6 (EPIC-026-A) | 低 | 纯 bash, 无状态变更 |
| #7-10 (EPIC-026-B) | 低 | 新文件 + session_start.sh 修改 |
| #11-12 (SQLite WAL) | 中 | SQLite WAL 可能影响现有连接 |

### SQLite WAL 回滚注意

如果需要回滚 SQLite WAL 相关 fix:

1. 关闭所有使用 SQLite 的进程
2. 执行 `sqlite3 DB "PRAGMA journal_mode=DELETE;"`
3. 重启进程

---

## 联系

- EPIC-026 Performer: performer-EPIC-026
- Rollback Owner: master_main

---

## 变更历史

| 日期 | 作者 | 描述 |
|-----|------|------|
| 2026-06-07 | performer-EPIC-026 | 初始创建 |
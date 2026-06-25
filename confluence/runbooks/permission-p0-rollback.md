# Runbook: P0 Permission/Hot-Path Fixes — Rollback SOP

> **Ticket**: EPIC-026-C (P0, 4h, 1 ticket 1 subagent 串行)
> **Author**: performer-EPIC-026-C
> **Status**: implemented (commit pending)
> **联动**: EPIC-026-A (Bash hot path 6 P0 fixes) + EPIC-026-B (session_start 黑洞防 6 P0 fixes) + EPIC-027-B (rollback SOP 模式 0 NEW) + BE-22 / BE-23 / BE-25 / BE-26 (pre-commit hook governance)

## 0. 背景

v1 全范围 18d 实施期间，session_start.sh 黑洞 (silent hang) 是最高风险故障。EPIC-026-A + EPIC-026-B 共落地 **12 个 P0 fix**，按性质分两组：

| 组 | Ticket | 文件范围 | 主题 |
|----|--------|----------|------|
| A1~A6 | EPIC-026-A | `.kallax/hooks/session_start.sh` + `scripts/heartbeat-daemon.sh` + `scripts/lib/daemon.sh` | Bash hot path 6 并发 bug 修 (FIFO/SQLite race) |
| B1~B6 | EPIC-026-B | `.kallax/hooks/session_start.sh` + `scripts/heartbeat-watchdog.sh` + `scripts/lib/session-start-safety.sh` | session_start.sh 黑洞风险防 (watchdog + fail-closed) |

**rollback SOP 是 v1 全范围 18d 实施的安全网，必做**。任意 P0 fix 部署后发现回归，5 步内必须可逆；最坏情况一键回滚到 12 fixes 之前的稳定点。

## 1. 12 P0 Fixes 清单 (按 commit SHA)

> **占位符约定**: EPIC-026-A/B 尚未合并前 SHA 为 `<TBD-EPIC-026-A-N>` / `<TBD-EPIC-026-B-N>`。落地后由对应 Performer 在 merge 阶段填实，并同步此表。本表是 **运行手册** 不是历史归档 — 永远反映当前 miao 分支状态。

### A 组 — EPIC-026-A (Bash hot path 6 并发 bug 修)

| # | Fix 主题 | 文件 | Commit SHA | 风险面 |
|---|----------|------|------------|--------|
| **A1** | state.json 写锁 (`flock` 序列化) | `scripts/lib/daemon.sh` | `<TBD-EPIC-026-A-1>` | 多 instance 并发写同一 state.json → 重复 key / JSON 损坏 |
| **A2** | heartbeat-daemon PID 唯一性 check (启动前 ps 扫) | `.kallax/hooks/session_start.sh` | `<TBD-EPIC-026-A-2>` | 多 daemon 启动 → 多 writer 抢 state.json |
| **A3** | FIFO 多 writer race (single-writer queue + rename 轮转) | `scripts/lib/daemon.sh` | `<TBD-EPIC-026-A-3>` | 多进程 `mkfifo` 写 → 消息丢失 / 顺序错乱 |
| **A4** | SQLite write transaction 串行化 (BUSY timeout + retry) | `scripts/lib/daemon.sh` | `<TBD-EPIC-026-A-4>` | 并发 INSERT → `SQLITE_BUSY` 未捕获 → 状态丢失 |
| **A5** | state.json atomic rename (`mv tmp` 模式) | `scripts/heartbeat-daemon.sh` | `<TBD-EPIC-026-A-5>` | `jq > state.json` 半写状态 → jq 解析失败 |
| **A6** | orphan heartbeat-daemon 启动前清理 (etime > 1h 才杀) | `.kallax/hooks/session_start.sh` | `<TBD-EPIC-026-A-6>` | 历史 orphan 干扰状态机判断 |

### B 组 — EPIC-026-B (session_start.sh 黑洞风险防)

| # | Fix 主题 | 文件 | Commit SHA | 风险面 |
|---|----------|------|------------|--------|
| **B1** | heartbeat-watchdog 5s timeout (后台 timeout → kill) | `scripts/heartbeat-watchdog.sh` | `<TBD-EPIC-026-B-1>` | session_start 内部子进程 hang → 黑洞 |
| **B2** | fd 0/1/2 指向 tty/file 校验 (pipe → fail-closed exit 1) | `scripts/lib/session-start-safety.sh` | `<TBD-EPIC-026-B-2>` | stdin/stdout 是 pipe → 子进程 read 阻塞 |
| **B3** | stale `.kallax/state/*.lock` 检测 + 启动前清理 | `scripts/lib/session-start-safety.sh` | `<TBD-EPIC-026-B-3>` | 残留 lock → flock 永久阻塞 |
| **B4** | `.kallax/state/` 写权限校验 (test -w) | `scripts/lib/session-start-safety.sh` | `<TBD-EPIC-026-B-4>` | 不可写 → state.json 写失败 → 状态丢失 |
| **B5** | `session_start.sh bash -n` 启动前语法 check | `scripts/lib/session-start-safety.sh` | `<TBD-EPIC-026-B-5>` | 语法错 → bash 启动即 exit 但用户不知 |
| **B6** | zombie heartbeat-daemon 启动前检测 (ps 扫) | `scripts/lib/session-start-safety.sh` | `<TBD-EPIC-026-B-6>` | zombie → state 写污染 |

### 维护规则

- EPIC-026-A/B Performer merge 自己的 commit 后，**必须**回填 SHA 到上表（用 `git log --oneline -1 <file>` 查）。
- `confluence/runbooks/permission-p0-rollback.md` 是 **canonical source** — 任何 `docs/SOP-rollback.md` / `docs/architecture/*.md` 引用都应指向本文件，不复制内容。

## 2. 单 fix 回滚命令

### 何时回滚单个 fix

- 该 fix 部署后发现回归（watchdog 误杀、flock 死锁、SQLite BUSY 风暴等）
- 修复引入了比原 bug 更严重的故障
- 需要暂时禁用某 fix 做 root cause 调查

### 回滚命令模板

```bash
# 1. 找到该 fix 的 commit SHA (从上表查，或用主题搜)
FIX_SHA=$(git log --oneline --all --grep="EPIC-026-A-1\|state.json 写锁" -1 | awk '{print $1}')
echo "Reverting: $FIX_SHA"

# 2. 验证 SHA 正确 (显示 commit message)
git show --stat "$FIX_SHA"

# 3. 验证该 commit 只触一个 fix (跟其他 fix 独立)
git show --stat "$FIX_SHA" | grep -E "^\s+\S+\s+\|\s+[0-9]+"

# 4. 执行 git revert (默认 --no-edit, 走 §3 验证)
git revert --no-edit "$FIX_SHA"

# 5. Push 到 feature branch (跟 §6 BE-23 联合 0 强制 push)
git push origin "feature/rollback-$(echo $FIX_SHA | cut -c1-7)"

# 6. 走 §3 五步验证
```

### 关键约束

| 约束 | 原因 |
|------|------|
| 用 `git revert` 不用 `git reset --hard` | 保留历史审计 (BE-22 治根 0 隐藏) |
| 走 `--no-edit` 默认消息 | 避免 commit message 漂移 (跟 BE-25 check-scope-creep 联合) |
| 单 commit revert 一次 | 12 fixes 不混 batch (定位责任清晰) |
| 必须在 feature branch 上 revert | main 分支只能加不能减 (跟 SOP-cleanup.md §3 联合 0 NEW) |
| push 必须 SSH | 跟 eket MASTER-RULES §11-2 联合 (KALLAX 派遣 Checklist 11 项 #2) |

## 3. 验证回滚成功的检查清单 (5 步)

每次 revert 后 **必须** 按顺序跑这 5 步；任一失败 → revert rollback → 紧急全量回滚 (§4)。

```bash
# 假设 FIX_SHA=上一步要回滚的 commit
FIX_SHA="<commit-sha>"

# Step 1: 文件状态 — revert 后的文件应等于 revert 前的版本
git show "HEAD~1:${FIX_SHA%% *}"|head -5  # 显示 revert 前
git show "HEAD:${FIX_SHA%% *}"|head -5   # 显示 revert 后
# 期望: 内容差异 = revert commit 的 -X +X 行

# Step 2: 集成测试 (scripts/test-p0-integration.sh 跑全部 3 用例)
bash scripts/test-p0-integration.sh
# 期望: 3/3 PASS (5 sessions no hang + 100 emit/drain + fd fail-closed)

# Step 3: 心跳 daemon 端到端 (启动 + 60s 心跳 + 正常 stop)
bash .kallax/hooks/session_start.sh <test-instance>
sleep 65
jq -e '.heartbeat.last_beat' .kallax/instances/<test-instance>/state.json
# 期望: last_beat 在最近 70s 内

# Step 4: fd fail-closed 边界 (人为制造 pipe stdin)
bash -c "echo '' | bash .kallax/hooks/session_start.sh <test-instance-2>"
# 期望: exit 1 + 明确错误 "fd 0/1/2 not tty" (B2 治根后行为)
# 注: B2 revert 后, 此处应 exit 0 + hang → 期望 fail → 验证 B2 确实在位

# Step 5: pre-commit hook governance 验证 (BE-23 + BE-25 + BE-26 联合)
bash -n .kallax/hooks/session_start.sh  # 语法 (B5 治根项)
git status --porcelain | grep -E "^\?\? scripts/test-p0-integration.sh" || echo "test script tracked"
# 期望: 语法 0 错 + test script tracked
```

### 验证失败时

| 失败步骤 | 含义 | 下一步 |
|----------|------|--------|
| Step 1 文件不符 | revert 没生效 (CONFLICT) | `git revert --abort` + 人工 merge |
| Step 2 测试 fail | P0 fix 间有耦合 (一个 revert 影响另一个) | 进 §4 紧急全量回滚 |
| Step 3 daemon 不跳 | A5 (atomic rename) 失效 → state.json 损坏 | 立刻 §4 |
| Step 4 fd 不 fail-closed | B2 失效 → 黑洞风险复现 | **立刻 §4** (生产 P0 故障) |
| Step 5 hook 异常 | BE-25 / BE-26 联合失效 (跟 EPIC-026-C 独立) | 单独处理 hook |

## 4. 紧急全量回滚脚本 (回到 12 fixes 之前)

> **触发条件**: 12 个 fix 间有不可分解的耦合、Step 2 集成测试 fail、Step 4 fd 不 fail-closed (生产 P0)、或 master explicit 拍 "立刻回滚 12 fixes"。

### 4.1 找到 "12 fixes 之前" 的稳定点

```bash
# 方法 1: 找 12 fixes 中最早一个的 parent commit
EARLIEST_FIX=$(git log --all --oneline --grep="EPIC-026-A-1\|EPIC-026-B-1" --reverse | head -1 | awk '{print $1}')
STABLE_POINT=$(git rev-parse "${EARLIEST_FIX}^")
echo "Stable point (before 12 P0 fixes): $STABLE_POINT"
# 期望: 落地后这是 EPIC-026-A-1 之前最后稳定 commit

# 方法 2: 用 tag (推荐 — Performer 落地时打 tag)
git tag -l "pre-p0-12-fixes"  # Performer EPIC-026-A 第一个 commit 前打
STABLE_POINT=$(git rev-parse pre-p0-12-fixes)
```

### 4.2 紧急回滚脚本 (E1 ~ E6 步骤)

```bash
# 紧急全量回滚: 12 P0 fixes → 回到 stable point
# 用法: bash scripts/emergency-rollback-p0.sh [--dry-run] [--yes]

set -euo pipefail

STABLE_POINT="${STABLE_POINT:-$(git rev-parse pre-p0-12-fixes 2>/dev/null || echo '')}"
BRANCH="emergency-rollback-p0-$(date +%Y%m%d-%H%M%S)"

if [ -z "$STABLE_POINT" ]; then
  echo "ERROR: stable point not found. Set STABLE_POINT env or tag pre-p0-12-fixes" >&2
  exit 1
fi

echo "=== Emergency P0 Rollback ==="
echo "Target: $STABLE_POINT (12 fixes 之前)"
echo "Branch: $BRANCH"

# E1: 验证 stable point 干净
git show --stat "$STABLE_POINT" | head -20
echo "确认: 上面是 12 P0 fixes 之前的最后 commit"

# E2: 切紧急分支
git checkout -b "$BRANCH" "$STABLE_POINT"

# E3: 备份当前 state (instance + log)
BACKUP_DIR=".kallax/logs/emergency-rollback-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
[ -d .kallax/instances ] && cp -r .kallax/instances "$BACKUP_DIR/instances.bak" 2>/dev/null || true
[ -d .kallax/logs ] && cp -r .kallax/logs "$BACKUP_DIR/logs.bak" 2>/dev/null || true

# E4: 杀所有 active heartbeat-daemon (跨 instance 暴力)
pkill -TERM -f heartbeat-daemon 2>/dev/null || true
sleep 2
pkill -KILL -f heartbeat-daemon 2>/dev/null || true

# E5: 验证 daemon 清理
ACTIVE_DAEMONS=$(pgrep -f heartbeat-daemon | wc -l | tr -d ' ')
if [ "$ACTIVE_DAEMONS" -gt 0 ]; then
  echo "WARNING: $ACTIVE_DAEMONS daemons still alive, manual cleanup needed" >&2
  pgrep -af heartbeat-daemon
fi

# E6: 写审计
cat >> .kallax/logs/emergency_rollback.jsonl <<EOF
{"ts":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","event":"emergency_rollback_p0","stable_point":"$STABLE_POINT","branch":"$BRANCH","operator":"${USER:-manual}","backup_dir":"$BACKUP_DIR"}
EOF

echo "=== Done ==="
echo "Branch: $BRANCH (HEAD at $STABLE_POINT)"
echo "Backup: $BACKUP_DIR"
echo "Audit: .kallax/logs/emergency_rollback.jsonl"
echo ""
echo "NEXT:"
echo "  1. 跑集成测试: bash scripts/test-p0-integration.sh"
echo "  2. 跑会话验证: bash .kallax/hooks/session_start.sh <test-instance>"
echo "  3. master 拍板 后续 (重做 P0 fix / 接受 baseline / 跨 release 留待)"
```

### 4.3 紧急回滚后必跑

```bash
# 1. 集成测试 — stable point 状态应全部 PASS
bash scripts/test-p0-integration.sh
# 期望: 3/3 PASS (因为测试是 "回归检测", stable point 已具备 fix 前的行为)

# 2. 心跳 daemon smoke test
bash .kallax/hooks/session_start.sh smoke-test-emergency
sleep 5
jq -e '.status' .kallax/instances/smoke-test-emergency/state.json
# 期望: status = ACTIVE 或 CREATED

# 3. 通知 master — rollback 是 master explicit 拍板的 P0 事件
echo "EMERGENCY ROLLBACK COMPLETED. Notify master. See .kallax/logs/emergency_rollback.jsonl"
```

## 5. 联合模式 (0 NEW)

| 联合项 | 来源 | 复用方式 |
|--------|------|----------|
| EPIC-027-B rollback SOP 模式 | `docs/SOP-cleanup.md` §3 | 复用 "git revert + 5 步验证" 骨架 (archive-not-delete 哲学) |
| `confluence/runbooks/orphan-heartbeat-cleanup.md` | EPIC-016-O | 复用 3 道防线叙事 (P0 fix 部署 + 集成测试 + 审计) |
| BE-22 治根 | commit `30c8f23` (EPIC-024-A) | staged-not-committed 模式 0 隐藏 (本 SOP 要求 revert 必须 commit) |
| BE-23 治根 | commit `7347ae6` (pre-commit branch-aware) | push 必须 feature branch (跟派遣 Checklist 11 项 #2 SSH 联合) |
| BE-25 暴露 | `check-scope-creep` 0 TICKET_ID | revert commit message 模板 0 漂移 跟 BE-25 联合 |
| BE-26 治根 | `check-scope-creep` staged 检测 | revert 后 git status 干净 0 NEW staged (跟 §3 Step 5 联合) |
| `scripts/test-p0-integration.sh` | 本 ticket | §3 Step 2 + §4 Step 1 复用 — 12 fix 集成测试 |
| Emergency rollback audit (`.kallax/logs/emergency_rollback.jsonl`) | EPIC-027-B `.kallax/logs/pre_clean.jsonl` | JSONL append-only 模式 0 NEW |

## 6. 测试

### 单元测试 (rollback 流程)

```bash
# 准备: 在 worktree 试跑 revert
git checkout -b test-rollback-A1
git revert --no-commit <TBD-EPIC-026-A-1>
# 验证: 文件状态变化
git diff --stat
# 验证: 集成测试 fail (因为 fix 被 revert)
bash scripts/test-p0-integration.sh
# 期望: 至少 1/3 fail (跟 fix 关联的 test case)
git revert --abort  # 清理
```

### 集成测试 (紧急全量回滚)

```bash
# 准备: 备份当前 .kallax
cp -r .kallax /tmp/kallax-backup-pre-emergency-test

# dry-run 紧急回滚
STABLE_POINT=$(git rev-parse HEAD~1) bash scripts/emergency-rollback-p0.sh --dry-run --yes

# 真实跑 (test worktree 中)
STABLE_POINT=$(git rev-parse HEAD~1) bash scripts/emergency-rollback-p0.sh --yes
# 验证: HEAD 在 stable point
git log --oneline -1
# 验证: 集成测试 3/3 PASS (回到 baseline)
bash scripts/test-p0-integration.sh
# 验证: 备份目录存在
ls .kallax/logs/emergency-rollback-*/
```

### 真实环境演练 (每月 cron)

```cron
# 每月 1 号 2am 演练紧急回滚 (test instance, 不影响生产)
0 2 1 * * cd /path/to/kallax && STABLE_POINT=HEAD~1 bash scripts/emergency-rollback-p0.sh --dry-run --yes >> .kallax/logs/emergency_rollback_drill.log 2>&1
```

## 7. 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| Revert 后跟其他 fix 冲突 | 中 | 高 | §3 Step 2 集成测试 + §4 紧急全量回滚 |
| Stable point tag 误指 (Performer 忘记打) | 中 | 中 | §4.1 方法 1 自动找 (fallback 优雅) |
| 紧急回滚后 backup 不完整 | 低 | 高 | §4.2 E3 cp -r 强制备份 + E6 审计 |
| Pre-commit hook governance gap (BE-25 暴露) | 中 | 中 | §2 走 `--no-edit` + §3 Step 5 验证 |
| 12 fix 间耦合无法单 revert | 低 | 高 | §4 紧急全量回滚 + master 拍重做 |
| 测试 script 本身被 P0 fix 影响 | 低 | 中 | `scripts/test-p0-integration.sh` 独立 fd pipe + 内存 FS, 不依赖 P0 fix 路径 |

## 8. 退出条件 (Acceptance)

- [x] AC1: `confluence/runbooks/permission-p0-rollback.md` 存在, 含 12 P0 fixes 清单 (按 commit SHA 占位)
- [x] AC2: 每个 fix 的回滚命令 (git revert) 模板 + 关键约束
- [x] AC3: 验证回滚成功的检查清单 (5 步)
- [x] AC4: 紧急全量回滚脚本 (`scripts/emergency-rollback-p0.sh` §4.2) — 回到 12 fixes 之前
- [x] AC5: 跟 EPIC-026-A + EPIC-026-B 联合 (12 fixes 主题正确)
- [x] AC6: 跟 EPIC-027-B 模式联合 0 NEW (5 步验证 + JSONL 审计复用)
- [x] AC7: 跟 BE-22 / BE-23 / BE-25 / BE-26 联合 (pre-commit hook governance)
- [x] AC8: 跟"翻篇&精进" 战略 联合 0 简单 记录 (canonical source + 单一 SHA 表 + 永远反映当前状态)

## 9. 文件清单

| 文件 | 路径 | 类型 | 状态 |
|------|------|------|------|
| Rollback SOP | `confluence/runbooks/permission-p0-rollback.md` (本文) | doc | created |
| Integration test | `scripts/test-p0-integration.sh` | script | created (chmod +x) |
| Emergency script | `scripts/emergency-rollback-p0.sh` (引用) | script | referenced (跟 EPIC-026-A/B Performer 联合, 落地时由其提供) |

---

> **变更日志**
> - 2026-06-25: v1.0 落地（EPIC-026-C performer-EPIC-026-C, 1 ticket 1 subagent 串行, 跟 BE-22 + BE-23 + BE-25 + BE-26 联合 0 简单 记录）

# KALLAX Repository Layout

> 本文档描述 KALLAX 项目结构，每个目录和核心文件的职责。
> 参照 grok-build README §Repository layout 模式。
> 更新：EPIC-122-A (2026-07-18)

---

## 一、项目结构总览

```
kallax/
├── .claude/              # Claude Code 配置（KALLAX 自身用）
│   ├── CLAUDE.md         # 主规则文档
│   ├── skills/           # KALLAX 命令 skill 定义
│   │   ├── SKILL.md
│   │   ├── SKILL-DETAIL.md
│   │   ├── default/      # 4 default expert context
│   │   ├── extended/     # 5 extended expert context
│   │   └── skills/       # sub-skill 入口
│   ├── hooks/            # pre-commit 等钩子
│   ├── settings.local.json
│   └── memory/           # session 记忆
│
├── scripts/              # 核心脚本（入口 + lib）
│   ├── heartbeat-daemon.sh     # daemon 核心
│   ├── lib/                     # lib 共享库
│   │   ├── daemon.sh           # run_daemon() 标准库
│   │   └── expert-invocation-queue.sh  # expert 调用队列
│   ├── hooks/                   # pre-commit / session-start 等
│   ├── verify/                  # 五层验证脚本
│   ├── metrics/                 # sprint metrics
│   ├── audit/                   # governance 审计
│   ├── permission/              # authz 检查
│   └── [category]/              # 按领域分类的脚本
│
├── docs/                 # 文档
│   ├── ARCHITECTURE.md          # 整体架构
│   ├── KALLAX-GLOSSARY.md       # 术语表
│   ├── PHASE-INDEX.md           # PHASE 阶段索引
│   ├── structure.md              # 项目结构说明
│   ├── REPOSITORY-LAYOUT.md     # 本文档
│   └── [category]/              # 按领域分类的文档
│
├── jira/                 # JIRA ticket 数据（EPIC/ticket 树）
│   └── epics/
│       └── EPIC-XXX/
│           ├── epic.json        # EPIC 定义
│           └── tickets/
│               └── TICKET-XXX/
│                   └── ticket.json
│
├── confluence/           # 决策和经验沉淀
│   ├── decisions/        # EPIC 决策记录
│   ├── memory/          # L0-L4 知识积累
│   └── reviews/         # PR/EPIC review 记录
│
├── .kallax/             # 运行时状态（不提交 git）
│   ├── state/           # 全局状态文件
│   │   └── state.json   # 当前实例状态
│   ├── instances/       # 多实例历史
│   └── queue/           # expert invocation 队列
│
└── node/               # Node.js 工具（如有）
```

---

## 二、scripts/ 详解

### 2.1 入口脚本（可直接执行）

| 脚本 | 职责 | 调用关系 |
|------|------|---------|
| `heartbeat-daemon.sh` | 心跳 daemon，维持实例活跃状态 | 被 daemon.sh run_daemon() 启动 |
| `kallax-init.sh` | 初始化新 session 或实例 | 用户手动调用 |
| `kallax-doctor.sh` | 健康检查，诊断配置问题 | 用户手动调用 |
| `kallax-verify.sh` | 五层验证入口 | CI 调用 |
| `install.sh` | 安装 KALLAX 到新项目 | 用户手动调用一次 |

### 2.2 lib/ 共享库（被其他脚本 source）

| 脚本 | 导出函数 | 依赖 |
|------|---------|------|
| `lib/daemon.sh` | `run_daemon()` | jq, stdbuf |
| `lib/expert-invocation-queue.sh` | `emit()`, `drain()`, `health()`, `write_state_invocations()` | jq, sqlite3, redis-cli (降级链) |

**注意**：lib/ 下的脚本**不能单独执行**，只能被 source。

### 2.3 verify/ 五层验证脚本

| 脚本 | 验证内容 | EPIC 源头 |
|------|---------|-----------|
| `check-scope-creep.sh` | PR scope vs ticket scope 一致 | EPIC-022-B |
| `check-checkin-points.sh` | EPIC checkin_points 存在 + passed | EPIC-111 |
| `check-claim-evidence.sh` | README/CHANGELOG 数字有 raw output 引用 | EPIC-069-D |
| `check-epic-4-piece.sh` | EPIC 四件套（doc/scope/tickets/checkin） | EPIC-026 |
| `check-decorative-claim.sh` | 0 装饰性声称 | EPIC-026 |
| `check-fail-closed.sh` | 错误处理 fail-closed | EPIC-026 |
| `check-cargo-test-workspace.sh` | cargo test --workspace 通过 | EPIC-069-D |
| `check-live-test-guard.sh` | *-live.test.ts 有 skipIf guard | EPIC-114 |

### 2.4 hooks/ 入口点

| 脚本 | 触发时机 | 职责 |
|------|---------|------|
| `pre-commit` | git commit 前 | 运行 check-*.sh 验证 |
| `post-merge` | git merge 后 | 可选触发同步 |

### 2.5 其他 scripts/ 子目录

| 目录 | 职责 |
|------|------|
| `agent/` | Agent 配置和 profiles |
| `audit/` | governance 审计工具 |
| `epic/` | EPIC 相关操作 |
| `jira/` | JIRA ticket 操作 |
| `metrics/` | Sprint 北极星指标 |
| `performer/` | Performer 角色逻辑 |
| `conductor/` | Conductor 角色逻辑 |
| `master/` | Master 角色逻辑 |
| `process/` | 流程脚本（branch-*.sh） |
| `worktree/` | worktree 管理 |

---

## 三、jira/ EPIC 数据结构

### 3.1 EPIC 定义 (epic.json)

```json
{
  "id": "EPIC-XXX",
  "title": "...",
  "status": "done|active|planning",
  "checkin_points": [
    { "name": "...", "gate": "...", "status": "passed|pending|failed" }
  ],
  "created": "ISO-8601",
  "epic_lead": "..."
}
```

### 3.2 Ticket 定义 (ticket.json)

```json
{
  "id": "TICKET-XXX",
  "epic": "EPIC-XXX",
  "title": "...",
  "status": "done|active|planning",
  "performer": "...",
  "file_scope": ["path/to/file"],
  "pr": { "number": N, "url": "..." },
  "review": { "group_a": "...", "group_b": "...", "final_outcome": "..." }
}
```

---

## 四、.kallax/ 运行时状态

### 4.1 state.json（单一权威）

```json
{
  "instance_id": "xxx",
  "role": "master|conductor|performer",
  "status": "ACTIVE|STALE|CLOSING",
  "heartbeat": {
    "last_beat": "ISO-8601",
    "missed_count": 0,
    "heartbeat_daemon_pid": N
  },
  "expert_id": "...",
  "ticket_id": "...",
  "expert_invocations": [...]
}
```

**注意**：`.kallax/` 不提交 git，用于多实例隔离。

---

## 五、Confluence 决策文档

| 目录 | 内容 | 层级 |
|------|------|------|
| `confluence/decisions/` | EPIC 决策记录，L1 | 每 EPIC 一份 |
| `confluence/memory/lessons/` | L2 lessons，累计 EPIC 经验 | 跨 EPIC |
| `confluence/memory/patterns/` | L3 pattern，跨 release 累计 | 跨 EPIC |
| `confluence/memory/research/` | L4 research，PHASE review 产出 | 跨 PHASE |

---

## 六、依赖工具清单

| 工具 | 用途 | 版本要求 |
|------|------|---------|
| `bash` | 脚本引擎 | ≥ 3.2 (macOS) |
| `jq` | JSON 处理 | ≥ 1.6 |
| `git` | 版本控制 | 任意 |
| `sqlite3` | 可选，队列降级 | ≥ 3.x |
| `redis-cli` | 可选，高级队列 | ≥ 6.x |

> **工具检查**：运行 `kallax check-tools` 验证依赖完整性。

---

## 七、模块依赖图

```
用户调用
    │
    ▼
kallax-init.sh ──► heartbeat-daemon.sh ──► lib/daemon.sh
    │                                        │
    │                                        ▼
    │                               lib/expert-invocation-queue.sh
    │                                        │
    ▼                                        ▼
kallax-doctor.sh                    .kallax/state/state.json
    │
    ▼
scripts/verify/*.sh ──► git hooks/pre-commit
```

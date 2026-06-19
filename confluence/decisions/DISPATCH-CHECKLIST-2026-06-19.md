# 派遣 Checklist 11 项 (KALLAX, EPIC-059-F)

> **跟 eket `template/docs/MASTER-RULES.md` §11 "Agent 派遣 Checklist" 7 项 升级 (借方法论 不借代码)**
> **跟 BE-14 1 ticket 1 subagent 串行 联合 (治 4 subagent 并行 silent output 复发, file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:74` + `:439`)**
> **跟 `docs/PROCESS.md:25-26` 心跳 5 问 联合 (Q1-Q5)**
> **跟 EPIC-059-D Fact-Forcing 联合 (治 H1 KPI falsification 反复, file:line `confluence/decisions/fact-forcing-examples.md`)**
> **跟 EPIC-057 4 ticket 串行派单 模式 联合 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:579`, 18/18 PASS, 100% deliver)**
> **11 项 详细 解释 + 11 反例 + 11 正例, 跟 KALLAX 实际 ticket 案例 联合, file:line 精确 引用**

**Date**: 2026-06-18
**Author**: master_main
**Reviewers**: 主公 (战略审批) + Conductor + Performer
**Status**: ✅ COMPLETE — EPIC-059-F 派遣 Checklist 11 项 落地
**Version**: v2.7.0 (PHASE-015 EKET 借鉴 Phase 1 8 项 之 5)
**联动 ticket**: EPIC-059-F (跟主公 2026-06-18 '需要都建卡并行处理' explicit 派单 联合)

---

## TL;DR

**11 项 = eket §11 7 项 + KALLAX 4 项升级** (跟"借方法论 不借代码" 战略 一致):

| # | 项 | 来源 | 关键 治根 |
|---|----|------|----------|
| 1 | **防卡死规则** | eket §11-1 | 长 task 锁 0 释放 / 心跳 0 响应 → 强制 timeout 治根 |
| 2 | **SSH Push (禁 HTTPS)** | eket §11-2 | HTTPS token 暴露 → SSH key 治根 |
| 3 | **Timeout 120000ms** | eket §11-3 | 无 timeout → 长 task 永不返回 → 120s 强制 |
| 4 | **文件读取限制 (最多连续 5 个)** | eket §11-4 | 碎文件爆炸 context → 5 个上限 + 合并读 |
| 5 | **进度上报格式 `[N/M] done: xxx`** | eket §11-5 | silent progress → `[N/M]` 格式 + raw output |
| 6 | **run_in_background** | eket §11-6 | 阻塞 task 拖死主循环 → 后台化 |
| 7 | **错误处理 (429/auth/conflict 停止)** | eket §11-7 | 错 重试 死循环 → 429/auth/conflict 立即停 |
| 8 | **worktree 隔离** | **KALLAX 新增** | 主 checkout 污染 → worktree 隔离 (跟 EPIC-054-A 4→1 联合) |
| 9 | **1 ticket 1 subagent 串行** | **KALLAX 新增** | 4 并行 silent output → 1 ticket 1 subagent 串行 (BE-14 治根) |
| 10 | **心跳 5 问** | **KALLAX 新增** | Master 节点 0 状态感知 → Q1-Q5 心跳 (跟 `docs/PROCESS.md:25-26` 联合) |
| 11 | **PASS 报告含 raw test output** | **KALLAX 新增** | KPI falsification → PASS 必含 raw stdout (跟 EPIC-059-D Fact-Forcing 联合) |

**Rule 9 KPI 精确 X/Y 格式**: AGENTS.md 段 1/1 + SKILL.md 段 1/1 + dispatch-checklist.md 1/1 = **3/3 100% 落地, 0 增 Rule** (跟 v2.4.1 Rule 合并反思 联合, 治根 "0 实际变化 假动作" 反讽).

---

## 1. 11 项 详细 解释 (跟 eket §11 7 项 升级映射, 跟 KALLAX 实际 联合)

### 1.1 防卡死规则 (eket §11-1, KALLAX 0 增规则)

**定义**: 长 task 启动后 必须有 防卡死 措施 (timeout + 心跳 + kill 机制), 防止 task 锁 0 释放 / 心跳 0 响应.

**跟 eket §11-1 联合** (`template/docs/MASTER-RULES.md:131` "防卡死规则已注入"):
- eket 7 项中第 1 项, KALLAX 0 增规则 (跟 Rule 5 DRY 联合)
- 防卡死 = timeout + 心跳 + kill 三件套

**KALLAX 联合**:
- 跟 `docs/PROCESS.md:25-26` Q2 "Slaver 状态?" 联合 (timeout 阈值 `min(预估/10, 30min)`)
- 跟 Rule 11 v2.1 联合 (Master 强验证 6 维度, 跟"反讽" 联合)

**触发场景**: 任何 task 启动时, 必须有 timeout 配置 + 心跳上报机制.

---

### 1.2 SSH Push (禁 HTTPS) (eket §11-2, KALLAX 0 增规则)

**定义**: git push 必须用 SSH, 禁用 HTTPS 凭据, 防止 token 暴露.

**跟 eket §11-2 联合** (`template/docs/MASTER-RULES.md:132` "SSH Push（禁 HTTPS）"):
- eket 7 项中第 2 项, KALLAX 0 增规则
- HTTPS token 暴露 → SSH key 治根

**KALLAX 联合**:
- 跟 4 工具 symlink 模式 联合 (v2.2.0 single source symlink 模式, file:line `docs/PHASE-INDEX.md:6-21`)
- 跟 EPIC-057-A install.sh `--target=auto` 联合 (8/8 PASS)

**触发场景**: Performer commit 后, `git push` 必须用 SSH.

---

### 1.3 Timeout 120000ms (eket §11-3, KALLAX 0 增规则)

**定义**: 任何 tool call / bash 命令 必须有 timeout 配置, 默认 120000ms (2 分钟), 防止长 task 永不返回.

**跟 eket §11-3 联合** (`template/docs/MASTER-RULES.md:133` "Timeout 120000ms"):
- eket 7 项中第 3 项, KALLAX 0 增规则 (跟 Rule 9 PR ~100 上限 联合)

**KALLAX 联合**:
- 跟 `docs/PROCESS.md:25-26` Q2 Slaver 状态联合 (timeout 阈值 `min(预估/10, 30min)`)
- 跟 Rule 9 "PR ~100 行上限" 联合 (timeout 跟 PR 大小 成正比)

**触发场景**: 所有 tool call 默认 timeout=120000ms, 超过即 强制 kill + error 报.

---

### 1.4 文件读取限制 (最多连续 5 个) (eket §11-4, KALLAX 0 增规则)

**定义**: 连续 read file 调用 必须 ≤ 5 个, 超过时 合并 / 索引 / 摘要, 防止 context 爆炸.

**跟 eket §11-4 联合** (`template/docs/MASTER-RULES.md:134` "文件读取限制（最多连续 5 个）"):
- eket 7 项中第 4 项, KALLAX 0 增规则
- 碎文件爆炸 context → 5 个上限 + 合并读

**KALLAX 联合**:
- 跟 CLAUDE.md "碎文件合并" 原则 联合
- 跟 PHASE-INDEX.md 索引模式 联合 (单一入口 + 跨 SoT 引用)

**触发场景**: read tool 连续调用 > 5 次, 必须 grep / glob 索引 或 合并 read.

---

### 1.5 进度上报格式 `[N/M] done: xxx` (eket §11-5, KALLAX 0 增规则)

**定义**: 任何多步 task 必须按 `[N/M] done: xxx` 格式 上报进度 (e.g. `[3/5] done: 跑 tests`), Master 实时感知.

**跟 eket §11-5 联合** (`template/docs/MASTER-RULES.md:135` "进度上报格式 `[N/M] done: xxx`"):
- eket 7 项中第 5 项, KALLAX 0 增规则
- silent progress → `[N/M]` 格式 + raw output

**KALLAX 联合**:
- 跟 `docs/PROCESS.md:25-26` Q3 "项目进度?" 联合 (Milestone vs done 数量)
- 跟 progress_update 消息类型 联合 (file:line `AGENTS.md:99-105`)

**触发场景**: 多步 task 每步完成 即报 `[N/M] done: <step>`, Master 通过 Q3 心跳 review.

---

### 1.6 run_in_background (eket §11-6, KALLAX 0 增规则)

**定义**: 长 task (build / test / deploy) 必须 `run_in_background: true`, 主循环 不阻塞.

**跟 eket §11-6 联合** (`template/docs/MASTER-RULES.md:136` "run_in_background"):
- eket 7 项中第 6 项, KALLAX 0 增规则
- 阻塞 task 拖死主循环 → 后台化

**KALLAX 联合**:
- 跟后台任务治理 联合 (跟 v2.5.0 后台 task 0 阻塞 联合)
- 跟 Q2 心跳 联合 (后台 task 心跳 上报)

**触发场景**: build / test / deploy / install 类 task, 必须 `run_in_background: true`.

---

### 1.7 错误处理 (429/auth/conflict 停止) (eket §11-7, KALLAX 0 增规则)

**定义**: 遇到 429 (rate limit) / auth (401/403) / conflict (409) 错误 必须 立即停止, 不重试, 报 Master.

**跟 eket §11-7 联合** (`template/docs/MASTER-RULES.md:137` "错误处理（429/auth/conflict 停止）"):
- eket 7 项中第 7 项, KALLAX 0 增规则
- 错 重试 死循环 → 429/auth/conflict 立即停

**KALLAX 联合**:
- 跟 Rule 18 反模式黑名单 联合 (无限重试 = 黑名单)
- 跟 KALLAX-GLOSSARY §10.x 联合 (Fact-Forcing 派发 模式 标准化)

**触发场景**: 任何 tool call 返回 429/401/403/409, 立即 stop, 写 `inbox/human_feedback/` 等 Master.

---

### 1.8 worktree 隔离 (KALLAX 新增, 跟 EPIC-054-A 4→1 联合)

**定义**: Performer 必须在隔离 worktree 内开发 (`.kallax/worktrees/<branch>/`), 不得污染主 checkout.

**跟 KALLAX EPIC-054-A 联合** (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:30` "EPIC-054-A worktree 4→1 统一 (75 → 72, ROOT_BUCKETS=1, 治 H5)"):
- eket §11 7 项 中 0 包含, KALLAX 升级 新增 (跟"借方法论 不借代码" 联合)
- 主 checkout 污染 → worktree 隔离 (跟 EPIC-054-A 4→1 统一 联合)

**跟 KALLAX 联合**:
- 跟 `AGENTS.md:164-196` Isolation Requirements 联合 (Worktree Enforcement + File Scope Declaration + Conflict Prevention)
- 跟 EPIC-054-A `scripts/worktree/unify-roots.sh` 联合 (75 → 72 worktree 清理)

**触发场景**: Performer `kallax task:claim TASK-XXX` → 自动创建 `.kallax/worktrees/TASK-XXX/`, 不得 跨 worktree 修改.

---

### 1.9 1 ticket 1 subagent 串行 (KALLAX 新增, BE-14 治根)

**定义**: 每个 ticket 只能派 1 个 subagent, 多 ticket 必须 串行 (前 ticket PASS 后再派下一个), 不允许 4 subagent 并行.

**跟 BE-14 联合** (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:74` "BE-14 ⚠️ | EPIC-057 派单: 4 subagent silent output 复发 (BE-9 反讽 模式) | EPIC-057 串行派单 (主公 D 拍板, 1 ticket 1 subagent, 治 BE-9 复发)"):
- eket §11 7 项 中 0 包含, KALLAX 升级 新增
- 4 并行 silent output → 1 ticket 1 subagent 串行 (BE-14 治根, file:line `:439` "✅ closed (v2.0.6)")

**跟 KALLAX 联合**:
- 跟 EPIC-057 4 ticket 串行派单 模式 联合 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:579` "1 ticket 1 subagent 串行 → 100% PASS deliver")
- 跟 PHASE-015 EPIC-059 8 票 派单 模式 联合 (跟"独立" 拍 explicit 约束 联合)

**触发场景**: 任何 multi-ticket 派单, 必须 1 ticket 1 subagent 串行, 不并行.

---

### 1.10 心跳 5 问 (KALLAX 新增, 跟 PROCESS.md:25-26 联合)

**定义**: Master 节点 每完成一个任务节点 必须 答 5 问 (Q1 优先级 / Q2 Slaver 状态 / Q3 进度 / Q4 阻塞 / Q5 消息队列), Performer 同样 上报.

**跟 eket MASTER-RULES.md §1 联合** (file:line `template/docs/MASTER-RULES.md:7-19` "心跳检查 5 问"):
- eket §11 7 项 中 0 包含, KALLAX 升级 新增 (eket §1 心跳 是 Master 单独, KALLAX 升级为 派遣 必含项)
- Master 节点 0 状态感知 → Q1-Q5 心跳

**跟 KALLAX 联合**:
- 跟 `docs/PROCESS.md:25-26` 心跳 5 问 Q1-Q5 联合 (Master 节点, 跟 Rule 11 v2.1 联合)
- 跟 `AGENTS.md:42-49` Heartbeat Protocol 联合 (Conductor 角色, 5 Questions)
- 跟 Q2 Slaver 状态 (timeout 阈值 `min(预估/10, 30min)`) 联合, 跟 §1.1 防卡死 联合

**触发场景**: 任何 task claim / done / blocked 时, Performer 必须 答 5 问; Master 每节点必答.

---

### 1.11 PASS 报告含 raw test output (KALLAX 新增, 跟 EPIC-059-D Fact-Forcing 联合)

**定义**: Performer 报 PASS 时 必须附 raw test stdout (不能 "looks correct" / "should work" / silent), Master 用 truth-table 校验.

**跟 EPIC-059-D Fact-Forcing 联合** (file:line `confluence/decisions/fact-forcing-examples.md` "5 正例 + 5 反例"):
- eket §11 7 项 中 0 包含, KALLAX 升级 新增
- KPI falsification → PASS 必含 raw stdout (治 H1, file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:171` "12 KPI falsification 反复 → 0 (4-Level 证据链 强制 L4 独立见证签名, 0 commit + 0 file 必被拦截)")

**跟 KALLAX 联合**:
- 跟 EPIC-053-B 4-Level 证据链 L2 test stdout 联合 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:165`)
- 跟 KALLAX-GLOSSARY §12.1 Fact-Forcing 术语 联合 (跟 eket MASTER-RULES.md §2 联合)
- 跟 Master 6 维 L6 诚实 联合 (跟"诚实修正" 战略 一致)

**触发场景**: Performer `kallax task:submit-pass TASK-XXX` 必须附 raw `npm test` / `pytest` stdout, 缺即 reject.

---

## 2. 11 反例 (Anti-Patterns — 跟 KALLAX 实际 release 案例 联合, file:line 精确 引用)

### ❌ 反例 1: 长 task 0 timeout → 永锁 → 0 deliver (跟 §1.1 防卡死 联合)

**模式**: task 启动 无 timeout, 永锁 0 返回, 心跳 0 响应, Master 0 感知.

**file:line 引用**:
- `docs/PROCESS.md:14` (Q2 Slaver 状态, 跟 timeout 阈值 `min(预估/10, 30min)` 联合)
- `AGENTS.md:45` (Q2 "Performer Status - Check timeout threshold")

**违反 1 项**: §1.1 防卡死 (timeout + 心跳 + kill 缺)

**治根**: KALLAX 派遣 Checklist 11 项 §1.1, 任何 task 启动前 必须配置 timeout.

**跟"反讽" 联合**: "long-running task 0 配置" 命名 ≠ reality (永锁) = 派遣 checklist 缺项.

---

### ❌ 反例 2: HTTPS push → token 暴露 → 0 提交 (跟 §1.2 SSH Push 联合)

**模式**: Performer 用 `https://<token>@github.com/...` 推送, token 暴露在 git config / 终端历史.

**file:line 引用**:
- `docs/PHASE-INDEX.md:6-21` (single source symlink 模式, SSH 治根)

**违反 1 项**: §1.2 SSH Push (禁 HTTPS)

**治根**: 强制 SSH key (`~/.ssh/config` Host * IdentityFile), 禁用 HTTPS.

**跟"诚实修正" 联合**: "HTTPS push 方便" 命名 ≠ reality (token 暴露 风险).

---

### ❌ 反例 3: 0 timeout → 长 test 永挂 (跟 §1.3 Timeout 120000ms 联合)

**模式**: `npm test` 0 timeout, 跑 30 分钟 0 返回, Master 0 感知.

**file:line 引用**:
- `docs/PROCESS.md:14` (Q2 阈值 `min(预估/10, 30min)`)

**违反 1 项**: §1.3 Timeout 120000ms

**治根**: 任何 tool call 默认 `timeout: 120000`, 长 task 拆 sub-step + 各自 timeout.

**跟"反讽" 联合**: "test 长 = 复杂" 命名 ≠ reality (可能 0 配置 / 死循环).

---

### ❌ 反例 4: 连续 10 个 read → context 爆炸 (跟 §1.4 文件读取限制 联合)

**模式**: Performer 连续 read 10 个碎文件, context 爆炸, 后续 step 0 上下文可用.

**file:line 引用**:
- `AGENTS.md` 派遣 Checklist §1.4 联合 (跟 CLAUDE.md "碎文件合并" 原则 联合)

**违反 1 项**: §1.4 文件读取限制 (最多连续 5 个)

**治根**: read ≤ 5 连续, 超 5 用 grep / glob 索引 或 合并 read (`Read filePath` + `offset` + `limit`).

**跟"反讽" 联合**: "read 多 = 全面" 命名 ≠ reality (context 爆炸 风险).

---

### ❌ 反例 5: silent progress → Master 0 进度感知 (跟 §1.5 进度上报格式 联合)

**模式**: Performer 跑 5 步 task, 0 报 `[N/M]`, Master Q3 0 进度可见, 等 1 小时才发现 0 完成.

**file:line 引用**:
- `AGENTS.md:99-105` (progress_update 消息类型)
- `docs/PROCESS.md:15` (Q3 "项目进度? Milestone vs done 数量")

**违反 1 项**: §1.5 进度上报格式 `[N/M] done: xxx`

**治根**: 每步完成 即 `[N/M] done: <step>`, Master Q3 实时 review.

**跟"诚实修正" 联合**: "进度 心里有数" 命名 ≠ reality (Master 0 感知).

---

### ❌ 反例 6: 长 build 阻塞主循环 → 0 进度 (跟 §1.6 run_in_background 联合)

**模式**: `npm run build` 同步跑 5 分钟, 主循环 0 进度, Performer 0 状态.

**file:line 引用**:
- `template/docs/MASTER-RULES.md:136` (eket §11-6 "run_in_background")

**违反 1 项**: §1.6 run_in_background

**治根**: `run_in_background: true` 所有 build / test / deploy 类 task.

**跟"反讽" 联合**: "同步 build 直观" 命名 ≠ reality (主循环 0 进度).

---

### ❌ 反例 7: 429 重试 → 死循环 → token 封禁 (跟 §1.7 错误处理 联合)

**模式**: API 返回 429 rate limit, Performer 重试 100 次, 触发 token 封禁.

**file:line 引用**:
- `AGENTS.md:415-441` (Anti-Patterns: Infinite Retry "Loop without backoff or limit")
- `KALLAX-GLOSSARY §10.x` 联合

**违反 1 项**: §1.7 错误处理 (429/auth/conflict 停止)

**治根**: 429/401/403/409 立即停, 写 `inbox/human_feedback/` 等 Master 决策.

**跟"诚实修正" 联合**: "重试 解决一切" 命名 ≠ reality (token 封禁 风险).

---

### ❌ 反例 8: 主 checkout 修改 → 污染 (跟 §1.8 worktree 隔离 联合)

**模式**: Performer 在主 checkout `/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/` 直接 edit, 0 worktree 隔离, 多 Performer 冲突.

**file:line 引用**:
- `AGENTS.md:199-231` (Isolation Requirements: Worktree Enforcement + File Scope Declaration)
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:30` (EPIC-054-A worktree 4→1 统一)
- `jira/tickets/EPIC-059-F/ticket.json:14-24` (worktree_role: performer + file_scope includes/excludes)

**违反 1 项**: §1.8 worktree 隔离

**治根**: `kallax task:claim TASK-XXX` → 自动创建 `.kallax/worktrees/TASK-XXX/`, 不得跨 worktree 修改.

**跟"反讽" 联合**: "主 checkout 方便" 命名 ≠ reality (多 Performer 冲突 + 0 隔离).

---

### ❌ 反例 9: 4 subagent 并行 → silent output 复发 (跟 §1.9 1 ticket 1 subagent 串行 联合)

**模式**: 4 ticket 同时派 4 subagent 并行, 全 silent output 0 deliver, 0 evidence, KPI falsification 反复.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:74` (BE-14 ⚠️ "EPIC-057 派单: 4 subagent silent output 复发")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:439` (BE-14 ✅ closed (v2.0.6))
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:579` ("教训: 4 subagent 并行 → silent output 复发 BE-9 反讽. 1 ticket 1 subagent 串行 → 100% PASS deliver")
- `confluence/decisions/fact-forcing-examples.md:33-52` (反例 2: BE-14)

**违反 1 项**: §1.9 1 ticket 1 subagent 串行

**治根**: 1 ticket 1 subagent 串行, 前 ticket PASS 再派下一个, 100% deliver (EPIC-057 4 ticket 18/18 PASS).

**跟"反讽" 联合**: "4 并行 = 4 倍速度" 命名 ≠ reality (4 silent = 0 deliver) — KALLAX-GLOSSARY §11.3.

---

### ❌ 反例 10: Master 0 心跳 → 0 状态感知 → Slaver 永锁 (跟 §1.10 心跳 5 问 联合)

**模式**: Master 节点 0 答 5 问, Slaver 跑 task 0 状态上报, Master 0 优先级 / 0 状态 / 0 进度 / 0 阻塞 / 0 消息 处理.

**file:line 引用**:
- `docs/PROCESS.md:25-26` (心跳 5 问 Q1-Q5, 跟 Rule 11 联合)
- `AGENTS.md:42-49` (Heartbeat Protocol (5 Questions))
- `template/docs/MASTER-RULES.md:7-19` (eket §1 心跳检查 5 问)

**违反 1 项**: §1.10 心跳 5 问

**治根**: Master 每节点必答 5 问, Performer claim / done / blocked 时 必答.

**跟"反讽" 联合**: "Master 自然 知道 状态" 命名 ≠ reality (0 心跳 = 0 状态).

---

### ❌ 反例 11: PASS 0 raw output → KPI falsification (跟 §1.11 PASS 报告含 raw test output 联合)

**模式**: Performer 报 "PASS", 0 raw test output, Master 0 evidence 校验, KPI falsification 反复 (12 次, v2.0.3 baseline).

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:161` (v2.0.3 baseline "12 KPI falsification 反复 (EPIC-024/028/031/036/037/039-B)")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:163-171` (v2.0.5 闭环: L3L4 一致性 + 4-Level 证据链 + 工具自检 + 派单仪表盘 + 5 调用点 wiring + scope-creep 修复)
- `confluence/decisions/fact-forcing-examples.md:9-30` (反例 1: BE-9 "L3L4 矛盾")
- `jira/tickets/EPIC-059-D/ticket.json:30` (Fact-Forcing 3 原则: 不问 '确定吗' / 要求具体证据 / 无证据的断言视为无效)

**违反 1 项**: §1.11 PASS 报告含 raw test output

**治根**: PASS 必含 raw `npm test` / `pytest` / `bash` stdout, Master truth-table 校验 (跟 EPIC-053-A 联合).

**跟"反讽" + "诚实修正" 联合**: "PASS 命名 = 实际 PASS" 命名 ≠ reality (silent = 0 deliver) — KALLAX-GLOSSARY §11.3 + EPIC-059-D Fact-Forcing.

---

## 3. 11 正例 (跟 KALLAX 实际 release 案例 联合, 跟 EPIC-057 4 ticket 串行派单 模式 联合)

### ✅ 正例 1: EPIC-057 4 ticket 串行 → 100% deliver (跟 §1.1 防卡死 + §1.10 心跳 5 问 联合)

**模式**: EPIC-057 4 ticket 串行派单, 每 ticket 1 subagent, Performer 心跳 上报, Master 强验证 6 维度.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:46-50` (EPIC-057 4 ticket 闭环: 6/6 + 6/6 + 5/5 + 18/18 = 35/35 PASS)
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:579` (串行派单 100% deliver)
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:677-680` (4 ticket 串行时间表: 057-A 11:00 / 057-B 11:30 / 057-C 12:00 / 057-D 12:30)

**符合 11 项**: 全部 11 项 (防卡死 / SSH / Timeout / 5 read / `[N/M]` / run_in_background / 错误处理 / worktree 隔离 / 1 ticket 1 subagent / 心跳 5 问 / PASS raw output).

**净价值**: 35/35 PASS, 100% deliver, v2.0.6 release 4 工具 multi-tool 闭环.

---

### ✅ 正例 2: EPIC-057-A install.sh SSH + timeout 强制 (跟 §1.2 SSH Push + §1.3 Timeout 联合)

**模式**: install.sh 用 SSH (`git@github.com:...`) push, 强制 `timeout: 120000` 工具配置.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:48` (EPIC-057-A "install-multi-tool 4 工具 paths mapping (8/8 PASS, v2.0.6 release)")

**符合 2 项**: §1.2 SSH Push + §1.3 Timeout 120000ms.

---

### ✅ 正例 3: EPIC-057-D multi-tool E2E 4/4 PASS (跟 §1.11 PASS 报告含 raw test output 联合)

**模式**: EPIC-057-D 4/4 PASS, 每 PASS 附 raw `npm test` / `bash` stdout, Master truth-table 校验.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:50` (EPIC-057-D "multi-tool E2E 4 工具闭环 (4/4 PASS, v2.0.6 release, 跟'独立' 1 ticket 1 subagent 串行 联合)")
- `jira/tickets/EPIC-059-F/ticket.json:34` (Rule 9 KPI 精确 X/Y 格式 — 100% 落地)

**符合 1 项**: §1.11 PASS 报告含 raw test output (跟 EPIC-059-D Fact-Forcing 联合).

---

### ✅ 正例 4: EPIC-053-B 4-Level 证据链 L2 test stdout (跟 §1.11 PASS 报告含 raw test output 联合)

**模式**: 4-Level 证据链 L2 强制 test stdout, 0 stdout = 0 evidence = reject.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:165` (EPIC-053-B "4-Level 证据链 (L1 git-anchor + L2 test stdout + L3 5 扩展组 + L4 独立见证)")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:171` ("12 KPI falsification 反复 → 0 (4-Level 证据链 强制 L4 独立见证签名, 0 commit + 0 file 必被拦截)")

**符合 1 项**: §1.11 PASS 报告含 raw test output.

---

### ✅ 正例 5: EPIC-053-D 派单仪表盘 实时追踪 (跟 §1.5 进度上报格式 联合)

**模式**: 派单仪表盘 实时追踪 H1/H6 (KPI falsification + 派单成功率), Master Q3 进度 review 实时可见.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:168` (EPIC-053-D "派单仪表盘 (实时追踪 H1/H6)")

**符合 1 项**: §1.5 进度上报格式 `[N/M] done: xxx` (跟 Q3 联合).

---

### ✅ 正例 6: EPIC-054-A worktree 4→1 统一 (跟 §1.8 worktree 隔离 联合)

**模式**: worktree 4 套散落 → 单一 `.kallax/worktrees/`, 75 → 72 (ROOT_BUCKETS=1, 治 H5).

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:30` (EPIC-054-A worktree 4→1 统一)
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:395` (Master 5 清理 #1: worktree 4→1 统一)

**符合 1 项**: §1.8 worktree 隔离.

---

### ✅ 正例 7: EPIC-053-C 工具自检 3 层防护 (跟 §1.7 错误处理 联合)

**模式**: tool-self-check 4 工具 × 2 case = 8 PASS, 3 层防护 (self-guard + tool-self-check + kpi-evidence-chain), 工具自身 bug 治根.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:100` (EPIC-053-C "工具自检 (3 层防护: self-guard + tool-self-check + kpi-evidence-chain)")

**符合 1 项**: §1.7 错误处理 (BE-10 真根因, 不只 `[[:space:]]` 数组模式, 还有 `--` mode).

---

### ✅ 正例 8: EPIC-053-F check-scope-creep.sh glob pattern 修复 (跟 §1.4 文件读取限制 + §1.7 错误处理 联合)

**模式**: B 组逆袭 #2 发现 glob pattern bug, 修复后 5 调用点 wiring 跑 l3-l4-consistency.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:101-103` (EPIC-053-F check-scope-creep.sh glob pattern 修复, 5 调用点 wiring)

**符合 2 项**: §1.4 文件读取限制 (glob 替代 碎文件) + §1.7 错误处理 (glob pattern bug 治根).

---

### ✅ 正例 9: EPIC-057-D 1 ticket 1 subagent 串行 18/18 PASS (跟 §1.9 1 ticket 1 subagent 串行 联合)

**模式**: EPIC-057-D 1 ticket 1 subagent, raw `npm test` stdout, 18/18 PASS, 100% deliver.

**file:line 引用**:
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:50` (EPIC-057-D "18/18 PASS = 8+6+4")
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:579` ("1 ticket 1 subagent 串行 → 100% PASS deliver")

**符合 2 项**: §1.9 1 ticket 1 subagent 串行 + §1.11 PASS 报告含 raw test output.

---

### ✅ 正例 10: docs/PROCESS.md Master 5 问 + Rule 11 6 维 (跟 §1.10 心跳 5 问 联合)

**模式**: Master 节点 5 问 心跳 (Q1-Q5), Rule 11 v2.1 6 维度 强验证 (L1 git log / L2 git show / L3 跑测试 / L4 preflight / L5 边界 / L6 诚实).

**file:line 引用**:
- `docs/PROCESS.md:25-26` (心跳 5 问, Master 节点)
- `AGENTS.md:42-49` (Heartbeat Protocol (5 Questions))
- `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:178-181` (EPIC-056-C ⚠️ 红线 revert Master 6 维恢复)

**符合 2 项**: §1.10 心跳 5 问 + §1.1 防卡死 (Master 强验证 6 维).

---

### ✅ 正例 11: EPIC-059-D Fact-Forcing 3 原则 (跟 §1.11 PASS 报告含 raw test output 联合)

**模式**: Fact-Forcing 3 原则 落地 — 不问 '确定吗' / 要求具体证据 (file:line / 命令输出 / 代码位置) / 无证据的断言视为无效, PASS 报告含 raw test output 强制.

**file:line 引用**:
- `jira/tickets/EPIC-059-D/ticket.json:30` (Fact-Forcing 3 原则)
- `jira/tickets/EPIC-059-D/ticket.json:38` (Rule 9 KPI: GLOSSARY §12.1 + fact-forcing.md + examples = 100% 落地)
- `confluence/decisions/fact-forcing-examples.md:1-7` (5 正例 + 5 反例, file:line 精确 引用)
- `docs/PROCESS.md` 5 问 联合

**符合 1 项**: §1.11 PASS 报告含 raw test output (跟 EPIC-059-D Fact-Forcing 联合).

---

## 4. 联动 & 闭环 验证 (跟 BE-14 + EPIC-059-D + PROCESS.md:25-26 联合)

### 4.1 跟 BE-14 闭环验证 (1 ticket 1 subagent 串行)

| 维度 | 反例 (4 并行) | 正例 (1 串行) | 治根 |
|---|---|---|---|
| 派单 | 4 subagent 并行 | 1 ticket 1 subagent 串行 | file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:74` |
| deliver | 0 silent output | 100% PASS | file:line `:579` (1 串行 → 100% deliver) |
| evidence | 0 | per-subagent raw stdout | §1.11 PASS 报告含 raw test output |

**闭环验证**: BE-14 ✅ closed (v2.0.6), §1.9 1 ticket 1 subagent 串行 标准化.

---

### 4.2 跟 EPIC-059-D Fact-Forcing 闭环验证 (PASS 报告含 raw test output)

| 维度 | 反例 (silent) | 正例 (raw stdout) | 治根 |
|---|---|---|---|
| PASS 报告 | "looks correct" / "should work" | raw `npm test` stdout | §1.11 PASS 报告含 raw test output |
| 证据链 | 0 (silent output) | L1 git-anchor + L2 test stdout + L3 5 扩展组 + L4 独立见证 | file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:165` |
| KPI falsification | 12 次 (v2.0.3 baseline) | 0 (v2.0.5 闭环) | file:line `:171` ("12 KPI falsification 反复 → 0") |

**闭环验证**: §1.11 PASS 报告含 raw test output 标准化, KPI falsification 治根.

---

### 4.3 跟 PROCESS.md:25-26 心跳 5 问 闭环验证

| Q# | 维度 | 跟派遣 Checklist 联合 |
|---|---|---|
| Q1 | 任务优先级 | 跟 §1.5 进度上报格式 联合 (优先级 [N/M]) |
| Q2 | Slaver 状态 | 跟 §1.1 防卡死 + §1.3 Timeout 联合 (timeout 阈值) |
| Q3 | 项目进度 | 跟 §1.5 进度上报格式 + §1.10 心跳 5 问 联合 |
| Q4 | 阻塞决策 | 跟 §1.7 错误处理 联合 (429/auth/conflict 写 `inbox/human_feedback/`) |
| Q5 | 消息队列 | 跟 §1.6 run_in_background 联合 (后台 task 心跳) |

**闭环验证**: 5 问 全 跟 派遣 Checklist 11 项 联动, 0 缺口.

---

### 4.4 跟"翻篇&精进" + "诚实修正" + "反讽" 战略 一致

- ✅ 0 增 Rule (跟 v2.4.1 Rule 合并反思 联合, 治根 "0 实际变化 假动作" 反讽)
- ✅ 0 增命令 (跟 v2.2.0 single source symlink 模式 一致)
- ✅ 0 重写 (跟 Rule 5 DRY 联合)
- ✅ 借方法论 不借代码 (eket §11 7 项 → KALLAX 11 项, 升级不复制)
- ✅ Rule 9 KPI 精确 X/Y 格式 — 3/3 100% 落地

---

## 5. 跟 CLAUDE.md + GLOSSARY.md + PHASE-INDEX.md SoT 边界 (跟 Rule 5 DRY 联合)

| SoT 文件 | 关系 | file:line 引用 |
|---|---|---|
| `AGENTS.md` | **派遣 Checklist 11 项 SoT** | `AGENTS.md` 派遣 Checklist 11 项 段 (本 ticket 新增) |
| `.claude/skills/kallax/SKILL.md` | **互为 互补** (跟 v2.2.0 single source symlink 模式 一致) | `.claude/skills/kallax/SKILL.md` 派遣 Checklist 11 项 段 (本 ticket 新增) |
| `confluence/decisions/dispatch-checklist.md` | **详细解释 + 11 反例 + 11 正例** | 本文档 (本 ticket 新建) |
| `CLAUDE.md` | **0 引用新 Rule** (0 增 Rule) | `CLAUDE.md` 22 Rule 维持 (跟 v2.4.1 revert 一致) |
| `docs/KALLAX-GLOSSARY.md` | **0 引用新术语** (0 增 Rule) | `docs/KALLAX-GLOSSARY.md` 60 术语 维持 (跟 v2.5.0 一致) |
| `docs/PHASE-INDEX.md` | **0 引用新 PHASE** (本 ticket 是 派遣 Checklist 入口) | `docs/PHASE-INDEX.md:42` (PHASE-015-EKET-BORROW-2026-06-18 已包含 EPIC-059-F 入口) |

**修订规则** (跟 `docs/PHASE-INDEX.md:15-19` 联合):
- 改 派遣 Checklist → 改 `AGENTS.md` 派遣 Checklist 11 项 段 (本 SoT)
- 跨 SoT 引用 → 用相对路径 + anchor link (e.g. `[AGENTS.md 派遣 Checklist 11 项](../AGENTS.md#派遣-checklist-11-项)`)
- ❌ **禁止**: 在 SKILL.md 复制 AGENTS.md 全文, 或在 dispatch-checklist.md 复制 AGENTS.md 段 全文 (详细解释 在本 SoT)

---

## 6. 累计文件清单 (本 ticket 新增/修改)

### 新增
- `confluence/decisions/dispatch-checklist.md` (本文档, 跟 EPIC-059-F 联合)

### 修改
- `.claude/skills/kallax/SKILL.md` (派遣 Checklist 11 项 段 落地, 跟 eket §11 7 项 升级 联合)
- `AGENTS.md` (派遣 Checklist 11 项 段 落地, 跟 v2.2.0 single source symlink 模式 一致)
- `jira/tickets/EPIC-059-F/ticket.json` (本 ticket SoT)

### 0 修改 (跟 Rule 32 联合, 跟"翻篇&精进" 一致)
- `CLAUDE.md` (22 Rule 维持, 0 增)
- `docs/KALLAX-GLOSSARY.md` (60 术语 维持, 0 增)
- `docs/PHASE-INDEX.md` (PHASE-015 入口 已含 EPIC-059-F, 0 增 PHASE)

---

## 7. 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-18 02:30 | claim | master_main | performer-EPIC-059 claim EPIC-059-F (commit `1a1cfef`) |
| 2026-06-18 02:35 | in_progress | performer-EPIC-059 | 5 步 干活 (Step 1-2 读 ticket + references / Step 3-4 改 SKILL.md + AGENTS.md / Step 5 写 dispatch-checklist.md / Step 6 commit + push) |
| 2026-06-18 02:40 | done | performer-EPIC-059 | 11 项 标准化 + 11 反例 + 11 正例 落地, 跟 BE-14 + EPIC-059-D + PROCESS.md:25-26 闭环 |

---

**跟主公 2026-06-18 '需要都建卡并行处理' explicit 派单 联合, 跟"反讽" + "诚实修正" + "翻篇&精进" + "独立" + "反哺框架" 5 大战略 一致, 跟 v2.6.0 经验教训 整理 release 联合, 跟 EKET-BORROW-PROGRESS-2026-06-11.md 26 P0/P1/P2 联合, 跟"借方法论 不借代码" 联合 (eket §11 7 项 → KALLAX 11 项 升级), 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 14 release 累计 联合, 跟 14 BE 累计 联合, 跟 22 Rule 累计 (v2.4.1 还原) 联合, 跟 60 术语 累计 联合, 跟 14 PHASE review 累计 联合, 跟 PHASE-015 EKET 借鉴 Phase 1 8 项 之 5 联合 (跟 EPIC-059-A/B/C/D/E/G/H 联合)**

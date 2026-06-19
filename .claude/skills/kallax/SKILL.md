---
name: kallax
description: Use when user types any `/kallax-*` slash command or mentions "expert panel", "architecture review", "kallax expert", "召唤专家", "EPIC 拆解", "PHASE review", or invokes a multi-role expert review for a new EPIC, architectural decision, or major refactor. Spawns a 3-phase governance (EPIC-056-A): Phase 1 Conductor 全局扫描 (Architect 合并) + Phase 2 4 default (Backend/Frontend/UX/Product) + 5 extended (security-tool-bypass + process-engineering + auditor + compliance + decision-gate) 并行 + Phase 3 Master 仲裁 + 主公拍板. Do NOT trigger for simple bug fixes, single-domain tasks, or chores.
triggerKeywords: [kallax, expert panel, architecture review, 召唤专家, 专家评审, multi-agent, subagent, EPIC 拆解, PHASE review, BE 教训, 3 阶段治理, EPIC-056-A]
---

# KALLAX Skills 命令索引

> 快速查找所有 /kallax-* 斜杠命令

## Quick Reference (10 类, 29 命令, 跟 v2.3.0 install.sh 联合)

> **使用方式**: 命令直接打 (e.g. `/kallax-init`), AI 工具 加载 SKILL.md 后 自动 识别 触发 条件

| 类别 | 命令 | 描述 | Argument hint |
|------|------|------|---------------|
| **Setup** | `/kallax-init` | 初始化 KALLAX in a new or existing project | (no args) |
| **Setup** | `/kallax-start` | Start KALLAX in current project | `[role]` |
| **Setup** | `/kallax-mode` | Switch between operation modes | `[conductor\|performer\|standalone]` |
| **Setup** | `/kallax-role` | View or change agent role | `[conductor\|performer\|master]` |
| **Status** | `/kallax-status` | Show current system and task status | (no args) |
| **Status** | `/kallax-help` | Show all available KALLAX commands and resources | (no args) |
| **Status** | `/kallax-board` | Show interactive ticket board | (no args) |
| **Status** | `/kallax-list` | List all available experts, skills, and resources | (no args) |
| **Status** | `/kallax-instances` | List active Conductor/Performer instances | (no args) |
| **Status** | `/kallax-check-progress` | Check team progress and milestone status | (no args) |
| **Status** | `/kallax-phase-review` | Phase-based project review | `[PHASE]` |
| **Work** | `/kallax-task` | Quick task management shortcut | `[action] [TASK_ID]` |
| **Work** | `/kallax-claim` | Claim an available task (auto-creates worktree) | `[TASK_ID]` |
| **Work** | `/kallax-submit-pr` | Complete task and submit PR for review | `[TASK_ID]` |
| **Work** | `/kallax-merge` | Merge an approved PR | `[PR_NUMBER]` |
| **Work** | `/kallax-save` | Save current session state for later resumption | (no args) |
| **Work** | `/kallax-resume` | Resume from a saved session | (no args) |
| **Review** | `/kallax-verify-pr` | Verify PR output before merge (4-Level Fact-Forcing) | `[PR_NUMBER]` |
| **Review** | `/kallax-review-pr` | Review a pull request (Conductor only) | `[PR_NUMBER] [BASE_BRANCH]` |
| **Review** | `/kallax-review-merge` | Combined review + merge workflow | `[PR_NUMBER]` |
| **Review** | `/kallax-review-analysis` | Review codebase analysis results | (no args) |
| **Expert** | `/kallax-expert` | Summon a specific expert for analysis | `<role> [context]` |
| **Expert** | `/kallax-panel` | Launch full expert panel (4 default + 5 extended + Conductor, v2.0.3 EPIC-056-A) | `[TOPIC]` |
| **Expert** | `/kallax-ask` | Ask a question to the expert panel | `<question>` |
| **Expert** | `/kallax-skill` | Execute a specific skill | `<skill-name> [target]` |
| **Analysis** | `/kallax-analyze` | Analyze project structure and dependencies | `[TARGET]` |
| **Analysis** | `/kallax-office-hours` | Requirements analysis (6 questions method) | `[TOPIC]` |
| **Onboard** | `/kallax-onramp` | Multi-level project analyzer (L1/L2/L3 audit) | `<project_path> <user_need>` |
| **Onboard** | `/kallax-takeover` | Mid-project takeover (3-repo scan + 3-piece output) | `<project_path> <user_need>` |

**Full 26-command reference**: `docs/reference/slash-commands.md`  
**Per-command help**: `/kallax-<cmd> --help` (in-tool)  
**CLI commands**: `kallax --help` (Node.js runtime)  
**Heartbeat prompts**: `heartbeat-conductor.md`, `heartbeat-performer.md` (auto-load on role assignment)

## Sub-Skills (auto-loaded on demand)

> **When to use**: User asks for expert review, specific domain analysis, or skill execution. The sub-skill files in `default/`, `extended/`, `scripts/`, `skills/` are loaded as additional context.

| Sub-Skill | Path | When to load |
|-----------|------|--------------|
| **Main skill** | `SKILL.md` | Always loaded (this file) |
| **Detail reference** | `SKILL-DETAIL.md` | Deep dive (daemon, zombie defense, Performer protocol) |
| **4 default experts** | `default/{backend,frontend,ux,product}.md` | Domain-specific analysis (note: architect 跟 Conductor 合并, EPIC-056-A) |
| **5 extended experts** | `extended/{security-tool-bypass,process-engineering-self-verify,auditor-independent-witness,compliance-rule-merge,decision-gate-complex-only}.md` | Cross-cutting concerns (Rule 29-33 治根因 1-5) |
| **Init skill** | `skills/kallax-init.md` | On `/kallax-init` invocation |
| **Hooks installer** | `scripts/install-hooks.sh` | Session start hook setup |

**Loading order** (跟 EPIC-056-A 3 阶段治理 联合):
1. `SKILL.md` (always)
2. `SKILL-DETAIL.md` (on /kallax-expert or /kallax-panel invocation)
3. `default/*.md` (per expert summoned via /kallax-expert <role>)
4. `extended/*.md` (for security/compliance/audit/process concerns)
5. `heartbeat-*.md` (on role assignment: Conductor or Performer)

**Note**: `.sh` files in `scripts/` are NOT loaded as context — they're executables. The `default/` and `extended/` are markdown context files for the LLM.

## 核心命令

| 命令 | 描述 | 触发场景 |
|------|------|----------|
| `/kallax-panel` | 启动专家评审面板 | 新 EPIC、架构决策、技术选型 |
| `/kallax-expert <role>` | 召唤单个专家 | 需要特定领域深度分析 |
| `/kallax-skill <name>` | 执行特定技能 | 需要特定技术能力 |
| `/kallax-list` | 列出所有可用专家和技能 | 查看可用资源 |

| `/kallax-init` | 初始化 session 身份 | 新 session 启动时 |
| `/kallax 初始化为新的<role>` | 同上，自然语言版 | 首次接入团队 |

## Expert Panel (专家面板, v2.0.3 EPIC-056-A 3 阶段治理)

```
/kallax-panel [topic]
```

启动 4 default + 5 extended 专家组进行评审 (跟 v1.2.4 5 扩展组 联合):

**4 default 专家** (Architect 退出, 合并入 Phase 1 Conductor):
- 💻 Backend - 后端工程师
- 🎨 Frontend - 前端工程师
- 🖌️ UX - UX 研究员
- 📋 Product - 产品经理

**5 extended 扩展** (跟 v1.2.4 5 扩展组 一致, 0 增 0 删):
- 🛡️ security-tool-bypass (Rule 29 治根因 1)
- ⚙️ process-engineering (Rule 30 治根因 2)
- 🔍 auditor (Rule 31 治根因 3)
- 📜 compliance (Rule 32 治根因 4)
- 🚦 decision-gate (Rule 33 治根因 5)

### 3 阶段执行流程 (跟 EPIC-056-A 联合, 跟 EPIC-055-B 拍板分级 联动)

1. **Phase 1 — Conductor 全局扫描** (原 Architect + Conductor 合并, 治 A4 协调开销)
   - Conductor 直接出全局扫描报告 (架构/边界/选型/重构 视角, 原 Architect 能力)
   - 1 份报告, 省 0.4h/ticket, 跟"流程效果 > 流程表演" 联合
2. **Phase 2 — 4 default + 5 extended 并行** (0 增 0 删, 9 专家 Promise.all 调度)
   - 4 default (Backend/Frontend/UX/Product) + 5 extended (security-tool-bypass/process-engineering/auditor/compliance/decision-gate)
   - 9 份专家报告, 0 协调开销 (per-subagent 独立 worktree)
3. **Phase 3 — Master 仲裁 + 主公拍板** (跟 EPIC-055-B P0/P1/P2 联动)
   - Master 收 9 份报告 → 合并去重 → 仲裁冲突 → 出汇总
   - 主公按 055-B 拍板分级: P0 战略红线 (阻塞 + REQUEST-P0-*.md) / P1 流程升级 (备案 + RECORD-P1-*.md) / P2 操作 (放手 + p2-log-*.jsonl)
   - Master 强验证 6 维度 (Rule 11 v2.1 联合)

**净价值估算** (跟 EPIC-056-B 3 KPI 联动): 62.5% → 65%+ (跟"流程效果 > 流程表演" 一致)

**协调脚本**: `scripts/audit/governance-3phase.sh` (6/6 TC PASS, Rule 9 X/Y 格式)
**TDD 测试**: `tests/integration/governance-3phase-test.sh`

## 单专家召唤

```
/kallax-expert <role> [context]
```

### 核心专家 (default/)
- `architect` - 系统架构、技术选型
- `backend` - 后端实现、API 设计
- `frontend` - 前端实现、组件设计
- `ux` - 用户体验、交互设计
- `product` - 产品规划、需求分析

### 扩展专家 (extended/)

**AI/ML**: `aiml`, `bigdata`, `cv`, `data-analyst`, `mlops`, `nlp`

**Business**: `business`, `compliance`, `finance`, `legal`, `strategy`

**Consulting**: `it-consulting`, `mgmt`, `process`

**Design**: `brand`, `industrial`, `motion`, `ux-research`, `visual`

**HR**: `recruitment`, `training`

**Knowledge**: `documentation`, `knowledge-mgmt`

**Marketing**: `content`, `digital`, `growth`

**Ops**: `devops`, `sre`, `infra`

**PR**: `communications`, `media`

**Tech**: `security`, `performance`, `database`

**Training**: `onboarding`, `skills-development`

## 技能执行

```
/kallax-skill <name> [params]
```

### 可用技能

**Algorithm**: `algorithm-design`

**Analysis**: `code-analysis`, `requirements-analysis`

**Data**: `data-modeling`

**DevOps**: `ci-cd`, `kubernetes`

**Documentation**: `technical-writing`, `api-docs`

**Implementation**: `tdd`, `refactoring`

**LLM**: `prompt-engineering`, `agent-design`

**Ops**: `monitoring`, `incident-response`

**Security**: `security-review`, `penetration-testing`

**UX**: `user-research`, `usability-testing`

## 触发条件

### ✅ 适合使用 Expert Panel
- 新 EPIC / 新产品需求
- 架构变更 / 技术选型
- 重大重构决策
- 用户明确要求专家评审

### ❌ 不需要 Expert Panel
- 简单 bug fix
- chore / docs 更新
- 单一明确任务
- 已有清晰实现路径

## 快速示例

```bash
# 启动完整专家面板讨论新功能
/kallax-panel "设计用户认证系统"

# 召唤架构师评审现有设计
/kallax-expert architect "评审当前微服务架构"

# 执行代码分析
/kallax-skill code-analysis src/

# 列出所有可用资源
/kallax-list
```

---

## Post-Process 11 步骤 (跟 eket MASTER-RULES.md §10 升级, EPIC-059-E)

> **跟 eket template/docs/MASTER-RULES.md §10 4 步骤升级, 跟 PHASE review 入口 标准化 联合**
> **自动化**: `scripts/post-process.sh` (默认 dry-run, `--apply` 实际执行)
> **TDD 测试**: `tests/integration/post-process-test.sh` (5/5 PASS)
> **详细定义**: `docs/PHASE-INDEX.md` Post-Process 11 步骤 段

```
# dry-run: 显示 11 步骤 状态 (不实际 修改)
scripts/post-process.sh

# 实际 执行 (默认 dry-run, --apply 标志)
scripts/post-process.sh --apply

# mock 测试: 模拟单步状态 (用于 CI / 集成测试)
scripts/post-process.sh --check-step 5 --status PASS    # GLOSSARY 已更新
scripts/post-process.sh --check-all --mock-scenario all-pass
```

**11 步骤** (跟 eket §10 4 步骤 升级映射):

| # | 步骤 | 触发 |
|---|---|---|
| 1 | 回归验证 (build/test/CI) | EPIC/Sprint 完成 |
| 2 | 分支同步 (miao → origin) | PR merged |
| 3 | 经验沉淀 (lessons/lessons-learned) | EPIC done |
| 4 | 技术债登记 (TODO/workaround → jira backlog) | EPIC done |
| 5 | GLOSSARY 更新 | EPIC done |
| 6 | PHASE-INDEX 更新 | EPIC done |
| 7 | ACCUMULATED-LESSONS 更新 | 跨 release |
| 8 | CHANGELOG 入口 | release 节点 |
| 9 | CLAUDE.md Rule 更新 (如需) | Rule 改变 |
| 10 | pre-commit hook 测试 | 任何 Rule 改 |
| 11 | 跨期 review 入口 (PHASE-XXX-REVIEW) | EPIC/Sprint 完成 |

**联动**:
- 跟 `docs/PHASE-INDEX.md` Post-Process 11 步骤 段 联合 (file:line)
- 跟 eket MASTER-RULES.md §10 4 步骤 → 11 步骤 升级 联合
- 跟 PHASE-005 → PHASE-014 review 入口 标准化 联合
- 跟 EKET-BORROW-PROGRESS-2026-06-11.md 26 P0/P1/P2 联合 (Post-Process 是 借鉴 8 项之一)
- 跟"翻篇&精进" + "反哺框架" 战略 一致

---

## 派遣 Checklist 11 项 (跟 eket MASTER-RULES.md §11 7 项 升级, EPIC-059-F)

> **跟 eket `template/docs/MASTER-RULES.md` §11 "Agent 派遣 Checklist" 7 项 升级 (借方法论 不借代码), 跟 BE-14 1 ticket 1 subagent 串行 联合, 跟 `docs/PROCESS.md:25-26` 心跳 5 问 联合, 跟 EPIC-059-D Fact-Forcing 联合**
> **11 项 = eket 7 项 + KALLAX 4 项升级 (worktree 隔离 + 1 ticket 1 subagent 串行 + 心跳 5 问 + PASS 报告含 raw test output)**
> **详细**: `confluence/decisions/dispatch-checklist.md` (11 项 详细解释 + 11 反例 + 11 正例)
> **联动 ticket**: EPIC-059-F (跟主公 2026-06-18 '需要都建卡并行处理' explicit 派单 联合, 跟 v2.6.0 经验教训 整理 release 联合)

**11 项** (跟 eket §11 7 项 升级映射):

| # | 项 | eket §11 联合 | KALLAX 升级 |
|---|----|--------------|------------|
| 1 | **防卡死规则** | eket §11-1 | KALLAX 0 增规则 (跟 Rule 5 DRY 联合) |
| 2 | **SSH Push (禁 HTTPS)** | eket §11-2 | KALLAX 0 增规则 (跟 4 工具 symlink 模式 联合) |
| 3 | **Timeout 120000ms** | eket §11-3 | KALLAX 0 增规则 (跟 Rule 9 联合) |
| 4 | **文件读取限制 (最多连续 5 个)** | eket §11-4 | KALLAX 0 增规则 (跟 CLAUDE.md "碎文件合并" 联合) |
| 5 | **进度上报格式 `[N/M] done: xxx`** | eket §11-5 | KALLAX 0 增规则 (跟 Q3 进度 review 联合) |
| 6 | **run_in_background** | eket §11-6 | KALLAX 0 增规则 (跟后台任务治理 联合) |
| 7 | **错误处理 (429/auth/conflict 停止)** | eket §11-7 | KALLAX 0 增规则 (跟 Rule 18 反模式黑名单 联合) |
| 8 | **worktree 隔离** | — | **KALLAX 新增** (跟 EPIC-054-A worktree 4→1 联合) |
| 9 | **1 ticket 1 subagent 串行** | — | **KALLAX 新增** (跟 BE-14 联合, file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:74` + `:439`) |
| 10 | **心跳 5 问** | — | **KALLAX 新增** (跟 `docs/PROCESS.md:25-26` 联合, 跟 Q1-Q5 联合) |
| 11 | **PASS 报告含 raw test output** | — | **KALLAX 新增** (跟 EPIC-059-D Fact-Forcing 联合, 治 H1 KPI falsification 反复) |

**联动**:
- 跟 eket `template/docs/MASTER-RULES.md` §11 7 项 → 11 项 升级 联合 (借方法论 不借代码, 7+4=11)
- 跟 `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:74` BE-14 联合 (4 subagent 并行 silent output 复发 → 1 ticket 1 subagent 串行)
- 跟 `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:439` BE-14 closed (v2.0.6) 联合
- 跟 `docs/PROCESS.md:25-26` 心跳 5 问 Q1-Q5 联合 (Master 节点, 跟 Rule 11 联合)
- 跟 EPIC-059-D Fact-Forcing 原则 联合 (file:line `confluence/decisions/fact-forcing-examples.md`, 治根 "0 假 PASS")
- 跟 EPIC-057 串行派单 模式 联合 (file:line `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md:579`, 100% PASS deliver)
- 跟"翻篇&精进" 战略 一致 (0 增 Rule 0 增命令 持平)
- 跟 v2.4.1 Rule 合并反思 联合 (治根 "0 实际变化 假动作" 反讽)
- 跟"借方法论 不借代码" 联合 (eket 7 项 → KALLAX 11 项, 升级不复制)
- Rule 9 KPI 精确 X/Y 格式 — SKILL.md 段 1/1 + AGENTS.md 段 1/1 + dispatch-checklist.md 1/1 = 3/3 100% 落地, 0 增 Rule

---

## 记忆分层 L0-L4 触发 (EPIC-059-H 2026-06-18)

> **跟 26 命令 SKILL 模式 一致** — 5 触发条件对应 5 升级路径, 跟 `scripts/memory-promote.sh` + `confluence/memory/LAYERS.md` 联合
> **跟 eket `confluence/memory/` 多级记忆 模式 联合**, 跟 `~/.claude/knowledge/core/patterns/knowledge-system.md` L0-L4 架构 联合
> **0 增 Rule, 0 重写** (跟 EPIC-059-A 9-hard-rules.md 联合, 跟 Rule 5 DRY 联合)

KALLAX 知识库按 5 层分层, 26 命令可触发不同层的升级:

### 5 触发条件 (5 Triggers, 跟 KALLAX-GLOSSARY §12.4 联合)

| 触发 # | 触发命令 | From → To | 落地位置 |
|---|---|---|---|
| **1** | `/kallax-claim` + `/kallax-submit-pr` (任务完成) | **L0 → L1** | `state.json` → `confluence/decisions/<ticket>.md` |
| **2** | `/kallax-phase-review` (EPIC 闭环) | **L1 → L2** | `confluence/decisions/EPIC-*.md` → `confluence/memory/lessons/epic-{ID}-{date}.md` |
| **3** | 跨 ≥ 3 release 引用 (累计触发) | **L2 → L3** | `confluence/memory/lessons/*` → `confluence/memory/patterns/{name}.md` |
| **4** | `/kallax-phase-review` (PHASE review) | **L3 → L4** | `confluence/decisions/PHASE-*-REVIEW-*.md` → `confluence/memory/research/{topic}.md` |
| **5** | `/kallax-skill` (借鉴外部) | **L4 沉淀** | eket / industry → L1-L4 适配层 (`scripts/eket-lessons-import.sh`) |

### 5 升级路径 (5 Promotion Paths, 跟 `scripts/memory-promote.sh` 联合)

```bash
# 路径 1: L0 → L1 (任务完成)
/kallax-claim TASK-001
... (开发)
/kallax-submit-pr TASK-001  # 触发 L0 → L1

# 路径 2: L1 → L2 (EPIC 完成)
/kallax-phase-review EPIC-031  # 触发 L1 → L2

# 路径 3: L2 → L3 (跨 release 累计, 手动 + Master 拍板)
bash scripts/memory-promote.sh promote L2 L3 <lesson> <pattern>
# 验证: grep -l "<keyword>" confluence/decisions/PHASE-*.md | wc -l >= 3

# 路径 4: L3 → L4 (PHASE review 升级)
/kallax-phase-review PHASE-015  # 触发 L3 → L4

# 路径 5: L4 沉淀 (外部借鉴)
bash scripts/eket-lessons-import.sh  # 沉淀到 L1-L4
```

### 验证 (5/5 PASS, 跟 `tests/integration/memory-l0-l4-test.sh` 联合)

```bash
bash scripts/memory-promote.sh verify-all
# 期望: 5/5 PASS (L0/L1/L2/L3/L4 全部存在)
```

**反模式 警告** (跟"反讽" + "诚实修正" 联合, 跟 KALLAX-GLOSSARY §12.4 5 反模式 联合):
- ❌ 跨层写入 (skip layer) → 跳级需 Master 拍板
- ❌ 倒序沉淀 (L4 → L3) → `memory-promote.sh` exit 1
- ❌ L0 长期累积 (`.kallax/state/` > 1GB) → LRU 清理
- ❌ L4 假沉淀 (缺 ≥ 3 PHASE 引用) → 视为无效
- ❌ 分层标记 vs 内容失配 → `verify-all` 强制检查

**详细**: [KALLAX-GLOSSARY §12.4](../../docs/KALLAX-GLOSSARY.md#124-l0-l4-记忆分层memory-layering-epic-059-h-2026-06-18) + [confluence/memory/LAYERS.md](../../confluence/memory/LAYERS.md) + `scripts/memory-promote.sh` + `tests/integration/memory-l0-l4-test.sh`

**Rule 引用**: Rule 5 (DRY) + Rule 6 (经验沉淀) + Rule 11 (Master 6 维) — [CLAUDE.md](../../CLAUDE.md), 跟 §1.1 反讽 + §1.2 诚实修正 + §2.2 反哺框架 战略 一致.

**联动 ticket**: EPIC-059-H (跟主公 2026-06-18 '需要都建卡并行处理' explicit 派单 联合, 跟 v2.6.0 经验教训 整理 release 联合).

**KPI 落地**: SKILL.md 段 1/1 + GLOSSARY §12.4 1/1 + memory-promote.sh 1/1 + test 5/5 PASS = 4/4 = 100.0%.

---

**详细文档**: [SKILL-DETAIL.md](./SKILL-DETAIL.md)
**使用指南**: [META-GUIDELINES.md](./META-GUIDELINES.md)


## Session 初始化

```
/kallax-init --role master     # 接管为 Master
/kallax-init --role conductor  # 初始化为 Conductor
/kallax 初始化为新的performer  # 自然语言版
```

新 session 第一步必须执行，用于:
- 注册 instance_id 到 .kallax/instances/
- 写入 state.json (角色、心跳、状态)
- 显示 ASCII Card (团队状态、inbox、下一步)
- 如果是 Master: 检测 handoff.json → 恢复上下文
- 如果是 Performer: 自动引导 EnterWorktree

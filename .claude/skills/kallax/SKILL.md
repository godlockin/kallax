---
name: kallax
description: Use when user types any `/kallax-*` slash command (`/kallax-panel`, `/kallax-expert`, `/kallax-skill`, `/kallax-init`, `/kallax-takeover`, `/kallax-ask`, `/kallax-claim`, `/kallax-submit-pr`, `/kallax-review-pr`, `/kallax-merge`, `/kallax-status`, `/kallax-help`, `/kallax-board`, `/kallax-start`, `/kallax-role`, `/kallax-mode`, `/kallax-save`, `/kallax-resume`, `/kallax-list`, `/kallax-analyze`, `/kallax-office-hours`, `/kallax-phase-review`, `/kallax-verify-pr`, `/kallax-review-merge`, `/kallax-review-analysis`, `/kallax-task`), or mentions "expert panel", "architecture review", "kallax expert", "召唤专家", "专家评审", "kallax 多 agent", "subagent workflow", "EPIC 拆解", "PHASE review", "BE 教训", or invokes a multi-role expert review for a new EPIC, architectural decision, or major refactor. Spawns a 3-phase governance (v2.0.3 EPIC-056-A): Phase 1 Conductor 全局扫描 (Architect 合并) + Phase 2 4 default (Backend/Frontend/UX/Product) + 5 extended (security-tool-bypass + process-engineering + auditor + compliance + decision-gate) 并行 + Phase 3 Master 仲裁 + 主公拍板. Do NOT trigger for simple bug fixes, single-domain tasks, or chores. See `docs/reference/slash-commands.md` for the full 26-command reference; each command also supports `/kallax-<cmd> --help` for in-tool usage.
triggerKeywords: [kallax, expert panel, architecture review, 召唤专家, 专家评审, multi-agent, subagent, EPIC 拆解, PHASE review, 实战, 反思, BE 教训, A+B review, 5 扩展组, 5 视角, 决策疲劳, KALLAX Onramp, 3 阶段治理, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, EPIC-056-A]
filePath: /Users/chenchen/.claude/skills/kallax/SKILL.md
---

# KALLAX Skills 命令索引

> 快速查找所有 /kallax-* 斜杠命令

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

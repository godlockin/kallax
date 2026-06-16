---
name: kallax
description: Use when user types `/kallax-panel`, `/kallax-expert`, `/kallax-skill`, `/kallax-init`, `/kallax-takeover`, or mentions "expert panel", "architecture review", "kallax expert", "召唤专家", "专家评审", "kallax 多 agent", "subagent workflow", "EPIC 拆解", "PHASE review", "BE 教训", or invokes a multi-role expert review for a new EPIC, architectural decision, or major refactor. Spawns a 5-person panel (Architect, Backend, Frontend, UX, Product) + 5 extended (security-tool-bypass + process-engineering + auditor + compliance + decision-gate). Do NOT trigger for simple bug fixes, single-domain tasks, or chores.
triggerKeywords: [kallax, expert panel, architecture review, 召唤专家, 专家评审, multi-agent, subagent, EPIC 拆解, PHASE review, 实战, 反思, BE 教训, A+B review, 5 扩展组, 5 视角, 决策疲劳, KALLAX Onramp, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合]
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

## Expert Panel (专家面板)

```
/kallax-panel [topic]
```

启动 5 人核心专家组进行评审:
- 🏗️ Architect - 架构师
- 💻 Backend - 后端工程师
- 🎨 Frontend - 前端工程师
- 🖌️ UX - UX 研究员
- 📋 Product - 产品经理

### 执行流程
1. **Phase 1**: Architect 先行 (全局扫描)
2. **Phase 2**: 4 专家并行工作
3. **Phase 3**: Conductor 汇总决策

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

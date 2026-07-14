# EPIC-119 — Tool Orchestration 分类 (OpenAI Building Agents 借鉴)

> Date: 2026-07-14 | 3 tickets (A/B/C) | OpenAI guide ref

## 起源

主公 2026-07-14 研究 OpenAI《A Practical Guide to Building Agents》后 explicit "加"。

**OpenAI 3 类 Tool**:

| 类型 | 定义 | KALLAX 示例 |
|------|------|------------|
| **Data** | 检索上下文 (查询 DB / 文件 / web) | metrics 查询, search, audit |
| **Action** | 执行操作 (写文件 / 发 PR / 更新 state) | commit, PR, merge, deploy |
| **Orchestration** | Agent 作为 tool 供其他 agent 调用 | expert panel, governance-3phase |

**Orchestration 关键洞察**: "Agents as tools for other agents" — 一个 agent 可以调用另一个 agent 作为 tool。这正是 KALLAX `kallax-expert` / `kallax-panel` 的本质。

## 3 Ticket

| Ticket | 主题 | 文件 | Acceptance |
|--------|------|------|-----------|
| **A** | tools-registry.md schema | docs/tools-registry.md | 3 类定义 + 每类 3+ 示例 |
| **B** | classify-tools.sh | scripts/tools/classify-tools.sh | 26 slash commands 全部分类 |
| **C** | SKILL.md 更新 | .claude/skills/kallax/SKILL.md | 新增 Tool 分类 section |

## 联动

- EPIC-117 (ACI — tool 接口统一)
- EPIC-118 (expertise — agent 能力分层)
- Anthropic Building Effective Agents (ACI tool design)
- OpenAI Building Agents (tool 3 分类)

## OpenAI 原文

```
Tool Categories:
- Data: retrieve context (database queries, file search, web search)
- Action: execute operations (send emails, update CRM, create tickets)
- Orchestration: enable multi-agent patterns (agents as tools for other agents)
```

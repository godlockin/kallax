# KALLAX Tools Registry — OpenAI Building Agents 3-Class Taxonomy

> EPIC-119-B | v3.25.0 | OpenAI 3-class tool taxonomy + KALLAX 26 slash commands

## 3-Class Tool Taxonomy (OpenAI Building Agents)

| Class | 定义 | OpenAI 示例 | KALLAX 示例 |
|-------|------|------------|------------|
| **Data** | 检索上下文, 不修改外部状态 | DB queries, file search, web search | `metrics:sprint`, `analyze`, `board` |
| **Action** | 执行操作, 产生副作用 | Send email, update CRM, create ticket | `commit`, `PR create`, `merge`, `claim`, `submit-pr` |
| **Orchestration** | Agent 作为 tool 供其他 agent 调用 | Multi-agent coordination | `expert`, `panel`, `ask`, `review-pr`, `governance-3phase` |

## KALLAX 26 Slash Commands — 分类结果

### Data (检索上下文, 只读)

| Command | 功能 | OpenAI 对应 |
|---------|------|------------|
| `/kallax-status` | 当前实例状态 | DB query |
| `/kallax-board` | Ticket 看板 | File search |
| `/kallax-list` | 列出 experts/skills | File search |
| `/kallax-instances` | 活跃实例列表 | DB query |
| `/kallax-check-progress` | 团队进度 | DB query |
| `/kallax-analyze` | 项目结构分析 | File search + web search |
| `/kallax-review-analysis` | 代码分析结果 | DB query |
| `/kallax metrics:sprint` | 北极星指标 | DB query (structured) |

### Action (执行操作, 写外部状态)

| Command | 功能 | OpenAI 对应 |
|---------|------|------------|
| `/kallax-claim` | 认领 ticket | Create ticket |
| `/kallax-submit-pr` | 提交 PR | Create PR |
| `/kallax-merge` | 合并 PR | Update CRM |
| `/kallax-init` | 初始化 session | Create instance |
| `/kallax-start` | 启动 KALLAX | Create workflow |
| `/kallax-mode` | 切换模式 | Update config |
| `/kallax-role` | 切换角色 | Update config |
| `/kallax-task` | 任务管理 | Update ticket |
| `/kallax-save` | 保存 session | Write file |
| `/kallax-resume` | 恢复 session | Read file |
| `/kallax-takeover` | Mid-project 接管 | Read + write |
| `/kallax-onramp` | 项目分析初始化 | Write + create |
| `/kallax-office-hours` | 需求分析 | Write doc |
| `/kallax-skill` | 执行 skill | Execute tool |

### Orchestration (Agent as tool for other agents)

| Command | 功能 | OpenAI 对应 |
|---------|------|------------|
| `/kallax-expert` | 召唤单个 expert | Agent as tool |
| `/kallax-panel` | 启动专家面板 (9 并行) | Orchestrator agent |
| `/kallax-ask` | 向 panel 提问 | Orchestrator query |
| `/kallax-review-pr` | PR 评审 | Reviewer agent |
| `/kallax-review-merge` | 评审+合并 | Orchestrator |
| `/kallax-verify-pr` | PR 验证 | Reviewer agent |
| `/kallax-phase-review` | PHASE 评审 | Orchestrator |

## Tool 属性 Schema

```yaml
type: data | action | orchestration
read_only: boolean         # data=true, action=false
idempotent: boolean        # 重复执行安全
parallel_safe: boolean     # 可并行调用
requires_confirmation: boolean  # 是否需要 master 确认
```

## 使用建议

| 场景 | 推荐类型 |
|------|---------|
| 查询状态/指标 | Data |
| 执行 git/PR 操作 | Action |
| 跨 agent 协调 | Orchestration |
| 需要 human-in-loop | Orchestration + confirmation |

## 联动

- EPIC-117 (ACI — tool 接口统一)
- EPIC-118 (expertise — agent 能力分层)
- OpenAI Building Agents (tool 3 分类)
- Anthropic Building Effective Agents (ACI tool design)

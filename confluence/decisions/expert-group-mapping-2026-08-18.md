# Expert 专家组映射决策 (EPIC-271)

> 日期: 2026-08-18 | 决策人: 主公 | 依据: 三份侦察报告 + 远程 kallax-experts 仓库实读

## 1. 结论

KALLAX 现有两套本地专家设定都被污染, 以远程 `godlockin/kallax-experts` 为**格式基准**, 建立 KALLAX 的 default 专家组。映射关系四类:

- **升级**: 远程有、且格式规范 → 直接引入并转成 `.claude/agents/*.md`
- **修改**: 远程有、但内容要贴合 KALLAX → 用远程 schema 重写
- **保留 KALLAX 特有**: 远程没有、但 KALLAX 框架需要 → 去污染后用远程 schema 重写
- **不引入**: 远程有、但 KALLAX 用不上 → 留外挂层, 不进 default

## 2. 远程 15 专家 → KALLAX default 组映射

| 远程 role_id | KALLAX default 组 | 处置 |
|---|---|---|
| backend-architect | backend | **升级** (远程版本更完整) |
| ux-researcher | ux | **升级** |
| product-manager | product | **升级** |
| security-engineer | security (extended) | **升级** |
| — | frontend | **新建** (远程缺) |
| — | architect | **新建** (远程 backend-architect 兼了, 拆独立) |
| — | process-engineering (extended) | **保留 KALLAX 特有**, 去污染重写 |
| — | auditor (extended) | **保留 KALLAX 特有**, 去污染重写 |
| — | decision-gate (extended) | **保留 KALLAX 特有**, 去污染重写 |
| legal-compliance | compliance (extended) | **修改** (远程是通用法务, KALLAX 要的是 Rule 合并合规视角) |
| llm-engineer / llm-engineer-senior | — | **不引入** (留外挂) |
| data-analyst | — | **不引入** (留外挂) |
| finance-analyst | — | **不引入** (留外挂) |
| legal-advisor | — | **不引入** (留外挂) |
| devops-engineer | — | **不引入** (留外挂) |
| sre-engineer | — | **不引入** (留外挂) |
| mobile-engineer | — | **不引入** (留外挂) |
| performance-engineer | — | **不引入** (留外挂) |
| qa-engineer | — | **不引入** (留外挂) |

## 3. 远程 schema (格式基准)

每个 expert 的 frontmatter 字段 (schema/frontmatter.yml):

```
name / name_en / role_id / emoji / color / vibe
source / source_id / divisions / domains
triggers (zh/en) / use_when (zh/en)
tools / related / priority / tokens / updated
```

**已知 bug**: 远程 `backend-architect.md` frontmatter 的 `---` 后有空 3 行 (YAML 不规范), 引入时要修。

## 4. KALLAX `.claude/agents/*.md` 需要的额外字段

Claude Code agent 定义 frontmatter 需: `name` / `description` / 可选 `tools` / 可选 `model`.

远程 schema 有 `name` / `tools`, 但 `description` 是"触发关键词"式 (Use when user mentions...), 需改写为"这个 agent 干什么"式任务描述。`model` 远程没有, 需补。

## 5. 待办 (拆卡输入)

1. 暂存本地两组 `.claude/skills/kallax/{default,extended}` + `.claude/commands/kallax/experts`
2. 从远程引入 4 个 (backend/ux/product/security), 转 `.claude/agents/*.md`
3. 新建 2 个 (frontend / 独立 architect)
4. 重写 4 个 KALLAX 特有 extended (process-engineering / auditor / decision-gate / compliance), 去污染 + 用远程 schema
5. 补 agent 定义需要的 description 改写 + model
6. 修远程 frontmatter 空行 bug

## 6. 关联

- 三份侦察: /tmp/recon-dispatch.md / recon-expert-template.md / recon-observability.md
- 远程仓库: github.com/godlockin/kallax-experts (default branch miao)
- 后续卡: 外挂加载 (B) / 派单链接线 (C) / 埋点 (D) / 复盘升级 (E)

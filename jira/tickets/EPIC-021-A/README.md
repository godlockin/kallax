# EPIC-021-A: 7 expert persona 文件 + KALLAX 专属字段

## 需求

按 EKET 7 节 full anatomy 模板, 创建 7 个 KALLAX expert 独立文件. 每文件含 KALLAX 5 维独有 frontmatter 字段 (worktree_role/review_group/tickets_served/version/last_reviewed), 这些字段是 EKET 没有的, 体现"执行式 persona"超越.

## 接受标准 (AC)

详见 `ticket.json`. 8 条 AC:
1. 7 个 .md 文件存在 (`.kallax/experts/default/{architect,backend,frontend,ux,product,security,pm}.md`)
2. frontmatter 必带 KALLAX 专属 5 字段
3. 7 节 full anatomy 齐全
4. 额外 5 节齐全 (When to Use / When NOT to Use / Process / Red Flags / Verification)
5. security.md 必带合规/法律/业务风控的 `When NOT to Use` 边界
6. pm.md worktree_role=conductor, phase=3
7. tier 全部 'default' (不引 optional/extended)
8. partial anatomy check 跑通

## 7 expert 角色定义

| ID | Name | worktree_role | review_group | phase | 触发症状 |
|---|---|---|---|---|---|
| `kallax.architect.001` | 🏗️ 架构 | master | A | 1 | 架构边界/选型争议 |
| `kallax.backend.001` | 💻 后端 | performer | A | 2 | 接口慢/DB 撑不住 |
| `kallax.frontend.001` | 🎨 前端 | performer | B | 2 | 页面卡/组件乱 |
| `kallax.ux.001` | 🖌️ UX | performer | B | 2 | 交互难用/流程不顺 |
| `kallax.product.001` | 📋 产品 | master | A | 1 | 功能优先级/砍哪个 |
| `kallax.security.001` | 🛡️ 安全 | performer | B | 2 | 系统风险 (path/inject/auth/race/fd) |
| `kallax.pm.001` | 🧭 PM/Conductor | conductor | A | 3 | 任务规划+ensuring (跨 ticket 协调) |

## KALLAX 专属 frontmatter 字段 (EKET 没有)

```yaml
---
id: kallax.<role>.001          # EKET 有
name: <中文显示名>              # EKET 有
tier: default                   # EKET 有, KALLAX 全部 default
worktree_role: <master|conductor|performer>  # NEW: 三角角色
review_group: <A|B|AB>          # NEW: 2-Group review 归属
phase: <1|2|3>                  # EKET 有
rationalizations_count: 6       # EKET 有, KALLAX 硬下限
version: 1.0.0                  # NEW: semver, 给 staleness metric 用
last_reviewed: 2026-06-07       # NEW: 给 anatomy aging 绑定 EPIC 周期
tickets_served: []              # NEW: 反向索引, EPIC 关闭时自动追加
---
```

## 7 节 full anatomy 模板 (借 EKET, 内容 KALLAX 化)

每文件必含 (章节顺序固定):
1. `mantras` (3 句口号)
2. `personality` (MBTI + traits + strengths/weaknesses)
3. `background` (experience + domain_expertise + notable_skills)
4. `thinking_framework` (4 个思考维度)
5. `analysis_focus` (5 个分析锚点)
6. `output_format` (YAML 4 节模板, C ticket 完成后填)
7. `Common Rationalizations` (>=6 行, 借口+反驳二元组)

额外 5 节:
- `When to Use` (3 行)
- `When NOT to Use` (3 行, security.md 必带合规/法律/业务边界)
- `Process` (5 步流程)
- `Red Flags` (>=5 条)
- `Verification` (3 checkbox, 末尾强制, D ticket 完成后填 4-Level)

## security.md When NOT to Use 强制边界

```markdown
## When NOT to Use
- **合规审计** (SOC2/GDPR/HIPAA/PCI-DSS) → 外部 Compliance 顾问
- **法律风险** (许可证/合同/ToS) → 外部 Legal 顾问
- **业务风控** (信用/欺诈/反洗钱) → 业务方主导, 合规配合

## Scope Boundary
本 persona 聚焦**系统级安全风险**:
- 路径穿越 (path traversal)
- 注入 (SQL/Command/JSON/Log)
- 认证绕过 (auth bypass)
- 竞态 (race condition / TOCTOU)
- 文件描述符泄漏 (fd leak)
- 进程孤儿 (zombie / orphan)
```

## 文件范围

7 个 NEW 文件, 无 excludes:
- `.kallax/experts/default/architect.md`
- `.kallax/experts/default/backend.md`
- `.kallax/experts/default/frontend.md`
- `.kallax/experts/default/ux.md`
- `.kallax/experts/default/product.md`
- `.kallax/experts/default/security.md`
- `.kallax/experts/default/pm.md`

## ⚠️ 阻塞说明

无. 此 ticket 是 EPIC-021 的基础, 必须**第一个完成**. B/C/D/E 都依赖它.

## 预估工时

1.8 小时 (7 文件, 0.25h/文件, 含 7 节模板填充)

## 2-Group review 期望

- **A 组 (Forward)**: 校验 KALLAX 5 字段填全, 7 节齐全, 数值合理
- **B 组 (Attack)**: 找 security.md 的 When NOT to Use 边界是否漏场景, 找 pm.md 是否真能跨 ticket 协调, 找 mantras 是否内化 (不是空话)

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 17:00 UTC | ready | master_main | 创建 |

# KALLAX - Claude Code Integration

> KALLAX = Knowledge-Augmented Leveraged Learning Agent eXecutor v3.0

---

## Setup (3 步)
`cargo install kallax` → `kallax init` → `kallax master:start`

## 身份确认
查 `.kallax/state/instance_config.yml` 中 `role:` 字段, 或 `/kallax-start` 自动检测. 4 角色 → [docs/4-roles.md](docs/4-roles.md).

## 12 Active Rules (operational summary)

| # | Rule | 1-line 落地 |
|---|------|------------|
| 1 | 并行隔离强制化 (P0) | Performer 必在独立 worktree, Conductor 派单前查文件不重叠 |
| 2 | 错误处理严格化 (P0) | 生产代码禁 expect/panic/unwrap, 用 Result<T,E> |
| 3 | 产出验证机制 (P0) | Conductor 必验产出真实性, 不依赖 agent 自述 |
| 4 | 资源管理规范化 (P1) | 缓存必配 TTL (LRU + max + ttl) |
| 5/8 | 类型安全 + Rule of 500 (P1) | TS strict + PR 净变更 ≤ 500 行, 4 档分级 |
| 6/7 | 经验沉淀 + PHASE 闭环 (P0) | EPIC 交付 4 件套 (A+B review / 文档 / LESSONS / 终审) |
| 9 | PR ~100 行上限 (P1) | 单 PR ≤ 100, 4 档分级, 跟 Rule of 500 互为互补 |
| 10 | Anti-Fabrication (P0) | 3 anti-fab 工具 pre-commit 必跑 (test-case / kpi / scope) |
| 11 | Master 写代码禁令 (P0) | Master 默认禁写, 极端情况需主公 explicit 拍 |
| 12 | 质量 ensure (P1) | expert > 50 必跑 5 维 audit (Schema/Tier/M1/Trigger/Domain) |
| 14 | 3 模式决策权 (P0) | ai-auto / ai-copilot / manual, decision-gate 复杂才问 |
| 15 | Performer sub-role + handoff (P0) | coder/reviewer/tester/docs, handoff_depth L1-L4 强制校验 |

详细 Rule 文本 / 教训 / 来源 / 红线 → [docs/5-levels.md](docs/5-levels.md) + [docs/4-roles.md](docs/4-roles.md).

## 9 类别 group 索引

| 类别 | 主题 | 联合 Rule |
|------|------|-----------|
| 1. 隔离与并行 | worktree / file-lock / session | Rule 1 + 14 + 17 |
| 2. 错误与验证 | Result / 产出真实性 / 5 levels / KPI 黑名单 | Rule 2 + 3 + 5/8 + 18 |
| 3. 资源与质量 | TTL / expert audit | Rule 4 + 12 |
| 4. 类型与安全 | strict / Rule of 500 / bypass / 见证 | Rule 5/8 + 30 + 31 |
| 5. 经验沉淀 | 4 件套 + PHASE + Anti-Fab / 文档卫生 / 新建 3 问 | Rule 6/7 + 10 + 9 Hard Rules Rule 6+7 |
| 6. 角色边界 | Master 禁写 / Conductor 禁越界 | Rule 11 + 13 |
| 7. 决策与模式 | 3 模式 + decision-gate | Rule 14 |
| 8. 流程与脚本 | PR 尺寸 / Subagent 5 步 / sub-role | Rule 5/8 + 9 + 16 + 15 |
| 9. 标签与治理 | 5 类标签 SOP | Rule 19 |

## 5 Levels (Fact-Forcing) → [docs/5-levels.md](docs/5-levels.md)
L1 git log SHA 真变 · L2 test stdout 实质 · L3 4-expert 接线 · L4 independent witness · L5 boundary 边界

## 4 Roles → [docs/4-roles.md](docs/4-roles.md)
master (1) → Conductor (分析/拆解/审核/合并) + Performer (coder/reviewer/tester/docs, 1+4 容量)

## 6 武器 (武器 1-6)
1. Hash-Chain Audit Log · 2. 5-Level Fact-Forcing · 3. Sub-Role Dispatch · 4. EPIC 4 件套 · 5. Hook Server · 6. Dashboard

## Q18 决策模型
KALLAX 评估 + 建议, 重大主公拍 (3 模式: ai-auto / ai-copilot / manual)

## KALLAX vs eket
独立项目, 互取所长 (eket 借 multi-agent 概念, KALLAX 实做 5 levels + 6 武器 + 1+4 容量)

## 30 命令 + 术语 → [docs/CHEATSHEET.md](docs/CHEATSHEET.md)

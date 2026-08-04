# EPIC-163 — Public/Private Boundary + Security Rules

> **借鉴 loopx `docs/public-private-boundary.md` + `loopx check` + AGENTS.md Security Rules**

## 起源

主公 2026-08-05 review loopx AGENTS.md 后拍板:

- **P1 高 ROI**: KALLAX 缺 Public/Private Boundary 检查
- 治理审计员报告: "KALLAX 无专门的 public-private boundary 文档 / 无 scan 工具检查 credentials / private context"
- 详细分析: `confluence/decisions/loopx-vs-kallax-governance-gap-2026-08-05.md`

## loopx 模式 (借鉴)

| 维度 | loopx | KALLAX (现状) | 差距 |
|------|-------|---------------|------|
| Boundary doc | `docs/public-private-boundary.md` (5078 字节) | 无 | **大** |
| Scanner | `loopx check` (tracked/untracked 双层) | 无 | **大** |
| 检测类别 | credentials / private paths / raw logs / sub-agent prompts | 无 | **大** |
| CONTRIBUTING.md 要求 | 贡献前必扫 | 无 | 中 |
| Security Rules 明文 | AGENTS.md Section | CLAUDE.md 无 | 中 |

## 设计 (3 步)

1. **`docs/public-private-boundary.md`** — 定义 public/private 分类 (跟 loopx 1:1 schema)
2. **`scripts/check-private-context.sh`** — 扫描器 (跟 loopx `loopx check` 1:1, treats boundary as file-state)
3. **CLAUDE.md Section 7 + CONTRIBUTING.md** — 加 Security Rules 明文 + 贡献前扫描要求

## 跟现有 EPIC 联合 (0 冲突)

| EPIC | 关系 |
|------|------|
| BE-14 1 ticket 1 subagent 串行 | ✅ 不破 |
| EPIC-054-A worktree 隔离 | ✅ 不破 |
| EPIC-069-D check-claim-evidence | ✅ 1:1 pattern 复用 (immutable check script) |
| EPIC-131/132 scan-dead-code | ✅ 退出码契约 0/1/2 1:1 |
| Rule 34 bugfix 独立复现 | ✅ 互补 (Rule 34 = reproduction 必填, EPIC-163 = private context 必扫) |

## Acceptance (10 项)

AC1~AC10 见 `jira/tickets/EPIC-163/ticket.json` `acceptance` 字段.

## Scope

- **新增**: `docs/public-private-boundary.md` + `scripts/check-private-context.sh` + 1 test + 1 confluence/decisions
- **改**: `scripts/hooks/pre-commit` + `CONTRIBUTING.md` + `CLAUDE.md`
- **不动**: 现有 source code + Rule + BE-14/EPIC-054-A

## 估时

~8 h (1 EPIC 周期), 含 5-Level Verify + 4-branch flow.

## Phase

PHASE-019 — LoopX Borrow (2026-08-05 主公拍板)
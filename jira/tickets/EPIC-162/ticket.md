# EPIC-162 — Skill 插件化 (同仓库 plugin, 跟 EPIC-167 submodule 双层)

> **借鉴 loopx 6 独立 skill 包 + install/status/uninstall CLI + activation gate + cross-host surface**
> **跟 EPIC-167 协同**: plugin + submodule 双层升级粒度

## 起源

主公 2026-08-05 召唤团队深度研究 https://github.com/huangruiteng/loopx, 跟 KALLAX 对比, 找出借鉴项拍板:

- **P0 最高 ROI**: Skill 插件化 (loopx 6 独立 skill 包 vs KALLAX 1 monolith skill)
- 详细分析: `confluence/decisions/loopx-vs-kallax-skill-gap-2026-08-05.md`

## loopx skill 模式 (借鉴)

| 维度 | loopx | KALLAX (现状) | 差距 |
|------|-------|---------------|------|
| 独立 skill 包 | 6 个 | 1 主 skill | **最大差距** |
| install CLI | `loopx project-skill install` | 缺 | **最大差距** |
| skill scope 标记 | `.loopx-skill-scope` (8 字节) | 缺 | 中 |
| 跨 host surface | `--surface codex/claude-code/opencode` | 缺 | **大** |
| activation gate | enabled_policy + 5 步 dry-run | 缺 | 中 |
| agents/ 子目录 | 每个 skill 有 | 部分有 | 中 |

## 设计 (5 步)

1. **拆 9 expert 到独立 skill 包** — `.claude/skills/kallax-experts/<role>/{SKILL.md, agents/*.md, .kallax-skill-scope}`
2. **skill CLI** — `scripts/skill/skill-manager.sh` 提供 `install/status/uninstall/list/enabled/disable` 6 子命令
3. **activation gate** — frontmatter 加 `enabled_policy`, 运行时检查, 5 步 dry-run
4. **cross-host surface** — `--surface codex/claude-code/opencode/cursor` 抽象
5. **install.sh 集成** — 跟 EPIC-160 Omnibus 1:1 pattern

## 跟现有 EPIC 联合 (0 冲突)

| EPIC | 关系 |
|------|------|
| BE-14 1 ticket 1 subagent 串行 | ✅ 不破 |
| EPIC-054-A worktree 隔离 | ✅ 不破 |
| EPIC-160 install.sh Omnibus | ✅ 集成 (skill scan/install 阶段) |
| EPIC-161 retrospective-routine | ✅ 6 子命令 pattern 复用 |
| EPIC-167 kallax-experts submodule | ✅ **1:1 协同** (plugin + submodule 双层) |
| EPIC-119 3-Class tool taxonomy | ✅ install 是 action class |
| Rule 34 bugfix 独立复现 | ✅ 互补 |

## Acceptance (15 项)

AC1~AC15 见 `jira/tickets/EPIC-162/ticket.json` `acceptance` 字段.

## Scope

- **新增**: 9 独立 skill 包 + `scripts/skill/skill-manager.sh` + 1 docs/reference + 1 confluence/decisions + 1 test
- **改**: `scripts/install.sh` + `CLAUDE.md`
- **不动**: 主 skill `kallax/SKILL.md` (向后兼容) + 现有 Rule + BE-14/EPIC-054-A

## 估时

~14 h (1 EPIC 周期), 含 5-Level Verify + 4-branch flow.

## Phase

PHASE-019 — LoopX Borrow (2026-08-05 主公拍板)
# EPIC-167 — kallax-experts submodule 化

> **借鉴主公 2026-08-05 拍板 — 把独立仓库 `kallax-experts` 改为 submodule 模式, 独立升级 + 互配合**

## 起源

主公 2026-08-05 review loopx + 跟当前项目对比时新指令:

> "有专门的 kallax-experts 项目, 是不是在某次升级的时候废弃了, 可以以它为当前项目的 submodule (独立升级迭代, 但是相互配合) 进行补充 experts 和额外 skills 的维护"

## 现状确认 (主公调研)

1. **独立仓库存在** — `/Users/chenchen/working/sourcecode/tools/dev-tools/kallax-experts`
   - remote: `https://github.com/godlockin/kallax-experts.git`
   - 已部署 GitHub Pages: godlockin.github.io/kallax-experts
   - 15 expert (tech/ai/design/marketing/research/business)
   - 3 配套 skill (expert-search/arena/compose)
   - tools/(search/arena/install/validate)
2. **历史废弃** — git log 显示:
   - `b2dd051 feat(kallax/experts): 专家系统 (参考 eket + agency-agents)`
   - `89fc2b4 feat(v3.1.0): 4 expert schema templates`
   - `2760a66 refactor(iter3): 删 3 装饰目录 (src/sdk/experts)` — 同时删 5 个 default expert `.md`
3. **当前解耦** — 无 submodule 关联, 跟主项目各自独立

## 跟 loopx 对比 (跨仓库升级粒度)

| 模式 | loopx | KALLAX (改进后) |
|------|-------|-----------------|
| 升级粒度 | 同仓库拆 6 skill | **双层**: 跨仓库 submodule + 同仓库 plugin |
| 引用方式 | hardcoded path | git submodule + plugin manifest |
| 跨仓库配合 | N/A | **互配合**: submodule 跟 monolith 协同 |

## 设计 (跟 EPIC-160/161/162 1:1 pattern)

1. **`.gitmodules`** — submodule 配置 (path + url + branch)
2. **`external/kallax-experts/`** — submodule 路径 (独立升级)
3. **`scripts/skill/skill-manager.sh`** — 加 `submodule-init/update/status` 3 子命令 (跟 EPIC-162 1:1)
4. **`scripts/install.sh`** — 加 `--install-submodule` + `--update-submodule` 阶段 (跟 EPIC-160 Omnibus 1:1)
5. **CLAUDE.md + docs/process.md** — 加 EPIC-167 引用 + submodule 升级流程

## 互配合机制 (双层升级粒度)

```
KALLAX 主项目
├── .claude/skills/kallax/SKILL.md          (主 skill, monolith)
├── .claude/skills/kallax-experts/<role>/   (EPIC-162 拆出的 plugin)
└── external/kallax-experts/                (EPIC-167 submodule)
    ├── experts/{tech,ai,design,...}/       (15 expert, 独立仓库迭代)
    ├── skills/{expert-search,arena,...}/   (3 skill, 独立仓库迭代)
    └── tools/{search,arena,install,...}/   (CLI 工具)
```

升级粒度:
- **Plugin 级** (EPIC-162) — 同仓库单 expert 迭代
- **Submodule 级** (EPIC-167) — 跨仓库批量 expert 迭代
- **Monolith 级** — 主项目整体迭代

## 跟现有 EPIC 联合 (0 冲突)

| EPIC | 关系 |
|------|------|
| BE-14 1 ticket 1 subagent 串行 | ✅ 不破 |
| EPIC-054-A worktree 隔离 | ✅ 不破, submodule 跟 worktree 共存 |
| EPIC-160 install.sh Omnibus | ✅ 1:1 pattern (install 集成) |
| EPIC-161 retrospective-routine | ✅ 1:1 pattern |
| EPIC-162 skill 插件化 | ✅ **1:1 协同** (plugin + submodule 双层) |
| EPIC-119 3-Class tool taxonomy | ✅ submodule init/update 是 action class |
| Rule 34 bugfix 独立复现 | ✅ 互补 |

## Acceptance (15 项)

AC1~AC15 见 `jira/tickets/EPIC-167/ticket.json` `acceptance` 字段.

## Scope

- **新增**: `.gitmodules` + `external/kallax-experts/` (submodule) + 1 test + 1 docs/reference
- **改**: `scripts/skill/skill-manager.sh` + `scripts/install.sh` + `docs/process.md` + `CLAUDE.md` + `.gitignore`
- **不动**: 现有 source code + Rule + BE-14/EPIC-054-A

## 估时

~10 h (1 EPIC 周期), 含 5-Level Verify + 4-branch flow.

## Phase

PHASE-019 — LoopX Borrow + Submodule (2026-08-05 主公拍板)

## 关键决策

1. **Submodule 路径** — `external/kallax-experts/` (跟 vendor/ pattern 1:1, 明确外部依赖)
2. **Branch 跟踪** — 跟踪 `main` 分支, 用 `git submodule update --remote` 拉最新
3. **向后兼容** — 旧 monolith 9 expert 保持, skill-manager 二选一 (submodule 优先, monolith fallback)
4. **互配合时机** — submodule 仓库迭代时, KALLAX 主项目自动同步 (lock file 记录)
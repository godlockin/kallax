---
paths:
  - scripts/install.sh
  - scripts/install*.sh
---

# Installation / Onboarding / Update (EPIC-160)

> **Path-scoped rule**: 只在 `scripts/install*.sh` 被修改时加载.

## 框架部件 inventory (主公 2026-08-03 拍板: 全部件 deploy)

| 来源 | 数量 | 目标 (Claude Code) | install.sh 处理 |
|---|---:|---|---|
| `.claude/commands/*.md` + `*.sh` | 30 | `~/.claude/commands/` | ✅ |
| `.claude/skills/kallax/SKILL.md` + sub | 20+ | `~/.claude/skills/kallax/` | ✅ |
| `.claude/skills/caveman/` | ~5 | `~/.claude/skills/caveman/` | ✅ |
| `.claude/rules/*.md` (EPIC-159) | 4 | `~/.claude/rules/` | ✅ (per EPIC-160) |
| `.claude/hooks/*.sh` | 2 | `~/.claude/hooks/` | ✅ (per EPIC-160) |
| `experts/*.md` + `index/*.yml` | 5 | `~/.claude/experts/` | ✅ (per EPIC-160) |
| `.claude/settings.json` | 1 | `~/.claude/settings.json` | ✅ |

## 3 大 flag (EPIC-160)

### `--update`

区别首次 install (`--target`) vs 升级 update. 升级走 symlink mode 不破坏 user-customized files. Per install.sh:235 已有的 symlink mode 1:1.

### `--inventory`

列 source→target 映射表, 透明可验证 (跟 EPIC-069-D check-claim-evidence 1:1).

### `--skip-{rules,experts,hooks}` (3 新 skip flag)

跟现有 `--skip-{cli,skills,commands}` 1:1 模式, 让用户 opt-out 单部件.

## 0 改 source code, 0 增 Rule

install.sh 改动是 docs/tooling, 不动 immutable scripts / Rule 体系.

## Reference

- EPIC-160 ticket: `jira/tickets/EPIC-160/`
- 完整 inventory: `bash scripts/install.sh --inventory`
- 升级用法: `bash scripts/install.sh --update`
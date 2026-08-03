# EPIC-160 — install.sh Omnibus

> **Origin**: 主公 2026-08-03 拍板 — "kallax 里的 command、rules、experts…等等都是框架的一部分, 在新环境 onboarding 以及 update 的时候都应该一并部署和升级".

## 当前 install.sh 覆盖率 (~50%)

| 部件 | 当前状态 | Files |
|---|---|---:|
| `.claude/commands/` | ✅ install | 30 |
| `.claude/skills/kallax/` (顶层) | ✅ install | 1 SKILL.md |
| `.claude/skills/kallax/{default,extended,scripts,skills}/` | ❌ 0 install | ~12 |
| `.claude/skills/caveman/` | ❌ 0 install | ~5 |
| `.claude/rules/` (EPIC-159 新增) | ❌ 0 install | 4 |
| `experts/` | ❌ 0 install | 5 |
| `.claude/hooks/` | ⚠️ settings.json ref 但不显式 install | 2 |
| `.claude/settings.json` | ✅ install | 1 |

**Total ~80 files / 当前 ~50% 已 install**.

## 3 大改动

### 1. `--update` flag

区别首次 install (--target) vs 升级 update. 升级时走 symlink mode 不破坏 user-customized files.

### 2. `--inventory` flag

列 source→target 映射表, 透明可验证 (跟 EPIC-069-D check-claim-evidence 1:1).

### 3. 全部件 install

rules/ + experts/ + skills/{kallax/{default,extended,scripts,skills},caveman}/ 全 install.

## scope

- 改: scripts/install.sh
- 加: tests/ + .claude/rules/installation.md + docs/reference/
- 不动: source code / immutable scripts / CLAUDE.md 主文件

## Acceptance

AC1~AC12 见 `jira/tickets/EPIC-160/ticket.json` `acceptance` 字段.

## 估时

~3 h (1 EPIC 周期, 含 5-Level Verify + 4-branch flow).
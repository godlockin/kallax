# KALLAX Installation & Update — EPIC-160 Omnibus

> **Reference doc** (lazy load, manual): install.sh 全部件 deploy + 升级 update 用法. 主公 2026-08-03 拍板 framework 全部件 (commands/skills/rules/experts/hooks/settings) 在新环境 onboarding + update 时一并部署.

## Usage

```bash
# Default install (auto-detect 10 AI tools + Claude Code 全部件)
./scripts/install.sh

# List inventory (transparent source→target mapping)
./scripts/install.sh --inventory

# Update existing install (symlink mode, no overwrite user files)
./scripts/install.sh --update

# Skip specific components (跟现有 --skip-cli/--skip-skills/--skip-commands 1:1)
./scripts/install.sh --skip-rules    # don't deploy .claude/rules/
./scripts/install.sh --skip-experts  # don't deploy experts/
./scripts/install.sh --skip-hooks    # don't deploy .claude/hooks/

# Dry-run (preview without installing)
./scripts/install.sh --dry-run
```

## Inventory (per EPIC-160)

| SOURCE | TARGET (Claude Code) | FILES |
|--------|----------------------|------:|
| `.claude/skills/` | `~/.claude/skills/` | 20 |
| `.claude/commands/` | `~/.claude/commands/` | 62 |
| `.claude/rules/` (EPIC-159) | `~/.claude/rules/` | 5 |
| `experts/` | `~/.claude/experts/` | 5 |
| `.claude/hooks/` | `~/.claude/hooks/` | 2 |
| `.claude/settings.json` | `~/.claude/settings.json` | 1 |
| **Total** | | **95** |

## 4 install function (新增)

1. `install_rules_for_tool()` — `~/.claude/rules/` (EPIC-159 path-scoped lazy load)
2. `install_experts_for_tool()` — `~/.claude/experts/` (4 .md + 1 .yml index)
3. `install_hooks_for_tool()` — `~/.claude/hooks/` (post-edit.sh + UserPromptSubmit.sh)
4. `print_inventory()` — 列 source→target 映射, 跟 EPIC-069-D 透明可验证 1:1

## 跟现有 Rule 联合 (0 冲突)

- **EPIC-069-D check-claim-evidence**: ✅ `--inventory` mode 透明可验证
- **EPIC-074 4-branch flow**: ✅ install.sh 改动走 4-PR
- **EPIC-159 .claude/rules/*.md**: ✅ 跟 .claude/skills/ 1:1 install
- **install.sh:235 symlink mode**: ✅ `--update` 复用, 不破坏 user files

## 0 增 Rule, 0 增 immutable script, 0 改 source code

## Reference

- EPIC-160 ticket: `jira/tickets/EPIC-160/`
- `.claude/rules/installation.md` (path-scoped, paths: `scripts/install*.sh`)
- Tests: `bash tests/integration/install-omnibus.test.sh` (13/13 PASS)
- Inventory: `bash scripts/install.sh --inventory`
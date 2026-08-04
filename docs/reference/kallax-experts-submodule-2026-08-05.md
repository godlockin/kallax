# KALLAX Experts Submodule — EPIC-167

> **Reference doc** (lazy load, manual): `external/kallax-experts/` submodule 用法 + 互配合机制 + 独立升级流程. 主公 2026-08-05 拍板: 独立仓库 `kallax-experts` 改为 submodule, 独立升级 + 互配合.

## 快速开始

```bash
# 1. Clone with submodule (fresh install)
git clone --recurse-submodules https://github.com/godlockin/kallax.git
cd kallax

# 2. Or add submodule to existing clone
git submodule add https://github.com/godlockin/kallax-experts.git external/kallax-experts

# 3. Update to latest
git submodule update --remote external/kallax-experts
git add .gitmodules external/kallax-experts
git commit -m "chore(experts): update submodule to latest"
```

## 双层升级粒度

KALLAX v3.32.12 采用 **双层升级粒度** (跟 EPIC-162 plugin 1:1 协同):

```
KALLAX 主项目
├── .claude/skills/kallax/SKILL.md          (monolith, 主项目整体迭代)
├── .claude/skills/kallax-experts/<role>/   (EPIC-162 plugin, 同仓库细粒度)
└── external/kallax-experts/                (EPIC-167 submodule, 跨仓库批量)
    ├── experts/{tech,ai,design,...}/       (15 expert, 独立仓库迭代)
    ├── tools/{search,arena,install,...}/   (9 CLI tools, 独立仓库迭代)
    └── docs/                               (GitHub Pages source)
```

| 层级 | 路径 | 升级方式 | 粒度 |
|------|------|----------|------|
| Monolith | `.claude/skills/kallax/` | `git commit/PR` 主项目 | 粗 |
| Plugin (EPIC-162) | `.claude/skills/kallax-experts/` | `git commit/PR` 同仓库 | 细 |
| Submodule (EPIC-167) | `external/kallax-experts/` | 跨仓库 PR + `git submodule update --remote` | 批量 |

## 互配合机制

**场景**: `kallax-experts` 独立仓库迭代时, KALLAX 主项目同步更新.

```
kallax-experts 仓库 (独立迭代)
    │
    ├── commit → PR → merge to miao/main
    │
    └── KALLAX 主项目:
        git submodule update --remote external/kallax-experts
        git add .gitmodules external/kallax-experts
        git commit -m "chore(experts): sync with kallax-experts@<hash>"
        → PR → merge (KALLAX 4-branch flow)
```

**Lock file**: `.gitmodules` + parent commit's submodule ref = lock file (跟 npm package-lock 1:1).

**互配合时机**: 独立仓库迭代不阻塞主项目; 主项目可选择 `git submodule update --remote` 时机.

## skill-manager.sh (EPIC-167)

```bash
# Submodule layer (EPIC-167)
./scripts/skill/skill-manager.sh submodule-init      # clone/register
./scripts/skill/skill-manager.sh submodule-update    # pull latest
./scripts/skill/skill-manager.sh submodule-status    # show commit + branch

# Plugin layer (EPIC-162)
./scripts/skill/skill-manager.sh install --role=architect
./scripts/skill/skill-manager.sh status
./scripts/skill/skill-manager.sh uninstall --role=architect
```

**向后兼容 (AC7)**: submodule 优先, monolith fallback.

## install.sh 集成 (EPIC-167)

```bash
# During fresh install
./scripts/install.sh --install-submodule

# During upgrade
./scripts/install.sh --update-submodule

# Opt-out
./scripts/install.sh --skip-submodule

# Dry-run
./scripts/install.sh --install-submodule --dry-run
./scripts/install.sh --update-submodule --dry-run
```

## Submodule 内容

| 目录 | 内容 | 数量 |
|------|------|-----:|
| `experts/tech/` | backend-architect, devops-engineer, security-engineer, qa-engineer, sre-engineer, mobile-engineer, performance-engineer | 7 |
| `experts/ai/` | llm-engineer, data-analyst | 2 |
| `experts/design/` | ux-researcher, product-manager | 2 |
| `experts/business/` | legal-advisor, finance-analyst, legal-compliance | 3 |
| `tools/` | search.sh, arena.sh, compose.sh, expert-resolver.sh, validate.sh, build-experts.py, build-html.py, inject-use-when.py, use-when-data.json | 9 |
| `docs/` | GitHub Pages source | 12 |

**总计**: 15 expert + 9 tools + docs (GitHub Pages: godlockin.github.io/kallax-experts).

## .gitmodules 格式

```ini
[submodule "external/kallax-experts"]
    path = external/kallax-experts
    url = https://github.com/godlockin/kallax-experts.git
    branch = miao
```

**注意**: 实际跟踪 `miao` 分支 (kallax-experts 稳定分支), 不是 `main`.

## 常见操作

```bash
# Check submodule status
git submodule status

# Update to latest remote
git submodule update --remote external/kallax-experts

# Re-clone from scratch
git submodule update --init --recursive

# View submodule log
git -C external/kallax-experts log --oneline -5

# Switch submodule branch
git config -f .gitmodules submodule.external/kallax-experts.branch main
git submodule sync
```

## 跟 loopx 对比

| 维度 | loopx | KALLAX (EPIC-167) |
|------|-------|-------------------|
| 升级粒度 | 同仓库拆 6 skill 包 | 双层: 跨仓库 submodule + 同仓库 plugin |
| 引用方式 | hardcoded path | git submodule + plugin manifest |
| 跨仓库配合 | N/A | 互配合: submodule 跟 monolith 协同 |
| 版本锁定 | package.json | .gitmodules + parent commit |

## 0 增 Rule, 0 改 source code

## Reference

- EPIC-167 ticket: `jira/tickets/EPIC-167/`
- `.gitmodules` (submodule config)
- `external/kallax-experts/` (submodule content)
- `scripts/skill/skill-manager.sh` (submodule management)
- `scripts/install.sh` (EPIC-167 integration)
- `docs/process.md` (submodule upgrade flow)
- Tests: `bash tests/integration/kallax-experts-submodule.test.sh`

# loopx vs KALLAX Skill Gap Analysis

> **Date**: 2026-08-05
> **Decision**: EPIC-162 — Skill plugin architecture (主公拍板 P0: ROI 最高)
> **Reference**: https://github.com/huangruiteng/loopx

## Background

主公 2026-08-05 召唤团队深度研究 loopx skill体系, 跟 KALLAX 对比, 找出最大差距和最高 ROI 改进点.

## loopx Skill System (Key Features)

| Feature | Implementation | File |
|---------|---------------|------|
| 6 独立 skill 包 | `skills/<name>/SKILL.md` + `agents/` | loopx repo |
| install CLI | `loopx project-skill install` | loopx CLI |
| skill scope marker | `.loopx-skill-scope` (8 字节) | loopx skill dir |
| cross-host surface | `--surface codex/claude-code/opencode` | loopx CLI |
| activation gate | enabled_policy + 5 步 dry-run | loopx skill loader |
| agents/ 子目录 | 每个 skill 有独立 agents/ | loopx skill dir |

## KALLAX Current State

| Feature | Status | Gap |
|---------|--------|-----|
| 独立 skill 包 | 1 主 skill (kallax/) | **最大差距** |
| install CLI | 缺 | **最大差距** |
| skill scope marker | 缺 | 中 |
| cross-host surface | 缺 | **大** |
| activation gate | 缺 | 中 |
| agents/ 子目录 | 部分有 (kallax/default/, extended/) | 中 |

## Gap Analysis

### Critical Gaps (P0 Priority)

1. **独立 skill 包**: KALLAX 9 expert 全部内嵌 monolith skill, 无法独立 install/uninstall/enable/disable
2. **install CLI**: 无 skill manager, 依赖 install.sh 全量 install

### High Gaps (P1 Priority)

3. **cross-host surface**: 仅支持 Claude Code, 无法跨 Codex/Cursor/OpenCode 复用

### Medium Gaps (P2 Priority)

4. **skill scope marker**: 无 scope 标记, 无法快速识别 skill 用途
5. **activation gate**: 无 enabled_policy 检查 + 5 步 dry-run

## ROI Analysis

| Improvement | Impact | Effort | ROI |
|-------------|--------|--------|-----|
| Skill plugin 拆包 | 独立管理, 按需启用 | 高 | **最高** |
| skill-manager CLI | 标准化 install/uninstall | 中 | **高** |
| cross-host surface | 跨工具复用 | 中 | **高** |
| scope marker | 快速识别 | 低 | 中 |
| activation gate | 防止误激活 | 低 | 中 |

## Decision

**EPIC-162 (P0)**: Skill plugin 架构, 借鉴 loopx 6 独立 skill 包模式.

**Key design decisions**:
1. **9 expert 拆包**: `.claude/skills/kallax-experts/<role>/{SKILL.md, agents/, .kallax-skill-scope}`
2. **skill-manager.sh**: 6 plugin 命令 + 3 submodule 命令
3. **enabled_policy field**: SKILL.md frontmatter
4. **cross-host surface**: 4 host 抽象 (codex/claude-code/opencode/cursor)
5. **activation gate**: 5 步 dry-run

**跟 EPIC-167 协同**: plugin + submodule 双层升级粒度.

## Implementation Plan

| Phase | Task | Deliverable |
|-------|------|-------------|
| Phase 1 | 拆 9 expert 到独立 skill 包 | `.claude/skills/kallax-experts/` |
| Phase 2 | 实现 skill-manager.sh CLI | `scripts/skill/skill-manager.sh` |
| Phase 3 | install.sh 集成 | `--scan-skill` + `--install-skill` |
| Phase 4 | Integration tests | `tests/integration/skill-plugin.test.sh` |
| Phase 5 | Docs + 5-Level Verify | reference doc + verify |

## Reference

- loopx repo: https://github.com/huangruiteng/loopx
- KALLAX skill: `.claude/skills/kallax/SKILL.md`
- EPIC-162 ticket: `jira/tickets/EPIC-162/`

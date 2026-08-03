# EPIC-159 — CLAUDE.md 治理 2.0

> **Anthropic 官方 CLAUDE.md 硬阈值 ≤ 200 行 (Memory docs: "Files over 200 lines consume more context and may reduce adherence"). 当前 307 行 / 19KB / 17 sections — 超阈值 53%.**

## 起源

主公 2026-08-03 review 当前 CLAUDE.md + 派 research expert 调研 2025-2026 prompt 工程最佳实践, 拍板:

- ✅ trim CLAUDE.md 307→≤ 200 行
- ✅ 顶部按 frequency 重排 (U-shape bias + Lost-in-the-Middle 教训)
- ✅ 拆 `.claude/rules/*.md` 4 文件 (Anthropic path-scoped lazy load 机制)
- ❌ NO XML tags

## Research 数据点

| Source | Finding |
|---|---|
| [Anthropic Memory docs](https://code.claude.com/docs/en/memory) | CLAUDE.md ≤ 200 行硬阈值 |
| [Anthropic Context Engineering Blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 1.7K token 范例 / sub-agent 1K-2K return |
| [Lost in the Middle (Liu et al., 2023)](https://arxiv.org/abs/2307.03172) | U-shape position bias |
| [RULER (Hsieh et al., 2024)](https://arxiv.org/abs/2404.06654) | claimed vs effective context gap |
| [.claude/rules/ docs](https://code.claude.com/docs/en/memory) | `paths:` frontmatter 是真 lazy load 机制 |

## 改动

### CLAUDE.md 主文件 (307→≤200 行)

**可 trim** (Claude 自主可 derive):
- Setup 3 步 (kallax --help 已有)
- 3 价值观 / 5 levels / 4 roles / 4 价值 自我描述

**保留** (pitfalls / 主公拍板, Claude derive 不到):
- 5-Level Verify 新规 (EPIC-069-D 假 PASS 教训)
- Rule 34 (EPIC-152 独立复现)
- 4-branch flow + 备案 (EPIC-074 + EPIC-155)
- 5-Level 硬化 (EPIC-131/132 教训)
- CLI 执行规范 (whisper-cpp + EPIC-026-A 教训)
- state.json 路径约定 (EPIC-068-A 9 script 实战坑)

### 顶部按 frequency 重排

按 U-shape bias + Lost-in-the-Middle 教训:
1. **CLI 执行规范** (每次工具调用, failure cost 最高)
2. **5-Level Verify 新规** (每次 PR)
3. **Rule 34** (每次 bugfix)
4. **4-branch flow** (每次 ship)
5. 5-Level 硬化 / state.json / 4 immutable / EPIC-114 / 备案 (中段, 低频)

### 拆 `.claude/rules/*.md` 4 文件

```
.claude/rules/
├── state-json.md       # paths: .kallax/**, scripts/permission/**
├── testing.md          # paths: **/*.test.ts, rust/**/tests/**
├── branch-flow.md      # paths: .github/workflows/**, **/CHANGELOG.md
└── strict-tsconfig.md  # paths: node/**/tsconfig.json, node/**/*.ts
```

## scope

- 改: CLAUDE.md + 4 个 .claude/rules/*.md
- 不动: docs/reference/* (15 个 lazy load doc 已存在)
- 不动: source code / immutable scripts / EPIC-157 / EPIC-158

## Acceptance

AC1~AC10 见 `jira/tickets/EPIC-159/ticket.json` `acceptance` 字段.

## 估时

~2 h (1 EPIC 周期, 含 5-Level Verify + 4-branch flow).
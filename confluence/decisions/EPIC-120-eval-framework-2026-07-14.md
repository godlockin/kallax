# EPIC-120 — 自动化 PR Eval Framework (OpenAI Evals 借鉴)

> Date: 2026-07-14 | 2 tickets (A/B) | OpenAI Evals ref

## 起源

主公 2026-07-14 研究 OpenAI blog 后 explicit "要"。

**OpenAI Evals 核心观点**:

> "Creating high-quality evals is among the most impactful activities for LLM development."

**KALLAX 现状**: 5-Level Verify 是人工评审，PR merge 前没有自动化 gate 检查 lint/tsc/vitest。

## OpenAI Eval 设计原则

1. **Thematically consistent**: eval 数据来自同 domain
2. **Challenging**: 人类专家能做但 LLM 有空间提升
3. **Directionally clear**: 有明确评分标准或参考答案
4. **Carefully crafted**: 工程师写 prompt，人工 spot-check

## KALLAX PR Eval 设计

每 PR 必须通过 3 项自动化检查:

| Eval | 命令 | 通过标准 |
|------|------|---------|
| **Lint** | `cd node && npx eslint . --max-warnings 0` | exit 0 |
| **TypeScript** | `cd node && npx tsc --noEmit` | exit 0 |
| **Tests** | `cd node && npx vitest run --reporter=json` | exit 0 |

**Exit code 语义**:
- `0`: 全部 PASS
- `1`: 至少一项 FAIL
- `2`: 环境错误 (gh CLI 缺失, node_modules 不存在)

## 架构

```
scripts/verify/pr-eval.sh
├── 输入: PR# 或 commit SHA
├── 读取: PR files (gh api)
├── 执行: eslint + tsc + vitest (并行)
├── 输出: JSON {lint: {errors, warnings}, tsc: {errors}, vitest: {failures, passed}}
└── exit: 0 = all pass, 1 = fail, 2 = error
```

## 联动

- EPIC-069-D (check-claim-evidence — claim 层)
- EPIC-117 (ACI — tool 接口统一)
- EPIC-118 (expertise — agent 能力分层)
- EPIC-119 (tool taxonomy — Data/Action/Orchestration)

## OpenAI 原文

```
Good eval criteria:
1. Thematically consistent (same use case/domain)
2. Challenging (human expert could do well)
3. Directionally clear (high quality reference answers or exhaustive rubrics)
4. Carefully crafted (engineer prompts, spot-check results)
```

Source: [OpenAI Evals README](https://github.com/wd0517/openai-evals/blob/main/README.md)

# Release Budget — 每 release 砍 1 (EPIC-117-C)

> Anthropic《Building Effective Agents》Simplicity 原则:
> "add complexity only when it demonstrably improves outcomes"

## 规则

每个 release (tag `vX.Y.Z`) commits 范围内, 至少要有 **1 项删除**:
- `## Rule` / `### Rule` 从 CLAUDE.md 移除
- `/kallax-xxx` slash command 移除
- `scripts/**/*.sh` 文件删除

`scripts/verify/check-release-budget.sh` 在 release tag 时跑, 0 删除则 FAIL。

## 为什么

**KALLAX complexity via accretion 现状** (2026-07-14):
- 26 commands
- 5 memory layers
- 11 dispatch checklist items
- 11 post-process steps
- 34+ hard-rules
- 56 verify scripts

每 release 只加不减 → 认知负担 exponential 增长。

## Bypass

`KALLAX_RELEASE_BUDGET_BYPASS=1` — 主公明确批准的 release 可跳过, 但必须在 release notes 说明理由。

## 联动

- CLAUDE.md v2.4.1 Rule 合并反思 (已有共识但无强制)
- EPIC-069-D fact-forcing (类似 hook 层强制)

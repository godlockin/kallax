# First-Screen Review Gate — EPIC-173

> **Date**: 2026-08-05
> **Source**: loopx AGENTS.md First-Screen Review Gate
> **主公 Phase 5 D 拍板**

## Overview

First-Screen Review Gate 要求 README/dashboard 改前主公预览机制, 跟 loopx AGENTS.md 1:1 联合.

## 5 First-Screen Paths

| # | Path | Description |
|---|------|-------------|
| 1 | `README.md` | 主入口 |
| 2 | `README.en.md` | English version |
| 3 | `web/index.html` | hosted frontstage |
| 4 | `web/showcase/index.html` | showcase index |
| 5 | `docs/showcases/README.md` | showcase catalog |

## Scanner

**Script**: `scripts/check-first-screen.sh`

**Exit codes**:
- 0 = PASS (无 first-screen 改动 或 已批准)
- 1 = FAIL (first-screen 改动未批准, fail-closed)
- 2 = BLOCKED-env (环境异常)

**Options**:
- `--staged-only` — 只扫 staged files (pre-commit hook 用)
- `--approved` — 标记 first-screen 改动已批准

## Approval Flow

### 方式1: env var
```bash
KALLAX_FIRST_SCREEN_APPROVED=1 git commit ...
```

### 方式2: marker file
```bash
echo "approved_by: master" > .first-screen-approved
echo "approved_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> .first-screen-approved
```

## Ticket Schema

```json
{
  "verification": {
    "first_screen_preview": "<preview URL or description>",
    "first_screen_approved_by": "<approver ID>"
  }
}
```

## Pre-commit Hook Integration

`scripts/hooks/pre-commit` 集成:
```bash
for _law in check-decorative-claim ... check-first-screen; do
  if ! KALLAX_STAGED_ONLY=1 bash "$_law_path" >/dev/null 2>&1; then
    exit 1
  fi
done
```

## 跟 EPIC-163 1:1 Pattern

| 维度 | EPIC-163 check-private-context | EPIC-173 check-first-screen |
|------|-------------------------------|----------------------------|
| 目的 | 防止 private context 泄露 | 防止 first-screen 未批准改动 |
| 检测 | 4 类 (credentials/private paths/raw logs/agent prompts) | 5 paths (README/showcase/frontstage) |
| 退出码 | 0/1/2 | 0/1/2 |
| 批准 | 无 | `KALLAX_FIRST_SCREEN_APPROVED=1` |

## 兼容性

- **0 改 source code** (除 jira/schemas/ticket-schema.json)
- **0 增 Rule, 0 增 immutable script**
- **跟 EPIC-159 path-scoped lazy load 1:1**
- **跟 EPIC-163 check-private-context 1:1**
- **跟 EPIC-074 4-branch flow 联合** (first-screen PR 必走 4-PR)

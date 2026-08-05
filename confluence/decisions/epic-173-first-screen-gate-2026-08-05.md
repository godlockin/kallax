# EPIC-173 First-Screen Review Gate — Decision Record

> **Date**: 2026-08-05
> **Source**: loopx AGENTS.md First-Screen Review Gate
> **主公 Phase 5 D 拍板**

## Problem Statement

README/dashboard 改前无主公预览机制, 可能导致:
- first viewport 未经审批改动
- hero block 未经审批改动
- primary CTA 未经审批改动
- opening navigation 未经审批改动

## Decision

借鉴 loopx AGENTS.md First-Screen Review Gate, 实现主公预览机制.

## 5 First-Screen Paths

| # | Path | Description |
|---|------|-------------|
| 1 | `README.md` | 主入口 |
| 2 | `README.en.md` | English version |
| 3 | `web/index.html` | hosted frontstage |
| 4 | `web/showcase/index.html` | showcase index |
| 5 | `docs/showcases/README.md` | showcase catalog |

## Implementation

### scripts/check-first-screen.sh

- scanner 检测 first-screen paths 改动
- 退出码: 0=PASS / 1=FAIL / 2=BLOCKED-env
- `--staged-only` flag (pre-commit hook 用)
- `--approved` flag (批准标记)

### Approval Flow

```bash
# 方式1: env var
KALLAX_FIRST_SCREEN_APPROVED=1 git commit ...

# 方式2: marker file
echo "approved_by: master" > .first-screen-approved
```

### pre-commit Hook Integration

`scripts/hooks/pre-commit` 加 check-first-screen 阶段 (跟 EPIC-163 1:1).

### Ticket Schema

```json
{
  "verification": {
    "first_screen_preview": "<preview URL or description>",
    "first_screen_approved_by": "<approver ID>"
  }
}
```

## 跟现有 EPIC 协同

| EPIC | 协同方式 |
|------|----------|
| EPIC-163 | 1:1 pattern (exit code 0/1/2, staged detection) |
| EPIC-159 | path-scoped lazy load 1:1 |
| EPIC-074 | 4-branch flow 联合 (first-screen PR 必走 4-PR) |
| EPIC-152 | verification field 1:1 |

## 兼容性

- **0 改 source code** (仅 jira/schemas/ticket-schema.json 改)
- **0 增 Rule, 0 增 immutable script**
- **跟 loopx AGENTS.md First-Screen Review Gate 1:1**

---
paths:
  - scripts/check-first-screen.sh
  - README*.md
  - web/index.html
  - web/showcase/index.html
  - docs/showcases/README.md
---

# First-Screen Review Gate (EPIC-173)

> **Path-scoped rule**: 只在 first-screen 文件被操作时加载.
> **来源**: loopx AGENTS.md First-Screen Review Gate (主公 2026-08-05 拍板)

## 5 First-Screen Paths (跟 loopx AGENTS.md 1:1)

1. `README.md` — 主入口
2. `README.en.md` — English version
3. `web/index.html` — hosted frontstage
4. `web/showcase/index.html` — showcase index
5. `docs/showcases/README.md` — showcase catalog

## 5 Rules

### Rule 1 — Preview Before Change

> Before committing, pushing, or self-merging changes that alter the first viewport, hero block, primary CTA, or opening navigation...

改 first-screen 前必须:
1. 主公预览 (show diff / screenshot)
2. 等批准
3. 记录 `verification.first_screen_approved_by`

### Rule 2 — Scanner Detection

`scripts/check-first-screen.sh` 检测:
- 5 first-screen paths 改动
- staged diff 触发
- 退出码: 0=PASS / 1=FAIL / 2=BLOCKED-env

### Rule 3 — Approval Flow

批准方式 (二选一):
```bash
# 方式1: env var
KALLAX_FIRST_SCREEN_APPROVED=1 git commit ...

# 方式2: marker file
echo "approved_by: master" > .first-screen-approved
echo "approved_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> .first-screen-approved
```

### Rule 4 — Ticket Schema

ticket.json 必含:
```json
{
  "verification": {
    "first_screen_preview": "<preview URL or description>",
    "first_screen_approved_by": "<approver ID>"
  }
}
```

### Rule 5 — pre-commit Hook Integration

`scripts/hooks/pre-commit` 集成 `check-first-screen.sh`:
- staged first-screen files 检测
- fail-closed (未批准则 block)
- bypass: `KALLAX_HOOK_BYPASS=1`

## 0 增 Rule, 0 增 immutable script

跟 EPIC-163 check-private-context 1:1 pattern 联合

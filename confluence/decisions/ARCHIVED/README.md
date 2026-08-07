# Archived Retrospectives

> These retrospectives have been archived because their content was merged into primary lesson documents.

| File | Reason | Redirect To |
|------|--------|-------------|
| `retrospective-v3.25.0-2026-07-14.md` | 37 lines; branch drift + Python/bash 3.2 lessons covered by epic-122-123-124-lessons | `confluence/memory/lessons/epic-122-123-124-lessons-2026-07-18.md` |
| `EPIC-117-simplicity-2026-07-14.md` | 36 lines; 内容被 retrospective-v3.23.0 覆盖 (含 5 教训 + 指标) | `retrospective-v3.23.0-2026-07-14.md` |
| `EPIC-118-expertise-aware-2026-07-14.md` | 51 lines; 内容被 retrospective-v3.24.0 覆盖 | `retrospective-v3.24.0-2026-07-14.md` |
| `EPIC-120-eval-framework-2026-07-14.md` | 65 lines; 内容被 retrospective-v3.26.0 覆盖 | `retrospective-v3.26.0-2026-07-14.md` |
| `EPIC-121-sandboxed-eval-2026-07-14.md` | 65 lines; 内容被 retrospective-v3.27.0 覆盖 | `retrospective-v3.27.0-2026-07-15.md` |
| `retrospective-v3.22.0-2026-07-14.md` | 62 lines; 内容合并入 retrospective-sprint-4-7 | `retrospective-sprint-4-7-epic-101-2026-07-09.md` |
| `retrospective-v3.23.0-2026-07-14.md` | 63 lines; 与 EPIC-117 主题重叠 | `EPIC-117-simplicity-2026-07-14.md` |
| `retrospective-v3.24.0-2026-07-14.md` | 51 lines; 与 EPIC-118 主题重叠 | `EPIC-118-expertise-aware-2026-07-14.md` |
| `retrospective-v3.26.0-2026-07-14.md` | 33 lines; 与 EPIC-120 主题重叠 | `EPIC-120-eval-framework-2026-07-14.md` |
| `retrospective-v3.27.0-2026-07-15.md` | 35 lines; 与 EPIC-121 主题重叠 | `EPIC-121-sandboxed-eval-2026-07-14.md` |

## Restoration

If you need content from an archived retrospective:

```bash
git log --all --full-history -- <file-path>
```

## 治理规则

1. **何时归档**: 重复内容被覆盖 / 数据过期已替代 / 设计未落地被显式 superseded
2. **归档三件套**: `git mv` (保 history) + README 加行 + 不删 (永久只读)
3. **恢复**: `git log --all --full-history -- <file>` 即可

## 归档批次

- 2026-07-30: v3.25 retrospective (1 篇, EPIC-122/123/124 lessons 覆盖)
- 2026-08-07: EPIC-117/118/120/121 + retrospective-v3.22/23/24/26/27 (9 篇, 内容重叠覆盖, EPIC-196)